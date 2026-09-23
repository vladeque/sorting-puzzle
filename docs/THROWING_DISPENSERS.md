# Throwing dispensers

Implemented in the game client and level tools on 2026-09-23. Existing levels are unchanged: a level
without `gameplay_mode` still loads as `classic`.

Every other mode hands the player a board that is already full, and play is about rearranging what is
there. This one inverts that. A level opens with an **empty** shelf layout and one or more
**dispensers** mounted above it. Tapping a dispenser throws items into random free slots; the player
matches triples on the shelves, taps again for more, and the level is finished when nothing is left
— neither on the shelves nor inside a dispenser.

The new decision is pacing: throw greedily and risk clogging the board, or clear first and throw when
there is room.

Not to be confused with the **dispenser shelf** (`"type": "dispenser"`), a narrow source-only shelf
the player drags items off. It is a different object that happens to share the word, and the two
never appear in the same level. See [CONFIGS.md](CONFIGS.md#configslevelslevel_json).

## Play it

In a debug build, open `scenes/main_menu_testing.tscn` and press **Throwing dispensers preview**, or
run `scenes/testing/throwing_dispensers_preview.tscn` directly with **Run Current Scene (F6)**. The
production menu is unchanged.

The preview plays `configs/test_levels/throwing_dispensers_preview.json`: a `grid_3x4` board of
twelve empty shelves and two dispensers holding fifteen items each, thirty items across ten types,
three per tap. It uses the ordinary level runtime, so it is also the touch-device check for this
mode — how a dispenser tap feels under a thumb, and whether taps near the top of a tall screen are
comfortable at all, is not something a capture can answer.

There is no campaign level in this mode yet; see [Not yet done](#not-yet-done).

## Rules

- Every shelf is a standard shelf with exactly one layer of three slots, authored empty. Matching,
  dragging, tapping, and all four abilities behave exactly as they do in a classic level.
- A dispenser holds an authored, ordered list of items and hands out the next `throw_count` of them
  per tap. Its badge shows exactly how many it still holds.
- **A throw never takes the last free slot.** It lands as many items as fit while leaving at least
  one slot open board-wide, and keeps the rest. This is a hard rule, not a config field: a move needs
  a free slot to land in, and a board with none has no legal move and no way to regain one.
- A tap that can throw nothing — no room, or nothing left — is refused with a shake and consumes no
  stock.
- Where an item lands is drawn from the level's authored `throw_seed`, so a retry replays the same
  run. Undispensed stock is data rather than nodes, so Hammer and Shuffle cannot reach it.
- The level completes once no item is left on the board **and** every dispenser is empty. An empty
  board with stock still waiting is the middle of a level, not the end of one.
- A board that fills with items that cannot be matched is not a special state. The player keeps
  playing until the countdown expires and the ordinary failure, retry, and time-extension flow takes
  over.
- `row_layouts`, `column_layout`, dispenser *shelves*, locked shelves, sticky items, and multiple
  layers are all rejected in this mode. Each needs its own compatibility task with solver fixtures.

## What the seed does and does not fix

The authored `throw_seed` fixes the **stream of random draws**, not the board. Throw number *N*
always draws the same numbers, but which slots those numbers select depends on which slots are free,
which depends on the order the player happened to play in. So:

- Replaying the same taps and moves reproduces the same board exactly. That is what makes a retry
  fair, and what makes tests and captures deterministic.
- Playing differently produces a different scatter from the same seed. That is the intended variety.

The Python playability estimate deliberately does **not** reproduce the Godot runtime's scatter:
the two languages use different generators, and the estimate varies the player as well. It answers
"does a reasonable player finish this board", not "what happens on attempt one".

## Solvability: sampled, not proven

This is the one place the mode cannot match the other two, and it is a deliberate limit rather than
a gap to close later.

`ClassicRules` and `CollapsingColumnsRules` author the whole board, so one exhaustive search decides
a level for good. Here the contents arrive over time and land in random slots, and which slots are
free depends on the player's move order. There is no single line of play to prove.

`ThrowingDispensersRules.estimate_playability()` instead plays the level many times with a greedy
player and reports how often it finishes. The report calls this `playability`, never `solvable`, so
two levels' reports cannot be confused. Under `--require-solvable` a level must reach a 0.95
completion rate over 200 sampled runs.

What actually keeps a sampled level safe in the hand is not the estimate but the reserved free slot:
the board can always be moved even when it cannot be matched, so it degrades into running out the
clock rather than locking up.

The greedy player models a completing move, an unblocking move (clearing the odd item off a shelf
that already holds a pair), a grouping move, a throw, and a last-resort consolidating move. The
unblock move matters more than it looks: without it the sampled player stalled on boards a real
player walks through, and the preview fixture was reported at a 20% completion rate for a reason
that was the model's fault rather than the level's.

## Ownership

| Concern | Owner |
| --- | --- |
| Level contract, validation, playability | `scripts/tools/validate_level_solvable.py` (`ThrowingDispensersRules`) |
| Generation | `scripts/tools/generate_level_shelves.py` (`--gameplay-mode throwing_dispensers`) |
| Materialization | `scripts/tools/level_item_progression.py` (`iter_dispenser_configs()`) |
| Runtime contract check | `scripts/throwing_dispenser_rules.gd` |
| Known modes, shared between both guards | `scripts/gameplay_modes.gd` |
| One dispenser: art, stock badge, tap input | `scenes/throwing_dispenser.tscn`, `scripts/throwing_dispenser.gd` |
| Placement above the board, layout bounds, aggregate stock | `scenes/throwing_dispenser_rack.tscn`, `scripts/throwing_dispenser_rack.gd` |
| Construction, throw lifecycle, completion | `scripts/level.gd` |
| Debug preview | `scenes/testing/throwing_dispensers_preview.tscn`, `scripts/throwing_dispensers_preview.gd` |

[CONFIGS.md](CONFIGS.md#throwing-dispensers) documents the schema, [SCENES.md](SCENES.md) the scene
hierarchy, and [SCRIPTS.md](SCRIPTS.md) the script APIs.

## Why both mode guards run on every level

`CollapsingColumnRules.validate_config()` and `ThrowingDispenserRules.validate_config()` both run on
every level, whatever mode it declares, because each one is also responsible for rejecting *its own*
fields on a level that did not declare it — `column_layout` on a throwing level, `dispensers` on a
classic one. That is why the canonical mode list lives in `scripts/gameplay_modes.gd`: without a
shared list, each guard would report the other's valid levels as an unknown mode.

## Verification

```powershell
py -m unittest discover -s tests/tools -p "test_*.py" -t tests/tools
py scripts\tools\validate_level_solvable.py configs\test_levels\throwing_dispensers_preview.json
& .\scripts\tools\run_isolated_godot_test.ps1 -Script res://tests/gameplay/test_throwing_dispensers.gd
```

`tests/gameplay/test_throwing_dispensers.gd` covers the contract guard's rejections, an empty board
building with its rack, a throw landing exactly `throw_count` items, the reserved slot and the
refused tap that follows it, seed reproducibility, a throw that completes triples, completion waiting
on dispenser stock, the rack sitting inside the fitted board, the preview scene and fixture, and a
classic-level regression.

Assertions about a throw count items rather than slots, because where an item lands is the one thing
this mode does not fix. Nine copies of one type thrown at a nine-slot board is clamped to eight by
the reserved slot, and eight items across nine slots must fill exactly two of three shelves whatever
order they land in — so the triples are forced even though the placement is not.

Rendered captures:

```powershell
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name throwing_dispensers -Position '0,0' -Settle 40 `
    -Setup scripts/tools/captures/throwing_dispensers_setup.gd
# The board part-way through, after three taps on each dispenser:
$env:SORTING_PUZZLE_CAPTURE_THROW_TAPS = '3'
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name throwing_dispensers_thrown -Position '0,0' -Settle 60 `
    -Setup scripts/tools/captures/throwing_dispensers_setup.gd
```

The setup rebuilds the board on every resize, because the rack is placed against the shelves' bounds
when the level is built. It also zeroes the flight: a capture that raced it showed items still drawn
at the dispenser mouth with one badge not yet decremented, which reads as a layout bug rather than
the half-finished animation it was.

Capturing the preview scene *directly* is not a supported path — it renders the board offset against
a grey field, the same way `scenes/testing/collapsing_columns_preview.tscn` does. Capture `level.tscn`
with the setup above instead.

Both layout decisions in `ThrowingDispenserRack` came from these captures and neither would have been
caught by reading the scene: dispensers are centered over an equal share of the board's width
(spreading them to its full width put them on the outermost corners, where the left one reached the
screen edge at 540x960), and they are drawn at 1.35x (at authored size they read as a small ornament
rather than the thing the player came here to press).

## Not yet done

- **Final dispenser art.** The current hopper is a procedural placeholder in the existing light-oak
  palette and reads more like a plant pot than a dispenser. Replacing it goes through the
  `AGENTS.md` art-direction process: 2-4 directions, then 2-3 candidates, then a selection.
- **A dedicated throw sound.** Landing currently reuses `item_place_valid`. A new cue needs a recipe
  in `scripts/tools/core_sfx_synthesis.gd`, a `GENERATOR_VERSION` bump, and regeneration.
- **Campaign content.** No campaign level uses this mode. Publishing one is blocked on the backend
  registering `throwing_dispensers` (`packages/configuration/src/types.ts`, `validation.ts`,
  `launch-normalization.ts`, `packages/game-validator/src/production-registration.ts` in
  `../sorting-puzzle-backend`) and on regenerating the content provenance manifest. That is a
  separate repository, a separate commit, and an approved operational action.
- **Replay-validator alignment.** If the dormant validator in
  `../sorting-puzzle-backend/docs/GAMEPLAY_VALIDATOR_BOUNDARY.md` is ever reactivated, a throw
  becomes a third consumer of the shared `xorshift32-rejection-v1` stream and needs an explicit
  versioned event. Nothing here depends on that today.
- **Play-balancing.** The preview fixture's thirty items, ten types, and three-per-tap are a first
  estimate, not a tuned difficulty curve.
