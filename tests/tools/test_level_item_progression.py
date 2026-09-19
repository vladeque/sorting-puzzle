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
    load_chapter_catalog,
    load_item_progression,
    logical_item_ids,
    materialize_level,
    validate_board_contract,
)
from generate_level_shelves import generate_shelves  # noqa: E402


class LevelItemProgressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.progression = load_item_progression(
            REPOSITORY_ROOT / "configs" / "item_progression.json",
            REPOSITORY_ROOT / "configs" / "item_sprites.json",
        )

    def test_chapter_level_pools_follow_configured_milestones(self) -> None:
        chapter_one_items = set(self.progression.chapter_item_ids("chapter_01"))
        previous_items: set[str] = set()
        for level_number in range(1, 11):
            available_items = set(self.progression.available_items(level_number))
            self.assertLessEqual(previous_items, available_items)
            self.assertLessEqual(available_items, chapter_one_items)
            previous_items = available_items

    def test_chapter_catalog_maps_global_to_local_levels(self) -> None:
        chapters = load_chapter_catalog(REPOSITORY_ROOT / "configs" / "chapters.json")
        chapter, chapter_level = chapters.chapter_for_level(10)
        self.assertEqual(chapter.chapter_id, "chapter_01")
        self.assertEqual(chapter_level, 10)
        with self.assertRaisesRegex(ValueError, "not assigned"):
            chapters.chapter_for_level(11)

    def test_chapter_catalog_applies_default_unlock_requirement(self) -> None:
        document = json.loads(
            (REPOSITORY_ROOT / "configs" / "chapters.json").read_text(encoding="utf-8")
        )
        document["chapters"][1]["unlock"].pop("required_completed_levels")
        with tempfile.TemporaryDirectory() as temp_directory:
            path = Path(temp_directory) / "chapters.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            chapters = load_chapter_catalog(path)
        self.assertEqual(chapters.chapters[1].required_completed_levels, 25)

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
        pool_size = len(self.progression.available_items(5))
        logical_ids_for_level = tuple(logical_item_ids(pool_size + 1))
        with self.assertRaisesRegex(ValueError, f"only {pool_size}"):
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
        chapters = {
            "schema_version": 1,
            "default_unlock_required_levels": 25,
            "chapters": [
                {
                    "id": "chapter_01",
                    "order": 1,
                    "title": "One",
                    "level_ids": [1],
                    "unlock": {"previous_chapter_id": None, "required_completed_levels": 0},
                    "gameplay_background_mode": "legacy",
                    "background_texture": "res://one.png",
                    "selection_preview": "res://one.png",
                }
            ],
        }
        duplicate_progression = {
            "schema_version": 2,
            "mapping_salt": "test",
            "chapters": [
                {
                    "chapter_id": "chapter_01",
                    "milestones": [
                        {"from_chapter_level": 1, "unlock": ["alpha"]},
                        {"from_chapter_level": 2, "unlock": ["alpha"]},
                    ],
                }
            ],
        }
        with tempfile.TemporaryDirectory() as temp_directory:
            temp_path = Path(temp_directory)
            catalog_path = temp_path / "items.json"
            progression_path = temp_path / "progression.json"
            chapters_path = temp_path / "chapters.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            chapters_path.write_text(json.dumps(chapters), encoding="utf-8")
            progression_path.write_text(json.dumps(duplicate_progression), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "more than once"):
                load_item_progression(progression_path, catalog_path, chapters_path)

            missing_progression = {
                "schema_version": 2,
                "mapping_salt": "test",
                "chapters": [
                    {
                        "chapter_id": "chapter_01",
                        "milestones": [
                            {"from_chapter_level": 1, "unlock": ["alpha"]}
                        ],
                    }
                ],
            }
            progression_path.write_text(json.dumps(missing_progression), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "does not schedule"):
                load_item_progression(progression_path, catalog_path, chapters_path)

    def test_progression_allows_an_item_in_different_chapters(self) -> None:
        catalog = {
            "items": [
                {"id": "alpha", "texture": "res://alpha.png"},
                {"id": "beta", "texture": "res://beta.png"},
            ]
        }
        chapters = {
            "schema_version": 1,
            "default_unlock_required_levels": 25,
            "chapters": [
                {
                    "id": "chapter_01",
                    "order": 1,
                    "title": "One",
                    "level_ids": [1],
                    "unlock": {"previous_chapter_id": None, "required_completed_levels": 0},
                    "gameplay_background_mode": "legacy",
                    "background_texture": "res://one.png",
                    "selection_preview": "res://one.png",
                },
                {
                    "id": "chapter_02",
                    "order": 2,
                    "title": "Two",
                    "level_ids": [2],
                    "unlock": {
                        "previous_chapter_id": "chapter_01",
                        "required_completed_levels": 1,
                    },
                    "gameplay_background_mode": "legacy",
                    "background_texture": "res://two.png",
                    "selection_preview": "res://two.png",
                },
            ],
        }
        progression_document = {
            "schema_version": 2,
            "mapping_salt": "test",
            "chapters": [
                {
                    "chapter_id": "chapter_01",
                    "milestones": [
                        {"from_chapter_level": 1, "unlock": ["alpha", "beta"]}
                    ],
                },
                {
                    "chapter_id": "chapter_02",
                    "milestones": [
                        {"from_chapter_level": 1, "unlock": ["alpha"]}
                    ],
                },
            ],
        }
        with tempfile.TemporaryDirectory() as temp_directory:
            temp_path = Path(temp_directory)
            catalog_path = temp_path / "items.json"
            progression_path = temp_path / "progression.json"
            chapters_path = temp_path / "chapters.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            chapters_path.write_text(json.dumps(chapters), encoding="utf-8")
            progression_path.write_text(json.dumps(progression_document), encoding="utf-8")
            progression = load_item_progression(
                progression_path,
                catalog_path,
                chapters_path,
            )

        self.assertEqual(progression.available_items(1), ("alpha", "beta"))
        self.assertEqual(progression.available_items(2), ("alpha",))

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

        for runtime_path in sorted(
            (REPOSITORY_ROOT / "configs" / "levels").glob("level_*.json")
        ):
            runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
            expected_level = int(runtime_path.stem.removeprefix("level_"))
            self.assertEqual(runtime["level"], expected_level, runtime_path.name)
            available = set(self.progression.available_items(expected_level))
            self.assertLessEqual(set(_item_counts(runtime)), available, runtime_path.name)


def _collapsing_template(**overrides) -> dict:
    """Three columns of two shelves; the top shelf of each column starts hidden.

    Uses a level number that belongs to a chapter, because materialization resolves the item pool
    through the campaign chapter the level is assigned to.
    """
    level = {
        "level": 3,
        "time_seconds": 300,
        "gameplay_mode": "collapsing_columns",
        "column_layout": {"shelf_counts": [2, 2, 2], "visible_shelves_per_column": 1},
        "shelves": [
            {"layers": [["item_01", "item_01", "item_01"]]},
            {"layers": [["item_02", "item_02", "item_02"]]},
            {"layers": [["item_03", "item_03", "item_03"]]},
            {"layers": [["item_04", "item_04", "item_04"]]},
            {"layers": [["item_05", "item_05", "item_05"]]},
            {"layers": [["item_06", "item_06", "item_06"]]},
        ],
    }
    level.update(overrides)
    return level


class CollapsingColumnMaterializationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.progression = load_item_progression(
            REPOSITORY_ROOT / "configs" / "item_progression.json",
            REPOSITORY_ROOT / "configs" / "item_sprites.json",
        )

    def test_mode_and_column_contract_survive_materialization_unchanged(self) -> None:
        template = _collapsing_template()
        materialized, _mapping = materialize_level(template, self.progression)
        self.assertEqual(materialized["gameplay_mode"], "collapsing_columns")
        self.assertEqual(materialized["column_layout"], template["column_layout"])
        self.assertIsNot(materialized["column_layout"], template["column_layout"])

    ## Shelves 2, 4 and 6 are the hidden top of each column. Item resolution walks the flat shelves
    ## array, so hidden content is mapped exactly like visible content.
    def test_maps_items_on_hidden_and_active_shelves_alike(self) -> None:
        template = _collapsing_template()
        materialized, mapping = materialize_level(template, self.progression)
        self.assertEqual(len(mapping), 6)
        for shelf_index, shelf in enumerate(materialized["shelves"]):
            with self.subTest(shelf=shelf_index + 1):
                logical_id = template["shelves"][shelf_index]["layers"][0][0]
                self.assertEqual(shelf["layers"][0], [mapping[logical_id]] * 3)

    ## Column position must never influence which concrete item a token becomes, or the same template
    ## would materialize differently after a purely structural edit.
    def test_column_grouping_does_not_change_the_item_mapping(self) -> None:
        _first, first_mapping = materialize_level(_collapsing_template(), self.progression)
        regrouped = _collapsing_template()
        regrouped["column_layout"] = {"shelf_counts": [3, 3], "visible_shelves_per_column": 2}
        _second, second_mapping = materialize_level(regrouped, self.progression)
        self.assertEqual(first_mapping, second_mapping)

    def test_a_malformed_column_contract_fails_before_publication(self) -> None:
        malformed = [
            {"column_layout": {"shelf_counts": [2, 2], "visible_shelves_per_column": 1}},
            {"column_layout": {"shelf_counts": [2, 2, 2], "visible_shelves_per_column": 0}},
            {"column_layout": {"shelf_counts": [], "visible_shelves_per_column": 1}},
            {"layout_preset": "grid_3x3"},
            {"gameplay_mode": "conveyor"},
        ]
        for overrides in malformed:
            with self.subTest(overrides=overrides):
                with self.assertRaises(ValueError):
                    materialize_level(_collapsing_template(**overrides), self.progression)

    def test_a_classic_template_still_materializes(self) -> None:
        classic = {
            "level": 1,
            "time_seconds": 300,
            "layout_preset": "grid_3x3",
            "shelves": [{"layers": [["item_01", "item_01", "item_01"]]}],
        }
        validate_board_contract(classic)
        materialized, mapping = materialize_level(classic, self.progression)
        self.assertNotIn("gameplay_mode", materialized)
        self.assertEqual(len(mapping), 1)


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
