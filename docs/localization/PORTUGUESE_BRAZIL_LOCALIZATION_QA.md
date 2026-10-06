# Brazilian Portuguese localization verification — October 6, 2026

## Reviewed copy and runtime ownership

`assets/translations/pt_BR.po` includes all 251 keyed entries from the owner's improved
`Sorting_Puzzle_Portugues_Brasil.md`. `PORTUGUESE_BRAZIL_TRANSLATIONS.md` archives the supplied
document verbatim; its SHA-256 matches the attachment. The independent engine fixture
`tests/localization/portuguese_brazil_inventory.json` retains the revised English/Portuguese text,
all seven supplied singular/plural pairs and supplementary deletion email labels.

The existing Português (Brasil) option resolves the registered `pt_BR` catalog. Portuguese device
locales, including `pt_BR` and `pt_PT`, retain their existing first-run mapping. The catalog supplies
stable keys, English scene aliases and uppercase card/product aliases through existing runtime
hooks. The revised `Pedir ajuda`, `Tentar de novo`, chest banner, `Toque para resgatar`, profile
unlock caption and deletion messages preserve the approved wording exactly.

Singular is selected for one and plural for other integer counts. The supplied product-name labels
stay fixed for counted boosters: `Martelo`, `Embaralhar`, `Lanterna`, `Congelador`. The `Retry` scene
alias uses the failure action `Tentar de novo`; destination reload uses the explicit stable key
`common.retry_load` (`Recarregar`). Both resume and move-on actions use `Continuar`.

Supplementary catalog entries cover the four deletion-email field labels, twelve lowercase month
names, the date pattern and the existing empty-leaderboard status (`Ainda não há pontuações`).
`GameText` uses period grouping (`1.234.567`) and dates such as `2 de novembro de 2026`.
Store-formatted prices, player names, references/IDs and compact `AD` / `OFF` markers retain their
existing content. Locale selection remains a local preference. Runtime ownership is documented
in `docs/LOCALIZATION.md`, `docs/SCENES.md` and `docs/TYPOGRAPHY.md`.

## Automated verification

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_portuguese_brazil_localization`: all 251 reviewed keys and English aliases; English and
  untranslated-locale fallback; seven plural pairs at 0/1/2/3/10/11/21/101/1000/1000000; fixed
  counted booster names; Portuguese glyphs; twelve dates; period grouping; preserved names,
  prices and markers; contextual reload/replay actions; live Main Menu, offer and resume refreshes;
  pending rewarded-action preservation; device mapping and local-only preference persistence.
- The Portuguese test measures the complete failure action and shelf-unlock action against their
  button widths and padding at all five viewports. It checks cream-panel clearance for the shelf's
  ready, pending and error states, and restoration of the original English replay font size after
  a live language switch.
- `test_language_selection` and `test_italian_localization` passed after catalog/formatting changes.
- `test_spanish_localization`, `test_arabic_localization` and `test_level_ui_consistency` passed
  after the failure-action and shelf-content fitting refinements.

The editor import completed successfully. Final capture logs contain no engine/script errors.
Gameplay captures/imports retain existing hammer-art UID path-fallback and anchor warnings.
The level-consistency test also retains its synthetic board-layout and ObjectDB shutdown warnings.

## Rendered review

All 25 final contact sheets in ignored `tmp/ui_capture/` were inspected. Each contains exact
540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: 125 images, zero size mismatches.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_pt_br`, `shop_pt_br` | Home badge, lives counter, level action, navigation, offer headings, prices, number grouping and `67% OFF`. |
| `starter_pt_br`, `claimed_boosters_pt_br` | One-time ribbon, coins, four booster names, fixed claimed labels and buy action. |
| `purchase_reward_pt_br` | `COMPRA CONCLUÍDA`, granted reward captions and revised `Toque para resgatar`. |
| `support_pt_br` | FAQ questions, expanded five-step ad report, email action and account row. |
| `deletion_pt_br`, `deletion_scrolled_pt_br` | Confirmation, irreversible-loss warning, reachable retained-records paragraph and 30-day period. |
| `deletion_accepted_pt_br`, `deletion_failure_pt_br`, `deletion_cleanup_pt_br` | Localized deadline, new-game action, revised failure title, nothing-deleted warning and revised cleanup headline. |
| `language_pt_br`, `profile_pt_br` | Native Português (Brasil) selection, Portuguese profile labels, preserved player name and `SALVAR`. |
| `failure_pt_br`, `complete_pt_br` | Reviewed failure banner/replay action, completion praise and continue action. |
| `pause_pt_br`, `leave_pt_br` | Settings labels, loss caption and both `Continuar` actions. |
| `chapter_pt_br` | Chapter title, quoted preceding chapter name and plural unlock requirement. |
| `timeup_pt_br` | Timeout offer and the two-line unavailable ad action. |
| `shelf_unlock_pt_br`, `shelf_pending_pt_br` | Full unlock action, complete match requirement, pending reward status and padded content. |
| `chest_pt_br`, `weekly_reward_pt_br`, `lives_pt_br` | Revised chest banner/hint, ranked weekly coin reward and life-refill offer. |
| `gameplay_pt_br` | Portuguese HUD, numeric combo and ability counters on a populated board. |

The first valid failure render showed `Tentar de novo` reaching the button edges at every size.
`level_failure_screen.gd` now fits that action within the existing button with configurable
32px maximum / 20px minimum font sizes and 32px horizontal padding. A shorter English action
restores the original font size.

The first valid shelf render showed the last description line touching the cream panel's bottom.
`shelf_unlock_menu.gd` now sizes the cream region and preferred outer panel from the offer row's
actual minimum height and scene-authored vertical padding, including visible reward status.
The shared shell still fits the whole panel to the safe viewport. Final ready and pending captures
show the complete Portuguese text with padding at all five sizes. Reviewed copy is unchanged.

Initial setup mismatches were rerun with the owning scenes: gameplay overlays use `level.tscn`,
the lives modal uses `scenes/main_menu.tscn`, and chapter selection uses its screen scene.
Only the corrected, error-free captures are included in the final review.

Pause and Leave Confirmation reuse diagnostic setups that override stretch aspect in their
isolated processes. Their tablet images visibly stretch the modal and do not establish production
tablet geometry for those two overlays. Other final captures retain production aspect behavior.
These desktop renders do not establish native mobile SDK or physical-device acceptance.
