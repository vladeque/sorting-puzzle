# In-game tips plan

Status: **Planned (2026-09-27).** The hand art is in the project; the tips themselves are not
implemented yet.

## Goal

Teach two mechanics at the moment a new player first needs them, without blocking play:

| Level | Mechanic | Tip |
| --- | --- | --- |
| 1 | Moving an item between shelves to form a triple | An animated hand drags an item from one shelf to a free slot on another, looping until the player makes the triple. No text. |
| 10 | `throwing_dispensers` (first campaign level in this mode; `configs/levels/level_010.json`) | A short message bubble plus an animated hand tapping a dispenser, until the player's first successful throw. |

## Product rules

- **Once per player on this device.** A tip is shown when its id is not yet in the saved seen set
  *and* its level is not yet completed. It is marked seen when the player performs the taught
  action, not when it first appears: the first cleared triple on level 1, the first successful
  throw on level 10. A player who leaves or loses the app before acting sees the tip again on the
  next attempt. A player who acts and then fails does not see it on the retry.
- The level-completed guard covers accounts restored from the backend onto a new device, where the
  device-local seen set is empty but the player clearly already knows the mechanic.
- **Non-blocking.** Every tip node ignores mouse and touch input. The level's board and dispenser
  input run in `_input()`, ahead of GUI, so the player can do the demonstrated action through the
  hand at any time.
- **No time cost.** The countdown already starts only on the first player action
  (`_start_level_timer_from_player_action()`), so the timer reads its full value while the tip
  plays. The tip itself never starts the timer.
- **Suspended, not dismissed**, while anything else owns the screen: the loading reveal, Pause and
  every other modal, failure, completion, an app interruption, an active ability effect, a throw in
  flight, shelves resolving, or the player currently pressing, dragging, or holding a selected item.
  The tip reappears after a short delay once the board is idle again. Only the taught action
  finishes it.
- A retry rebuilds the board through `_apply_level_config()`, which resets the tip and re-applies
  the rules above.

## Tip 1: level 1 move

Level 1 is a single row of three shelves, each holding one raspberry jam jar in its left slot
(baseline capture below). The tip demonstrates **drag**, the more discoverable gesture; tapping an
item and then a target still works and also completes the tip.

- **What the hand shows**, looping about every 2 seconds: fade in over the source item, press
  (scale down), travel to the destination slot carrying a semi-transparent ghost of the item's
  texture, release, fade out, pause.
- **Which move** is derived from the live board each time the tip is (re)shown, so it follows
  whatever the player actually did. Reuse `_find_immediate_triple_items()` (the Lantern's helper):
  the target shelf is the one holding most of those items with a free, drop-eligible front slot
  (ties go to the lowest configured shelf id, so the left shelf); the source is the nearest of the
  remaining items on another move-eligible shelf that is not busy; the destination is the target
  shelf's first free eligible slot. On a fresh level 1 that is middle jar to left shelf, then right
  jar to left shelf.
- If no move can be found, the tip hides without being marked seen.
- **Finishes** when `_clear_matching_shelves()` clears the first matched triple, which on level 1
  is also the level's completion. Not in `_record_triples_cleared()`: the Hammer also reaches that,
  and a triple the Hammer destroys teaches nothing about moving items. A Hammer-completed level 1
  still counts as completed, so the level guard stops the tip from coming back.

## Tip 2: level 10 dispenser

- **Hand**: fingertip on the center of the first stocked dispenser's `get_tap_global_rect()` (the
  left one on level 10), repeating a press with a small ripple ring about every 1.2 seconds. The hand
  body hangs down over the top row of shelves, which are empty at this point.
- **Message bubble**: `Tap a dispenser to throw items onto the shelves!` in a rounded cream bubble
  with a tail pointing up toward the dispenser. It sits below the hand, is centered on the board, and
  is clamped to the safe area with a 16 px gutter. It uses `GameBodyLabel` from
  `assets/themes/game_typography.tres` and fades in with `scripts/ui_motion.gd`.
- **Finishes** in `_throw_items()` once `dispenser.take()` returns items. A refused tap (no room or
  no stock) does not count. Hand and bubble fade out as the throw starts.

## Configuration

New client-only file `configs/gameplay_tips.json`:

```json
{
  "tips": [
    { "id": "level_1_move_to_triple", "level": 1, "type": "move_to_triple",
      "start_delay_seconds": 0.6, "reshow_delay_seconds": 1.5 },
    { "id": "level_10_tap_dispenser", "level": 10, "type": "tap_dispenser",
      "message": "Tap a dispenser to throw items onto the shelves!",
      "start_delay_seconds": 0.6, "reshow_delay_seconds": 1.5 }
  ]
}
```

- Tips are **not** added to `configs/levels/level_*.json`. Those files are hashed into
  `configs/backend/content_provenance.json`, so editing them would change the published content
  identity and need a backend republication. This file is presentation only and is not part of the
  provenance file list.
- `type` is `move_to_triple` or `tap_dispenser`; `message` is optional for either; at most one tip
  per level. A `tap_dispenser` tip on a level without a dispenser rack is skipped with a warning.
- The message is English source text shown through `tr()`. No translation catalogs exist yet
  ([LOCALIZATION.md](LOCALIZATION.md)), so this string joins the future catalog work.

## Saved state

`PlayerProgress` gains `seen_gameplay_tips`, an array of tip ids stored in the local `preferences`
partition next to `locale` and `selected_chapter_id`. It is excluded from the authoritative
snapshot and the backend journal, so this needs no protocol or backend change. Touch the same places
those keys are handled: initial preferences, `_apply_loaded_partitions()`,
`_snapshot_without_preferences()`, `_preferences_for_storage()`, `_sanitize_data()` (unique,
non-empty, bounded strings), and `_default_data()`.

API: `has_seen_gameplay_tip(tip_id) -> bool`, `mark_gameplay_tip_seen(tip_id) -> bool`, and
`reset_seen_gameplay_tips()` for the debug menu.

## Ownership

| Concern | Owner |
| --- | --- |
| Loading and validating `configs/gameplay_tips.json`, lookup by level | `scripts/gameplay_tip_catalog.gd` |
| Hand art, fingertip anchor, press/drag animation | `scenes/ui/tutorial_hand.tscn`, `scripts/tutorial_hand.gd` |
| Message bubble layout and tail | `scenes/ui/gameplay_tip_bubble.tscn`, `scripts/gameplay_tip_bubble.gd` |
| Screen-space tip view: timing, loops, ghost item, suspend/resume, finish fade | `scenes/ui/gameplay_tip_overlay.tscn`, `scripts/gameplay_tip_overlay.gd` |
| Which tip applies, board anchors, suspension state, finishing and marking seen | `scripts/level.gd` |
| Seen set | `scripts/player_progress.gd` |
| Debug reset | `scenes/main_menu_testing.tscn`, `scripts/main_menu.gd` |

The overlay knows nothing about shelves or dispensers. It exposes `show_move(from, to, texture,
item_scale)`, `show_tap(target_rect, message)`, `set_suspended(bool)`, and `finish()` in screen
coordinates. It is instanced as `UI/GameplayTipOverlay` in `level.tscn`, after `AbilityBar` and
before `TimeUpTransition`, so every modal and result screen draws above it.

`level.gd` glue stays small:

- `_setup_gameplay_tip()` at the end of `_apply_level_config()` picks the tip for `selected_level`
  and applies the rules above.
- `_refresh_gameplay_tip()` runs at the **top** of `_process()`, before its early returns, like
  `_refresh_dispenser_availability()`. It computes the suspended state and converts anchors from
  world to screen space with `get_global_transform_with_canvas()`, so layout changes and resizes are
  followed each frame. The hand scales with `_shelves_layout_scale` to match item size.
- `_find_gameplay_tip_move()` is the move selection described for Tip 1.
- `_finish_gameplay_tip(type)` is called from `_clear_matching_shelves()` and `_throw_items()`.
- A `force_gameplay_tips` export ignores the seen set and completion guard for tests and captures.

## Hand art

**Selected (2026-09-27): `assets/ui/tips/tutorial_hand.png`**, supplied by the user. It is a cartoon
white glove with a navy outline (about `rgb(22,32,76)`) and cool grey-blue shading, drawn on a
256x256 transparent canvas.

- **Pose.** The hand is tilted: the index finger points up and to the left, and the hand hangs down
  and to the right of whatever it points at. Tip placement and the level 10 bubble must leave room
  below and to the right of the target.
- **Fingertip anchor: texture pixel (75, 44)**, the centre of the rounded tip just inside its
  outline. The visible artwork's bounding box (alpha above 5%) is 162x180 at (47, 38). The anchor
  is an exported property on `tutorial_hand.tscn`, not a script constant, so replacing the art does
  not change code.
- **Display size.** About 0.6x at the level 1 board's layout scale, which makes the hand about 108
  logical px tall against a 77 px jar at 720x1280. Scale it with `_shelves_layout_scale` from
  there. A 256 px source is never enlarged on the target resolutions.
- **Cleanup already applied.** The supplied file's antialiased edge still carried chroma-key green:
  399 of its 761 semi-transparent pixels were green-dominant, which showed as a thin green line on
  the beige wall. ImageMagick recoloured every pixel below 98% alpha to the outline navy while
  leaving alpha untouched (0 alpha pixels differ from the supplied file). Opaque pixels are
  unchanged. Godot import settings are the UI defaults: lossless, no mipmaps, `fix_alpha_border`.

## Implementation sequence

1. Hand art: **done**, `assets/ui/tips/tutorial_hand.png` (above).
2. `PlayerProgress` seen set, with persistence tests in `tests/save/test_player_progress_facade.gd`.
3. `configs/gameplay_tips.json` and `gameplay_tip_catalog.gd`, with validation tests.
4. `tutorial_hand`, `gameplay_tip_bubble`, and `gameplay_tip_overlay` scenes and scripts, plus a
   capture setup that shows each state on a neutral background.
5. `level.gd` / `level.tscn` wiring, the Tip 1 move selection, and the two finish hooks.
6. Testing-menu **Reset gameplay tips** button.
7. Level captures, then updates to `docs/CONFIGS.md`, `docs/SCENES.md`, `docs/SCRIPTS.md`,
   `docs/PROJECT_MAP.md`, and a short tips section in `docs/THROWING_DISPENSERS.md`. Turn this plan
   into `docs/GAMEPLAY_TIPS.md` once implemented.

## Acceptance checks

New `tests/gameplay/test_gameplay_tips.gd`:

- The catalog loads the shipped config and rejects duplicate ids, unknown types, a second tip on
  one level, and a non-positive level. The shipped level-10 tip's level really is
  `throwing_dispensers`, and level 1 has a findable move.
- Level 1: the first anchors are middle jar to left shelf; after one programmatic move they update
  to right jar to left shelf; clearing the triple marks the tip seen and hides it. A Hammer clear
  does not mark it seen.
- Level 10: the anchor is the left dispenser's tap rect; a refused tap leaves the tip active and
  unseen; a successful throw marks it seen and hides hand and bubble.
- A seen tip, and a completed level, both produce no tip on rebuild; `force_gameplay_tips` still
  shows it.
- Suspension: loading pending, Pause, a drag in progress, and an ability effect each hide the tip;
  it returns after the reshow delay.
- A press on an item under the hand still selects that item, and a tap under the hand still throws.
  The timer has not started while only the tip has played.

Rendered captures, looked at rather than inferred, at 540x960, 720x1280, 1080x1920, 1080x2400, and
a squarer tablet viewport, with the animation frozen mid-drag and mid-press:

- Level 1: hand and ghost jar sized like a jar, fingertip on the source jar and aimed at the free
  slot, nothing clipped at the screen edges.
- Level 10: fingertip on the left dispenser, bubble fully inside the safe area and clear of the hand,
  HUD, and dispenser count badges, text unclipped at 540x960.

## Existing visual baseline

Captured before implementation at 540x960, 720x1280, and 1080x2400, in git-ignored
`tmp/ui_capture/tip_baseline_level_001_*` and `tip_baseline_level_010_*`. Level 1 leaves wide empty
wall above and below its single shelf row. On level 10 there are only about 70 logical px between
the HUD and the dispensers, so the bubble belongs over the empty top shelf row rather than above the
dispensers. (The level-10 capture's HUD reads `LEVEL 1` because the scratch setup did not refresh
the label; the real level shows 10.)

## Out of scope

Tips for other mechanics (locked shelves, sticky items, collapsing columns, dispenser shelves),
seen state synced through the backend, and new sound effects.
