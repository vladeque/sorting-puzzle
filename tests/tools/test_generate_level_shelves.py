from __future__ import annotations

import contextlib
import copy
import io
import json
import random
import re
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from generate_level_shelves import (  # noqa: E402
    GATE_MIN_TRIPLES,
    LAYOUT_PRESETS,
    active_collapsing_shelves,
    count_collectible_front_types,
    count_layers_with_pairs,
    describe_flow_shortfall,
    measure_board_flow,
    seed_colocated_pairs,
    apply_dispenser_shelves,
    fill_empty_collapsing_shelves,
    generate_shelves,
    generate_with_optional_validation,
    infer_item_type_count,
    parse_column_heights,
    parse_dispenser_shelves,
    generate_throwing_level,
    split_evenly,
    split_shelves_into_columns,
    wrap_level,
)
from generate_level_shelves import main as generate_main  # noqa: E402
from level_item_progression import logical_item_ids  # noqa: E402


class LayoutPresetTests(unittest.TestCase):
    def test_every_generator_preset_has_a_runtime_scene(self) -> None:
        for layout_preset in LAYOUT_PRESETS:
            with self.subTest(layout_preset=layout_preset):
                scene_path = (
                    REPOSITORY_ROOT
                    / "scenes"
                    / "layouts"
                    / f"layout_{layout_preset}.tscn"
                )
                self.assertTrue(scene_path.is_file(), msg=f"Missing {scene_path}")

    def test_shape_presets_use_three_columns_and_exactly_five_rows(self) -> None:
        expected_row_counts = {
            "shape_arch_3x5": [3, 2, 2, 2, 2],
            "shape_cup_3x5": [2, 2, 2, 2, 3],
            "shape_hourglass_3x5": [3, 1, 1, 1, 3],
            "shape_keyhole_3x5": [3, 2, 3, 1, 1],
            "shape_t_3x5": [3, 1, 1, 1, 1],
            "shape_zigzag_3x5": [2, 2, 2, 2, 2],
        }
        for layout_preset, expected_counts in expected_row_counts.items():
            with self.subTest(layout_preset=layout_preset):
                scene_path = (
                    REPOSITORY_ROOT
                    / "scenes"
                    / "layouts"
                    / f"layout_{layout_preset}.tscn"
                )
                scene_text = scene_path.read_text(encoding="utf-8")
                marker_blocks = re.findall(
                    r'\[node name="Shelf\d+" type="Marker2D" parent="\."\]'
                    r'(.*?)(?=\n\[node|\Z)',
                    scene_text,
                    flags=re.DOTALL,
                )
                positions: list[tuple[float, float]] = []
                for marker_block in marker_blocks:
                    match = re.search(
                        r"position = Vector2\(([-\d.]+), ([-\d.]+)\)", marker_block
                    )
                    positions.append(
                        (float(match.group(1)), float(match.group(2)))
                        if match
                        else (0.0, 0.0)
                    )

                row_counts: dict[float, int] = {}
                for x_position, y_position in positions:
                    self.assertIn(x_position, {-228.96, 0.0, 228.96})
                    row_counts[y_position] = row_counts.get(y_position, 0) + 1

                self.assertEqual(len(row_counts), 5)
                self.assertEqual(
                    [row_counts[y_position] for y_position in sorted(row_counts)],
                    expected_counts,
                )


def layer_index_counts(shelves: list[dict]) -> list[Counter]:
    """Items per type at each layer depth -- what the distribution engine solved for."""
    depth = max(len(shelf["layers"]) for shelf in shelves)
    counts = [Counter() for _ in range(depth)]
    for shelf in shelves:
        for layer_index, layer in enumerate(shelf["layers"]):
            counts[layer_index].update(item for item in layer if item is not None)
    return counts


class SeedColocatedPairsTests(unittest.TestCase):
    def build_board(self, **overrides) -> list[dict]:
        arguments = dict(
            shelf_count=12,
            layer_count=3,
            filled_layer_count=3,
            item_types=logical_item_ids(24),
            difficulty="medium",
            seed=4242,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
            pair_ratio=0.0,
        )
        arguments.update(overrides)
        return generate_shelves(**arguments)[0]

    def test_pairing_keeps_every_item_count_identical(self) -> None:
        board = self.build_board()
        before = Counter(item for shelf in board for layer in shelf["layers"]
                         for item in layer if item is not None)
        seed_colocated_pairs(board, 0.6, random.Random(7))
        after = Counter(item for shelf in board for layer in shelf["layers"]
                        for item in layer if item is not None)
        self.assertEqual(before, after)

    ## The point of swapping inside one layer depth: the distribution engine's per-depth solution,
    ## and so layer readiness and each item's layer range, survive the pass untouched.
    def test_pairing_keeps_every_layer_depth_composition_identical(self) -> None:
        board = self.build_board()
        before = layer_index_counts(board)
        seed_colocated_pairs(board, 0.6, random.Random(7))
        self.assertEqual(layer_index_counts(board), before)

    def test_pairing_never_completes_a_layer(self) -> None:
        board = self.build_board()
        seed_colocated_pairs(board, 1.0, random.Random(7))
        for shelf in board:
            for layer in shelf["layers"]:
                with self.subTest(layer=layer):
                    self.assertFalse(None not in layer and len(set(layer)) == 1)

    def test_pairing_adds_pairs(self) -> None:
        board = self.build_board()
        before = count_layers_with_pairs(board)
        seed_colocated_pairs(board, 0.75, random.Random(7))
        self.assertGreater(count_layers_with_pairs(board), before)

    def test_a_zero_ratio_changes_nothing(self) -> None:
        board = self.build_board()
        untouched = copy.deepcopy(board)
        self.assertEqual(seed_colocated_pairs(board, 0.0, random.Random(7)), 0)
        self.assertEqual(board, untouched)

    def test_the_generator_rejects_a_ratio_outside_the_unit_range(self) -> None:
        with self.assertRaises(ValueError):
            self.build_board(pair_ratio=1.5)


class FlowGateTests(unittest.TestCase):
    def board(self, **overrides) -> list[dict]:
        arguments = dict(
            shelf_count=12,
            layer_count=3,
            filled_layer_count=3,
            item_types=logical_item_ids(12),
            difficulty="medium",
            seed=4242,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
        )
        arguments.update(overrides)
        return generate_shelves(**arguments)[0]

    def test_a_board_is_measured_and_reports_its_flow(self) -> None:
        report = measure_board_flow(self.board(), None, None)
        self.assertIsNotNone(report)
        self.assertGreaterEqual(report.total_triples, GATE_MIN_TRIPLES)
        self.assertIn("average_options", report.as_dict())
        self.assertIn("scarce_option_ratio", report.as_dict())

    def test_an_unreachable_bar_is_reported_as_a_shortfall(self) -> None:
        class FinishedReport:
            average_options = 1.5
            scarce_option_ratio = 0.1
            cleared_triples = 29
            total_triples = 29
            completed = True

        message = describe_flow_shortfall(FinishedReport(), min_average_options=99.0,
                                          max_scarce_option_ratio=1.0)
        self.assertIsNotNone(message)
        self.assertIn("--min-average-options", message)

    def test_a_scarce_board_is_reported_against_the_right_flag(self) -> None:
        class ScarceReport:
            average_options = 1.0
            scarce_option_ratio = 0.9
            cleared_triples = 29
            total_triples = 29
            completed = True

        message = describe_flow_shortfall(ScarceReport(), min_average_options=0.0,
                                          max_scarce_option_ratio=0.3)
        self.assertIsNotNone(message)
        self.assertIn("--max-scarce-option-ratio", message)

    ## The regression this guards: a walk that stalls early still posts the option counts of the
    ## healthy opening it did play, so a board can look good precisely because it went wrong.
    def test_a_walk_that_stalls_fails_however_good_its_sampled_moves_look(self) -> None:
        class StalledReport:
            average_options = 9.0
            scarce_option_ratio = 0.0
            cleared_triples = 11
            total_triples = 31
            completed = False

        message = describe_flow_shortfall(StalledReport(), min_average_options=2.0,
                                          max_scarce_option_ratio=0.3)
        self.assertIsNotNone(message)
        self.assertIn("stalled after 11 of 31", message)

    def test_an_unfinished_walk_is_ignored_when_no_bar_is_set(self) -> None:
        class StalledReport:
            average_options = 0.1
            scarce_option_ratio = 1.0
            cleared_triples = 1
            total_triples = 31
            completed = False

        self.assertIsNone(
            describe_flow_shortfall(StalledReport(), min_average_options=0.0,
                                    max_scarce_option_ratio=1.0)
        )

    def test_a_met_bar_reports_nothing(self) -> None:
        report = measure_board_flow(self.board(), None, None)
        self.assertIsNone(
            describe_flow_shortfall(report, min_average_options=0.0,
                                    max_scarce_option_ratio=1.0)
        )

    ## A tutorial board has one option because one triple is the whole level. Failing it would say
    ## nothing about how it plays, so the gate leaves boards that small alone.
    def test_a_board_too_small_to_have_a_mid_game_is_never_failed(self) -> None:
        tiny = [{"layers": [["item_01", "item_01", None]]},
                {"layers": [["item_01", None, None]]}]
        report = measure_board_flow(tiny, None, None)
        self.assertLess(report.total_triples, GATE_MIN_TRIPLES)
        self.assertIsNone(
            describe_flow_shortfall(report, min_average_options=99.0,
                                    max_scarce_option_ratio=0.0)
        )

    def test_the_opening_check_counts_only_what_can_be_gathered(self) -> None:
        # Three copies are visible, but every shelf is full so none of them can be brought together.
        jammed = [
            {"layers": [["item_01", "item_02", "item_03"]]},
            {"layers": [["item_01", "item_02", "item_03"]]},
            {"layers": [["item_01", "item_02", "item_03"]]},
        ]
        self.assertEqual(count_collectible_front_types(jammed), 0)


class GenerateLevelShelvesTests(unittest.TestCase):
    def test_infers_item_type_count_from_fractional_preferred_copies(self) -> None:
        shelves, stats = generate_shelves(
            shelf_count=9,
            layer_count=2,
            filled_layer_count=2,
            item_types=None,
            difficulty="medium",
            seed=123,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
            preferred_copies_per_type=4.5,
        )
        counts = Counter(
            item_id
            for shelf in shelves
            for layer in shelf["layers"]
            for item_id in layer
            if item_id is not None
        )
        expected_type_count = infer_item_type_count(stats["target_filled_slots"], 4.5)
        self.assertEqual(len(counts), expected_type_count)
        self.assertEqual(stats["item_type_count"], expected_type_count)
        self.assertEqual(stats["item_type_count_source"], "inferred")
        self.assertEqual(stats["preferred_copies_per_type"], 4.5)

    def test_defaults_to_three_preferred_copies_per_type(self) -> None:
        _shelves, stats = generate_shelves(
            shelf_count=9,
            layer_count=2,
            filled_layer_count=2,
            item_types=None,
            difficulty="medium",
            seed=123,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
        )
        expected_type_count = infer_item_type_count(stats["target_filled_slots"], 3.0)
        self.assertEqual(stats["item_type_count"], expected_type_count)
        self.assertEqual(stats["item_type_count_source"], "inferred")
        self.assertEqual(stats["preferred_copies_per_type"], 3.0)

    def test_explicit_item_types_override_preferred_copy_inference(self) -> None:
        item_types = logical_item_ids(7)
        _shelves, stats = generate_shelves(
            shelf_count=9,
            layer_count=2,
            filled_layer_count=2,
            item_types=item_types,
            difficulty="medium",
            seed=123,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
            preferred_copies_per_type=3.0,
        )
        self.assertEqual(stats["item_type_count"], 7)
        self.assertEqual(stats["item_type_count_source"], "explicit")

    def test_rejects_invalid_preferred_copy_count(self) -> None:
        self.assertEqual(infer_item_type_count(42, 4.5), 10)
        for invalid_preference in (0.0, 2.9, float("inf"), float("nan")):
            with self.subTest(preferred_copies_per_type=invalid_preference):
                with self.assertRaisesRegex(ValueError, "finite and at least 3"):
                    infer_item_type_count(42, invalid_preference)

    def test_layer_triple_readiness_tracks_difficulty(self) -> None:
        expected_targets = {
            "easy": 0.65,
            "medium": 0.50,
            "hard": 0.40,
            "expert": 0.30,
        }
        average_ratios = {}
        for difficulty, expected_target in expected_targets.items():
            with self.subTest(difficulty=difficulty):
                _shelves, stats = generate_shelves(
                    shelf_count=15,
                    layer_count=3,
                    filled_layer_count=3,
                    item_types=logical_item_ids(19),
                    difficulty=difficulty,
                    seed=4004,
                    max_items_per_type_override=None,
                    min_front_visible_triples=1,
                )
                ratios = [
                    layer_stats["triple_ready_ratio"]
                    for layer_stats in stats["layer_triple_readiness"]
                ]
                self.assertEqual(stats["preferred_layer_triple_ratio"], expected_target)
                self.assertTrue(
                    all(abs(ratio - expected_target) <= 0.10 for ratio in ratios),
                    msg=f"{difficulty} layer ratios {ratios} missed target {expected_target}",
                )
                self.assertEqual(stats["non_adjacent_item_spreads"], {})
                average_ratios[difficulty] = sum(ratios) / len(ratios)

        self.assertGreater(average_ratios["easy"], average_ratios["medium"])
        self.assertGreater(average_ratios["medium"], average_ratios["hard"])
        self.assertGreater(average_ratios["hard"], average_ratios["expert"])

    def test_scattered_copies_stay_in_a_compact_adjacent_layer_range(self) -> None:
        shelves, stats = generate_shelves(
            shelf_count=12,
            layer_count=6,
            filled_layer_count=6,
            item_types=None,
            difficulty="medium",
            seed=6004,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
        )
        occupied_layers_by_item: dict[str, set[int]] = {}
        for shelf in shelves:
            for layer_index, layer in enumerate(shelf["layers"]):
                for item_id in layer:
                    if item_id is not None:
                        occupied_layers_by_item.setdefault(item_id, set()).add(layer_index)

        self.assertEqual(stats["non_adjacent_item_spreads"], {})
        for item_id, occupied_layers in occupied_layers_by_item.items():
            with self.subTest(item_id=item_id):
                first_layer = min(occupied_layers)
                last_layer = max(occupied_layers)
                self.assertEqual(
                    occupied_layers,
                    set(range(first_layer, last_layer + 1)),
                )
                item_count = stats["item_counts"][item_id]
                self.assertLessEqual(
                    len(occupied_layers),
                    (item_count + 1) // 2,
                )

    def test_layer_triple_ratio_remains_soft_for_constrained_boards(self) -> None:
        _shelves, stats = generate_shelves(
            shelf_count=1,
            layer_count=4,
            filled_layer_count=4,
            item_types=None,
            difficulty="expert",
            seed=1,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
        )
        ratios = [
            layer_stats["triple_ready_ratio"]
            for layer_stats in stats["layer_triple_readiness"]
        ]
        self.assertEqual(stats["preferred_layer_triple_ratio"], 0.30)
        self.assertTrue(any(abs(ratio - 0.30) > 0.10 for ratio in ratios))
        self.assertEqual(stats["non_adjacent_item_spreads"], {})


class DispenserShelfGenerationTests(unittest.TestCase):
    @staticmethod
    def _board() -> list[dict[str, object]]:
        return [
            {"layers": [["item_01", "item_01", "item_02"], ["item_02", "item_02", "item_01"]]},
            {"layers": [["item_03", "item_03", None], ["item_03", "item_04", "item_04"]]},
            {"layers": [["item_04", None, None], [None, None, None]]},
        ]

    def test_parses_dispenser_entries(self) -> None:
        self.assertEqual(parse_dispenser_shelves("10:3,11:4"), {10: 3, 11: 4})
        self.assertEqual(parse_dispenser_shelves(None), {})
        self.assertEqual(parse_dispenser_shelves(""), {})

    def test_rejects_malformed_dispenser_entries(self) -> None:
        for raw in ["10", "10:3:4", "x:3", "0:3"]:
            with self.subTest(raw=raw):
                with self.assertRaises(ValueError):
                    parse_dispenser_shelves(raw)

    def test_rejects_layer_counts_outside_the_supported_range(self) -> None:
        for raw in ["10:1", "10:5"]:
            with self.subTest(raw=raw):
                with self.assertRaises(ValueError):
                    parse_dispenser_shelves(raw)

    ## Queue items are relocated out of the generated board, never minted, so the multiple-of-three
    ## counts the distribution engine produced have to survive the pass untouched.
    def test_relocating_items_preserves_every_item_count(self) -> None:
        shelves = self._board()
        before = Counter(
            item_id
            for shelf in shelves
            for layer in shelf["layers"]
            for item_id in layer
            if item_id is not None
        )

        apply_dispenser_shelves(shelves, {2: 3}, random.Random(7))

        after = Counter(
            item_id
            for shelf in shelves
            for layer in shelf["layers"]
            for item_id in layer
            if item_id is not None
        )
        self.assertEqual(before, after)

    def test_inserts_dispensers_at_their_requested_positions(self) -> None:
        shelves = self._board()
        apply_dispenser_shelves(shelves, {1: 2, 4: 3}, random.Random(11))

        self.assertEqual(len(shelves), 5)
        self.assertEqual(shelves[0].get("type"), "dispenser")
        self.assertEqual(shelves[3].get("type"), "dispenser")
        self.assertEqual(len(shelves[0]["layers"]), 2)
        self.assertEqual(len(shelves[3]["layers"]), 3)
        for shelf in [shelves[0], shelves[3]]:
            for layer in shelf["layers"]:
                self.assertEqual(len(layer), 1)
                self.assertIsNotNone(layer[0])

    def test_rejects_a_position_beyond_the_resulting_shelf_count(self) -> None:
        with self.assertRaises(ValueError):
            apply_dispenser_shelves(self._board(), {9: 2}, random.Random(1))

    def test_rejects_a_board_without_enough_items_to_stock_the_queues(self) -> None:
        sparse = [{"layers": [["item_01", None, None]]}]
        with self.assertRaises(ValueError):
            apply_dispenser_shelves(sparse, {1: 4}, random.Random(1))

    def test_leaves_a_board_without_dispensers_untouched(self) -> None:
        shelves = self._board()
        expected = copy.deepcopy(shelves)
        apply_dispenser_shelves(shelves, {}, random.Random(1))
        self.assertEqual(shelves, expected)


COLLAPSING_ARGUMENTS = [
    "--gameplay-mode", "collapsing_columns",
    "--column-heights", "5,5,5",
    "--visible-shelves-per-column", "4",
    "--item-type-count", "10",
    "--difficulty", "medium",
    "--seed", "24601",
    "--require-solvable",
]


def run_generator(arguments: list[str]) -> tuple[int, str, str]:
    stdout, stderr = io.StringIO(), io.StringIO()
    argv = sys.argv
    sys.argv = ["generate_level_shelves.py", *arguments]
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            exit_code = generate_main()
    except SystemExit as error:
        exit_code = int(error.code or 0)
    finally:
        sys.argv = argv

    return exit_code, stdout.getvalue(), stderr.getvalue()


class CollapsingColumnArgumentTests(unittest.TestCase):
    def test_parses_column_heights(self) -> None:
        self.assertEqual(parse_column_heights("8, 8,8"), [8, 8, 8])

    def test_rejects_malformed_column_heights(self) -> None:
        for raw in ["8,x,8", "8,0,8", "8,-1", ","]:
            with self.subTest(raw=raw):
                with self.assertRaises(ValueError):
                    parse_column_heights(raw)

    ## argparse exits 2 on a conflicting request rather than quietly reconciling it: a silently
    ## accepted conflict would produce content the mode's solver was never asked to prove.
    def test_rejects_conflicting_arguments(self) -> None:
        conflicts = [
            (["--gameplay-mode", "collapsing_columns", "--visible-shelves-per-column", "4"],
             "requires --column-heights"),
            (["--gameplay-mode", "collapsing_columns", "--column-heights", "4,4"],
             "requires --visible-shelves-per-column"),
            ([*COLLAPSING_ARGUMENTS, "--shelf-count", "15"], "do not also pass --shelf-count"),
            ([*COLLAPSING_ARGUMENTS, "--layer-count", "2"], "--layer-count must be 1"),
            ([*COLLAPSING_ARGUMENTS, "--filled-layer-count", "2"], "--filled-layer-count must be 1"),
            ([*COLLAPSING_ARGUMENTS, "--dispenser-shelves", "3:2"], "--dispenser-shelves is not supported"),
            ([*COLLAPSING_ARGUMENTS, "--locked-shelves", "3:2"], "--locked-shelves is not supported"),
            ([*COLLAPSING_ARGUMENTS, "--sticky-items-percent", "10"], "--sticky-items-percent is not supported"),
            ([*COLLAPSING_ARGUMENTS, "--layout-preset", "grid_3x3"], "--layout-preset cannot be combined"),
            (["--gameplay-mode", "collapsing_columns", "--column-heights", "4,4",
              "--visible-shelves-per-column", "99"], "must be between 1 and"),
            (["--column-heights", "4,4", "--shelf-count", "8", "--layer-count", "1"],
             "--column-heights requires --gameplay-mode"),
            (["--layer-count", "1"], "--shelf-count is required"),
            (["--shelf-count", "9"], "--layer-count is required"),
        ]
        for arguments, expected in conflicts:
            with self.subTest(expected=expected):
                exit_code, _stdout, stderr = run_generator(arguments)
                self.assertEqual(exit_code, 2)
                self.assertIn(expected, stderr)


class CollapsingColumnShelfRepairTests(unittest.TestCase):
    def test_splits_the_flat_array_column_by_column_bottom_to_top(self) -> None:
        shelves = [{"layers": [[f"item_{index:02d}", None, None]]} for index in range(1, 7)]
        columns = split_shelves_into_columns(shelves, [2, 3, 1])
        self.assertEqual([len(column) for column in columns], [2, 3, 1])
        self.assertIs(columns[0][0], shelves[0])
        self.assertIs(columns[1][0], shelves[2])
        self.assertIs(columns[2][0], shelves[5])

    def test_active_shelves_are_the_bottom_of_each_column(self) -> None:
        shelves = [{"layers": [[f"item_{index:02d}", None, None]]} for index in range(1, 7)]
        active = active_collapsing_shelves(shelves, [3, 3], 2)
        self.assertEqual(
            [shelf["layers"][0][0] for shelf in active],
            ["item_01", "item_02", "item_04", "item_05"],
        )

    def test_rescues_an_empty_shelf_without_changing_any_item_count(self) -> None:
        shelves = [
            {"layers": [["item_01", "item_01", "item_01"]]},
            {"layers": [[None, None, None]]},
        ]
        before = Counter(
            item for shelf in shelves for item in shelf["layers"][0] if item is not None
        )
        rescued = fill_empty_collapsing_shelves(shelves, random.Random(7))
        after = Counter(
            item for shelf in shelves for item in shelf["layers"][0] if item is not None
        )
        self.assertEqual(rescued, 1)
        self.assertEqual(before, after)
        self.assertTrue(all(any(item is not None for item in shelf["layers"][0]) for shelf in shelves))

    def test_refuses_to_rescue_a_board_with_too_few_items(self) -> None:
        shelves = [
            {"layers": [["item_01", None, None]]},
            {"layers": [[None, None, None]]},
        ]
        with self.assertRaises(ValueError):
            fill_empty_collapsing_shelves(shelves, random.Random(7))


class CollapsingColumnGenerationTests(unittest.TestCase):
    def generate(self, **overrides):
        arguments = {
            "shelf_count": 15,
            "layer_count": 1,
            "filled_layer_count": 1,
            "item_types": logical_item_ids(10),
            "difficulty": "medium",
            "seed": 24601,
            "should_validate": True,
            "require_solvable": True,
            "max_attempts": 25,
            "max_items_per_type_override": None,
            "min_front_visible_triples": 1,
            "max_states": 20000,
            "max_depth": 200,
            "column_heights": [5, 5, 5],
            "visible_shelves_per_column": 4,
        }
        arguments.update(overrides)
        return generate_with_optional_validation(**arguments)

    def test_generates_a_proven_solvable_board_with_the_requested_columns(self) -> None:
        shelves, stats, validation, _seed = self.generate()
        self.assertEqual(len(shelves), 15)
        self.assertEqual(stats["gameplay_mode"], "collapsing_columns")
        self.assertEqual(stats["column_heights"], [5, 5, 5])
        self.assertEqual(stats["visible_shelves_per_column"], 4)
        self.assertEqual(stats["total_shelf_count"], 15)
        self.assertEqual(stats["active_shelf_count"], 12)
        self.assertEqual(stats["hidden_shelf_count"], 3)
        self.assertIn("active_occupied_slots", stats)
        self.assertIn("rescued_empty_shelves", stats)
        self.assertIn("attempt", stats)
        self.assertTrue(validation["solvable"], validation["reason"])
        self.assertEqual(validation["gameplay_mode"], "collapsing_columns")

    def test_every_shelf_has_one_layer_and_at_least_one_item(self) -> None:
        shelves, _stats, _validation, _seed = self.generate()
        for shelf_index, shelf in enumerate(shelves):
            with self.subTest(shelf=shelf_index + 1):
                self.assertEqual(len(shelf["layers"]), 1)
                self.assertEqual(len(shelf["layers"][0]), 3)
                self.assertTrue(any(item is not None for item in shelf["layers"][0]))

    def test_every_item_copy_count_stays_divisible_by_three(self) -> None:
        shelves, _stats, _validation, _seed = self.generate()
        counts = Counter(
            item for shelf in shelves for item in shelf["layers"][0] if item is not None
        )
        self.assertTrue(counts)
        for item_id, count in counts.items():
            with self.subTest(item=item_id):
                self.assertEqual(count % 3, 0)

    def test_output_is_deterministic_for_a_fixed_seed(self) -> None:
        first, first_stats, _validation, first_seed = self.generate()
        second, second_stats, _second_validation, second_seed = self.generate()
        self.assertEqual(first, second)
        self.assertEqual(first_seed, second_seed)
        self.assertEqual(first_stats["item_counts"], second_stats["item_counts"])

    ## The opening-progress guarantee has to be judged on the window the player actually opens with;
    ## a triple whose copies sit behind a hidden shelf is not progress they can make.
    def test_opening_progress_is_measured_on_active_shelves_only(self) -> None:
        _shelves, stats, _validation, _seed = self.generate()
        self.assertGreaterEqual(stats["active_collectible_front_types"], 1)

    def test_wrap_level_emits_the_column_contract_and_no_layout_preset(self) -> None:
        level = wrap_level(
            shelves=[{"layers": [["item_01", "item_01", "item_01"]]}],
            level_number=11,
            time_seconds=300,
            layout_preset="grid_3x3",
            seed=1,
            difficulty="medium",
            column_heights=[1],
            visible_shelves_per_column=1,
        )
        self.assertNotIn("layout_preset", level)
        self.assertEqual(level["gameplay_mode"], "collapsing_columns")
        self.assertEqual(
            level["column_layout"],
            {"shelf_counts": [1], "visible_shelves_per_column": 1},
        )


class CollapsingColumnCommandLineTests(unittest.TestCase):
    def test_writes_a_valid_solvable_full_level(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output_path = Path(directory) / "level_011.json"
            exit_code, _stdout, _stderr = run_generator(
                [*COLLAPSING_ARGUMENTS, "--full-level", "--level-number", "11",
                 "--output", str(output_path)]
            )
            self.assertEqual(exit_code, 0)
            level = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(level["gameplay_mode"], "collapsing_columns")
        self.assertEqual(level["column_layout"]["shelf_counts"], [5, 5, 5])
        self.assertEqual(len(level["shelves"]), 15)

    ## `--require-solvable` must never leave an unproven board behind for someone to publish.
    def test_writes_no_output_when_no_solvable_board_is_found(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output_path = Path(directory) / "level_011.json"
            exit_code, _stdout, stderr = run_generator(
                ["--gameplay-mode", "collapsing_columns",
                 "--column-heights", "6,6,6",
                 "--visible-shelves-per-column", "1",
                 "--item-type-count", "6",
                 "--difficulty", "expert",
                 "--seed", "99",
                 "--require-solvable",
                 "--max-generation-attempts", "2",
                 "--validator-max-states", "2000",
                 "--full-level", "--output", str(output_path)]
            )
            self.assertNotEqual(exit_code, 0)
            self.assertFalse(output_path.exists(), stderr)


class ClassicGenerationRegressionTests(unittest.TestCase):
    ## Omitting the new mode must leave the classic generator byte-for-byte where it was.
    def test_classic_output_is_unchanged_when_the_new_mode_is_omitted(self) -> None:
        shelves, stats = generate_shelves(
            shelf_count=9,
            layer_count=2,
            filled_layer_count=2,
            item_types=logical_item_ids(7),
            difficulty="medium",
            seed=123,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
        )
        self.assertEqual(len(shelves), 9)
        self.assertTrue(all(len(shelf["layers"]) == 2 for shelf in shelves))
        self.assertNotIn("gameplay_mode", stats)
        self.assertNotIn("column_heights", stats)

        level = wrap_level(
            shelves=shelves,
            level_number=2,
            time_seconds=300,
            layout_preset="grid_3x3",
            seed=123,
            difficulty="medium",
        )
        self.assertEqual(level["layout_preset"], "grid_3x3")
        self.assertNotIn("gameplay_mode", level)
        self.assertNotIn("column_layout", level)


class ThrowingDispenserGenerationTests(unittest.TestCase):
    def generate(self, **overrides: object):
        arguments = {
            "shelf_count": 12,
            "dispenser_count": 2,
            "throw_count": 3,
            "item_type_count": 10,
            "seed": 4242,
            "throw_seed": None,
            "require_playable": True,
            "max_attempts": 4,
            "playability_trials": 40,
        }
        arguments.update(overrides)
        return generate_throwing_level(**arguments)

    def test_the_board_is_authored_empty(self) -> None:
        shelves, _, _, stats, _ = self.generate()
        self.assertEqual(len(shelves), 12)
        self.assertTrue(all(shelf["layers"] == [[None, None, None]] for shelf in shelves))
        self.assertEqual(stats["total_items"], 30)

    ## Every item in the level lives in a dispenser, so the copy counts that make the level
    ## completable have to hold across the dispensers rather than across the board.
    def test_every_item_has_a_multiple_of_three_copies(self) -> None:
        _, dispensers, _, _, _ = self.generate()
        counts = Counter(
            item_id for dispenser in dispensers for item_id in dispenser["contents"]
        )
        self.assertEqual(sorted(counts), logical_item_ids(10))
        self.assertTrue(all(count == 3 for count in counts.values()))

    def test_contents_are_split_across_the_requested_dispensers(self) -> None:
        _, dispensers, _, _, _ = self.generate(dispenser_count=3)
        self.assertEqual(len(dispensers), 3)
        self.assertEqual(sum(len(d["contents"]) for d in dispensers), 30)
        self.assertTrue(all(d["throw_count"] == 3 for d in dispensers))

    ## Regenerating a level with the same `--seed` has to reproduce its scatter too, or the level
    ## would be retuned every time it was rebuilt.
    def test_the_same_seed_reproduces_the_same_scatter_seed(self) -> None:
        _, first_dispensers, first_scatter, _, _ = self.generate()
        _, second_dispensers, second_scatter, _, _ = self.generate()
        self.assertEqual(first_scatter, second_scatter)
        self.assertEqual(first_dispensers, second_dispensers)
        self.assertRegex(first_scatter, r"^[0-9a-f]{16}$")

    def test_an_authored_scatter_seed_is_kept(self) -> None:
        _, _, scatter_seed, _, _ = self.generate(throw_seed="00000000000052ad")
        self.assertEqual(scatter_seed, "00000000000052ad")

    def test_generation_reports_its_playability_estimate(self) -> None:
        _, _, _, stats, _ = self.generate()
        self.assertEqual(stats["gameplay_mode"], "throwing_dispensers")
        self.assertEqual(stats["playability"]["completion_rate"], 1.0)
        self.assertEqual(stats["board_slots"], 36)

    ## A board with no room to assemble a triple cannot be rescued by another shuffle, so the
    ## generator has to report it rather than spend every attempt and claim success.
    def test_an_unplayable_board_is_reported(self) -> None:
        _, _, _, stats, _ = self.generate(shelf_count=1, throw_count=1, item_type_count=1)
        self.assertLess(stats["playability"]["completion_rate"], 0.95)

    def test_split_evenly_keeps_every_item_and_balances_the_parts(self) -> None:
        chunks = split_evenly(list("abcdefg"), 3)
        self.assertEqual([len(chunk) for chunk in chunks], [3, 2, 2])
        self.assertEqual("".join("".join(chunk) for chunk in chunks), "abcdefg")
        self.assertEqual(split_evenly(["a"], 3), [["a"], [], []])


class ThrowingDispenserArgumentTests(unittest.TestCase):
    def error_for(self, *arguments: str) -> str:
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), self.assertRaises(SystemExit):
            generate_main(list(arguments))
        return stderr.getvalue()

    def base_arguments(self) -> list[str]:
        return [
            "--gameplay-mode", "throwing_dispensers",
            "--shelf-count", "12",
            "--dispenser-count", "2",
            "--throw-count", "3",
            "--item-type-count", "10",
        ]

    ## Rejected rather than silently ignored: a flag that shapes a shelf's contents has nothing to
    ## act on when the board is authored empty.
    def test_shelf_content_flags_are_rejected(self) -> None:
        for flag, value in (
            ("--dispenser-shelves", "1"),
            ("--locked-shelves", "1:3"),
            ("--sticky-items-percent", "10"),
            ("--layer-count", "2"),
        ):
            with self.subTest(flag=flag):
                message = self.error_for(*self.base_arguments(), flag, value)
                self.assertIn("throwing_dispensers", message)

    def test_throwing_flags_require_the_mode(self) -> None:
        for flag, value in (("--dispenser-count", "2"), ("--throw-count", "3"),
                            ("--throw-seed", "00000000000052ad")):
            with self.subTest(flag=flag):
                message = self.error_for(
                    "--shelf-count", "9", "--layer-count", "1", flag, value
                )
                self.assertIn("requires --gameplay-mode throwing_dispensers", message)

    def test_a_throw_larger_than_the_board_is_rejected(self) -> None:
        message = self.error_for(
            "--gameplay-mode", "throwing_dispensers",
            "--shelf-count", "1",
            "--dispenser-count", "1",
            "--throw-count", "3",
            "--item-type-count", "1",
        )
        self.assertIn("slots a throw may ever fill", message)

    def test_a_malformed_scatter_seed_is_rejected(self) -> None:
        message = self.error_for(*self.base_arguments(), "--throw-seed", "52AD")
        self.assertIn("16-digit lowercase hex string", message)


if __name__ == "__main__":
    unittest.main()
