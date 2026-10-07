# Indonesian localization verification — October 7, 2026

## Reviewed copy and runtime ownership

`assets/translations/id.po` applies all 251 keyed entries from the owner's improved
`INDONESIAN_TRANSLATIONS.md`, archived byte-for-byte beside this verification document.
`tests/localization/indonesian_inventory.json` retains the exact English/Indonesian text,
six invariant plural messages, four fixed counted booster names, supplementary email labels
and twelve month names. Source attachment SHA-256:
`BCEE2436B8006C1B97E64549FBA158A6A2DAB92A389B84E31B86831CCC3428AB`.

The existing Bahasa Indonesia choice selects the registered `id` catalog; regional device
locales `id_ID` and `id-ID` resolve to `id`. The catalog contains 527 unique messages/contexts,
including stable keys, English scene aliases, uppercase card aliases and counted-booster
contexts. Every supplied placeholder type, count and order, forced line break, blank paragraph
and trailing email-template line break is preserved. All 17 owner improvements over the
earlier draft are applied, including `Mengerti`, `HEBAT!`, `Pojok Permen`, `Sudah Dipakai`,
`Piawai`, `Terhebat`, `Memverifikasi...`, leaderboard captions, support and deletion copy.

Gettext uses one form for every integer count (`nplurals=1; plural=0`). Counted booster names
remain `Palu`, `Acak`, `Lentera` and `Pembeku`; claimed captions keep `+%d %s`. Gameplay
resume uses `Lanjut Main`, move-on uses `Lanjutkan`, failed-level replay uses `Main Lagi`
through the `Retry` scene alias, and destination reload uses `common.retry_load` (`Muat Ulang`).

`GameText` groups Indonesian counts with periods (`1.234.567`) and formats deadlines in
day/month/year order (`2 November 2026`). The four supplementary deletion-help email field
names use the supplied wording. The existing empty leaderboard, absent from the attachment,
uses supplementary `Belum ada skor`. Store-formatted prices, player/platform names,
references/IDs, native language labels, `SortingPuzzle`, `Sorting Puzzle`, `AD` and `OFF`
keep their existing values. Locale preferences remain local to the device and outside the
synchronized gameplay snapshot.

The existing bundled typography covers all supplied characters. Two focused fitting fixes
were needed without changing reviewed wording or scene hierarchies:

- `AbilityBar` measures the complete `%d dtk` caption inside its scaled timer-badge rectangle.
  Exported font bounds and padding retain the authored 16-point maximum and reduce it only
  when needed. Text assignment, responsive layout and live language changes refresh the fit.
- `TimeUpExtensionModal` fits the complete `Sudah Dipakai` price caption inside the action's
  existing 26-pixel side padding. Numeric prices also reserve the visible coin icon and row
  gap. Exported font bounds retain the authored 30-point maximum; resizing, live language
  changes and new offers restore the largest fitting size without changing disabled states.

Runtime ownership is recorded in `docs/LOCALIZATION.md`, `docs/SCRIPTS.md` and `docs/SCENES.md`.
The archived attachment retains its pre-integration recommendations; this page records the
implemented behavior. The existing Word document remains the earlier 16-page review draft
and predates the owner's improved attachment.

## Automated verification

Passed using Godot 4.6.2 and `scripts/tools/run_isolated_godot_test.ps1`:

- `test_indonesian_localization`: all 251 supplied keys and English scene aliases; English
  and untranslated-locale fallback; six single-form messages at
  0/1/2/3/10/11/21/101/1000/1000000; fixed counted boosters and claimed captions; bundled font
  coverage in all theme roles; twelve month/date cases; period grouping; unchanged
  provider-formatted prices, names, references and markers; contextual actions; regional
  device mapping; live menu/chapter/offer/resume refreshes; pending ad state and local-only
  preference persistence. FAQ, deletion, shelf, replay, 15/30-second badges and used-price
  captions fit at all five viewports. Live switches restore font sizes for shorter English
  captions, refit Indonesian, and retain used-extension state. Restoring a numeric offer
  restores the regular price font. Shelf descriptions and ready/pending/error status remain
  inside the cream panel.
- `test_language_selection`: pending/saved language selection and live application.
- All eleven existing localization suites: Russian, Ukrainian, Italian, Arabic, Spanish,
  Brazilian Portuguese, German, French, Korean, Japanese and Traditional Chinese. Their
  untranslated-locale checks now use catalog-free `tr` because `id` has its own catalog.
- `test_time_extension` and `test_rewarded_time_extension`: timeout offers, decline, coin
  extension, subsequent timeout, insufficient-coin Shop routing and verified rewarded claims.

Editor import completed successfully for the catalog and new scripts. It reports existing
hammer-art UID path-fallback warnings. Artifact checks confirm 251 unique inventory keys,
527 unique catalog messages/contexts, exact placeholders and line breaks, and a byte-identical
source archive. Runtime code, tests and integration docs pass `git diff --check`.

## Rendered review

All **30 contact sheets** in ignored `tmp/ui_capture/` were inspected. Every sheet contains
exact 540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: **150 images**, zero
resolution mismatches and zero manifest failures.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_id`, `shop_id` | Level action, full-heart status, PAKET badge, Indonesian offer/section names, navigation and period-grouped amounts with unchanged store prices and OFF markers. |
| `starter_id`, `claimed_boosters_id`, `purchase_reward_id` | Offer title/ribbons, fixed booster names, claimed +3 captions, complete purchase action and collection prompt. |
| `support_id` | Full FAQ questions with room for expand icons, five-step ad-report answer, email action and password/payment warning. |
| `deletion_id`, `deletion_scrolled_id` | Permanent-deletion and irreversibility text, account re-creation paragraph and complete reachable retention/30-day paragraph. |
| `deletion_accepted_id`, `deletion_failure_id`, `deletion_cleanup_id` | Indonesian deadline, explicit nothing-deleted text, HAMPIR SELESAI cleanup state and complete action captions. |
| `language_id`, `settings_id`, `profile_id` | Selected Bahasa Indonesia row, SIMPAN, settings/diagnostics/privacy copy, avatar/frame tabs and raw player names. |
| `failure_id`, `complete_id`, `pause_id`, `leave_id` | LEVEL GAGAL, HEBAT!, replay/move-on/resume distinction, setting toggles and loss warning. |
| `chapter_id` | Pojok Permen title, complete unlock sentence quoting Kota Kelontong, progress and locked action. |
| `timeup_id`, `timeup_used_id` | Full timeout description, normal numeric price, two-line unavailable ad action and both complete Sudah Dipakai captions after fitting. |
| `shelf_unlock_id`, `shelf_pending_id`, `ability_id` | Full shelf offer, unlock/verification actions, wrapped pending status, booster action and unchanged AD marker. |
| `chest_id`, `weekly_reward_id`, `lives_id` | Chest title/banner/instruction, rank/coin sentence, refill caption, timer and actions. |
| `gameplay_id`, `timed_boosters_id`, `leaderboard_id` | Level/combo HUD, complete 15 dtk and 30 dtk badges, leaderboard/reset duration, tabs/navigation and raw names. |

The complete Indonesian labels stay inside their panels at all five sizes. No
resolution-specific clipping or overlap was observed after the two fitting fixes. Long
descriptions wrap within their existing regions. Deletion confirmation intentionally
scrolls; the final retention paragraph remains reachable even at 540x960, also inspected
at full resolution. Countdown units remain visible within the compact circular badges,
and both used-extension actions retain the complete reviewed wording.

Captures contain no script errors. Gameplay captures retain existing hammer-art UID,
synthetic board-layout and anchor warnings. The isolated purchase-reward capture reports an
ObjectDB leak and four resources still in use at shutdown, matching the existing locale
capture-teardown limitation. All five purchase-reward images were saved; this does not
claim a clean capture shutdown. Temporary isolated saves do not change the real player's
language or perform real purchases/account deletion.

Reproduce ordinary captures with `capture_ui.ps1 -Locale id` and the existing setup scripts.
The ignored `tmp/capture_indonesian_localization.ps1` records the 28 ordinary review states.
Focused fitting captures use:

```powershell
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Locale id -Position '0,0' `
    -Name timed_boosters_id -Setup scripts/tools/captures/localization_timed_boosters_setup.gd
& .\scripts\tools\capture_ui.ps1 -Scene level.tscn -Locale id -Position '0,0' `
    -Name timeup_used_id -Setup scripts/tools/captures/time_up_extension_used_setup.gd
```
