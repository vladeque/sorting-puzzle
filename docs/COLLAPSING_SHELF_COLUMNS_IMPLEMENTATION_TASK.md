# Collapsing Shelf Columns Implementation Task

Status: Draft implementation task. Product decisions in the decision gate below must be confirmed
before gameplay implementation begins.

Date: 2026-09-18.

## Summary

Add a new level gameplay mode in which every shelf has exactly one item layer and shelves are
organized into tall vertical columns. A column can contain more shelves than fit in the visible
play area. When a shelf becomes empty, that shelf is destroyed and every shelf above it in the same
column moves down by one shelf position. Progressively clearing shelves therefore makes each column
shorter. The level completes only after every shelf in every column has been destroyed.

This is a new gameplay mode, not only a new `layout_preset`. Existing layouts assume that all
shelves remain present for the duration of a level and that the responsive board can be fitted from
the bounds of every shelf. Collapsing columns change shelf lifetime, reachability, legal moves,
ability targeting, solvability, responsive fitting, and the terminal condition.

Working name: `collapsing_columns`.

## Requested behavior

- Every shelf has exactly one layer with three standard shelf slots.
- A level can contain many shelves split across multiple vertical columns.
- Only part of each column fits in the visible gameplay area.
- When the last item leaves a shelf for any valid reason, the empty shelf is destroyed.
- Shelves above a destroyed shelf move down by one logical shelf position.
- Shelves below the destroyed shelf do not move.
- A shelf entering the visible window becomes playable after the collapse settles.
- The level completes when no shelves remain.

## Product decision gate

The following behavior is recommended but has not yet been confirmed by the project owner. Do not
silently choose different behavior during implementation. Record confirmed decisions and their date
in this section before starting the runtime work.

| Decision | Recommended first version | Why it matters |
| --- | --- | --- |
| Column count | Three columns | Matches the common three-shelf board width and existing standard shelf art. |
| Visible height | Four shelves per column | Keeps a useful workspace while leaving clear room for the HUD and ability bar. |
| Cross-device behavior | Keep the same logical visible count at every resolution; scale and center the board | A taller device must not expose extra legal moves and thereby change level solvability. |
| Playable shelves | Every fully visible shelf is a legal source and target | This matches the request that clearing any shelf makes the shelves above it fall. |
| Partial shelves | Do not expose partially interactive shelves | Avoids device-dependent hit areas and ambiguous reachability. |
| Hidden shelves | Hidden and unavailable to moves, abilities, hints, and automatic matching | Offscreen content must not affect current legal choices until revealed. |
| Empty-shelf trigger | Destroy after a committed move, triple clear, or ability leaves the shelf empty | Dragging an item temporarily out of its slot must not destroy its origin shelf. |
| Collapse concurrency | Batch all empty shelves found in one resolution pass; animate columns in parallel and shelves within each column as one coordinated shift | Prevents competing tweens and unstable shelf indices after Hammer clears several shelves. |
| Interaction during collapse | Block item input and ability activation until all affected columns settle | Prevents drops against moving or soon-to-be-destroyed shelves. |
| Core abilities | Support Hammer, Shuffle, Highlight/Lantern, and Freezer | These are normal level controls and should not silently disappear in this mode. |
| Special shelf content | Disallow dispensers, moving rows, multiple layers, locks, and sticky items in the first version | Reduces the first implementation and solver matrix; each can be added later through an explicit compatibility task. |
| Remaining-content indicator | Show a small remaining-shelf count per column or one total count | Makes the size of offscreen stacks understandable without revealing their item contents. |
| Completion | All column shelf collections are empty | An item-only check is insufficient because shelf destruction is the objective. |

Questions requiring owner confirmation:

1. Are three columns and four visible shelves per column the intended initial board size?
2. Can the player interact with every visible shelf, or only the lowest shelf in each column?
3. Should all four current abilities remain available in this mode?
4. Are locks and sticky items intentionally deferred from the first version?
5. Should the player see per-column remaining counts, one total count, or no explicit count?

## Scope

### In scope

- An additive `collapsing_columns` level configuration contract.
- Dedicated reusable board and column scenes.
- Shelf visibility, availability, destruction, and collapse animation.
- Integration with moves, matching, automatic resolution, abilities, timer, pause, retry, failure,
  and completion.
- Mode-aware static validation and solvability search.
- Deterministic level generation for one-layer column boards.
- Abstract-to-runtime item materialization coverage.
- A focused development/test fixture and, after the rules are approved, at least one campaign level
  template.
- Responsive rendering and screenshot verification at every project-required viewport.
- Ownership and configuration documentation.

### Out of scope for the first version

- Real 3D shelves or physics.
- Player-controlled scrolling or camera movement.
- Horizontal or vertical wrap conveyors.
- Dispenser shelves.
- Multiple layers on one shelf.
- Generated shelf artwork or audio.
- Changing rewards, stars, combo scoring, lives, timer extension, or campaign progression.
- Changing the completion/save wire payload.
- Reactivating the dormant deterministic backend replay validator.
- Modifying the sibling backend repository unless a separately approved cross-repository task adds
  publication support.

## Current implementation constraints

| Area | Current behavior | Required change |
| --- | --- | --- |
| Level construction | `scripts/level.gd` creates a preset layout or `row_layouts` and instantiates every configured shelf. | Add a mode branch that creates a dedicated collapsing board and registers shelves by column and stack position. |
| Responsive fitting | `_get_shelves_local_bounds()` includes every recognized root shelf or moving row. | Fit the fixed visible column window; hidden stack depth must not shrink the board. |
| Shelf discovery | `_get_all_shelves()` recursively finds `Shelf` nodes. | Preserve recursive discovery, while adding an availability rule for shelves owned by a collapsing column. |
| Shelf resolution | Each shelf resolves matches and layer promotion independently. Empty one-layer shelves remain as reusable destinations. | Add a coordinated post-resolution collapse phase that permanently removes empty shelves. |
| Completion | `_check_level_completed()` completes when `_get_all_items()` is empty. | Classic mode keeps that behavior; collapsing mode completes only when the board reports zero shelves. |
| Abilities | Ability helpers generally inspect all unlocked shelves/front items. | Exclude hidden, entering, collapsing, and destroyed shelves consistently. |
| Solver | Empty shelves remain reusable; shelves are globally canonicalized without column identity. | Preserve column topology, permanently remove empty shelves, reveal replacements, and retain stable authored shelf IDs. |
| Generator | Generates standard layered boards and selects a static/moving layout preset. | Add column heights, fixed visible depth, one-layer enforcement, and mode-aware solvability. |
| Materializer | Deep-copies top-level/shelf metadata and replaces logical item IDs inside `shelves`. | Preserve the new mode fields and validate their relationship to the flat shelf list. |

Avoid adding column lifecycle and animation directly to the already broad `scripts/level.gd`.
`Level` should orchestrate the component through a small API; the new scenes should own their visual
hierarchy and shelf movement.

## 1. Configuration contract

Use an additive top-level gameplay mode. Existing levels omit `gameplay_mode` and continue to load
as `classic`.

Recommended template shape:

```json
{
  "level": 11,
  "time_seconds": 300,
  "gameplay_mode": "collapsing_columns",
  "column_layout": {
    "shelf_counts": [8, 8, 8],
    "visible_shelves_per_column": 4
  },
  "shelves": [
    { "layers": [["item_01", "item_02", null]] },
    { "layers": [["item_03", "item_01", "item_02"]] }
  ]
}
```

Contract rules:

- `gameplay_mode` is optional and defaults to `classic`.
- Supported initial values are `classic` and `collapsing_columns`.
- `column_layout` is required for `collapsing_columns` and rejected for `classic` unless a future
  compatibility decision says otherwise.
- `column_layout.shelf_counts` is a non-empty array of positive integers.
- The sum of `shelf_counts` must equal `shelves.size()`.
- `visible_shelves_per_column` is a positive integer. It can exceed a shorter column's current
  height but should be capped to the maximum supported design footprint.
- The flat `shelves` array is consumed column-by-column, left-to-right. Within each column, entries
  are ordered bottom-to-top. Document and test this ordering; never infer it from node names or
  coordinates.
- Each shelf must be `standard`, have exactly one layer, and that layer must contain exactly three
  item ID/null slots.
- Each authored shelf must initially contain at least one item. Fully empty authored shelves would
  be destroyed immediately and should be rejected as a content error.
- Total copies of each item ID must remain a multiple of three.
- `layout_preset` and `row_layouts` are mutually exclusive with `collapsing_columns`.
- For the first version, reject `type: dispenser`, positive `unlock_after_triples`, and non-empty
  `sticky_items` with actionable validation messages.
- Animation durations, easing, pixel spacing, and presentation offsets are scene/script properties,
  not level-content fields and not solvability inputs.
- The runtime must fail closed with a clear configuration error. It must not fall back to
  `grid_3x3`, because that would change the new mode's rules and could accept an invalid level.

Do not use the backend term `rules_version` as the client config field. `gameplay_mode` describes
the board behavior, while a backend rules version is an immutable compatibility identifier.

## 2. Scene and script ownership

Add the following focused components:

- `scenes/collapsing_shelf_board.tscn`
- `scripts/collapsing_shelf_board.gd`
- `scenes/collapsing_shelf_column.tscn`
- `scripts/collapsing_shelf_column.gd`

### `CollapsingShelfBoard`

Responsibilities:

- Create or receive the configured column components.
- Expose one stable layout footprint based on column count and logical visible height.
- Register each instantiated shelf with its authored shelf ID, column index, and bottom-to-top stack
  index.
- Answer whether a shelf is currently active and legal for gameplay.
- Find active shelves that are truly empty after committed resolution.
- Batch removal requests by column.
- Start column collapse animations in parallel and emit one completion result after every affected
  column settles.
- Return newly revealed shelves so `Level` can run automatic match resolution on them.
- Expose remaining shelf counts and `is_cleared()`.
- Refresh optional remaining-count presentation without exposing hidden item identities.

Suggested public API; exact names may be refined during implementation:

```gdscript
func configure(column_counts: Array[int], visible_count: int, shelf_step: Vector2) -> void
func get_column_parent(column_index: int) -> Node2D
func register_shelf(column_index: int, authored_shelf_id: int, shelf: Shelf) -> void
func is_shelf_active(shelf: Shelf) -> bool
func get_active_shelves() -> Array[Node]
func get_layout_bounds() -> Rect2
func collapse_empty_shelves() -> Dictionary
func get_remaining_shelf_count() -> int
func is_cleared() -> bool
```

The result of `collapse_empty_shelves()` should identify removed shelves and newly revealed shelves,
and should complete only after its visual movement is finished. Do not require callers to inspect
private column arrays.

### `CollapsingShelfColumn`

Responsibilities:

- Own one bottom-to-top ordered shelf collection.
- Preserve stable authored shelf identity even after earlier shelves are removed.
- Position active shelves at logical row locations counted upward from the column base.
- Keep all non-active shelves hidden, unpickable, and unavailable to abilities.
- When one or more shelves are removed, calculate each survivor's destination from the resulting
  ordered collection rather than applying accumulated relative offsets.
- Animate every affected survivor to its absolute destination to avoid floating-point drift.
- Reveal at most the configured number of active shelves.
- Ensure a newly revealed shelf begins outside/above the visible stack and enters with the same
  coordinated downward movement.
- Queue-free removed shelf nodes only after references needed by resolution bookkeeping have been
  released safely.
- Expose a deterministic non-animated settle path for setup and automated tests.

Use the current standard `scenes/shelf.tscn`; do not create a second copy of standard shelf visuals.
The column component owns placement and lifetime, while `Shelf` continues to own its slots and art.

## 3. Runtime construction and responsive layout

Update `scripts/level.gd` to:

1. Parse `gameplay_mode` before choosing a layout construction path.
2. Clear all prior board nodes and reset any previous mode/controller reference.
3. For `classic`, retain the current preset/row-layout behavior without semantic changes.
4. For `collapsing_columns`, instantiate `CollapsingShelfBoard` under `Shelves`.
5. Iterate `column_layout.shelf_counts`, consuming the flat shelf config in documented
   column-major, bottom-to-top order.
6. Create each standard shelf through the existing shelf factory/configuration functions, parent it
   to the correct column, and register its stable authored ID.
7. Apply horizontal left/middle/right shelf placement visuals based on column position, not the
   number of currently surviving shelves in a row.
8. Initialize hidden/active state before automatic resolution runs.

Responsive behavior:

- Extend `_get_shelves_root_child_bounds()` to recognize the collapsing board and use its fixed
  visible layout bounds.
- Never include hidden stack depth in responsive fitting.
- Keep the configured logical visible count consistent at 540x960, 720x1280, 1080x1920,
  1080x2400, and the selected tablet-like portrait viewport.
- Scale and center the board within the existing playable wall area between the HUD and ability bar.
- Keep touch targets aligned with the rendered shelf scale.
- Do not make additional shelves playable merely because a taller screen has spare pixels.
- If a remaining-count indicator is approved, include it in visual bounds and safe-area checks.

The board should keep a fixed logical footprint while its stacks become shorter. Do not recenter or
rescale after each shelf removal; the column bases must remain visually anchored and the board must
not jump as the player progresses.

## 4. Shelf availability and input rules

Introduce one central helper in `Level`, such as `_is_shelf_gameplay_available(shelf)`, that combines
mode-specific visibility with existing locks and moving-window reachability where applicable.

Audit and apply the helper to:

- Tap selection.
- Drag initiation.
- Direct `_move_item_to_slot()` validation.
- Empty-slot target search.
- Occupied-target fallback routing.
- Snap-distance target selection.
- Sticky blocked-feedback lookup if sticky support is added later.
- Visible-item enumeration.
- Ability availability and execution.
- Automatic matching and promotion entry points.

Hidden shelves must have their shelf/item visuals disabled and their collision/input state disabled.
Do not rely only on `visible = false`; direct method calls and ability helpers must still reject them.

An origin shelf must not be considered empty while an item is temporarily reparented into the drag
layer. Collapse checks run only after a move is committed or an ability/match removal has completed.
Canceled or rejected drops restore the origin without changing shelf lifetime.

During a collapse:

- Cancel or finish any active selection before movement starts.
- Block new item presses, drops, and ability activation.
- Keep pause/back handling available through the existing modal flow.
- Ensure app backgrounding, pause, retry, failure, or scene exit cannot leave a half-applied stack
  order or input lock.
- Prefer a single authoritative logical reorder before the tween, then animate visuals toward the
  new positions. Gameplay stays blocked until visual and logical state agree.

## 5. Resolution and shelf destruction lifecycle

The existing resolver can process several shelves asynchronously. Do not let each shelf independently
queue-free itself and shift its column; Hammer and automatic triples can empty several related
shelves during the same resolution wave.

Implement a coordinated resolution lifecycle:

1. Resolve requested active shelves using the existing match and promotion rules.
2. Wait until the current set of shelf resolution coroutines has drained.
3. Ask the collapsing board for every active shelf that is empty and has no pending/busy item.
4. Group removals by column and remove all shelves from each column's logical collection in one
   bottom-to-top-safe operation.
5. Animate affected columns in parallel.
6. Remove stale shelf references from pending-resolution, selection, highlight, and ability state.
7. Recompute shelf perspective edges and input state.
8. Resolve every newly revealed shelf. An authored visible triple must clear automatically just as a
   newly promoted matching layer does in classic mode.
9. Repeat collapse/reveal resolution until the board is stable.
10. Refresh abilities and check the mode-specific terminal condition.

Required invariants:

- One shelf node is destroyed at most once.
- A shelf being destroyed is never offered as a move target or ability target.
- Stable authored shelf IDs never change even when visual row positions change.
- Removing a shelf moves exactly the shelves above it; survivors below retain their positions.
- Removing multiple shelves from one column produces the same final order regardless of discovery
  order.
- No resolver instance ID remains registered after its shelf is freed.
- No completion check runs against a transient between logical removal and visual settling.

The collapse animation should have a short, exported duration on the column script and use a shared
easing choice. Add a semantic SFX/haptic event only through a separately reviewed audio/haptics
change; the mechanics must not depend on a new asset.

## 6. Completion, timer, pause, and retry

- Keep the classic completion rule unchanged.
- For `collapsing_columns`, `_check_level_completed()` calls `board.is_cleared()` only after all
  resolving and collapse work has settled.
- The final shelf receives the same destruction/collapse feedback before the completion celebration
  begins.
- Set `_level_completed` only through the existing `_complete_level()` path so progression, stars,
  reward chest state, audio, haptics, and result UI remain unchanged.
- A shelf collapse is gameplay resolution, not a pause. The countdown follows the same policy as
  current match-clear and promotion animations unless the owner explicitly changes that rule.
- Freezer continues to affect the timer only; it must not freeze collapse movement.
- Pause and app interruption must produce a deterministic result. Either pause the collapse tween
  with the gameplay tree or complete the logical settle immediately and restore visuals on resume;
  document and test the selected behavior.
- Retry rebuilds the original authored columns, hidden shelf state, item placement, timer, and
  abilities from config. No live column state belongs in persistent player data.

## 7. Ability behavior

| Ability | Required first-version behavior |
| --- | --- |
| Hammer | Select only items on currently active shelves. If the destruction empties several shelves, feed all affected shelves into one collapse batch after the impact. Hidden shelves cannot supplement Hammer targets. |
| Shuffle | Shuffle only eligible items on active shelves. Preserve the existing number of occupied slots on each shelf so Shuffle itself cannot create or remove a shelf. Hidden item identities and positions remain unchanged. |
| Highlight / Lantern | Search only active shelves and return a move that is legal before any future reveal. Do not hint from or to a hidden shelf. Refresh after collapse because the available state changed. |
| Freezer | Preserve existing timer behavior. It does not alter shelf movement, visibility, or selection. |

All ability availability checks and execution paths must use the same shelf-availability rule. A
rejected ability use must not spend inventory or coins. Classic levels must retain their current
ability behavior.

If locks or sticky items are later enabled, add a separate compatibility matrix and solver fixtures
before allowing them in content. Do not merely remove the first-version validation rejection.

## 8. Solvability model

Update `scripts/tools/validate_level_solvable.py` before enabling generation or campaign content.
The current solver cannot prove this mode correctly because an empty classic shelf remains a legal
destination and global shelf canonicalization discards pile topology.

Required state additions:

- Gameplay mode.
- Stable authored shelf ID.
- Column index and bottom-to-top order.
- The ordered surviving shelf IDs in each column.
- Configured visible shelf count.
- Existing triples-cleared, layer, kind, lock, and sticky state needed by classic mode.

Mode-aware settle behavior:

1. Restrict sources, targets, and matching to active shelves.
2. Clear matching triples on active standard shelves.
3. In collapsing mode, permanently remove every active shelf whose only layer is empty.
4. Compact each affected column while preserving survivor order.
5. Reveal the next shelves up to the fixed visible count.
6. Resolve any automatic matches on newly visible shelves.
7. Repeat until stable.

Search requirements:

- `legal_moves()` must never target a hidden or removed shelf.
- `apply_move()` must address shelves through stable authored IDs or stable column/stack coordinates,
  not tuple indices that change after removal.
- Solution output must remain replayable against the authored Godot board after earlier shelves have
  disappeared.
- Canonicalization may normalize slot order as today where legal, but must preserve column topology
  and relative stack order. Symmetric-column normalization is optional and must not alter solution
  coordinates.
- `is_cleared()` for this mode means every column contains zero surviving shelves.
- Necessary-count validation remains insufficient by itself; a board can deadlock because required
  partners are hidden behind shelves that cannot be emptied.
- Preserve the distinction among solvable, unsolvable, depth-limit, and state-limit results.

Keep classic solver behavior and existing fixture results unchanged. Prefer a mode-aware state
wrapper or focused rules object over scattering `if collapsing` branches through every helper.

## 9. Generator and materialization

Extend `scripts/tools/generate_level_shelves.py` with an explicit mode and column inputs. Recommended
CLI shape:

```powershell
py scripts\tools\generate_level_shelves.py `
  --gameplay-mode collapsing_columns `
  --column-heights 8,8,8 `
  --visible-shelves-per-column 4 `
  --item-type-count 12 `
  --difficulty medium `
  --seed 11011 `
  --full-level `
  --level-number 11 `
  --output configs\level_templates\level_011.json `
  --require-solvable `
  --stats
```

Generator rules:

- `--column-heights` determines `shelf_count`; reject a conflicting explicit `--shelf-count`.
- Force or require `--layer-count 1` and `--filled-layer-count 1`.
- Reject dispenser and locked-shelf options for the first version.
- Preserve deterministic output for the same seed and arguments.
- Distribute all item copies across the complete authored stack, including initially hidden shelves.
- Ensure every shelf has at least one item while keeping every item count divisible by three.
- Evaluate any opening-progress requirement against active shelves only.
- Run the new mode-aware validator after every candidate layout.
- Under `--require-solvable`, never write an invalid, unsolvable, or inconclusive board.
- Extend stats with mode, column heights, visible count, total/initially active/hidden shelf counts,
  occupied slots, attempts, and solver outcome.

`scripts/tools/level_item_progression.py` should retain the flat `shelves` representation and map
logical item tokens exactly as it does today. Add validation/tests proving that:

- `gameplay_mode` and `column_layout` survive materialization unchanged.
- Every hidden and active shelf item is mapped.
- No logical item metadata is inferred from column position.
- A malformed column contract fails before a stale runtime level is published.

Run `scripts/tools/materialize_level_templates.py --check` in CI/release verification and regenerate
runtime levels only from their templates.

## 10. Visual behavior

The first mechanics implementation should reuse standard shelf art. No generated asset is required.

Required presentation:

- Columns read as fixed vertical stacks with their bases aligned.
- Empty shelf destruction is visually distinct from the following downward shift.
- Shelves below a removed shelf remain stationary.
- Newly revealed content enters predictably from above without flashing in its final location.
- Input remains blocked until the shift ends.
- The current top cap, side placement, and shelf shadows update after a collapse and do not expose
  seams or double-dark overlaps.
- Hidden shelves and items do not render above the play window or through the HUD.
- The board does not rescale or recenter as columns shrink.
- Optional remaining counts are readable but do not reveal hidden item types.

If clipping cannot be achieved cleanly with the current `Node2D` hierarchy, prefer explicit
visibility and one offscreen entering shelf over introducing a `SubViewport`. The gameplay contract
already limits interaction to fully active shelves, so a complex render target should not be needed.

Add capture setup(s), for example:

- `scripts/tools/captures/collapsing_columns_initial_setup.gd`
- `scripts/tools/captures/collapsing_columns_progress_setup.gd`

Capture and inspect both states at 540x960, 720x1280, 1080x1920, 1080x2400, and a tablet-like
portrait resolution. If a motion capture helper is needed, keep it under `scripts/tools/captures/`.

## 11. Automated tests

### Godot gameplay tests

Add a focused test such as `tests/gameplay/test_collapsing_shelf_columns.gd` covering:

- Valid config builds the exact column count and bottom-to-top shelf order.
- Only the configured number of shelves per column is active.
- Hidden shelves and their items are not visible, pickable, valid drop targets, ability targets, or
  automatic match candidates.
- Emptying the lowest shelf moves every survivor above it down one position.
- Emptying a middle visible shelf leaves shelves below stationary and moves shelves above.
- Emptying the current top visible shelf reveals the next hidden shelf.
- A committed ordinary move can destroy its now-empty source shelf.
- A canceled/rejected drag never destroys its source shelf.
- A triple clear destroys its shelf only after the match animation completes.
- Hammer can empty several shelves in one or more columns without duplicate removal or competing
  tweens.
- Removing multiple shelves from one column preserves survivor order and correct final positions.
- A newly revealed matching triple resolves and can trigger another collapse.
- Shuffle never changes hidden shelves and does not accidentally remove a shelf.
- Highlight never proposes a hidden source or destination.
- Freezer does not stop column movement and retains its timer semantics.
- Input and abilities are disabled during collapse and restored exactly once afterward.
- Perspective caps/shadows refresh after a removal.
- The level does not complete merely because active shelves are empty while hidden shelves remain.
- The final shelf is destroyed before completion begins.
- Retry reconstructs the authored board.
- Pause, app interruption, failure, and scene teardown during collapse leave no invalid references,
  leaked tweens, or stuck interaction state.
- A classic fixture retains current empty-shelf, layer-promotion, layout, ability, and completion
  behavior.

### Python tool tests

Extend `tests/tools/test_validate_level_solvable.py` with:

- Valid and invalid column contract shapes.
- Shelf-count sum mismatch.
- Zero/negative/excessive visible counts.
- Multiple layers, empty authored shelves, dispenser, lock, sticky, `layout_preset`, and
  `row_layouts` rejection under the first-version contract.
- A solution that requires revealing a hidden shelf.
- A board that passes item-count checks but is unsolvable because required workspace is hidden.
- Permanent loss of an emptied shelf as a move destination.
- Several empty shelves removed from one column in one settle pass.
- Automatic clear/collapse chains after reveal.
- Stable solution coordinates after earlier shelf removals.
- Distinct canonical states for different column order/topology.
- Existing classic solver regression fixtures.

Extend `tests/tools/test_generate_level_shelves.py` with:

- Argument validation and conflicting-argument rejection.
- Deterministic output for fixed seeds.
- Exact column counts and flat ordering.
- One layer and at least one item per shelf.
- Item-copy divisibility.
- Active-only opening-progress evaluation.
- Solvable output under `--require-solvable`.
- No output on invalid, unsolvable, or inconclusive generation.
- Existing classic generator output unchanged when the new mode is omitted.

Extend item progression/materialization tests with preservation and rejection cases for the new
top-level fields.

## 12. Manual and visual verification

For each required viewport:

1. Verify the configured number of columns and active shelves.
2. Verify the HUD, board, and ability bar do not overlap.
3. Remove a bottom, middle, and top visible shelf.
4. Verify only shelves above the removed shelf move.
5. Verify a new shelf enters after a top-window vacancy.
6. Try selecting, dropping onto, hammering, shuffling, and highlighting hidden content.
7. Trigger simultaneous Hammer removals.
8. Pause/background during collapse and resume.
9. Fail/retry after partial progress.
10. Clear the last shelf and verify completion timing.

Capture commands should use the existing windowed helper, for example:

```powershell
& .\scripts\tools\capture_ui.ps1 `
  -Scene level.tscn `
  -Name collapsing_columns_initial `
  -Setup scripts/tools/captures/collapsing_columns_initial_setup.gd
```

Review the contact sheet rather than only checking that files were created. Report any requested
resolution whose rendered size differs from the requested size.

Also test on a touch device or emulator for drag accuracy while the board is scaled, rapid actions
immediately before collapse, and pause/background restoration.

## 13. Performance and content limits

- Measure setup, resolution, and collapse cost using the largest supported content shape.
- Avoid per-frame scans across hidden item nodes when no interaction or resolution state changed.
- Cache column membership and active state in the board/column owners; invalidate deliberately after
  removal or reveal.
- Existing backend publication documentation limits normalized levels to 100 shelves and 300
  non-null items. Keep generated content within those ceilings unless a separate backend decision
  changes them.
- A fully occupied standard shelf contains three items, so 300 items permits at most 100 such
  shelves, but a practical mobile level should be tested for node count, memory, setup time, and
  solver search cost before approaching that limit.
- Solver budgets may need mode-specific tuning. Never treat budget exhaustion as proof of
  solvability.

## 14. Backend and release dependency

Current protocol 1.3 trusts bounded completion claims, and protocol 2 local-first synchronization
does not upload move-by-move gameplay. The client feature therefore does not inherently require a
completion payload or save-schema change.

However, the backend's normalized level/rules artifact and dormant replay validator describe the
classic rules. If collapsing-column content must be published through the authoritative backend
configuration path:

- Create a separately scoped backend task and follow `../sorting-puzzle-backend/AGENTS.md`.
- Extend configuration normalization/publication to preserve `gameplay_mode` and the column
  contract rather than silently dropping them.
- Publish new immutable level/configuration identities.
- Gate the content to clients that support the mode; an older client must not interpret the same
  shelf array as a classic board.
- If deterministic replay validation is ever reactivated, create a new immutable rules version and
  add shared Godot/TypeScript conformance fixtures for shelf removal, reveal, legal moves, abilities,
  and completion.
- Refresh `configs/backend/content_provenance.json` only through the established publication flow
  and run the provenance check. Do not hand-edit digests.

No sibling-repository file is changed by this client task unless cross-repository work is explicitly
approved. Keep game and backend commits separate.

## 15. Documentation updates

Update these files in the same batches that establish their behavior:

- `docs/CONFIGS.md`: mode schema, ordering, restrictions, generation, validation, and examples.
- `docs/SCENES.md`: board/column scene ownership and lifecycle.
- `docs/SCRIPTS.md`: board controller, column controller, level integration, and solver/tool owners.
- `docs/PROJECT_MAP.md`: new gameplay mode and verification entry points.
- `docs/IMPLEMENTATION_TICKETS.md`: link and status for this task.

After implementation, either convert this document into the maintained behavior reference or add a
short `docs/COLLAPSING_SHELF_COLUMNS.md` reference and mark this task historical, following the
sticky-items documentation pattern.

## 16. Implementation sequence and commit plan

### Batch 1: Confirm contract and add tool validation

- Record confirmed product decisions.
- Add config parsing/shape validation in Python.
- Add mode-aware solver state and fixtures.
- Preserve classic solver behavior.
- Commit example: `Add collapsing column level rules and solver`.

### Batch 2: Add deterministic generation and materialization coverage

- Add column generator arguments and stats.
- Add materialization validation and tests.
- Generate only test fixtures at this stage; do not add campaign content until runtime works.
- Commit example: `Generate solvable collapsing column levels`.

### Batch 3: Add board and column components

- Create the two reusable scenes/scripts.
- Implement registration, active-window state, absolute layout, batched removal, animation, and
  isolated component tests.
- Commit example: `Add collapsing shelf column components`.

### Batch 4: Integrate runtime rules

- Add level construction mode branch.
- Add centralized shelf availability.
- Integrate resolution, abilities, completion, pause/retry, and perspective refresh.
- Add gameplay tests and preserve classic regressions.
- Commit example: `Integrate collapsing column gameplay`.

### Batch 5: Add content, polish, and verification

- Add the approved campaign template and materialized runtime level.
- Add optional count presentation using existing UI primitives.
- Capture all responsive resolutions and correct observed issues.
- Update all ownership/configuration documentation.
- Refresh content provenance only if the approved release path requires it.
- Commit example: `Add and verify collapsing column campaign level`.

Run the relevant test suite after every batch. Do not combine the backend publication follow-up into
these client commits.

## Acceptance criteria

- Existing levels with no `gameplay_mode` behave exactly as before.
- A valid `collapsing_columns` level builds the configured columns in documented bottom-to-top order.
- Every shelf has exactly one three-slot layer and unsupported feature combinations fail clearly.
- Only the fixed configured active window is visible and playable on every supported viewport.
- Hidden shelves cannot be accessed by direct input, fallback target selection, automatic matching,
  Hammer, Shuffle, or Highlight.
- Emptying a shelf through a committed move, match, or Hammer destroys it exactly once.
- Only shelves above a destroyed shelf move, and they move to exact logical positions without drift.
- Simultaneous removals settle deterministically within and across columns.
- Newly revealed shelves become active after movement and participate in automatic resolution.
- Input and abilities remain blocked throughout collapse and recover correctly afterward.
- The board does not rescale, recenter, or shift its bases as columns shrink.
- The level completes only after the final shelf has been destroyed and its resolution has settled.
- Timer, pause, failure, retry, completion rewards, stars, combo, lives, save data, and result screens
  retain their existing semantics unless this task explicitly states otherwise.
- The solver models shelf destruction and visibility and can replay every reported solution using
  stable authored shelf identities.
- The generator writes only valid, proven-solvable output when `--require-solvable` is used.
- Materialization preserves the mode/column contract and maps items on active and hidden shelves.
- Automated classic-mode regression tests pass.
- Rendered captures have been inspected at 540x960, 720x1280, 1080x1920, 1080x2400, and a
  tablet-like portrait viewport.
- `docs/CONFIGS.md`, `docs/SCENES.md`, `docs/SCRIPTS.md`, and `docs/PROJECT_MAP.md` identify the final
  owners and behavior.

## Definition of done

The feature is done when the configuration, solver, generator, materializer, scene components,
runtime integration, abilities, completion rule, automated tests, responsive captures, manual touch
verification, documentation, and approved campaign content all satisfy the acceptance criteria.
Backend publication compatibility, if required for the target release, must be completed through a
separately approved task before that content is activated for connected clients.
