from __future__ import annotations

import json
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from level_item_progression import (  # noqa: E402
    build_item_mapping,
    collect_logical_item_ids,
    load_item_progression,
    logical_item_ids,
    materialize_level,
)
from generate_level_shelves import generate_shelves  # noqa: E402


class LevelItemProgressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.progression = load_item_progression(
            REPOSITORY_ROOT / "configs" / "item_progression.json",
            REPOSITORY_ROOT / "configs" / "item_sprites.json",
        )

    def test_milestones_are_cumulative_at_boundaries(self) -> None:
        self.assertEqual(len(self.progression.available_items(1)), 10)
        self.assertEqual(len(self.progression.available_items(5)), 10)
        self.assertEqual(len(self.progression.available_items(6)), 15)
        self.assertEqual(len(self.progression.available_items(8)), 15)
        self.assertEqual(len(self.progression.available_items(9)), 19)
        self.assertEqual(len(self.progression.available_items(12)), 24)

    def test_logical_item_ids_are_canonical(self) -> None:
        self.assertEqual(logical_item_ids(3), ["item_01", "item_02", "item_03"])
        with self.assertRaisesRegex(ValueError, "at least 1"):
            logical_item_ids(0)

    def test_materialization_is_deterministic_and_one_to_one(self) -> None:
        abstract = {
            "level": 5,
            "shelves": [
                {"layers": [["item_02", "item_01", "item_03"]]},
                {"layers": [["item_01", "item_02", "item_03"]]},
                {"layers": [["item_01", "item_02", "item_03"]]},
                {"layers": [[None, None, None]]},
            ],
        }
        first_level, first_mapping = materialize_level(abstract, self.progression)
        second_level, second_mapping = materialize_level(abstract, self.progression)

        self.assertEqual(first_level, second_level)
        self.assertEqual(first_mapping, second_mapping)
        self.assertEqual(len(set(first_mapping.values())), len(first_mapping))
        self.assertEqual(first_level["shelves"][3]["layers"][0], [None, None, None])

    def test_materialization_preserves_item_counts(self) -> None:
        abstract = {
            "level": 6,
            "shelves": [
                {"layers": [["item_01", "item_01", "item_02"]]},
                {"layers": [["item_02", "item_02", "item_01"]]},
            ],
        }
        materialized, mapping = materialize_level(abstract, self.progression)
        abstract_counts = _item_counts(abstract)
        materialized_counts = _item_counts(materialized)
        self.assertEqual(
            Counter({mapping[item_id]: count for item_id, count in abstract_counts.items()}),
            materialized_counts,
        )

    def test_materialization_rejects_more_types_than_the_level_pool(self) -> None:
        logical_ids_for_level = tuple(logical_item_ids(11))
        with self.assertRaisesRegex(ValueError, "only 10"):
            build_item_mapping(logical_ids_for_level, 5, self.progression)

    def test_templates_reject_concrete_or_malformed_item_ids(self) -> None:
        concrete = {
            "level": 1,
            "shelves": [{"layers": [["milk_carton", None, None]]}],
        }
        with self.assertRaisesRegex(ValueError, "item_NN"):
            collect_logical_item_ids(concrete)

        malformed_shape = {
            "level": 1,
            "shelves": [{"layers": [["item_01"]]}],
        }
        with self.assertRaisesRegex(ValueError, "must contain 3 slots"):
            collect_logical_item_ids(malformed_shape)

        noncanonical = {
            "level": 1,
            "shelves": [{"layers": [["item_02", "item_02", "item_02"]]}],
        }
        with self.assertRaisesRegex(ValueError, "contiguous canonical"):
            collect_logical_item_ids(noncanonical)

    def test_generator_uses_abstract_types_without_art_catalog_limits(self) -> None:
        item_types = logical_item_ids(10)
        shelves, stats = generate_shelves(
            shelf_count=15,
            layer_count=3,
            filled_layer_count=3,
            item_types=item_types,
            difficulty="hard",
            seed=4004,
            max_items_per_type_override=None,
            min_front_visible_triples=1,
        )
        counts = Counter(
            item_id
            for shelf in shelves
            for layer in shelf["layers"]
            for item_id in layer
            if item_id is not None
        )
        self.assertEqual(set(counts), set(item_types))
        self.assertEqual(stats["filled_slots"], stats["target_filled_slots"])
        self.assertTrue(all(count % 3 == 0 for count in counts.values()))

    def test_progression_rejects_duplicate_and_unscheduled_items(self) -> None:
        catalog = {
            "items": [
                {"id": "alpha", "texture": "res://alpha.png"},
                {"id": "beta", "texture": "res://beta.png"},
            ]
        }
        duplicate_progression = {
            "schema_version": 1,
            "mapping_salt": "test",
            "milestones": [
                {"from_level": 1, "unlock": ["alpha"]},
                {"from_level": 2, "unlock": ["alpha"]},
            ],
        }
        with tempfile.TemporaryDirectory() as temp_directory:
            temp_path = Path(temp_directory)
            catalog_path = temp_path / "items.json"
            progression_path = temp_path / "progression.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            progression_path.write_text(json.dumps(duplicate_progression), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "more than once"):
                load_item_progression(progression_path, catalog_path)

            missing_progression = {
                "schema_version": 1,
                "mapping_salt": "test",
                "milestones": [{"from_level": 1, "unlock": ["alpha"]}],
            }
            progression_path.write_text(json.dumps(missing_progression), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "does not schedule"):
                load_item_progression(progression_path, catalog_path)

    def test_committed_runtime_levels_match_templates_and_level_pools(self) -> None:
        for template_path in sorted(
            (REPOSITORY_ROOT / "configs" / "level_templates").glob("level_*.json")
        ):
            abstract = json.loads(template_path.read_text(encoding="utf-8"))
            materialized, _mapping = materialize_level(abstract, self.progression)
            runtime_path = REPOSITORY_ROOT / "configs" / "levels" / template_path.name
            runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
            self.assertEqual(materialized, runtime, template_path.name)

            available = set(self.progression.available_items(runtime["level"]))
            self.assertLessEqual(set(_item_counts(runtime)), available, template_path.name)


def _item_counts(level: dict) -> Counter[str]:
    return Counter(
        item_id
        for shelf in level["shelves"]
        for layer in shelf["layers"]
        for item_id in layer
        if item_id is not None
    )


if __name__ == "__main__":
    unittest.main()
