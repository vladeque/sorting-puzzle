from __future__ import annotations

import sys
import unittest
from collections import Counter
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from generate_level_shelves import generate_shelves, infer_item_type_count  # noqa: E402
from level_item_progression import logical_item_ids  # noqa: E402


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

    def test_defaults_to_six_preferred_copies_per_type(self) -> None:
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
        expected_type_count = infer_item_type_count(stats["target_filled_slots"], 6.0)
        self.assertEqual(stats["item_type_count"], expected_type_count)
        self.assertEqual(stats["item_type_count_source"], "inferred")
        self.assertEqual(stats["preferred_copies_per_type"], 6.0)

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


if __name__ == "__main__":
    unittest.main()
