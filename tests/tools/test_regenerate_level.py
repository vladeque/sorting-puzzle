from __future__ import annotations

import contextlib
import hashlib
import io
import json
import shlex
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOLS_PATH = REPOSITORY_ROOT / "scripts" / "tools"
sys.path.insert(0, str(TOOLS_PATH))

from generate_level_shelves import main as generate_main  # noqa: E402
from regenerate_level import (  # noqa: E402
    MANIFEST_FILE_NAME,
    MANIFEST_SCHEMA_VERSION,
    describe_metadata_changes,
    level_file_name,
    parse_args,
)
from regenerate_level import main as regenerate_main  # noqa: E402


BASE_ARGUMENTS = [
    "--shelf-count",
    "9",
    "--layer-count",
    "2",
    "--item-type-count",
    "7",
    "--difficulty",
    "easy",
    "--seed",
    "123",
    "--max-items-per-type",
    "6",
]


def run_regenerate(arguments: list[str]) -> tuple[int, str, str]:
    stdout = io.StringIO()
    stderr = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            exit_code = regenerate_main(arguments)
    except SystemExit as error:
        exit_code = int(error.code or 0)

    return exit_code, stdout.getvalue(), stderr.getvalue()


class ArgumentContractTests(unittest.TestCase):
    def test_requires_an_explicit_level_number(self) -> None:
        exit_code, _stdout, stderr = run_regenerate(BASE_ARGUMENTS)

        self.assertEqual(exit_code, 2)
        self.assertIn("--level-number is required", stderr)

    def test_rejects_an_explicit_output_path(self) -> None:
        exit_code, _stdout, stderr = run_regenerate(
            [*BASE_ARGUMENTS, "--level-number", "2", "--output", "somewhere.json"]
        )

        self.assertEqual(exit_code, 2)
        self.assertIn("--output is not accepted", stderr)

    def test_requires_a_solvability_proof_by_default(self) -> None:
        args = parse_args([*BASE_ARGUMENTS, "--level-number", "2"])

        self.assertTrue(args.require_solvable)
        self.assertTrue(args.full_level)

    def test_allow_unsolvable_drops_the_proof_requirement(self) -> None:
        args = parse_args([*BASE_ARGUMENTS, "--level-number", "2", "--allow-unsolvable"])

        self.assertFalse(args.require_solvable)


class MetadataChangeTests(unittest.TestCase):
    def test_reports_no_changes_for_a_new_template(self) -> None:
        self.assertEqual(describe_metadata_changes(None, {"level": 2, "shelves": []}), [])

    def test_reports_changed_added_and_removed_keys(self) -> None:
        previous = {"level": 5, "layout_preset": "grid_3x4", "time_seconds": 420, "shelves": []}
        current = {"level": 5, "layout_preset": "grid_3x3", "seed": 5005, "shelves": []}

        changes = describe_metadata_changes(previous, current)

        self.assertIn("  ~ layout_preset: 'grid_3x4' -> 'grid_3x3'", changes)
        self.assertIn("  + seed: 5005 added", changes)
        self.assertIn("  - time_seconds: 420 removed", changes)

    def test_reports_a_changed_shelf_count(self) -> None:
        previous = {"level": 2, "shelves": [{"layers": []}]}
        current = {"level": 2, "shelves": [{"layers": []}, {"layers": []}]}

        self.assertIn("  ~ shelves: 1 -> 2", describe_metadata_changes(previous, current))


class RegenerationTests(unittest.TestCase):
    def test_writes_the_template_and_materializes_the_runtime_level(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            templates_directory = Path(directory) / "templates"
            levels_directory = Path(directory) / "levels"
            exit_code, stdout, _stderr = run_regenerate(
                [
                    *BASE_ARGUMENTS,
                    "--level-number",
                    "2",
                    "--templates-directory",
                    str(templates_directory),
                    "--levels-directory",
                    str(levels_directory),
                ]
            )

            self.assertEqual(exit_code, 0)
            template_path = templates_directory / level_file_name(2)
            runtime_path = levels_directory / level_file_name(2)
            self.assertTrue(template_path.is_file())
            self.assertTrue(runtime_path.is_file())
            self.assertIn("content provenance", stdout)

            template = json.loads(template_path.read_text(encoding="utf-8"))
            runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
            self.assertEqual(template["level"], 2)
            template_items = {
                value
                for shelf in template["shelves"]
                for layer in shelf["layers"]
                for value in layer
                if value is not None
            }
            runtime_items = {
                value
                for shelf in runtime["shelves"]
                for layer in shelf["layers"]
                for value in layer
                if value is not None
            }
            self.assertTrue(all(item.startswith("item_") for item in template_items))
            self.assertTrue(all(not item.startswith("item_") for item in runtime_items))
            self.assertEqual(len(template_items), len(runtime_items))

    ## The wrapper must stay a composition of the two tools rather than a second formatter, so the
    ## template it writes has to match `generate_level_shelves.py --output` byte for byte.
    def test_template_matches_direct_generator_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            templates_directory = Path(directory) / "templates"
            levels_directory = Path(directory) / "levels"
            run_regenerate(
                [
                    *BASE_ARGUMENTS,
                    "--level-number",
                    "2",
                    "--templates-directory",
                    str(templates_directory),
                    "--levels-directory",
                    str(levels_directory),
                ]
            )

            direct_path = Path(directory) / "direct.json"
            stdout = io.StringIO()
            stderr = io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                generate_main(
                    [
                        *BASE_ARGUMENTS,
                        "--level-number",
                        "2",
                        "--full-level",
                        "--require-solvable",
                        "--output",
                        str(direct_path),
                    ]
                )

            self.assertEqual(
                (templates_directory / level_file_name(2)).read_text(encoding="utf-8"),
                direct_path.read_text(encoding="utf-8"),
            )

    ## Generation and materialization are one publication step. A board the item pool cannot
    ## satisfy must leave the previous template in place instead of stranding it against a runtime
    ## level that was never rewritten.
    def test_failed_materialization_leaves_the_existing_template_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            templates_directory = Path(directory) / "templates"
            levels_directory = Path(directory) / "levels"
            templates_directory.mkdir()
            template_path = templates_directory / level_file_name(2)
            original_text = json.dumps({"level": 2, "shelves": []}, indent=2) + "\n"
            template_path.write_text(original_text, encoding="utf-8")

            exit_code, _stdout, stderr = run_regenerate(
                [
                    "--level-number",
                    "2",
                    "--shelf-count",
                    "6",
                    "--layer-count",
                    "2",
                    "--item-type-count",
                    "30",
                    "--difficulty",
                    "easy",
                    "--seed",
                    "7",
                    "--allow-unsolvable",
                    "--templates-directory",
                    str(templates_directory),
                    "--levels-directory",
                    str(levels_directory),
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("was not modified", stderr)
            self.assertEqual(template_path.read_text(encoding="utf-8"), original_text)
            self.assertFalse((levels_directory / level_file_name(2)).exists())

    def test_dry_run_reports_changes_without_writing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            templates_directory = Path(directory) / "templates"
            levels_directory = Path(directory) / "levels"
            templates_directory.mkdir()
            template_path = templates_directory / level_file_name(2)
            original_text = (
                json.dumps({"level": 2, "layout_preset": "grid_3x4", "shelves": []}, indent=2)
                + "\n"
            )
            template_path.write_text(original_text, encoding="utf-8")

            exit_code, stdout, _stderr = run_regenerate(
                [
                    *BASE_ARGUMENTS,
                    "--level-number",
                    "2",
                    "--dry-run",
                    "--templates-directory",
                    str(templates_directory),
                    "--levels-directory",
                    str(levels_directory),
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertIn("~ layout_preset: 'grid_3x4' -> 'grid_3x3'", stdout)
            self.assertIn("dry run", stdout)
            self.assertEqual(template_path.read_text(encoding="utf-8"), original_text)
            self.assertFalse((levels_directory / level_file_name(2)).exists())

    ## Level 10 ships as a hand-authored runtime level with no template behind it. Generating one
    ## replaces authored content, so the run has to say so.
    def test_warns_when_a_runtime_level_has_no_template(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            templates_directory = Path(directory) / "templates"
            levels_directory = Path(directory) / "levels"
            levels_directory.mkdir()
            (levels_directory / level_file_name(2)).write_text("{}", encoding="utf-8")

            exit_code, _stdout, stderr = run_regenerate(
                [
                    *BASE_ARGUMENTS,
                    "--level-number",
                    "2",
                    "--templates-directory",
                    str(templates_directory),
                    "--levels-directory",
                    str(levels_directory),
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertIn("authored by hand", stderr)


class GenerationManifestTests(unittest.TestCase):
    def regenerate(
        self,
        directory: Path,
        arguments: list[str],
    ) -> tuple[int, str, str, Path, Path]:
        templates_directory = directory / "templates"
        levels_directory = directory / "levels"
        exit_code, stdout, stderr = run_regenerate(
            [
                *arguments,
                "--templates-directory",
                str(templates_directory),
                "--levels-directory",
                str(levels_directory),
            ]
        )
        return exit_code, stdout, stderr, templates_directory, levels_directory

    def read_manifest(self, templates_directory: Path) -> dict:
        return json.loads(
            (templates_directory / MANIFEST_FILE_NAME).read_text(encoding="utf-8")
        )

    def test_records_the_arguments_the_run_used(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            exit_code, stdout, _stderr, templates_directory, _levels = self.regenerate(
                Path(directory), [*BASE_ARGUMENTS, "--level-number", "2"]
            )

            self.assertEqual(exit_code, 0)
            self.assertIn("recorded the generation arguments", stdout)
            manifest = self.read_manifest(templates_directory)
            self.assertEqual(manifest["schema_version"], MANIFEST_SCHEMA_VERSION)
            entry = manifest["entries"][level_file_name(2)]
            self.assertEqual(entry["resolved_seed"], 123)
            self.assertEqual(entry["arguments"]["--shelf-count"], 9)
            self.assertEqual(entry["arguments"]["--difficulty"], "easy")
            self.assertTrue(entry["arguments"]["--require-solvable"])
            self.assertTrue(entry["command"].startswith("py scripts/tools/regenerate_level.py"))
            self.assertIn("--seed 123", entry["command"])

            template_text = (templates_directory / level_file_name(2)).read_text(
                encoding="utf-8"
            )
            self.assertEqual(
                entry["template_sha256"],
                hashlib.sha256(template_text.encode("utf-8")).hexdigest(),
            )

    ## Recording the requested seed would lose the board whenever one was not given or a retry
    ## advanced it, which is exactly when the record matters most.
    def test_records_the_seed_the_generator_resolved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            arguments = [argument for argument in BASE_ARGUMENTS if argument not in ("--seed", "123")]
            _exit_code, _stdout, _stderr, templates_directory, _levels = self.regenerate(
                Path(directory), [*arguments, "--level-number", "2"]
            )

            entry = self.read_manifest(templates_directory)["entries"][level_file_name(2)]
            template = json.loads(
                (templates_directory / level_file_name(2)).read_text(encoding="utf-8")
            )
            self.assertIsInstance(entry["resolved_seed"], int)
            self.assertEqual(entry["resolved_seed"], template["seed"])
            self.assertIn(f"--seed {template['seed']}", entry["command"])

    def test_records_the_resolved_layout_preset(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            _exit_code, _stdout, _stderr, templates_directory, _levels = self.regenerate(
                Path(directory), [*BASE_ARGUMENTS, "--level-number", "2"]
            )

            entry = self.read_manifest(templates_directory)["entries"][level_file_name(2)]
            self.assertEqual(entry["arguments"]["--layout-preset"], "grid_3x3")

    ## A collapsing board is rejected when it is replayed with a layout preset, so the record must
    ## not invent one.
    def test_omits_the_layout_preset_for_collapsing_columns(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            exit_code, _stdout, _stderr, templates_directory, _levels = self.regenerate(
                Path(directory),
                [
                    "--level-number",
                    "9",
                    "--gameplay-mode",
                    "collapsing_columns",
                    "--column-heights",
                    "9,9,9",
                    "--visible-shelves-per-column",
                    "4",
                    "--item-type-count",
                    "14",
                    "--difficulty",
                    "medium",
                    "--seed",
                    "9009",
                ],
            )

            self.assertEqual(exit_code, 0)
            entry = self.read_manifest(templates_directory)["entries"][level_file_name(9)]
            self.assertIsNone(entry["arguments"]["--layout-preset"])
            self.assertNotIn("--layout-preset", entry["command"])
            self.assertEqual(entry["arguments"]["--column-heights"], "9,9,9")

    ## The record is only worth keeping if replaying it rebuilds the same board.
    def test_the_recorded_command_reproduces_the_level(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _exit_code, _stdout, _stderr, templates_directory, levels_directory = self.regenerate(
                root / "first", [*BASE_ARGUMENTS, "--level-number", "2"]
            )
            entry = self.read_manifest(templates_directory)["entries"][level_file_name(2)]

            replay_arguments = shlex.split(entry["command"])[2:]
            _replay_code, _out, _err, replay_templates, replay_levels = self.regenerate(
                root / "replay", replay_arguments
            )

            self.assertEqual(
                (templates_directory / level_file_name(2)).read_text(encoding="utf-8"),
                (replay_templates / level_file_name(2)).read_text(encoding="utf-8"),
            )
            self.assertEqual(
                (levels_directory / level_file_name(2)).read_text(encoding="utf-8"),
                (replay_levels / level_file_name(2)).read_text(encoding="utf-8"),
            )

    def test_keeps_existing_entries_sorted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.regenerate(root, [*BASE_ARGUMENTS, "--level-number", "3"])
            _exit_code, _stdout, _stderr, templates_directory, _levels = self.regenerate(
                root, [*BASE_ARGUMENTS, "--level-number", "2"]
            )

            entries = self.read_manifest(templates_directory)["entries"]
            self.assertEqual(list(entries), [level_file_name(2), level_file_name(3)])

    def test_no_record_leaves_no_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            exit_code, stdout, _stderr, templates_directory, _levels = self.regenerate(
                Path(directory), [*BASE_ARGUMENTS, "--level-number", "2", "--no-record"]
            )

            self.assertEqual(exit_code, 0)
            self.assertNotIn("recorded", stdout)
            self.assertFalse((templates_directory / MANIFEST_FILE_NAME).exists())

    def test_dry_run_records_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            exit_code, stdout, _stderr, templates_directory, _levels = self.regenerate(
                Path(directory), [*BASE_ARGUMENTS, "--level-number", "2", "--dry-run"]
            )

            self.assertEqual(exit_code, 0)
            self.assertIn("would write", stdout)
            self.assertFalse((templates_directory / MANIFEST_FILE_NAME).exists())

    ## An unusable manifest has to stop the run before the level files are replaced, so the run
    ## never half-applies.
    def test_an_unreadable_manifest_stops_the_run_before_writing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            templates_directory = Path(directory) / "templates"
            templates_directory.mkdir()
            (templates_directory / MANIFEST_FILE_NAME).write_text(
                json.dumps({"schema_version": 99, "entries": {}}), encoding="utf-8"
            )

            exit_code, _stdout, stderr = run_regenerate(
                [
                    *BASE_ARGUMENTS,
                    "--level-number",
                    "2",
                    "--templates-directory",
                    str(templates_directory),
                    "--levels-directory",
                    str(Path(directory) / "levels"),
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("schema_version must be", stderr)
            self.assertIn("was not modified", stderr)
            self.assertFalse((templates_directory / level_file_name(2)).exists())


if __name__ == "__main__":
    unittest.main()
