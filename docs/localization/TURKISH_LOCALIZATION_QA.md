# Turkish localization verification — October 7, 2026

## Reviewed source and ownership

`assets/translations/tr.po` applies all 251 keyed entries from the owner's improved
`Sorting Puzzle — Türkçe Translations.md`. The attachment is archived byte-for-byte at
`TURKISH_TRANSLATIONS.md`; its SHA-256 is
`CC7E97C2E67A84DAE2A219F5379B90407E70925F992C1FB2249CAC5BF3D46492`.
The archive retains its pre-integration notes; this document records the implementation.
`tests/localization/turkish_inventory.json` retains the exact reviewed English/Turkish copy,
six invariant counted messages, fixed counted booster names, four supplementary email labels
and twelve Turkish month names. The catalog provides 527 unique messages/contexts, including
stable keys, English scene aliases and uppercase product/card aliases.

Both gettext slots preserve the same supplied counted wording, including the fixed product
names `Çekiç`, `Karıştır`, `Fener` and `Dondurucu`. The header uses
`nplurals=2; plural=(n > 1)` following the
[GNU gettext Turkish rule](https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html).
The supplementary empty-leaderboard caption, absent from the attachment, is `Henüz puan yok`.
All reviewed placeholder types/order, forced breaks, paragraph breaks and trailing email
template breaks are retained. Resume (`Oyuna Dön`), move-on (`Devam Et`), replay
(`Tekrar Oyna`) and reload (`Tekrar Yükle`) keep their distinct supplied wording.

The existing Türkçe choice selects the registered catalog; regional device locales resolve to
`tr`. `GameText` owns Turkish period-grouped counts (`1.234.567`) and Turkish month dates
(`2 Kasım 2026`). `GameText.uppercase()` preserves dotted/dotless I in translated titles;
`ShopPurchaseDialog` uses it on presentation and live switches. Uppercase card aliases supply
`BAŞLANGIÇ PAKETİ` and `TEMEL PAKET` directly. Bundled fonts are used for Turkish glyphs.
Prices, player names, reference/ID values, native language names, branding, `AD` and `OFF`
retain their existing values. Locale selection stays in device-local preferences, outside
synchronized gameplay data. Backend repositories and protocol behavior are unchanged.

## Automated verification

Passed with Godot 4.6.2 and `scripts/tools/run_isolated_godot_test.ps1`:

- `test_turkish_localization`: all 251 reviewed keys and English scene aliases; English and
  catalog-free fallback; six invariant counted messages at 0/1/2/3/10/11/21/101/1000/1000000;
  fixed counted boosters and claimed captions; all reviewed non-ASCII characters and Turkish
  alphabet/circumflex glyphs through bundled fonts in twelve theme roles; twelve Turkish date
  cases; period grouping; Turkish uppercase card aliases and purchase-dialog titles; regional
  device mapping; contextual resume/replay/reload actions; raw provider prices, player names,
  references and markers. Live switches refresh menus, chapters, offers and resume controls,
  preserve pending ads and used extensions, and retain local-only preference persistence.
  Full FAQ questions, deletion/shelf/replay actions, 15/30-second badges and used captions fit
  at 540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600.
- All twelve existing localization suites: Arabic, French, German, Indonesian, Italian,
  Japanese, Korean, Brazilian Portuguese, Russian, Spanish, Traditional Chinese and Ukrainian.
  Their catalog-free fallback checks now use `hi` directly through `TranslationServer`, since
  Turkish has its own catalog. The production allowlist remains unchanged.
- `test_language_selection`: pending/saved selection, cancellation, live application and
  local-only preference persistence.
- `test_level_ui_consistency`: shared UI, modal lifecycle, layouts, input routing and state.
  It retains existing synthetic-board/anchor and hammer-art UID warnings, plus an ObjectDB
  teardown warning; its assertions passed.

Editor import completed without script errors. It retains existing hammer-art UID path-fallback
warnings. Artifact checks confirm 251 unique inventory keys, 527 catalog messages/contexts,
preserved placeholders/line breaks and a byte-identical source archive.

## Rendered review

All **31 contact sheets** in ignored `tmp/ui_capture/` were inspected. Each contains exact
540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: **155 images**, zero requested/
actual resolution mismatches and zero manifest failures.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_tr`, `shop_tr` | Level action, full-heart status, PAKET badge, navigation, Turkish offer/section titles, period-grouped amounts, unchanged store prices and OFF markers. |
| `starter_tr`, `claimed_boosters_tr`, `purchase_reward_tr`, `purchase_dialog_tr` | Offer title/ribbons, booster names and +3 captions, full price/collection actions, purchase-complete banner and uppercase purchase-error title. |
| `support_tr` | Complete FAQ questions, expanded five-step ad-report answer, report action and password/payment warning. |
| `deletion_tr`, `deletion_scrolled_tr` | Permanent deletion, irreversibility, new-account paragraph and full reachable retention/30-day paragraph. |
| `deletion_accepted_tr`, `deletion_failure_tr`, `deletion_cleanup_tr` | Turkish deadline, explicit nothing-deleted text, revised final-cleanup wording and complete actions. |
| `language_tr`, `settings_tr`, `profile_tr` | Selected Türkçe row, KAYDET, settings/diagnostics/privacy labels, avatar/frame tabs and raw player names. |
| `failure_tr`, `complete_tr`, `pause_tr`, `leave_tr` | SEVİYE GEÇİLEMEDİ, TEBRİKLER!, replay/move-on/resume distinction, setting toggles and loss warning. |
| `chapter_tr` | Şeker Köşesi, full unlock sentence quoting Market Kasabası, revised progress label and locked action. |
| `timeup_tr`, `timeup_used_tr` | Timeout description, numeric price, two-line unavailable ad action and complete Kullanıldı captions. |
| `shelf_unlock_tr`, `shelf_pending_tr`, `ability_tr` | Full shelf offer, unlock/verification actions, revised pending status, booster action and unchanged AD marker. |
| `chest_tr`, `weekly_reward_tr`, `lives_tr` | Chest title/banner/hint, rank/coin sentence, revised refill caption, timer and actions. |
| `gameplay_tr`, `timed_boosters_tr`, `leaderboard_tr` | Level/combo HUD, complete 15 sn and 30 sn badges, reset duration, leaderboard tabs/navigation and raw names. |

No resolution-specific clipping or overlap was observed. Long text wraps within its existing
panels; titles and actions use the existing scene-owned fitting. Deletion confirmation
intentionally scrolls, with the full final retention paragraph reachable at every size.
The longer refill caption wraps into two lines above the timer. Countdown units remain visible
within their circular badges, and both used-extension actions retain the complete wording.
No new scene hierarchy or layout changes were needed.

Captures contain no script errors. Gameplay captures retain existing hammer-art UID,
synthetic-board and anchor warnings. The purchase-reward capture retains the known capture-
teardown ObjectDB leak and four-resources-in-use error reported in the earlier Indonesian
review. All five reward images were saved; this does not claim a clean shutdown for that setup.
Runtime code, tests and integration docs pass `git diff --check`.

The ignored `tmp/capture_turkish_localization.ps1` records all 31 setups. Reproduce them with
the existing `capture_ui.ps1 -Locale tr` and scene-specific setup scripts. Captures use isolated
saves without changing the real player's language or performing real purchases/account deletion.
