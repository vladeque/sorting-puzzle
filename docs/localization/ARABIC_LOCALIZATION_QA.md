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
- `test_language_selection.gd`: fourteen native labels, regional Arabic mapping, pending Arabic
  selection, Save, reload persistence and cancel from an RTL picker, plus Main Menu stacking.

All runs use `scripts/tools/run_isolated_godot_test.ps1`; real player saves are untouched.
The three checks above pass. Fourteen other regression checks pass:

- `tests/ui/test_russian_localization.gd`, `test_ukrainian_localization.gd` and
  `test_italian_localization.gd`, including English and untranslated-locale fallback.
- `tests/ui/test_chapter_ui.gd`, `test_chapter_selection_overlay.gd`, `test_support_screen.gd`,
  `test_account_deletion_modal.gd`, `test_profile_menu.gd` and `test_out_of_lives_menu.gd`.
- `tests/ui/test_level_ui_consistency.gd`, `test_starter_bundle_offer.gd`,
  `test_purchase_reward_sequence.gd` and `test_reward_chest_open_ceremony.gd`.
- `tests/ads/test_rewarded_time_extension.gd`.

One existing check fails: `tests/ui/test_shelf_lock_overlay.gd` expects Level 7 to contain a shelf
requiring at least two clears, but `configs/levels/level_007.json` contains no
`unlock_after_triples`. Both the fixture and test are identical to planning commit `61920db`.
This is a stale campaign-fixture dependency, and the Arabic work does not change either file.
The passing level UI suite covers locked-shelf feedback using Level 3; the Arabic lock and unlock
screens were also rendered below.

The existing hammer-art UID fallback, default-board template and anchor-size warnings still appear
in level-based diagnostic runs. No script parse errors remain in the final captures. Early blank
captures from applying level-owner setups to standalone hidden modals were replaced with correctly
prepared scenes. `git diff --check` passes. The current export preset uses `all_resources` without
include/exclude filters and is configured to include the registered Arabic catalog and fonts.

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
- `arabic_deletion`, `arabic_deletion_scrolled`: joined confirmation text; long body stays in its
  scroll region and the final retention paragraph remains reachable.
- `arabic_language`, `arabic_settings`: native Arabic selection, scrollable language list,
  visible Save/Support/Language/privacy actions and readable settings labels.
- `arabic_profile`, `arabic_leaderboard`: mirrored tabs, rounded outer tab corners, readable names,
  intact rank/score tokens and visible lists/actions.
- `arabic_shop`, `arabic_starter`: mirrored cards and offer contents; correct `$4.99`, `×3`,
  `67%`/`OFF`, coin ribbon and booster names. `arabic_starter_busy` and `arabic_starter_error`
  confirm the status pill clears both names and Buy; `arabic_starter_claimed` keeps `+3` intact.
- `arabic_gameplay`, `arabic_gameplay_tip`: physical board/item/gesture geometry remains unchanged;
  UI mirrors, timer stays `05:00`, combo stays `×3`, and ability buttons remain visible.
- `arabic_pause`, `arabic_leave`, `arabic_failure`, `arabic_completion`: joined titles/captions,
  visible resume/leave/retry/continue controls and intact `×12345` reward count.
- `arabic_lives`, `arabic_ability`, `arabic_time_up`: offer controls fit, prices remain numeric,
  `+01:00` retains its order and the timeout explanation is fully inside the cream panel.
- `arabic_shelf_lock`, `arabic_shelf_unlock`: unchanged chain/item geometry, intact countdown and
  `AD` plate, readable plural explanation and full rewarded CTA.
- `arabic_weekly_reward`, `arabic_chest_reveal`, `arabic_purchase`: intact `#2`, `+100` and
  `+2,500`, joined reward copy, mirrored booster order and readable collect action.
- `english_home_regression`, `english_starter_regression`: LTR placement, labels and prices remain
  readable at all five sizes with the Arabic fonts bundled.

All 28 Arabic screen/state contact sheets above were visually inspected at the five requested
sizes. No remaining clipping or overlap was observed in these final states. The HUD's taller font
minimum is centered on the shared row; the icon-only Pause glyph uses its dedicated Latin font.
The Starter Bundle and timeout owners now size their content from actual font/container minima.

To reproduce the full-board and offer review:

```powershell
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Name arabic_gameplay -Locale ar -Position '0,0' -Setup scripts/tools/captures/localization_gameplay_setup.gd
& .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/starter_bundle_offer_modal.tscn -Name arabic_starter -Locale ar -Setup scripts/tools/captures/localization_starter_setup.gd
```

`SORTING_PUZZLE_CAPTURE_STARTER_STATE` accepts `busy`, `error` or `claimed` for offer variants.
`account_deletion_scrolled_setup.gd` holds the long confirmation at the end of its scroll area.
The `arabic_investigation_*` and `arabic_geometry` contact sheets predate the final implementation
and are not acceptance evidence.

## Device release checks

Desktop captures and engine tests establish client behavior here. Android/iOS touch scrolling,
native Arabic keyboard/caret behavior, exported text-server shaping and real device cutouts still
require device acceptance. No backend contracts, purchases, grants or deletion operations changed.
