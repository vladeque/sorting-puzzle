# Ukrainian localization verification — October 5, 2026

## Reviewed copy and implementation

`assets/translations/uk.po` includes all 251 keyed entries from the owner's updated
`Sorting_Puzzle_Ukrainian_Translations.md`, archived in `UKRAINIAN_TRANSLATIONS.md`.
The archived document retains its original draft/pre-integration notes; the translations are now
implemented. Runtime ownership and catalog conventions are described in `docs/LOCALIZATION.md`.

The catalog preserves the reviewed wording, placeholders and explicit line breaks. It includes
the five sentence plural tables, four counted booster-name tables, twelve genitive month names
and supplementary email field labels. The existing empty-leaderboard message also has Ukrainian
copy. The compact `AD` and percentage + `OFF` markers remain unchanged; `BUNDLE` becomes `НАБІР`.

The native-name language picker exposes `Українська` (`uk`). A Ukrainian device locale maps to
`uk` on a fresh save; saved language choices remain local preferences. Number grouping uses
spaces, and dates use the Ukrainian month names and `р.` suffix.

## Automated checks

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_ukrainian_localization`: all 251 reviewed strings, English and untranslated-locale
  fallback, every sentence/booster plural table at 16 integer boundaries, Ukrainian font coverage,
  all twelve dates, number grouping, unchanged names/prices, badge aliases, live language changes,
  preserved pending reward state and exclusion of locale from synchronized gameplay data.
- `test_language_selection`: twelve native-name entries, Ukrainian device mapping, pending/save
  behavior, persistence and the existing cancellation/stacking checks.
- `test_russian_localization`: all 251 current Russian entries, plural behavior and live switches,
  including unchanged Russian dates after introducing the shared catalog date pattern.
- `test_support_screen` and `test_out_of_lives_menu`: existing component behavior after the
  caption-fitting changes.

The final test and capture logs contain no engine or script errors. The out-of-lives test still
reports the existing hammer-art UID fallback and synthetic level layout/anchor warnings.

## Rendered review

Actual PNGs and contact sheets in ignored `tmp/ui_capture/` were inspected with Ukrainian selected
in isolated sessions. Captures do not change the real player's save or language preference.
Every screen below was reviewed at 540x960, 720x1280, 1080x1920 and 1080x2400; the generated
textures matched those four requested phone sizes.

| Contact-sheet prefix | Reviewed content |
| --- | --- |
| `main_menu_uk` | Home/HUD captions and the `НАБІР` hanging badge. |
| `shop_uk` | Offer headings, descriptions, prices and unchanged `67% OFF` tags. |
| `starter_uk`, `starter_error_uk` | Full offer title, coin ribbon, booster names, purchase price and the reviewed retry action/error. |
| `settings_uk`, `language_uk` | Settings labels, native Ukrainian language row and Save action. |
| `support_uk` | Expanded ad-report question, body and action. |
| `deletion_uk` | Confirmation paragraphs, deletion warning and confirm/cancel actions. |
| `lives_uk`, `lives_empty_uk`, `lives_pending_uk` | Full-lives copy, next-life timer, ad action and pending verification caption/action. |
| `chest_uk` | Reward-chest heading, long hero caption, progress and Continue action. |
| `complete_uk` | Completion heading, stars/reward and Continue action. |
| `chapter_uk` | Locked chapter heading, remaining-level requirement, progress and disabled action. |

The initial renders exposed three places where the approved copy needed more room. The final
renders show the following corrections:

- `support_faq_item.tscn` reserves a 384-pixel action width, giving the ad-report caption padding.
- `out_of_lives_menu.tscn` wraps the next-life caption within its timer column. Its focused script
  fits the rewarded-ad action font to the authored button width, including the longer pending
  verification action.
- `reward_chest_menu.tscn` bounds the hero label to its banner, and its focused script fits the
  translated font instead of letting the long caption expand the text stack.

The reviewed wording is unchanged by these layout corrections.

## Capture limitations and existing layout findings

- Tablet requests at 1200x1600 for Main Menu, Shop, Support, the three lives states, Chest and
  Chapter produced 900x1600 textures under the existing keep-width capture behavior. The capture
  manifests/logs report this mismatch. Those PNGs do not verify the requested tablet dimensions.
- Main Menu at 1080x1920 and 1080x2400 places the level button and bottom navigation above the
  bottom of the image. The same positioning was previously confirmed in English and Russian;
  this integration does not change Main Menu geometry. Full responsive Main Menu approval is
  not claimed. Modal text remains readable within its panels at those phone sizes.
- The existing hammer-art UID fallback and level layout/anchor warnings remain outside this
  localization change.
