# Arabic localization verification

Implementation and desktop review: October 5, 2026, Godot 4.6.2.

## Automated checks

- `test_arabic_localization.gd`: reviewed 251 keys/aliases, all seven six-form plural tables,
  four fixed booster contexts, email labels, 0–9 formatting, Gregorian dates, prices/names,
  bundled font coverage, local preference persistence and pending-ad state on live switches.
  Purchasing/error status clears booster names and Buy at all five target sizes.
- `test_arabic_direction.gd`: BiDi/shaping capabilities, LTR/RTL page gestures/arrows/bounds,
  switching during drag, paragraph alignment, mixed-name selection, numeric directions and
  physical safe-area padding on either side across English/Arabic/Russian/Ukrainian/Italian.
  It also checks timeout explanation bounds at all five sizes and price/rank/reward direction.
- `test_language_selection.gd`: fourteen native labels, regional Arabic mapping and existing
  selection/Save/cancel/persistence behavior.

All runs use the isolated runner; real player saves are untouched. Further regression and rendered
results are recorded below as the implementation review proceeds.

## Rendered review

Contact sheets are under git-ignored `tmp/ui_capture/`. Final captures use 540×960, 720×1280,
1080×1920, 1080×2400 and 1200×1600. Initial tablet renders were 900×1600 under `keep_width`;
they are superseded by full-size captures after adopting `expand` stretching. Desktop safe-area
lookup now shares the mobile-only helper, preventing spurious bottom insets during window resize.

- `arabic_home`: joined heading text, mirrored navigation, correct bracket mounting, intact
  `0/500` count and bottom-anchored actions at all five sizes.
- `arabic_chapters`: correctly ordered `0 / 25`, joined titles/status, mirrored arrows and dots,
  fully visible locked-card controls at all five sizes.
- `arabic_support`: right-aligned numbered paragraphs, intact email run and reachable account action.

## Device release checks

Desktop captures and engine tests establish client behavior here. Android/iOS touch scrolling,
native Arabic keyboard/caret behavior, exported text-server shaping and real device cutouts still
require device acceptance. No backend contracts, purchases, grants or deletion operations changed.
