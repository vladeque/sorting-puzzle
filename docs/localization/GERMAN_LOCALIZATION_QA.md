# German localization verification — October 6, 2026

## Reviewed copy and runtime ownership

`assets/translations/de.po` includes all 251 keyed entries from the owner's improved
`Sorting_Puzzle_German_Translations.md`. The supplied text is archived at
`GERMAN_TRANSLATIONS.md`; `tests/localization/german_inventory.json` retains the reviewed
English/German entries, six supplied singular/plural pairs, fixed counted booster names and
supplementary deletion email labels. Source attachment SHA-256:
`EDBFEC4459F400857B5B75B7F3782D9B39BF64E05AD2EA9101EC0E3F8BE398E4`.

The existing Deutsch option resolves the registered `de` catalog. Regional device locales such
as `de_DE`, `de_AT`, `de_CH` and `de_LI` retain their first-run mapping to `de`. Stable keys,
English scene aliases and uppercase card/product aliases use the existing localization hooks.
The improved document supersedes the earlier root-level German draft. Its pre-integration
review notes remain in the archive; the results below describe the integrated game.

Gettext selects singular for one and plural for other integer quantities. Counted booster product
labels remain fixed: `Hammer`, `Mischen`, `Laterne`, `Zeitstopp`. The invariant weekly coin-prize
tooltip has identical singular/plural forms. Gameplay resume uses `Weiterspielen`, move-on uses
`Weiter`, replay uses `Nochmal spielen` through the `Retry` scene alias, and destination reload
uses the explicit `common.retry_load` key (`Neu laden`). Placeholders and paragraph breaks retain
the supplied order and content.

Supplementary entries cover four deletion-email labels and the existing empty-leaderboard
status (`Noch keine Ergebnisse`). `GameText` supplies period grouping (`1.234.567`) and numeric
dates with leading zeros (`02.11.2026`). Store-formatted prices, names, references, IDs and the
compact `AD` / `OFF` markers keep their existing content. Locale remains a local preference.
Ownership is documented in `docs/LOCALIZATION.md`, `docs/SCENES.md`, `docs/SCRIPTS.md` and
`docs/TYPOGRAPHY.md`.

## Automated verification

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_german_localization`: all 251 reviewed keys and English scene aliases; English and
  untranslated-locale fallback; six plural pairs at 0/1/2/3/10/11/21/101/1000/1000000; fixed
  counted booster names; German glyphs; twelve numeric dates; period grouping; preserved names,
  prices and markers; contextual reload/replay and resume/move-on actions; regional device
  mapping; live Main Menu/offer/resume refreshes; pending ad state; local-only persistence.
- The German test measures full FAQ questions and deletion, shelf-unlock and failure actions
  against the available widths and padding at all five viewports. It checks shelf cream-panel
  clearance in ready, pending and error states, and restoration of the original English action
  font sizes after a live switch.
- `test_language_selection` and `test_italian_localization` passed after catalog/formatting changes.
- `test_support_screen`, `test_arabic_direction`, `test_portuguese_brazil_localization` and
  `test_account_deletion_modal` passed after the shared FAQ/action fitting changes.

Editor import completed successfully. Final captures contain no script errors. Gameplay
captures retain hammer-art UID path-fallback, synthetic board-layout and anchor warnings.
The isolated purchase-reward capture reports an ObjectDB leak and four resources still in use
at shutdown. An English capture with the same setup reproduces those diagnostics; all requested
images were saved successfully. This is a capture teardown limitation, not a clean shutdown claim.

## Rendered review

All 26 final German contact sheets in ignored `tmp/ui_capture/` were inspected. Each contains
exact 540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: 130 images, zero size
mismatches and zero manifest failures.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_de`, `shop_de` | Home badge, lives counter, level action, navigation, offer headings, prices, grouped counts and `67% OFF`. |
| `starter_de`, `claimed_boosters_de` | One-time ribbon, coins, four booster names, fixed claimed labels and `Für … kaufen`. |
| `purchase_reward_de` | Purchase-complete banner, granted reward captions and `Zum Abholen tippen`. |
| `support_de` | Full FAQ questions, expanded five-step ad report, email action and account row. |
| `deletion_de`, `deletion_scrolled_de` | Confirmation, irreversible-loss warning, reachable retained-records paragraph and 30-day period. |
| `deletion_accepted_de`, `deletion_failure_de`, `deletion_cleanup_de` | Numeric deadline, new-game action, nothing-deleted warning, retry action and revised cleanup headline. |
| `language_de`, `profile_de` | Native Deutsch selection, profile labels, preserved player name and `SPEICHERN`. |
| `failure_de`, `complete_de` | Failure banner, `Nochmal spielen`, completion praise and `Weiter`. |
| `pause_de`, `leave_de` | Settings labels, loss caption and both `Weiterspielen` actions. |
| `chapter_de` | Chapter title, quoted preceding chapter name, unlock progress and plural level requirement. |
| `timeup_de` | Timeout offer and two-line unavailable ad action. |
| `shelf_unlock_de`, `shelf_pending_de` | Full unlock action, complete match requirement and pending reward status. |
| `chest_de`, `weekly_reward_de`, `lives_de` | Chest banner/hint, ranked weekly coin reward and life-refill offer. |
| `gameplay_de`, `leaderboard_de` | Populated board/HUD, numeric combo, ability counters, leaderboard tabs, reset timer and unchanged player names. |

The initial FAQ captures showed the long synchronization question overlapping its expand icon
at all four phone resolutions. The question styles now reserve icon space, and
`support_faq_item.gd` fits captions from configurable 22px down to 16px on resize and live locale
changes. Final captures show the full question clear of the icon at all five sizes. The 74px
minimum touch target is retained. An additional five-resolution Arabic support review confirms
readable questions, mirrored icons and preserved answer alignment after the shared change.
The scene-local question margins swap with reading direction, keeping the question and answer
edges aligned while moving the icon clearance to the correct side.

The initial deletion failure captures showed `Erneut versuchen` reaching the button edges at
every resolution. `account_deletion_modal.gd` now fits action captions from configurable 22px
down to 16px with 24px horizontal padding after state, size and locale changes. Final captures
show the full action inside the existing button. Confirmation, scrolled content, accepted and
cleanup states were recaptured and reviewed after the adjustment. Approved wording is unchanged.

Pause and Leave Confirmation reuse diagnostic setups that override stretch aspect in their
isolated processes. Their tablet images visibly stretch the modal and do not establish production
tablet geometry for those two overlays. Other final captures retain production aspect behavior.
These desktop renders do not establish native mobile SDK or physical-device acceptance.
