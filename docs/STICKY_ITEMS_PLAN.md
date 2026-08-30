# Sticky Items Implementation Plan

Status: Draft for product review; no gameplay changes implemented.
Date: 2026-08-31.

## Requested behavior

- Some individual items are sticky and cannot be moved by the player.
- The player brings matching items onto that shelf to clear the sticky item in a normal triple.
- A shelf may contain at most one sticky item.
- Level generation accepts a sticky-items percentage and distributes the resulting sticky items
  randomly across shelves.

Sticky is an item-instance property, not an item type or another whole-shelf lock. Other items on
the shelf remain movable and its empty slots remain valid destinations.

## Product decisions to confirm

These recommendations are proposals, not additional approved requirements. Settle them before
implementing the affected behavior.

| Decision | Recommendation | Consequence |
| --- | --- | --- |
| Scope of one sticky item per shelf | One across every authored layer, not one per layer | A shelf never contains two sticky items, including hidden ones. |
| Placement depth | Allow any occupied layer | Hidden sticky items promote normally and become immovable when exposed. Promotion is automatic, not a player move. |
| Eligible shelves | Standard shelves, including moving and initially locked standard shelves; never dispensers | Moving shelves carry sticky items with them. Existing visibility and shelf-lock rules still apply. Dispensers cannot receive drops or form triples. |
| Hammer | Exclude sticky items and preserve enough matching copies for remaining sticky items | Sticky items clear only through shelf triples; Hammer must not destroy their required partners. |
| Shuffle | Exclude sticky items from both animation and identity reassignment | Their position, identity, and sticky state remain unchanged. |
| Percentage meaning | Percentage of all non-null items in the finished board, including hidden and dispenser items | Placement still uses only eligible standard shelves. Empty slots do not count. |
| Rounding and capacity | Round to nearest integer, halves upward; cap at the number of eligible occupied shelves; report the cap | Small positive percentages can produce zero sticky items. A requested percentage is a target, not always achievable. |
| Feedback | Persistent item marker and a short blocked-tap response; no timer start from a blocked tap alone | Item identity must remain readable, and blocked selection must not look like successful selection. |

If one sticky item *per layer* is desired instead, change the proposed schema and placement capacity
before implementation. If Hammer is allowed to remove sticky items, specify whether it can gather
them away from their shelves and how its animation communicates that exception.

## Current implementation and change map

| Area | Current owner | Required work |
| --- | --- | --- |
| Template generation | `scripts/tools/generate_level_shelves.py` | New percentage option, deterministic placement, capacity checks, stats, validation integration. |
| Static validation and search | `scripts/tools/validate_level_solvable.py` | Parse sticky metadata; model immovability, promotion, clearing, and state equivalence correctly. |
| Art materialization | `scripts/tools/level_item_progression.py`, `materialize_level_templates.py` | Preserve sticky coordinates while mapping only item IDs; validate the new metadata and regress existing outputs. |
| Item state and visuals | `scripts/item.gd`, `scenes/item.tscn` | Per-instance sticky property and dedicated marker component. |
| Board loading, input, matching, abilities | `scripts/level.gd` | Load flags, enforce source restrictions, retain destination behavior, update ability eligibility and hints. |
| Shelf layers and variants | `scripts/shelf.gd`, `dispenser_shelf.gd`, `moving_shelf.gd` | Preserve flags and presentation through layers; explicitly reject incompatible shelf types. No new shelf type is needed. |
| Content publication | Backend configuration normalization/publication and `configs/backend/content_provenance.json` | Preserve the mechanic in published definitions and refresh provenance before a connected release. |

Avoid an unrelated rewrite of `level.gd`. Put reusable item restriction logic in a focused
`scripts/item_rules.gd` helper if needed; item visuals belong to the item component, not the level.

## 1. Configuration contract

Recommended additive shelf field, with zero-based indices:

```json
{
  "layers": [
    ["item_01", null, "item_02"],
    ["item_03", "item_01", "item_02"]
  ],
  "sticky_item": { "layer": 1, "slot": 0 }
}
```

This marks the specific `item_03` instance in the second layer. Keeping `layers` as strings/null
avoids changing every item catalog/counting/materialization consumer to accept object-valued slots.
The example illustrates the shelf shape, not a complete solvable level.

- Omit `sticky_item` for an ordinary shelf. Existing configurations retain their behavior.
- Require exactly the `layer` and `slot` integer fields, both nonnegative and in range; reject
  booleans, fractions, null metadata, empty target slots, and metadata on dispensers.
- A singular field structurally represents at most one sticky instance per shelf. Do not also add
  a second flag format in the layer arrays.
- Store exact placement in the canonical template and preserve it in the materialized runtime
  level. Never roll sticky placement randomly when loading a level.
- Coordinates identify the initial instance. After loading, sticky state follows that instance
  through promotion; it is not a permanent sticky slot and is not reassigned after a clear.
- Authoring metadata may record the requested percentage, actual count, and used seed for
  reproducibility. Exact shelf placements, not the percentage, control runtime gameplay.
- Validate before building the runtime board. Malformed sticky metadata must produce a clear
  content error rather than silently turning an intended sticky item into a movable one.
- `materialize_level()` already deep-copies shelf metadata. Preserve that behavior, add focused
  validation/tests, and leave the item progression catalog unchanged.

## 2. Solvability model first

Update the solver before enabling sticky generation. Merely marking an already validated board
does not preserve solvability.

- Model occupied cells with item identity and sticky state, or equivalently extend shelf state
  with a sticky position that is correctly remapped on every transition.
- Exclude sticky instances from legal move sources and enforce that in move application too.
  Other items can still move into empty slots on the sticky item's shelf.
- Match by item identity only. A sticky flag must not prevent a three-of-a-kind clear.
- Preserve the flag during layer promotion and remove it when its owning instance clears.
- Include sticky state in hashing, sorting, and duplicate-state pruning. The current solver sorts
  items within layers and shelves globally: sorting IDs while retaining old sticky coordinates
  would attach the restriction to the wrong instance and produce false solvability results.
- Audit solution reconstruction as well as search deduplication. A reported solution must map back
  to actual authored shelf/slot indices and replay without ever moving a sticky instance.
- Preserve lock behavior and the existing moving-shelf abstraction. This solver proves a logical
  solution without abilities; it does not prove completion within the level timer or conveyor timing.
- Retain the distinction between unsolvable and search-budget exhaustion. An inconclusive result
  must never be accepted as a solvability guarantee.

A useful necessary condition is:

```text
sticky instances of type T <= total remaining copies of T / 3
```

Each sticky instance needs its own triple because sticky instances on different shelves cannot be
gathered together. With only three copies of an item, two sticky copies on different shelves make
the level impossible. Check this early, but still run the solver: matching partners can also be
trapped in deeper layers, behind locks, or in circular dependencies.

## 3. Generator option and placement

Add `--sticky-items-percent`, accepting finite values from `0` through `100`, default `0`.
Reject invalid input before writing output. Preserve existing generation and RNG behavior when the
option is omitted or zero.

Recommended count policy:

```text
N = count of all non-null items after dispenser insertion
E = count of occupied standard shelves eligible for sticky placement
requested_count = floor(N * percent / 100 + 0.5)
target_count = min(requested_count, E)
```

Example: 90 items, 9 eligible shelves, 20% requested gives 18 requested, 9 targeted, and 10%
effective. Emit a clear capacity warning; never report that board as having 20% sticky items.

Placement pipeline:

1. Generate ordinary item distribution using existing difficulty, copy limits, and layer rules.
2. Insert dispenser shelves and apply whole-shelf locks as today.
3. Compute the count and sample eligible shelves without replacement, then occupied cells within
   them. Use a deterministic RNG stream derived from the attempt seed for sticky placement.
4. Respect per-item-type sticky limits. Use bounded retry/backtracking when shelf and type choices
   conflict; an unlucky greedy choice must not be reported as proof that placement is impossible.
5. Check the opening-progress requirement after sticky placement and locks. Counting three visible
   copies is insufficient if they cannot legally be gathered. Preserve the existing meaning of
   `--min-front-visible-triples` and document how legal gathering is checked.
6. Validate and solve the final board with all constraints together. Reuse the existing attempt,
   state, and depth budgets. Retry placement/layout without silently lowering `target_count`.
7. Under `--require-solvable`, write only a result with `valid: true` and `solvable: true`; return a
   clear failure on exhausted attempts. Outside that mode, explicitly report unverified results.

The shelf capacity cap is the only proposed automatic reduction. If the targeted count cannot be
placed with the type limits or cannot be proven solvable within the budget, report that distinction
and suggest a lower percentage or larger budget instead of silently delivering fewer sticky items.

Extend `--stats` with requested percentage/count, eligible shelf count, targeted/actual count,
effective percentage, chosen coordinates, cap reason, used seed, attempts, and solver outcome.
Recompute final-board statistics after dispenser and sticky passes.

Update the level-generation skill's optional inputs, command examples, preservation rules, and
validation instructions when implementing the CLI; do not change the skill as part of this draft.

## 4. Runtime movement, matching, and lifecycle

- Add `is_sticky`, default false, to `ShelfItem`; apply it in `_add_configured_layers()` /
  `_add_configured_item()` from validated shelf metadata.
- Block sticky sources in tap selection, drag initiation, and `_move_item_to_slot()` itself.
  The last guard is necessary because input filtering alone does not protect direct method calls.
- Keep item detection separate from movement eligibility so a sticky item can show blocked
  feedback and can still identify the shelf the player is targeting.
- With a normal item selected, tapping the sticky item should use the existing occupied-target
  routing to a free slot on that shelf. A full shelf still rejects the move; no swapping or
  overwriting the sticky item is introduced.
- Do not disable an entire shelf or remove sticky items from item counts, triple matching,
  completion checks, or read-only inspection helpers.
- Audit code that re-enables input after unlock, promotion, landing, and ability animation.
  Preserve source restrictions even when an item becomes visible or an animation ends.
- Match clearing removes the sticky instance and its marker with the other two items. Stars,
  combo progression, shelf unlock counts, and completion behavior remain normal.
- Reset/retry reloads the authored sticky placement. Moving shelves carry the anchored instance;
  clipping and reachable-window checks remain unchanged.
- No new persistent player-save field is expected: this feature belongs to level content and
  live item state, not inventory or campaign progression.

## 5. Abilities and hints

| Ability | Required behavior under the proposed rules |
| --- | --- |
| Shuffle | Filter sticky instances before animation and ID reassignment, including hidden layers. Preserve all sticky identities and positions; continue shuffling eligible ordinary items. |
| Hammer | Exclude sticky targets in both front and back-layer selection. For a candidate type, require `remaining_count - 3 >= 3 * remaining_sticky_count` before destroying three ordinary copies. Count all layers and shelves for this reserve check. |
| Highlight / lantern | Include sticky instances as match destinations, but never propose gathering two sticky instances on different shelves into one triple. Choose ordinary movable partners and respect target-shelf capacity, locks, and reachability. |
| Freezer | Keep its existing timer behavior; no sticky-specific rule is needed. |

Ability availability, target selection, and execution must use consistent eligibility checks. A
rejected/no-op use must not consume inventory or coins. Preserve current behavior on non-sticky
levels unless separately fixing an existing issue.

The Hammer reserve check prevents destruction of indispensable copies; it is not a full proof that
the resulting board is solvable. Likewise, excluding sticky instances from Shuffle does not prove
the shuffled board is solvable. The generation guarantee applies to the initial board, not every
later player action. If abilities must always preserve solvability, that requires an explicitly
scoped runtime search/validated-assignment policy rather than an undocumented promise here.

## 6. Visual design and verification

- Add a reusable marker scene such as `scenes/ui/sticky_item_indicator.tscn`, with a focused script
  if it has animation. Instance it from `scenes/item.tscn`; do not construct its hierarchy in
  `level.gd`.
- Select a visual treatment before asset production: for example, a small glue patch, a fastening
  badge, or a restraint around the item. It must differ from the whole-shelf lock overlay and remain
  recognizable without relying only on color.
- Keep the item art recognizable. Define front/back-preview appearance, correct scaling on narrow
  and moving shelves, blocked feedback, hint overlap, and marker removal during a triple clear.
- A brief pulse or restraint response must not look like the item has been picked up or unblocked.
- No generated art is required for the mechanics prototype. If generated assets are requested,
  follow the repository's direction/candidate selection workflow before integrating them.
- Add a capture setup with ordinary/sticky neighbors, a hidden sticky item, a locked shelf, a
  moving shelf, highlighted state, and a match-ready example.
- Render and inspect at 540x960, 720x1280, 1080x1920, 1080x2400, and a tablet-like portrait viewport
  using `scripts/tools/capture_ui.ps1`. Verify actual capture dimensions and review the contact
  sheet. Exercise blocked interactions, promotion, and clear animation in the running game too.

## 7. Backend/content release dependency

Current backend documentation makes replay validation dormant: protocol 1.3 trusts bounded
completion claims, and protocol 2.0 uses local-first saves. Do not activate proof generation or
extend the historic replay engine just to ship sticky items.

Content publication still needs coordination:

- `../sorting-puzzle-backend/packages/configuration/src/launch-normalization.ts` currently copies
  shelf locks and layers explicitly. A new client field would otherwise be omitted during this
  normalization. Audit the active publication path and extend its normalized shelf contract,
  validation, hashes, and fixtures to preserve sticky semantics.
- Publish new immutable level/rule/configuration identities where their semantics change. Preserve
  old definitions and old save-operation provenance; do not rewrite an existing published version.
- Gate sticky content to compatible client builds. An old client ignoring the additive field would
  incorrectly allow movement, so additive JSON alone is not sufficient release compatibility.
- Regenerate `configs/backend/content_provenance.json` through the established publication flow,
  then run `scripts/tools/check_content_provenance.gd`. Never hand-edit hashes to bypass the gate.
- Verify the connected v2 completion/sync path accepts the new publication without changing the
  completion payload or player-save schema unless an actual contract dependency is found.
- Backend work is a separately scoped follow-up with its own commit. No sibling-repository files
  are changed by this plan. Do not edit the game repository's backend-requirements snapshot.

## 8. Tests and acceptance gates

Extend the existing Python suites:

- `tests/tools/test_validate_level_solvable.py`: valid/invalid metadata, ordinary versus sticky
  source moves, matching by identity, promotion, locks, dispenser rejection, distinct canonical
  states, insufficient-partner deadlocks, deeper-layer dependency traps, and replayable solutions.
- `tests/tools/test_generate_level_shelves.py`: default/zero regression, deterministic seeds,
  percentage validation, rounding, saturation, one sticky per shelf, per-type limits, no empty or
  dispenser targets, final opening-progress checks, and explicit exhausted-budget failures.
- `tests/tools/test_level_item_progression.py`: preserve coordinates exactly, map the targeted item
  normally, reject malformed metadata, and retain unchanged ordinary-level outputs.

Add focused Godot gameplay tests for both input modes and direct move calls; normal-item moves on a
sticky shelf; dropping/tapping onto the occupied sticky target; triple clearing and rewards; hidden
promotion; unlock; retry; moving rows; and malformed content. Add ability regressions covering
sticky identity preservation, Hammer partner reservation, valid highlight grouping, and no charge
on failure. Reuse the existing hammer, lantern, dispenser, and moving-shelf tests where appropriate.

Validate a deterministic seed matrix across difficulty, layer count, percentage, copy caps, locks,
and dispenser combinations, plus existing campaign fixtures. Replay selected Python solutions in
Godot to detect semantic disagreement. Record solver success rate and time/state budgets so sticky
support does not silently make generation impractical.

Update `docs/CONFIGS.md`, `docs/SCRIPTS.md`, `docs/SCENES.md`, and `docs/PROJECT_MAP.md` alongside
implementation. Keep tests and visual evidence tied to the behavior each batch changes.

## Delivery order

1. Confirm the product decisions above and the final config/percentage contract.
2. Implement config validation and sticky-aware solver with regression fixtures.
3. Add generator placement/stats and materialization coverage, with default behavior unchanged.
4. Implement item state, movement guards, lifecycle handling, and ability/hint rules.
5. Integrate the selected visual treatment and complete rendered/motion verification.
6. Add a small dedicated tutorial/test fixture and tune initial examples; do not pick a production
   campaign level or regenerate existing levels until that rollout scope is selected.
7. Complete separately scoped backend publication/provenance compatibility work before connected
   release, and validate packaged content plus completion synchronization.

Commit each meaningful implementation batch with its documentation and tests. Preserve unrelated
working-tree edits. This planning pass does not modify levels, scenes, assets, scripts, or backend
files and does not claim implementation tests or screenshot verification have been performed.
