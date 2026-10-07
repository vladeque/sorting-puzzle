# Korean localization verification — October 7, 2026

## Reviewed copy and runtime ownership

`assets/translations/ko.po` registers all 251 keyed entries from the owner's improved
`Sorting Puzzle — Korean Translations.md`, archived verbatim at `KOREAN_TRANSLATIONS.md`.
`tests/localization/korean_inventory.json` retains the exact supplied English/Korean wording,
six invariant plural messages, four fixed counted booster names, supplementary email labels
and twelve Korean month labels. Source attachment SHA-256:
`B3AD4F4E6FEEBBE285665A27F1D8A4F10AB711DAC3AD5354D17465E54F3A9C40`.

The existing `한국어` option selects the registered `ko` catalog. Regional device locales
`ko_KR`, `ko-KR` and `ko_KP` retain their existing mapping to `ko`. The catalog contains 527
unique keys, English scene aliases and counted-booster contexts. Uppercase English card and
product aliases resolve the supplied Korean names; Korean has no case distinction.
The improved shelf actions/progress, booster tooltips/descriptions, combo praise, price action,
ad-report action and deletion state copy are preserved exactly. Placeholder types, order and
count, forced line breaks, trailing email line breaks and warning paragraphs retain the source.

Korean gettext uses a single form for every integer count (`nplurals=1; plural=0`). The fixed
booster names `망치`, `섞기`, `랜턴` and `얼리기` are also used in `booster.counted` context.
Claimed booster captions retain the reviewed `+%d %s` pattern. Gameplay resume uses
`계속하기`, move-on uses `계속`, failure replay uses `다시 도전` through the `Retry` scene
alias, and destination reload explicitly uses `common.retry_load` (`다시 불러오기`).

`GameText` retains comma grouping (`1,234,567`) and formats Korean deadlines in year/month/day
order (`2026년 11월 2일`). Other languages retain their existing date branches. The shared
day/month/year catalog key and month labels are retained for catalog completeness; Korean
deadline presentation uses the formatter's explicit year-first branch.
The four deletion-help email labels use the supplied Korean text. The only additional screen
caption absent from the attachment is the existing empty-leaderboard state, translated as
`아직 기록이 없어요`. Store prices, player/platform names, reference/ID values, native language
names, brand and compact `AD` / `OFF` markers retain their existing values.
Language selection remains a local preference and does not enter synchronized gameplay state.

`assets/themes/game_typography.tres` supplies bundled Noto Sans KR fallback variations at
matching 500/600/700 weights for every display, reading, rich-text and editing role.
The unmodified 10,414,588-byte font and its SIL Open Font License are vendored together;
source provenance and SHA-256 are recorded in `docs/TYPOGRAPHY.md`.
Hangul coverage is independent of mobile system fonts. No new UI scene or layout change was
needed: existing scene owners retain their responsive fitting and live translation refreshes.

Ownership is recorded in `docs/LOCALIZATION.md`, `docs/SCRIPTS.md`, `docs/SCENES.md` and
`docs/TYPOGRAPHY.md`. The archive retains its pre-integration notes; this page describes the
implemented behavior and completed verification.

## Automated verification

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_korean_localization`: all 251 supplied keys and English scene aliases; English and
  untranslated-locale fallback; all six single-form messages at
  0/1/2/3/10/11/21/101/1000/1000000; fixed counted boosters and claimed captions; every
  non-ASCII character used by the reviewed strings and supplemental copy through all bundled
  theme font roles, plus decomposed Hangul, date units and the won symbol; twelve Korean dates;
  comma grouping; provider-formatted won prices and unchanged player/reference/marker values;
  contextual actions; regional device mapping; live main-menu/chapter/offer/resume refreshes;
  preserved pending ad state and local-only locale persistence. Full FAQ questions and deletion,
  shelf and replay actions fit their measured bounds at all five viewports. Shelf descriptions
  and ready/pending/error status remain inside the cream region.
- `test_language_selection`: supported choices, pending/saved preference behavior and live
  language application.
- `test_french_localization`: the existing 251-entry suite passes with the extended theme and
  Korean date branch.
- `test_arabic_localization`: the existing 251-entry suite and bundled-font checks still pass.

Editor import completed successfully, including the Korean PO catalog, font and test script.
It reports existing hammer-art UID path-fallback warnings. Catalog generation checked 251
unique inventory rows, 527 unique runtime messages/contexts, placeholder order/count and
forced line-break counts. The archived document is byte-identical to the owner's attachment.

## Rendered review

All 28 Korean contact sheets in ignored `tmp/ui_capture/` were inspected. Each contains exact
540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: 140 images, zero resolution
mismatches and zero manifest failures.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_ko`, `shop_ko` | Korean level action, full-heart status, `패키지` badge, offer/section names, coin amounts, navigation and unchanged prices/percentage/`OFF` markers. |
| `starter_ko`, `claimed_boosters_ko`, `purchase_reward_ko` | Complete offer title/ribbons, all four booster names, claimed `+3` captions, full purchase action and collection prompt. |
| `support_ko` | Complete FAQ questions and expand icons, expanded five-step ad-report copy, revised email action and password/payment warning. |
| `deletion_ko`, `deletion_scrolled_ko` | Permanent deletion and irreversibility wording, account re-creation paragraph and reachable complete retention/30-day paragraph. |
| `deletion_accepted_ko`, `deletion_failure_ko`, `deletion_cleanup_ko` | Korean deadline, explicit nothing-deleted message, revised device cleanup wording and full action captions. |
| `language_ko`, `settings_ko`, `profile_ko` | Selected native `한국어` row, `저장`, settings/diagnostics/privacy labels, avatar/frame tabs and unchanged player names. |
| `failure_ko`, `complete_ko`, `pause_ko`, `leave_ko` | Korean failure/result titles, replay/move-on/resume distinction, setting toggles and leave-loss wording. |
| `chapter_ko` | Chapter title, `사탕 골목`, complete remaining-level sentence quoting `마트 마을`, progress and locked action. |
| `timeup_ko`, `shelf_unlock_ko`, `shelf_pending_ko`, `ability_ko` | Complete Korean titles/descriptions, two-line disabled ad action, full unlock/verification actions, wrapped pending status and unchanged `AD`. |
| `chest_ko`, `weekly_reward_ko`, `lives_ko` | Chest title/banner/instruction, weekly rank/coin sentence, refill caption/timer and action buttons. |
| `gameplay_ko`, `leaderboard_ko` | Korean level/combo HUD, rankings/reset duration, complete tabs/navigation and raw player names. |

Hangul renders correctly in every inspected role. Captions remain inside their banners,
buttons and panels at every resolution; longer Korean descriptions/status wrap within the
existing regions. The shelf unlock and revised starter purchase actions fit in full.
Deletion confirmation intentionally scrolls: the complete final retained-records/30-day
paragraph remains reachable at every resolution, including 540x960. No resolution-specific
clipping or overlap requiring a new layout was observed.

Final captures contain no script errors. Gameplay captures retain existing hammer-art UID,
synthetic board-layout and anchor warnings. The isolated purchase-reward capture reports an
ObjectDB leak and four resources still in use at shutdown, matching the existing French/German
capture-teardown limitation. All five purchase-reward images were saved; this does not claim
a clean capture shutdown. Review sessions use isolated temporary saves and do not change the
real player's language or perform purchases/account deletion.

Capture reproduction uses `capture_ui.ps1 -Locale ko` with the existing scene setup scripts;
the environment-based pending, claimed and deletion states match the capture families above.
The transient batch driver `tmp/capture_korean_localization.ps1` records the exact 28 setups
used in this review and remains ignored with the capture output.
