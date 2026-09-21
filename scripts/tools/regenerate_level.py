#!/usr/bin/env python3
"""Generate one campaign level template in place and materialize its runtime level file.

This wraps `generate_level_shelves.py` and the single-level materialization path so a level is
regenerated from its authored arguments in one command:

    py scripts\\tools\\regenerate_level.py --level-number 5 --shelf-count 12 --layer-count 2 \\
        --difficulty hard --seed 5005

The template path comes from `--level-number`, so `--output` is not accepted here.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from generate_level_shelves import build_parser, run as run_generator, validate_mode_arguments
from level_item_progression import (
    DEFAULT_CHAPTERS_CONFIG,
    DEFAULT_ITEM_CONFIG,
    DEFAULT_PROGRESSION_CONFIG,
    format_json,
    load_item_progression,
    load_json_object,
    materialize_level,
)


DEFAULT_TEMPLATES_DIRECTORY = Path("configs/level_templates")
DEFAULT_LEVELS_DIRECTORY = Path("configs/levels")
PROVENANCE_PATH = Path("configs/backend/content_provenance.json")

## The manifest sits beside the templates it describes. `materialize_level_templates.py` globs
## `level_*.json`, so this name is not picked up as a template.
MANIFEST_FILE_NAME = "generation_manifest.json"
MANIFEST_SCHEMA_VERSION = 1

## Wrapper plumbing and output switches say nothing about the board, so they stay out of the
## record. Everything else the generator accepts is recorded, defaults included: a later change to
## a generator default must not silently change what a replay of this entry produces.
NON_GENERATION_ARGUMENTS = frozenset(
    {
        "allow_unsolvable",
        "chapters_config",
        "dry_run",
        "full_level",
        "item_config",
        "levels_directory",
        "no_record",
        "output",
        "progression_config",
        "stats",
        "templates_directory",
    }
)


def build_wrapper_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Regenerate a campaign level template from generator arguments and materialize its "
            "runtime level file."
        ),
        parents=[build_parser(add_help=False)],
    )
    ## The generator defaults `--level-number` to 1 because it can also emit a throwaway board to
    ## stdout. Here the number selects which shipped template is replaced, so an accidental
    ## omission would silently overwrite level 1.
    parser.set_defaults(level_number=None)
    parser.add_argument("--templates-directory", type=Path, default=DEFAULT_TEMPLATES_DIRECTORY)
    parser.add_argument("--levels-directory", type=Path, default=DEFAULT_LEVELS_DIRECTORY)
    parser.add_argument("--progression-config", type=Path, default=DEFAULT_PROGRESSION_CONFIG)
    parser.add_argument("--item-config", type=Path, default=DEFAULT_ITEM_CONFIG)
    parser.add_argument("--chapters-config", type=Path, default=DEFAULT_CHAPTERS_CONFIG)
    parser.add_argument(
        "--allow-unsolvable",
        action="store_true",
        help=(
            "Replace the template even without a solvability proof. Regeneration requires "
            "--require-solvable by default because the output ships as a campaign level."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate and materialize, report what would change, but write nothing.",
    )
    parser.add_argument(
        "--no-record",
        action="store_true",
        help=f"Skip updating {MANIFEST_FILE_NAME} with the arguments this run used.",
    )
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = build_wrapper_parser()
    args = parser.parse_args(argv)
    if args.level_number is None:
        parser.error("--level-number is required; it selects the template that gets replaced")
    if args.level_number < 1:
        parser.error("--level-number must be a positive integer")
    if args.output is not None:
        parser.error(
            "--output is not accepted; the template path is derived from --level-number"
        )
    ## A shelves-only array cannot be a template, and a board that ships without a solvability
    ## proof is the expensive kind of mistake, so both are forced rather than offered.
    args.full_level = True
    if not args.allow_unsolvable:
        args.require_solvable = True
    validate_mode_arguments(parser, args)
    return args


def level_file_name(level_number: int) -> str:
    return f"level_{level_number:03d}.json"


def count_shelves(level: dict[str, Any]) -> int:
    shelves = level.get("shelves")
    return len(shelves) if isinstance(shelves, list) else 0


## Post-generation hand edits are real in this repo: level 5's layout preset and level 3's timer
## were changed after their boards were generated. Regeneration reverts them, so every top-level
## difference is reported instead of disappearing into a large shelves diff.
def describe_metadata_changes(
    previous: dict[str, Any] | None,
    current: dict[str, Any],
) -> list[str]:
    if previous is None:
        return []

    changes: list[str] = []
    keys = (set(previous) | set(current)) - {"shelves"}
    for key in sorted(keys):
        if key not in current:
            changes.append(f"  - {key}: {previous[key]!r} removed")
        elif key not in previous:
            changes.append(f"  + {key}: {current[key]!r} added")
        elif previous[key] != current[key]:
            changes.append(f"  ~ {key}: {previous[key]!r} -> {current[key]!r}")

    previous_shelves = count_shelves(previous)
    current_shelves = count_shelves(current)
    if previous_shelves != current_shelves:
        changes.append(f"  ~ shelves: {previous_shelves} -> {current_shelves}")
    return changes


def argument_flag(argument_name: str) -> str:
    return "--" + argument_name.replace("_", "-")


## The recorded arguments are the replay contract, so they are stored structurally. A shell string
## would be quoting-specific and would invite replaying a config file through a shell; the command
## below is derived from these values for reading, not for being the source of truth.
def resolved_seed(template: dict[str, Any]) -> int | None:
    seed = template.get("seed")
    return seed if isinstance(seed, int) else None


## Values are recorded as the generator resolved them, not as they were requested: replaying an
## entry has to rebuild this board even after a generator default moves.
def build_recorded_arguments(
    args: argparse.Namespace,
    template: dict[str, Any],
) -> dict[str, Any]:
    recorded = {
        argument_flag(name): value
        for name, value in sorted(vars(args).items())
        if name not in NON_GENERATION_ARGUMENTS
    }
    ## The generator draws a fresh seed when none is given and advances it on every retry, so the
    ## board came from this seed rather than from whatever was requested.
    recorded["--seed"] = resolved_seed(template)
    ## A classic board falls back to the default preset when none is requested. A collapsing board
    ## has no preset at all and must not be replayed with one.
    if "layout_preset" in template:
        recorded["--layout-preset"] = template["layout_preset"]
    return recorded


def format_command(recorded_arguments: dict[str, Any]) -> str:
    parts = ["py", "scripts/tools/regenerate_level.py"]
    for flag, value in recorded_arguments.items():
        if value is None or value is False:
            continue
        parts.append(flag)
        if value is not True:
            parts.append(str(value))
    return " ".join(parts)


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_manifest(manifest_path: Path) -> dict[str, Any]:
    if not manifest_path.is_file():
        return {"schema_version": MANIFEST_SCHEMA_VERSION, "entries": {}}

    manifest = load_json_object(manifest_path)
    schema_version = manifest.get("schema_version")
    if schema_version != MANIFEST_SCHEMA_VERSION:
        raise ValueError(
            f"{manifest_path} schema_version must be {MANIFEST_SCHEMA_VERSION}, "
            f"found {schema_version!r}"
        )
    if not isinstance(manifest.get("entries"), dict):
        raise ValueError(f"{manifest_path} must contain an entries object")
    return manifest


def build_manifest_entry(
    args: argparse.Namespace,
    template: dict[str, Any],
    template_text: str,
) -> dict[str, Any]:
    recorded_arguments = build_recorded_arguments(args, template)
    return {
        "command": format_command(recorded_arguments),
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "resolved_seed": resolved_seed(template),
        "template_sha256": sha256_text(template_text),
        "arguments": recorded_arguments,
    }


def write_manifest(
    manifest_path: Path,
    manifest: dict[str, Any],
    file_name: str,
    entry: dict[str, Any],
) -> None:
    manifest["entries"][file_name] = entry
    manifest["entries"] = dict(sorted(manifest["entries"].items()))
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(format_json(manifest), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    file_name = level_file_name(args.level_number)
    template_path = args.templates_directory / file_name
    runtime_path = args.levels_directory / file_name
    manifest_path = args.templates_directory / MANIFEST_FILE_NAME

    ## An unreadable manifest is resolved before generation rather than after the level files have
    ## already been replaced, so the run either records itself or changes nothing.
    manifest: dict[str, Any] | None = None
    if not args.no_record:
        try:
            manifest = load_manifest(manifest_path)
        except (OSError, ValueError) as error:
            print(f"error: {error}", file=sys.stderr)
            print(f"error: {template_path} was not modified", file=sys.stderr)
            return 1

    previous_template: dict[str, Any] | None = None
    if template_path.is_file():
        try:
            previous_template = load_json_object(template_path)
        except (OSError, ValueError) as error:
            print(f"warning: cannot read existing {template_path}: {error}", file=sys.stderr)
    elif runtime_path.is_file():
        ## Level 10 is authored directly in `configs/levels/` with no template behind it. Adding a
        ## template for such a level replaces hand-authored content rather than regenerating.
        print(
            f"warning: {runtime_path} exists without a template; it was authored by hand and "
            "will be replaced by generated content",
            file=sys.stderr,
        )

    ## The generator writes to a temporary file first: materialization can still fail on the board
    ## contract or an exhausted chapter item pool, and a half-applied run would leave the template
    ## and its runtime level out of sync.
    with tempfile.TemporaryDirectory(prefix="regenerate_level_") as temporary_directory:
        args.output = Path(temporary_directory) / file_name
        generator_exit_code = run_generator(args)
        if generator_exit_code != 0:
            print(
                f"error: generation failed with exit code {generator_exit_code}; "
                f"{template_path} was not modified",
                file=sys.stderr,
            )
            return generator_exit_code

        template_text = args.output.read_text(encoding="utf-8")
        template = load_json_object(args.output)

    try:
        progression = load_item_progression(
            args.progression_config,
            args.item_config,
            args.chapters_config,
        )
        materialized, _mapping = materialize_level(template, progression)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        print(f"error: {template_path} was not modified", file=sys.stderr)
        return 1

    changes = describe_metadata_changes(previous_template, template)
    if changes:
        print(f"{template_path} metadata changes:")
        print("\n".join(changes))

    if args.dry_run:
        recorded = "" if manifest is None else f", and record it in {manifest_path}"
        print(f"dry run: would write {template_path} and {runtime_path}{recorded}")
        return 0

    try:
        template_path.parent.mkdir(parents=True, exist_ok=True)
        template_path.write_text(template_text, encoding="utf-8")
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.write_text(format_json(materialized), encoding="utf-8")
        if manifest is not None:
            write_manifest(
                manifest_path,
                manifest,
                file_name,
                build_manifest_entry(args, template, template_text),
            )
    except OSError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(f"wrote {template_path}")
    print(f"wrote {runtime_path}")
    if manifest is not None:
        print(f"recorded the generation arguments in {manifest_path}")
    print(
        f"note: {PROVENANCE_PATH} hashes both files and is now stale; republish content "
        "provenance before shipping this level."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
