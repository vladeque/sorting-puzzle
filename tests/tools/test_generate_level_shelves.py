from __future__ import annotations

import copy
import random
import sys
import unittest
from collections import Counter
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from generate_level_shelves import (  # noqa: E402
    LAYOUT_PRESETS,
    apply_dispenser_shelves,
    generate_shelves,
    infer_item_type_count,
    parse_dispenser_shelves,
)
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


if __name__ == "__main__":
    unittest.main()
