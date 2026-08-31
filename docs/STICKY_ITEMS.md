# Sticky items

Implemented in the game client and level tools on 2026-08-31. Existing campaign layouts are unchanged.
The earlier design discussion is retained in [STICKY_ITEMS_PLAN.md](STICKY_ITEMS_PLAN.md).

## Play and compare the artwork

Run `scenes/testing/sticky_items_preview.tscn` with Godot's **Run Current Scene (F6)**, or open
`scenes/main_menu_testing.tscn` and press **Sticky items preview** in a debug build.
The production menu is unchanged.

The preview uses `configs/test_levels/sticky_items_preview.json`: nine shelves, six sticky items
across successive layers, an initially locked shelf, and a moving row. The board is solvable in
17 moves according to the Python validator. Pink, Amber, Both, and Reset controls stay below the
ability bar and account for safe-area insets. Both shows pink on the upper shelves and amber on
the lower shelves. Switching artwork updates hidden items too. Reset and retry retain the choice.
This is a dev-mode level with temporary ability counts; completing it does not advance the campaign.

The two selected generated assets are retained separately:

- `assets/ui/sticky_items/gum_pink.png`: pink gum, from `exec-739e3fcf-8e5e-47f4-ae60-5aa9f46d757e.png`.
- `assets/ui/sticky_items/glue_amber.png`: amber glue, from `exec-73b84264-0749-4752-8fd6-53a027519bb6.png`.

ImageMagick removed only the connected gray background, trimmed and resized the images, and added
a transparent border. Originals in the user's generated-images directory were not modified. The
marker scene draws back and front portions around the item's base without covering its identity.
Authored sticky levels default to the pink variant; change `level.gd`'s exported `sticky_marker_variant`
or call `set_sticky_marker_variant("amber")` to compare the other artwork on an authored level.
No final art choice is implied by this default.

## Rules and ownership

| Owner | Responsibility |
| --- | --- |
| `scripts/sticky_item_rules.gd` | Sticky config validation and Hammer partner reserves. |
| `scripts/item.gd`, `scenes/item.tscn` | Instance flag, marker, and blocked-tap feedback. |
| `scripts/sticky_item_indicator.gd`, `scenes/ui/sticky_item_indicator.tscn` | Texture variant, front/back presentation, and brief brightness pulse. |
| `scripts/level.gd` | Load flags, movement guards, matching, sticky-aware ability selection and hints. |
| `scripts/sticky_items_preview.gd`, `scenes/testing/sticky_items_preview.tscn` | Playable comparison, reset, dev-mode isolation. |
| `scripts/sticky_preview_controls.gd`, `scenes/ui/sticky_preview_controls.tscn` | Variant/reset controls and safe-area placement. |
| `scripts/tools/sticky_items.py` | Shared Python authoring validation. |
| `scripts/tools/generate_level_shelves.py` | Percentage, deterministic placement, final statistics, validation/retry. |
| `scripts/tools/validate_level_solvable.py` | Sticky state, legal moves, promotion, copy constraints, and replayable solutions. |
| `scripts/tools/level_item_progression.py` | Validate and preserve coordinates while mapping logical IDs. |

Sticky belongs to an item instance, not its type or its slot. There is at most one sticky item
per individual shelf layer. Standard shelves may carry sticky items, including hidden layers,
locked shelves, and moving shelves, subject to the existing shelf rules. Dispensers cannot.

Sticky items cannot be selected, dragged, or moved through direct move calls. A blocked tap pulses
the marker without starting the timer. With an ordinary item selected, tapping the sticky item
still routes to an empty slot on that shelf. The sticky item clears normally with two matching
items, earning normal stars/combo progress. Hidden sticky items retain their flags on promotion.
Shelf unlocking never removes an item's sticky flag. Retry reloads the authored placements.

Hammer excludes sticky targets in front and back layers. It also reserves matching partners:
removing three ordinary copies of a type is allowed only when
`remaining_count - 3 >= 3 * remaining_sticky_count`, counting all shelves/layers.
Shuffle excludes sticky instances from animation and identity reassignment. Lantern may highlight
an exposed sticky destination plus ordinary partners; it never proposes moving another anchor.
Hints conservatively require enough reachable outside empty slots to park mismatching blockers.
Unusable Hammer, Shuffle, or Lantern requests do not spend inventory or coins. Freezer is unchanged.

These checks do not prove that every later player move or shuffle preserves solvability. The
generator's proof applies to the initial board; the Hammer reserve is a necessary copy-count check.

## Configuration and generation

Keep `layers` as strings/null. Add optional zero-based coordinates on each shelf:

```json
{
  "layers": [["item_01", null, "item_02"], ["item_03", null, null]],
  "sticky_items": [{"layer": 0, "slot": 0}, {"layer": 1, "slot": 0}]
}
```

This is a schema example, not a complete level. Omission or `[]` means no sticky items. Each entry
must contain exactly `layer` and `slot`, nonnegative integer indices referencing an occupied slot.
Repeated layers, empty targets, malformed metadata, and sticky dispensers are rejected. Python
rejects float coordinates; Godot accepts integer-valued JSON numbers because its JSON parser
represents numbers as floats. Runtime invalid metadata pauses the level with a diagnostic instead
of silently creating movable items. Materialization deep-copies coordinates and maps only IDs.

Example generating a temporary abstract board without replacing campaign content:

```powershell
py scripts/tools/generate_level_shelves.py --shelf-count 6 --layer-count 2 --difficulty easy --seed 42 --sticky-items-percent 10 --require-solvable --stats --output tmp/sticky_shelves.json
```

`--sticky-items-percent` accepts finite values from 0 through 100 and defaults to 0. Zero preserves
the previous generator output and RNG behavior. For positive values:

1. Count all non-null items, including hidden and dispenser items. Compute
   `floor(item_count * percent / 100 + 0.5)`.
2. Cap that count at the number of occupied standard shelf layers and report the capacity cap.
3. Use a separate seeded assignment to distribute sticky items with one per layer and enough
   matching copies per type. Moving geometry does not change their source restriction.
4. Check collectible opening types after dispenser/lock/sticky placement and solve the final board
   when `--validate` or `--require-solvable` is supplied. Structural validation always runs for positive
   percentages; the CLI warns when output has no proof. Prefer `--require-solvable` for authored content.

Small positive percentages may round to zero. If type/dependency constraints cannot meet the target,
retry within `--max-generation-attempts`; never silently reduce it beyond the layer-capacity cap.
`--require-solvable` refuses to write/overwrite output unless proof succeeds. State/depth exhaustion
reports `solvable: null`, not a false proof of impossibility.

`--stats` includes `sticky_items.requested_percent`, `requested_count`, `eligible_layer_count`,
`target_count`, `actual_count`, `effective_percent`, `placements`, and `cap_reason`, plus the used
seed/attempt and final solver result. Placement coordinates are zero-based. Full-level output also
records positive `sticky_items_percent` as authoring metadata; runtime uses only exact placements.
The personal `sorting-puzzle-generate-level` skill documents preservation and materialization.

Solver canonical keys include sticky identity and layer. Search paths keep the authored board
order; `--show-solution` now reports `solution_indexing: "authored_1_based"` and `from_shelf` /
`to_shelf` fields, replacing the old canonical-shelf labels. Moving rows are treated as eventually
accessible; timing and screen geometry are tested separately in Godot.

## Verification

```powershell
py -m unittest discover -s tests/tools -v
& scripts/tools/run_isolated_godot_test.ps1 -Script tests/gameplay/test_sticky_items.gd -Windowed
& scripts/tools/capture_ui.ps1 -Scene scenes/testing/sticky_items_preview.tscn -Name sticky_preview -Position '0,0'
```

`tests/tools/test_sticky_items.py` covers malformed metadata, deterministic placement/caps,
materialization, movement and promotion, canonical identity, depth limits, CLI no-overwrite on
failed proof, and the shared `tests/fixtures/sticky_items_conformance.json` replay.
`tests/gameplay/test_sticky_items.gd` exercises tap/drag/direct moves, promotion, locks, moving rows,
both artwork variants, partner reserves, actual Hammer execution, no-op ability charges, and the
same Python solution clearing in Godot.

The 2026-08-31 seed matrix solved 15/16 requests within 5 attempts, 3,000 states, and depth 150.
It covers four difficulties, 1-3 layers, 10/20%, copy caps 3/6, locks, and dispensers, with seeds
11/42. One medium/20%/locked request exhausted its state budget and remained explicitly inconclusive.
Artifacts and timings are in ignored `tmp/sticky_seed_matrix.json`; this is not a universal success
rate or a guarantee for high percentages.

The tools suite passes all 50 tests, and the dedicated Godot sticky suite passes all six stages.

Rendered preview and testing-menu captures were inspected at 540x960, 720x1280, 1080x1920, and
1080x2400. Both markers are readable and footer controls fit. Requested 1200x1600 rendered only a
900x1600 viewport under existing `keep_width` stretch behavior; the capture warns about the mismatch
and is not full tablet-resolution verification. The testing menu's existing decorative ribbon is
offset from its title at 1080x2400; the added preview button remains visible and usable.
Images/contact sheets are in ignored `tmp/ui_capture/`.

## Release boundary

The client mechanic and comparison preview are implemented; no campaign levels were regenerated,
and no save/protocol schema or sibling-backend files were changed. Before publishing sticky campaign
content, update the backend normalization contract to preserve `sticky_items`, publish compatible
immutable content/rule identities, gate older clients, and regenerate provenance through the
established publication flow. See section 7 of the original plan. Do not activate dormant replay
proofs or hand-edit hashes to bypass this work.

The read-only `scripts/tools/check_content_provenance.gd` check currently reports
`content_manifest.source_stale`; connected export is not release-ready. The unrelated dispenser
regression also reports that `RightWallInnerFace` should be above the item shadow: unchanged baseline
art has wall Z=5 and effective shadow Z=6. Its gameplay checks run, but the suite is not all green.
Moving-shelf, Hammer-animation, Lantern, item-selection, and item-progression regression suites pass.
