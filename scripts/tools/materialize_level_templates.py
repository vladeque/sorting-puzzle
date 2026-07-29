"""Materialize every abstract campaign level template into runtime level JSON."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from level_item_progression import (
    DEFAULT_ITEM_CONFIG,
    DEFAULT_PROGRESSION_CONFIG,
    format_json,
    load_item_progression,
    load_json_object,
    materialize_level,
    write_json,
)


DEFAULT_TEMPLATES_DIRECTORY = Path("configs/level_templates")
DEFAULT_OUTPUT_DIRECTORY = Path("configs/levels")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Materialize all Sorting Puzzle level templates."
    )
    parser.add_argument(
        "--templates-directory",
        type=Path,
        default=DEFAULT_TEMPLATES_DIRECTORY,
    )
    parser.add_argument(
        "--output-directory",
        type=Path,
        default=DEFAULT_OUTPUT_DIRECTORY,
    )
    parser.add_argument(
        "--progression-config",
        type=Path,
        default=DEFAULT_PROGRESSION_CONFIG,
    )
    parser.add_argument("--item-config", type=Path, default=DEFAULT_ITEM_CONFIG)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail instead of writing when a runtime level is missing or stale.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        progression = load_item_progression(args.progression_config, args.item_config)
        template_paths = sorted(args.templates_directory.glob("level_*.json"))
        if not template_paths:
            raise ValueError(
                f"{args.templates_directory} does not contain any level templates"
            )

        stale_paths: list[Path] = []
        for template_path in template_paths:
            abstract_level = load_json_object(template_path)
            materialized, _mapping = materialize_level(abstract_level, progression)
            output_path = args.output_directory / template_path.name
            expected = format_json(materialized)
            if args.check:
                if not output_path.is_file() or output_path.read_text(encoding="utf-8") != expected:
                    stale_paths.append(output_path)
            else:
                write_json(output_path, materialized)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if stale_paths:
        print("error: materialized runtime levels are stale:", file=sys.stderr)
        for stale_path in stale_paths:
            print(f"- {stale_path}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
