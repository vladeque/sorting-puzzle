# Traditional Chinese localization verification — October 7, 2026

## Reviewed copy and ownership

`assets/translations/zh_Hant.po` applies all 251 entries from the owner's refined Taiwan
Traditional Chinese attachment, archived byte-for-byte at `TRADITIONAL_CHINESE_TRANSLATIONS.md`.
`tests/localization/traditional_chinese_inventory.json` retains the supplied English/Chinese
text, six invariant counted messages, four fixed counted booster names, supplementary email
labels and twelve month labels. Source attachment SHA-256:
`A16D22C3B732E81DF88A7B03E9672AA2DCA75E2BEE18BA02B40ABA19900505AF`.

The catalog contains 527 unique messages/contexts, including stable keys, English scene aliases,
uppercase card aliases and `booster.counted` contexts. Placeholder types and order, forced line
breaks, paragraph breaks and trailing email-template line breaks match the supplied inventory.
The refined combo praise, reward-verification status, purchase captions, `國內` leaderboard,
support synchronization guidance, `本機` deletion wording and email templates are preserved.

The existing `繁體中文` language choice selects `zh_Hant`. Taiwan, Hong Kong, Macao and
Traditional-script device locales map to it on a fresh save; Simplified Chinese continues to
fall back to English. Selection persists only in local preferences. Gameplay resume uses
`繼續遊戲`, move-on uses `繼續`, failed-level replay uses `重新挑戰`, and destination
reload uses `重新載入`. Chinese uses one gettext form for every integer count.
The four booster names remain `槌子`, `重排`, `提燈` and `冰凍器` after quantities.

`GameText` retains comma grouping (`1,234,567`) and formats Chinese deadlines as
`2026年11月2日`. Provider-formatted prices, names, identifiers, reference values, native
language labels, branding, `AD` and percentage/`OFF` tags retain their values.
The existing empty-leaderboard caption, absent from the inventory, is `尚無成績`.
The attachment's supplementary deletion-email labels use the existing email-field formatter.

`assets/themes/game_typography.tres` supplies bundled Noto Sans TC fallback variations at
500/600/700 weights across display, button, HUD, body, rich-text and editing roles.
`scripts/localization/locale_typography.gd`, called by `LocaleManager` before applying a locale,
places these before the Japanese fallback while Traditional Chinese is selected. Other locales
restore their original order. Latin, Cyrillic and Arabic faces keep their existing priority.
The font and SIL Open Font License are vendored together; provenance and SHA-256 are recorded
in `docs/TYPOGRAPHY.md`. Existing scene owners retain their fitting, wrapping, scrolling and
live refresh behavior. No new screen hierarchy is required.

## Automated verification

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_traditional_chinese_localization`: all 251 reviewed keys and English aliases; English
  and untranslated-locale fallback; six single-form messages at
  0/1/2/3/10/11/21/101/1000/1000000; fixed counted boosters and claimed captions; every supplied
  non-ASCII character through bundled fonts in all roles; Taiwan font priority and restoration
  of Japanese priority; all twelve year/month/day dates; comma grouping; raw prices, player
  names, references and markers; contextual actions; regional mapping and Simplified Chinese
  fallback; live main-menu/chapter/offer/resume changes; preserved pending ad state and local-only
  preference persistence. FAQ questions and deletion, shelf and replay actions fit at all five
  responsive viewports. Shelf descriptions and ready/pending/error status stay in their panel.
- `test_language_selection`: supported choices, pending/saved selection, cancellation and live
  application.
- `test_japanese_localization` and `test_korean_localization`: existing reviewed catalogs,
  bundled glyph coverage, dates, formatting, live switching and preserved state.

Final editor import succeeds with the existing hammer-art UID path-fallback warnings.
Artifact checks confirm the byte-identical archive, 251 exact keyed translations, 527 unique
messages/contexts and preserved placeholders/line breaks. Runtime code, fixtures and integration
documentation pass `git diff --check`.

## Rendered review

The 28 contact sheets in ignored `tmp/ui_capture/` were inspected. Each contains exact
540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: **140 images**, zero resolution
mismatches and zero manifest failures.

| Capture prefixes | Reviewed content |
| --- | --- |
| `main_menu_zh`, `shop_zh` | Level/chapter actions, full-life caption, 禮包 badge, shop sections/offer names, navigation, unchanged prices and discount markers. |
| `starter_zh`, `claimed_boosters_zh`, `purchase_reward_zh` | Full offer title/ribbons, booster names, claimed +3 captions, purchase action, completion banner and collection prompt. |
| `support_zh` | Complete FAQ questions, expanded five-step ad report, email action and password/payment warning. |
| `deletion_zh`, `deletion_scrolled_zh` | Permanent deletion, irreversibility, new-account paragraph and complete retention/30-day paragraph. |
| `deletion_accepted_zh`, `deletion_failure_zh`, `deletion_cleanup_zh` | Chinese deadline, explicit nothing-deleted copy, cleanup text and complete actions. |
| `language_zh`, `settings_zh`, `profile_zh` | Selected native 繁體中文 row, 儲存, settings/diagnostics/privacy text, avatar/frame tabs and raw player names. |
| `failure_zh`, `complete_zh`, `pause_zh`, `leave_zh` | Result titles, replay/move-on/resume distinction, setting toggles and leave-loss caption. |
| `chapter_zh` | 糖果街角 title, full unlock sentence with 雜貨小鎮, progress and locked action. |
| `timeup_zh`, `shelf_unlock_zh`, `shelf_pending_zh`, `ability_zh` | Full descriptions, two-line disabled ad caption, unlock/verification actions, pending status and unchanged AD. |
| `chest_zh`, `weekly_reward_zh`, `lives_zh` | Chest title/banner/instruction, weekly rank/coin message, refill caption/timer and actions. |
| `gameplay_zh`, `leaderboard_zh` | Level/combo HUD, ranking/reset duration, tabs/navigation and raw player names. |

Chinese glyphs render across every inspected role. Text remains inside buttons and panels at
all five sizes; no resolution-specific clipping or overlap was observed. Longer descriptions
wrap within their existing regions. The full deletion confirmation fits in the existing panel
at 540x960, including all three paragraphs; that render and the expanded support FAQ were also
inspected at their original resolution.

Captures have no script errors. Gameplay setups retain existing hammer-art UID, synthetic
board-layout and anchor warnings. The isolated purchase-reward preview reports an ObjectDB
leak and four resources still in use at shutdown, matching the documented Japanese/Korean
preview-teardown limitation. All five preview images were saved and their manifests passed.
The isolated review sessions use temporary saves and mock presentation states.

Reproduce captures with `capture_ui.ps1 -Locale zh_Hant` and the existing scene setup scripts.
The ignored `tmp/capture_traditional_chinese_localization.ps1` records all 28 setups and
environment states used for this review.
