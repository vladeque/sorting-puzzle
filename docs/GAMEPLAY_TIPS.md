# In-game tips

Implemented on 2026-09-27. Two first-time tips teach a mechanic at the moment a new player first
needs it, without blocking play:

| Level | Mechanic | Tip |
| --- | --- | --- |
| 1 | Moving an item between shelves to form a triple | A hand drags a jar from one shelf to a free slot on another, carrying a translucent copy of the jar. It loops until the player makes the first triple. No text. |
| 10 | `throwing_dispensers`, the first campaign level in this mode (`configs/levels/level_010.json`) | A hand taps a dispenser, with a message bubble below it: `Tap a dispenser to throw items onto the shelves!` Both stay until the player's first successful throw. |

## Rules

- **Once per player on this device.** A tip appears while its id is not in the saved seen set. It
  is marked seen when the player *performs* the taught action, not when it first appears: the first
  matched triple on level 1, the first throw that lands items on level 10. A player who leaves
  before acting sees the tip again next time. A player who acts and then fails does not see it on the
  retry.
- **A completed level shows no tip** on a campaign launch, even when the seen set is empty. That
  covers progress restored onto a new device. Launches from the developer level picker skip this
  guard, so **Reset gameplay tips** in `scenes/main_menu_testing.tscn` can replay a tip on a
  progressed save.
- **Only a real launch arms a tip.** `activate_after_loading_transition()` arms it once the loading
  reveal has finished. Only `LevelTransition` calls that, so a board rebuilt by a test or a capture
  with `_apply_level_config()` never picks up a campaign tip by accident. `_apply_level_config()`
  also drops any active tip.
- **Non-blocking.** Every tip node ignores the pointer. Board and dispenser input run in the level's
  `_input()`, ahead of GUI, so the player can act straight through the hand.
- **No time cost.** The countdown starts only on the player's first action, so the timer holds its
  full value while the tip plays. The tip never starts it.
- **Suspended, not dismissed**, while anything else owns the screen: the loading reveal, Pause and
  every other modal, failure, completion and its celebration, an app interruption, an ability effect,
  a throw in flight, resolving shelves, a collapse, or the player pressing, dragging, or holding a
  selected item. The tip returns `reshow_delay_seconds` after the board is idle again.
- **Hammer does not count.** The level 1 tip finishes in `_clear_matching_shelves()`, not in
  `_record_triples_cleared()`, which the Hammer also reaches. A triple the Hammer destroys teaches
  nothing about moving items. The level still completes, and the completed-level guard then keeps
  the tip away.

## How each tip finds its target

**Level 1** derives its move from the live board every frame (`_find_gameplay_tip_move()`), so it
follows whatever the player actually did. The target is the shelf that already holds the most items
of one type, with nothing else on it and a free drop-eligible slot; ties go to the first authored
shelf. The source is the nearest item of that type on another shelf. On a fresh level 1 that is the
middle jar to the left shelf, then the right jar to the left shelf. Sticky, back-layer, busy, and
locked items are never used. If there is no such move, the tip hides without being marked seen.

**Level 10** points at the first dispenser that still has stock, at the centre of its
`get_tap_global_rect()`. The bubble is centred on the board, placed below the hand's artwork, and
kept inside the safe area with a 16 px gutter. Its tail points straight up at the dispenser. A
refused tap (no room or no stock) does not count.

## Configuration

`configs/gameplay_tips.json` is client-only presentation data; the schema is in
[CONFIGS.md](CONFIGS.md#configsgameplay_tipsjson). Tips are deliberately **not** stored in
`configs/levels/level_*.json`. Those files are hashed into `configs/backend/content_provenance.json`,
so editing them would change the published content identity and need a backend republication.

The message is English source text shown through `tr()`. No translation catalogs exist yet
([LOCALIZATION.md](LOCALIZATION.md)), so it joins the future catalog work.

## Saved state

`PlayerProgress` keeps `seen_gameplay_tips`, an array of tip ids, in the local `preferences`
partition next to `locale` and `selected_chapter_id`. It is excluded from the authoritative
snapshot and the backend journal, so no protocol or backend change was needed. The API is
`has_seen_gameplay_tip()`, `mark_gameplay_tip_seen()`, and `reset_seen_gameplay_tips()`.
Sanitizing keeps unique, non-empty ids of at most 64 characters, and at most 64 ids.

## Hand art

`assets/ui/tips/tutorial_hand.png` is a user-supplied cartoon white glove with a navy outline
(about `rgb(22,32,76)`) on a 256x256 transparent canvas.

- **Pose.** The index finger points up and to the left, so the hand hangs down and to the right of
  its target.
- **Fingertip anchor: texture pixel (75, 44).** The visible artwork's bounds (alpha above 5%) are
  162x180 at (47, 38). Both are exported on `scenes/ui/tutorial_hand.tscn`, so replacing the art
  does not change code.
- **Size.** `level.gd`'s `gameplay_tip_hand_scale` (0.68) times the shelves' drawn scale makes the
  hand about 108 logical px tall next to a 77 px jar at 720x1280.
- **Edge cleanup.** The supplied file's antialiased edge still carried chroma-key green (399 of 761
  semi-transparent pixels). ImageMagick recoloured every pixel below 98% alpha to the outline navy,
  leaving alpha and opaque pixels untouched.

## Ownership

| Concern | Owner |
| --- | --- |
| Loading and validating the config, lookup by level | `scripts/gameplay_tip_catalog.gd` |
| Hand art, fingertip anchor, tap and drag loops, ripple, translucent item copy | `scenes/ui/tutorial_hand.tscn`, `scripts/tutorial_hand.gd` |
| Message bubble, measured layout, merged tail | `scenes/ui/gameplay_tip_bubble.tscn`, `scripts/gameplay_tip_bubble.gd`, `assets/themes/style_box_gameplay_tip_bubble.tres` |
| Screen-space view: delays, suspend and resume, restarting on moved anchors, bubble placement, finish fade | `scenes/ui/gameplay_tip_overlay.tscn`, `scripts/gameplay_tip_overlay.gd` |
| Which tip applies, board anchors, suspension state, finishing and marking seen | `scripts/level.gd` |
| Seen set | `scripts/player_progress.gd` |
| Debug reset | `scenes/main_menu_testing.tscn`, `scripts/main_menu.gd` |
| Capture setup | `scripts/tools/captures/gameplay_tips_setup.gd` |

The overlay knows nothing about shelves or dispensers. `level.gd` feeds it screen points every frame
through `update_move()` / `update_tap()`, suspends it with `set_suspended()`, and ends it with
`finish()`. It is `UI/GameplayTipOverlay` in `level.tscn`, after `AbilityBar` and before
`TimeUpTransition`, so every modal and result screen draws above it.

## Verification

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script res://tests/gameplay/test_gameplay_tips.gd
```

`tests/gameplay/test_gameplay_tips.gd` covers:

- the shipped catalog, including that level 10 is still a throwing-dispensers level, and the
  catalog's rejections;
- the seen set's persistence and its absence from the snapshot and the journal;
- that only a real launch arms a tip;
- both level 1 demonstrations and the triple that finishes them;
- a touch through the hand still selecting the jar under it;
- suspension for pause, a modal, and a selection;
- a rebuild dropping the tip, and the Hammer not finishing it;
- level 10's anchor, bubble bounds, refused tap, and finishing throw;
- the seen, forced, and completed-level guards.

Rendered captures freeze the loop mid-drag and mid-tap:

```powershell
$env:SORTING_PUZZLE_CAPTURE_TIP_LEVEL = '1'    # or '10'
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name gameplay_tip_level_001 -Position '0,0' `
    -Settle 40 -Setup scripts/tools/captures/gameplay_tips_setup.gd
```

Both tips were reviewed at 540x960, 720x1280, 1080x1920, and 1080x2400:

- **Level 1:** the hand is jar-sized and carries the translucent jar between the shelves.
- **Level 10:** the fingertip sits on the left dispenser's glass with the ripple visible. The bubble
  wraps to two lines, stays inside the gutters, and sits clear of the hand, the HUD, and the count
  badges. The tail joins the bubble outline without a seam.

On this machine the window manager would not render a squarer tablet viewport. It turned 1200x1600
into 900x1600, 960x1280 into 720x1280, and 768x1024 into 576x1024, the same limit recorded in
[ADS_004_REWARDED_LIFE.md](ADS_004_REWARDED_LIFE.md). Those captures are not faithful tablet views.
The layout uses the same keep-width scaling as the phone sizes, but the tablet case is unverified.

## Out of scope

Tips for other mechanics (locked shelves, sticky items, collapsing columns, dispenser shelves), seen
state synced through the backend, and new sound effects.
