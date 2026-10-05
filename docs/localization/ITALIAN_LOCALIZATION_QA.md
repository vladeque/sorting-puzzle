# Italian localization verification — October 5, 2026

## Reviewed copy and implementation

`assets/translations/it.po` includes all 251 keyed entries from the owner's corrected
`Sorting Puzzle — Italian Translations.md`. `ITALIAN_TRANSLATIONS.md` archives the supplied
file verbatim. `tests/localization/italian_inventory.json` retains the reviewed English/Italian
entries and singular/plural pairs as an independent engine-test fixture.

The native-name language picker includes `Italiano` (`it`); fresh Italian and Swiss Italian
device locales resolve to it. Language selection remains in local preferences.
The catalog preserves the corrected `Home`, `LIVELLO NON SUPERATO`, `Verifica in corso...`,
`Acquista per %s` and account-deletion copy, placeholders and explicit line breaks.
`AD`, `OFF`, player names, reference values and store-formatted prices remain unchanged.

The six supplied plural pairs are included, along with the supplied singular coin-prize
tooltip. Claimed chips use counted booster names (`Martelli`, `Lanterne`, `Congelatori`);
the product verb `Rimescola` stays unchanged. Pause and Leave Confirmation explicitly use
`common.resume` (`Riprendi`), while move-on actions use `Continua`.
Display numbers use periods (`1.234.567`) and deadlines use lowercase Italian month names
(`2 novembre 2026`). Additional email labels come from the document's supplemental table;
the existing empty-leaderboard message reads `Ancora nessun punteggio`.
Runtime ownership is documented in `docs/LOCALIZATION.md`.

## Automated checks

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_italian_localization`: all 251 reviewed entries, English scene aliases, English and
  untranslated-locale fallback, every plural pair at 0/1/2/3/10/11/21/101/1000/1000000, counted
  boosters, Italian glyphs, twelve dates, number grouping, unchanged names/prices, badge aliases,
  live resume/offer/Main Menu refreshes, preserved pending ad state and local-only preferences.
- `test_language_selection`: thirteen native-name options, Italian/Swiss Italian device mapping,
  pending/save behavior, persistence, cancellation and the existing stacking checks.
- `test_russian_localization` and `test_ukrainian_localization`: their reviewed catalogs,
  formatting and live-switch behavior continue to pass after the shared presentation changes.
- `test_level_ui_consistency`: English gameplay-modal actions, routing, safe layouts and
  existing component behavior pass after separating the resume caption.

Both editor import passes completed successfully. Final imports and capture logs contain no
engine/script errors. The level consistency test and gameplay captures retain existing
hammer-art UID fallbacks, synthetic board/layout-anchor warnings; the consistency test also
reports its existing ObjectDB shutdown leak warning.

## Rendered review

PNG contact sheets in ignored `tmp/ui_capture/` were inspected with Italian selected in isolated
sessions. All fourteen captures below match the requested phone sizes: 540x960, 720x1280,
1080x1920 and 1080x2400. The reviewed Italian captions fit within their panels, buttons and
labels at those sizes; no production layout or font changes were needed.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_it` | `PACCHETTO` badge, lives status, home and level action. |
| `shop_it` | Offer headings, hints, period grouping, prices and `67% OFF`. |
| `starter_it` | Offer title, coin ribbon, four booster names and corrected buy caption. |
| `starter_claimed_it` | Purchase reward reveal, amount, booster names and collect prompt. |
| `claimed_boosters_it` | Diagnostic claimed-chip state: `+3 Martelli`, `+3 Rimescola`, `+3 Lanterne`, `+3 Congelatori`. |
| `support_it` | FAQ questions, expanded five-step report, email action and account row. |
| `deletion_it` | Full account-deletion confirmation paragraphs and action buttons. |
| `deletion_accepted_it` | Accepted-state title, localized `1 novembre 2026` deadline and new-game action. |
| `language_it` | Native `Italiano` selection and `SALVA`. |
| `failure_it` | `LIVELLO NON SUPERATO` banner and retry action. |
| `pause_it`, `leave_it` | Settings/loss captions and both `Riprendi` actions. |
| `chapter_it` | Chapter title, quoted previous-chapter name and plural unlock requirement. |
| `chest_it` | Long chest title, progress hint, hero banner and `Continua`. |

`scripts/tools/captures/starter_bundle_claimed_boosters_setup.gd` prepares the existing offer and
switches its chips to a claimed display for fitting checks; it does not purchase or grant rewards.

## Capture limits and existing geometry

- Default 1200x1600 requests render at 900x1600 under the existing keep-width capture behavior.
  Manifests and logs report that mismatch; these images do not verify the requested tablet size.
- Pause and Leave Confirmation use their existing setup scripts' diagnostic stretch override
  and produced exact 1200x1600 images. Their text fits, but those diagnostic images do not establish
  production tablet geometry for the other screens.
- Main Menu at 1080x1920 and 1080x2400 retains its previously documented level-button/navigation
  placement above the bottom of the image. The Italian text remains readable; this integration
  does not constitute a correction or full approval of that existing responsive geometry.
