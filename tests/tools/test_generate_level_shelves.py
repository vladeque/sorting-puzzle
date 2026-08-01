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


if __name__ == "__main__":
    unittest.main()
