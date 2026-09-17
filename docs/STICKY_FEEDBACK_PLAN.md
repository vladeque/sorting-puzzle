# Stronger feedback for blocked sticky items

Status: Implemented 2026-08-31 after approval of **Finger resistance for holding** and
**Anchored wobble for taps**. Both behaviors are active together. The implementation record below
supersedes the staged recommendation in the original investigation retained afterward.
Pink gum remains the primary asset. The item's artwork stays above the gum, and back-layer markers
remain hidden until front promotion finishes. Existing scene edits, including the gum sprite's
local vertical offset, must be preserved.

## Implemented behavior

- Press begins gentle gum tension. A release within 180 ms, without a pull of at least 6 local
  units, plays a 400 ms anchored wobble: 85 ms to 4.5 degrees, 105 ms reverse rebound, 90 ms small
  correction, then 120 ms settling. Tap cooldown is 280 ms; repeated taps replace existing motion.
- Held pulls follow the pointer smoothly with an asymptotic resistance curve (36 local units),
  capped at 5 degrees. Vertical pulling stretches/compresses the body by at most 2.5% while its
  ground contact stays fixed. Release springs past rest and settles over 220 ms.
- Gum widens up to 11%, compresses up to 14%, and skews gently with the lean. This replaces the
  brightness flash and preserves the authored sprite offset. The original visual implementation
  added no supporting media; the later shared feedback pass adds one saved-setting-gated, 32 ms
  resistance haptic on the initial blocked press.
- The item root, slot, ID, sticky flag, hitbox and grounded shadow remain unchanged. Blocked
  gestures do not select/drag, raise Z-order, create drop previews, play pickup SFX, or start time.
- Ordinary selection still routes onto the sticky shelf first. A full destination fails normally
  without incorrectly playing refusal on the destination item.

`scenes/ui/sticky_blocked_feedback.tscn` and `scripts/sticky_blocked_feedback.gd` own exported
timing/intensity, smoothing, tweens, cooldown and exact reset. Their `pose_changed` signal feeds a
separate channel in `ShelfItem`, composed with landing/outline/highlight presentation around the
source artwork's ground line. `StickyItemIndicator` applies gum pressure and skew while retaining
texture sizing and authored positioning. Existing Sprite2D/OutlineSprite paths remain unchanged.

`level.gd` owns a separate blocked item/slot, pointer origin and touch index (or mouse identity).
Only the owning pointer may pull/release it. Emulated duplicates of native touch/mouse are ignored.
Pointer delta is transformed as a vector through the inverse item basis, excluding translation:
responsive scaling preserves the feel, and shelf motion beneath a stationary finger creates no pull.

The level checks only active effects through `active_sticky_feedback`. Feedback cancels on pause,
ability interruption, application pause, desktop focus loss, failure/completion, off-window/hidden
items, back-layer state, clear/transition, reparenting of a held item, retry/exit, freeing, or loss
of the sticky flag. Busy items suppress new effects until transition completion. Both interactions
run directly in the existing preview; the proposed extra mode selector is unnecessary for the
approved combined behavior. No content, inventory, persistence, protocol or backend changes.

## Implementation verification

The new `tests/gameplay/test_sticky_feedback.gd` passes five stages covering motion/invariants,
native touch ownership/cancellation/emulation, lifecycle cancellation, moving rows/scaling, and
destination routing/freeing. The existing sticky suite passes all six stages, including promotion,
actual Hammer execution and solver conformance. Selection, landing impact, contact shadow, Lantern,
moving-shelf and item-progression suites also pass.

```powershell
& scripts/tools/run_isolated_godot_test.ps1 -Script tests/gameplay/test_sticky_feedback.gd -Windowed
& scripts/tools/run_isolated_godot_test.ps1 -Script tests/gameplay/test_sticky_items.gd -Windowed
& scripts/tools/capture_ui.ps1 -Scene scenes/testing/sticky_items_preview.tscn -Setup scripts/tools/captures/sticky_feedback_setup.gd -Name sticky_resistance -Position '0,0'
& scripts/tools/run_isolated_godot_test.ps1 -Script scripts/tools/capture_sticky_feedback_motion.gd -Windowed -GodotArguments @('--fixed-fps','60') -UserArguments @('--out','D:/projects/sorting-puzzle/tmp/ui_capture/sticky_motion')
```

Held poses on a bottle, candy bag and robot were rendered and inspected at 540x960, 720x1280,
1080x1920 and 1080x2400: feet stay planted, the artwork covers the gum, and adjacent items remain
readable without new overlaps. Requested 1200x1600 still renders 900x1600 under existing
`keep_width` behavior, so it is not full tablet-resolution verification.

The deterministic motion capture saves 90 frames at 30 samples per simulated second through actual
input helpers and asserts return to rest. Rest, tap lean, rebound, held-right, held-left and settled
frames were inspected; the assembled preview is `tmp/ui_capture/sticky_feedback.gif`. Captures are
ignored artifacts. Physical-device finger occlusion is unverified. Existing resource-UID warnings
and release/provenance boundaries in `STICKY_ITEMS.md` remain outside this visual feature.

## Original investigation (historical)

The remaining sections record the initial options and sequencing before the combined behavior was
approved. Use the implementation record above for current behavior and tuning.

### Findings before implementation

- `StickyItemIndicator.play_blocked_feedback()` brightens only the gum to 1.35 for 70 ms, then
  restores white over 180 ms. It cannot visibly communicate pulling resistance, and the player's
  finger can cover the small area that changes.
- `level.gd::_handle_press_at()` triggers this effect and returns before assigning `_pressed_item`.
  Consequently `_handle_motion_at()` and release have no blocked gesture to follow. Increasing the
  brightness alone would not fix this missing drag response.
- `_begin_drag()` rejects the source immediately. `_move_item_to_slot()` separately rejects sticky
  moves and triggers the current pulse. The movement guards are correct and must stay.
- `item.gd::_apply_visual_scale()` already coordinates item/outline scale, contact offset, shadow,
  and sticky presentation. Independent tweens directly writing those same sprite properties would
  fight this owner. A new feedback channel needs to compose with it.
- `ui_motion.gd` provides replaceable tweens and cancellation. `ShelfLockOverlay` is an existing
  example of a focused visual owner, but its chain/lock artwork describes a different restriction.
- This historical finding predates the shared feedback systems. `SfxManager` now owns the
  `sticky_move_blocked` cue, and `HapticsManager` owns the rate-limited resistance pulse through the
  saved vibration preference.
  No shared reduced-motion setting was found in the inspected gameplay/UI code.

## Directions

| Direction | What the player sees | Scope and tradeoff |
| --- | --- | --- |
| Stronger gum squeeze | Gum widens/compresses and rebounds; the item remains visually still. | Small change to the marker component; can still be hidden by the finger. |
| Anchored wobble — recommended first | The item rocks briefly around its planted base while the gum squeezes and rebounds. | Stronger response without introducing a draggable item or changing input ownership. Reuses existing artwork. |
| Finger resistance | While held, the item leans a little toward the finger, reaches a firm limit, and springs back on release. | Best connection to the attempted gesture; needs a separate blocked-press state, touch ownership, and cancellation handling. |

The conversation includes an interactive motion sketch of these directions using the current
bottle and pink gum images. It is a concept comparison, not a Godot implementation or proof of
final in-game timing, layering, or performance.

## Recommended first implementation: anchored wobble

Start with one short response on press, approximately 350-420 ms total. These are tuning starting
points, not measured requirements:

| Phase | Initial tuning | Intent |
| --- | --- | --- |
| Resistance, 0-90 ms | Item leans about 3-5 degrees around its bottom contact point; gum widens 8-12% and compresses 10-15%. | Make the attempted pickup visibly meet resistance. |
| Rebound, 90-220 ms | Item rocks a smaller amount in the opposite direction; gum returns past rest slightly. | Show elastic attachment. |
| Settle, 220-400 ms | One small final correction back to the exact resting pose. | End cleanly without persistent jitter. |

The item's root position, parent slot, collision shape, ID, and sticky flag never change. Animate
the visible body/outline together around a contact pivot; leave the base planted, with no drag
shadow lift, pickup sound, raised drag Z-order, or drop-target highlight. Any shadow adjustment is
subtle and remains grounded. Gum always renders behind the item. Cap deformations to the available
space so adjacent items and narrow/moving shelves remain readable.

Use a single restartable effect with a short cooldown (start near 250-350 ms). Rapid taps must not
stack tweens or accumulate a tilted pose. A tap on a sticky destination while an ordinary item is
selected must still perform normal occupied-slot routing; it must not play a refusal effect for
a valid move. A full destination shelf remains a normal failed drop, not a claim that the selected
ordinary item has become sticky.

Do not shake the whole shelf or camera, add a lock icon, emit match-style sparkles, or use the
successful-selection outline as the main signal. Keep this a local response that says the item is
attached to gum. A small non-rotating gum pulse is a reasonable low-motion variant; do not introduce
a new global accessibility setting or save schema as part of this first pass.

## Ownership and integration

1. Add a focused `scenes/ui/sticky_blocked_feedback.tscn` and
   `scripts/sticky_blocked_feedback.gd`, instanced by `scenes/item.tscn`. They own timing, exported
   intensity/cooldown settings, and cancellation. They do not move gameplay items or decide rules.
2. Extend `ShelfItem` with a separate blocked-feedback presentation channel, applied alongside its
   current scale/outline/contact calculations. Keep `Sprite2D` and `OutlineSprite` paths intact if
   possible. Do not reuse `land_squash` or selection offset as shared mutable animation state.
3. Give `StickyItemIndicator` a deformation input for the gum sprite, composed with its existing
   texture scale and authored offset. Replace the current brightness-only effect as the main cue;
   a restrained brightness accent can remain secondary.
4. Retain the existing `ShelfItem.play_sticky_blocked_feedback()` entry point. Let the two current
   refusal call sites use it, with cooldown preventing duplicate responses. Suppress hidden,
   back-layer, busy, or invalid targets.
5. Restore all feedback channels on clear, promotion, becoming a back-layer preview, pause,
   application interruption, retry, and scene exit. Rendering updates from hint/shuffle effects
   must not overwrite the blocked animation or re-show a hidden back-layer marker.
6. Extend the dedicated preview with a developer-only effect comparison/tuning control. Run the
   effect on a tall bottle, a broad box, and a short item, on both stationary and moving shelves.
   Keep this control inside the preview component, outside the production HUD.

No level JSON, generator, solver, item identity, inventory, scoring, timer, or persistence rule
changes are needed. Blocked attempts continue not to start the level timer.

## Optional second pass: held resistance

If the one-shot wobble does not sufficiently explain a sustained drag, add a distinct blocked
gesture state in `level.gd`, separate from `_pressed_item`, `_dragged_item`, and ordinary selection.
Track the item, press origin, and active touch index (or mouse identity). The current input helpers
do not retain touch indices, so this must be addressed before supporting a held touch effect.

- Begin only on an eligible exposed sticky source when no ordinary item is being routed there.
- Convert the pointer delta to shelf/item-local coordinates so responsive scaling and moving
  shelves do not manufacture a pull from shelf motion alone.
- Use an asymptotic or clamped response, initially limited to approximately 3-5 degrees of lean.
  Keep the ground contact fixed; do not let the item follow the finger freely.
- On release, return to rest over roughly 180-240 ms. Cancel immediately when paused, interrupted,
  hidden/off-window, cleared, replaced, or freed. Ensure a second finger cannot move or release the
  first finger's blocked item. Other shelves should remain usable after the gesture ends.
- Never reparent into the drag layer, invoke `_move_item_to_slot()`, create a drop preview, or start
  the timer for this gesture. Keep the defensive source guard in every move path.

## Optional supporting cues

Keep the first implementation visual-only. A short soft rubbery creak could later reinforce the
resistance, but requires a new catalog event, a reviewed sound asset, a cooldown, and the existing
sound setting. Do not repurpose the successful pickup or placement sound. No new art is required.

A brief light haptic is now implemented through `HapticsManager`, gated by the saved vibration
setting and the same 280 ms semantic cooldown as the blocked gesture. Physical-device tuning is
still required. Neither audio nor haptics is necessary to understand the feedback.

If players still misunderstand the mechanic, a one-time contextual hint such as **“Stuck! Bring
matching items here.”** is an onboarding option. Keep it out of the repeat-tap effect, place it above
the finger, and implement it as its own scene. Localization and its display frequency should be
decided when that onboarding work is requested.

## Verification and delivery

- First implement the one-shot wobble and gum deformation with the existing art, then compare it
  in the preview before adding held resistance or supporting cues.
- Extend existing sticky gameplay coverage for repeated attempts, no root/slot/ID change, no timer
  start, valid routing onto the sticky shelf, complete reset after interruption, and hidden marker
  preservation. Add gesture-ownership/cancellation checks only if the held interaction is built.
- Inspect timed captures at rest, maximum lean, rebound, and settled state; also record a short
  motion sequence, since one screenshot cannot establish timing or reset. Check finger occlusion
  on-device and avoid exaggerated motion that looks like successful pickup.
- Capture 540x960, 720x1280, 1080x1920, 1080x2400, and a tablet-like viewport. Check the actual image
  dimensions and retain the current warning if the tablet render target is narrower than requested.
- Re-run sticky, item-selection, landing/contact-shadow, Lantern, and moving-shelf regression checks.
  Keep unrelated existing rendering failures distinct from any new failures.
- Update `STICKY_ITEMS.md`, scene/script ownership docs, and commit the implementation separately
  from this planning document. Backend publication remains the existing release dependency; this
  feedback proposal does not authorize or perform backend changes.
