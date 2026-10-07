# Japanese localization verification — October 7, 2026

## Reviewed copy and runtime ownership

`assets/translations/ja.po` registers all 251 keyed entries from the owner's improved
`Sorting_Puzzle_Japanese_Translations.md`, archived byte-for-byte at `JAPANESE_TRANSLATIONS.md`.
`tests/localization/japanese_inventory.json` retains the exact supplied English/Japanese text,
six invariant plural messages, four fixed counted booster names, supplementary email labels
and twelve Japanese month labels. Source attachment SHA-256:
`9DD50E6B84769D15CD6B0280953E09D92918746D880533E8A6E0F07469D013FA`.

The existing `日本語` choice selects the registered `ja` catalog. Regional device locales
`ja_JP` and `ja-JP` retain their mapping to `ja`. The catalog has 527 unique messages/contexts,
including English scene aliases, uppercase card/product aliases and counted-booster contexts.
Every supplied placeholder type, count and order, forced line break, blank paragraph and
trailing email-template line break is preserved. The revised chapter unlock sentence, leave
warning, completion headline, radiant combo praise, lives-full body, ready-chest banner and
deletion copy are applied exactly as supplied.

Japanese gettext uses one form for every integer count (`nplurals=1; plural=0`).
Booster product names remain `ハンマー`, `シャッフル`, `ランタン` and `フリーザー`
in counted contexts. Claimed captions keep `+%d %s`. Gameplay resume uses `再開`, move-on
uses `続ける`, failed-level replay uses `もう一度プレイ` through the `Retry` scene alias,
and destination reload explicitly uses `common.retry_load` (`再読み込み`).

`GameText` retains comma grouping (`1,234,567`) and formats Japanese deadlines in
year/month/day order (`2026年11月2日`). Other locales keep their existing date branches.
The four deletion-help email field names use the supplied Japanese wording within the existing
email formatter. The only supplementary screen caption absent from the attachment is the
existing empty leaderboard, translated as `まだスコアがありません`. Store-formatted prices,
player/platform names, reference/ID values, native language labels, `SortingPuzzle`,
`Sorting Puzzle`, `AD` and percentage/`OFF` tags keep their existing values.
Language selection remains a local preference outside synchronized gameplay state.

`assets/themes/game_typography.tres` supplies bundled Noto Sans JP fallback variations at
matching 500/600/700 weights for every display, reading, rich-text and editing role.
They precede the Korean fallbacks after the existing Latin/Cyrillic/Arabic faces, providing
Japanese glyph forms. The unmodified 9,589,900-byte font and its SIL Open Font License are
vendored together; source provenance and SHA-256 are recorded in `docs/TYPOGRAPHY.md`.
No new UI scene or layout change was needed. Existing scene owners keep their responsive
fitting, wrapping, scrolling and live translation refreshes.

Ownership is recorded in `docs/LOCALIZATION.md`, `docs/SCRIPTS.md`, `docs/SCENES.md` and
`docs/TYPOGRAPHY.md`. The archived attachment retains its pre-integration notes; this page
describes the implemented behavior and completed verification.

## Automated verification

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_japanese_localization`: all 251 supplied keys and English scene aliases; English and
  untranslated-locale fallback; six single-form messages at
  0/1/2/3/10/11/21/101/1000/1000000; fixed counted boosters and claimed captions; all supplied
  non-ASCII characters plus decomposed kana, date units and yen symbols through every bundled
  theme font role; twelve Japanese dates; comma grouping; unchanged provider-formatted yen
  prices and player/reference/marker values; contextual actions; regional device mapping;
  live main-menu/chapter/offer/resume refreshes; preserved pending ad state and local-only
  preference persistence. FAQ questions and deletion, shelf and replay actions fit their
  measured bounds at all five viewports. Shelf descriptions and ready/pending/error status
  stay inside the cream panel.
- `test_language_selection`: supported choices, pending/saved selection and live application.
- The nine existing localization suites also pass: Korean, Arabic, French, German, Spanish,
  Brazilian Portuguese, Italian, Russian and Ukrainian. Their untranslated-locale checks now
  use catalog-free `id`, since Japanese has its own catalog.

Editor import completed successfully, including the Japanese catalog, font and test script.
It reports existing hammer-art UID path-fallback warnings. Artifact checks confirm 251 unique
inventory keys, 527 unique catalog messages/contexts, exact placeholders/line breaks and a
byte-identical source archive. Runtime code, tests and integration docs pass `git diff --check`;
the verbatim attachment retains its two intentional Markdown hard-break spaces.

## Rendered review

All 28 Japanese contact sheets in ignored `tmp/ui_capture/` were inspected. Each contains
exact 540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: **140 images**, zero
resolution mismatches and zero manifest failures.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_ja`, `shop_ja` | Japanese level action, full-heart status, セット badge, offer and section names, navigation, and unchanged prices/percentage/OFF markers. |
| `starter_ja`, `claimed_boosters_ja`, `purchase_reward_ja` | Full offer title/ribbons, four booster names, claimed +3 captions, purchase action and collection prompt. |
| `support_ja` | Full FAQ questions and expand icons, expanded five-step ad-report text, email action and password/payment warning. |
| `deletion_ja`, `deletion_scrolled_ja` | Permanent-deletion and irreversibility wording, account re-creation paragraph and reachable complete retention/30-day paragraph. |
| `deletion_accepted_ja`, `deletion_failure_ja`, `deletion_cleanup_ja` | Japanese deadline, explicit nothing-deleted message, cleanup text and complete action captions. |
| `language_ja`, `settings_ja`, `profile_ja` | Selected native 日本語 row, 保存, settings/diagnostics/privacy text, avatar/frame tabs and raw player names. |
| `failure_ja`, `complete_ja`, `pause_ja`, `leave_ja` | Result titles, replay/move-on/resume distinction, setting toggles and leave-loss wording. |
| `chapter_ja` | キャンディーコーナー title, full unlock sentence quoting おかいものタウン, progress and locked action. |
| `timeup_ja`, `shelf_unlock_ja`, `shelf_pending_ja`, `ability_ja` | Full Japanese titles/descriptions, two-line disabled ad action, unlock/verification actions, wrapped pending status and unchanged AD. |
| `chest_ja`, `weekly_reward_ja`, `lives_ja` | Chest title/banner/instruction, weekly rank/coin sentence, refill caption/timer and action buttons. |
| `gameplay_ja`, `leaderboard_ja` | Japanese level/combo HUD, ranking/reset duration, complete tabs/navigation and raw player names. |

Kana and kanji render correctly in every inspected role. Buttons, headings and status labels
stay within their panels at every resolution. Longer Japanese headlines and descriptions wrap
inside their existing regions; no resolution-specific clipping or overlap was observed.
Deletion confirmation intentionally scrolls: the complete final retained-records/30-day
paragraph remains reachable at all resolutions, including 540x960. The smallest scrolled
deletion capture was also inspected at its full resolution.

Captures contain no script errors. Gameplay captures retain existing hammer-art UID,
synthetic board-layout and anchor warnings. The isolated purchase-reward capture reports an
ObjectDB leak and four resources still in use at shutdown, matching the existing Korean,
French and German capture-teardown limitation. All five purchase-reward images were saved;
this does not claim a clean capture shutdown. Review sessions use temporary isolated saves
and do not change the real player's language or perform purchases/account deletion.

Reproduce captures with `capture_ui.ps1 -Locale ja` and the existing scene setup scripts.
The transient `tmp/capture_japanese_localization.ps1` records the 28 setups and environment
states used for this review; it remains ignored alongside capture images and logs.
