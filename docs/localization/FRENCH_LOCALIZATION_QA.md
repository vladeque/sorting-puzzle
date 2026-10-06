# French localization verification — October 6, 2026

## Reviewed copy and runtime ownership

`assets/translations/fr.po` registers all 251 keyed entries from the owner's improved
`Sorting Puzzle — French Translations.md`, archived verbatim at `FRENCH_TRANSLATIONS.md`.
`tests/localization/french_inventory.json` retains the reviewed English/French wording,
six supplied singular/plural pairs, fixed counted booster names, supplemental email labels
and twelve French month names. Source attachment SHA-256:
`959EAF5D17CDFB3A0D1201F1052096F2FB27B1F7F638F97B88C440F321B24D8E`.

The existing Français option resolves the registered `fr` catalog. Regional device locales
`fr_FR`, `fr_CA`, `fr_BE` and `fr_CH` retain their mapping to `fr`. The catalog supplies stable
keys, English scene aliases and uppercase card/product aliases through the existing owners.
It preserves all 25 main-table improvements over the earlier French draft, including
`Quartier des épiceries`, `NIVEAU RATÉ`, the combo escalation, `Vibrations`, `Options de
confidentialité`, typographic ellipses, revised deletion copy and support-email subjects.
Placeholders, forced line breaks and warning paragraphs retain the supplied content.

Gettext selects singular for integer counts zero and one, plural for two or more (`n > 1`).
Plural selection uses the actual numeric count; leaderboard text uses stars or coins rather
than rank. Claimed boosters use `+%d × %s` with fixed product names: `Marteau`, `Mélange`,
`Lanterne`, `Gel`. The weekly coin-prize tooltip names the currency before the amount and
uses the same wording for both counts. Gameplay resume uses `Reprendre`, move-on uses
`Continuer`, replay uses `Rejouer` through the `Retry` alias, and data reload explicitly
uses `common.retry_load` (`Réessayer`).

`GameText` provides space grouping (`1 234 567`) and lowercase day/month/year dates
(`2 novembre 2026`). Supplementary email labels keep the reviewed space before their colon.
The only extra screen caption absent from the attachment is the existing empty-leaderboard
status, translated as `Aucun résultat pour le moment`. Store-formatted prices, actual names,
reference/ID values, native language names, brand and compact `AD` / `OFF` markers retain
their existing content. Locale persists only in local preferences.

Ownership is recorded in `docs/LOCALIZATION.md`, `docs/SCRIPTS.md`, `docs/SCENES.md` and
`docs/TYPOGRAPHY.md`. The archive retains its pre-integration notes; this page describes
the implemented runtime behavior.

## Automated verification

Passed with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_french_localization`: all 251 reviewed keys and English scene aliases; English and
  untranslated-locale fallback; all six plural pairs at 0/1/2/3/10/11/21/101/1000/1000000;
  fixed counted boosters; accented glyphs, quotation marks, apostrophe, ° and ×; twelve French
  dates; space grouping; preserved prices/names/markers/reference content; email punctuation;
  distinct contextual actions; regional device mapping; live Main Menu/offer/resume refreshes;
  pending ad-state preservation and local-only locale persistence. Full FAQ questions and
  deletion, shelf and replay actions fit their measured bounds at all five viewports; shelf
  descriptions/status stay inside the cream panel in ready, pending and error states.
- `test_language_selection`: supported language choices, pending/saved preference behavior
  and live locale application.
- `test_german_localization`: the existing 251-entry German suite still passes after the
  shared presentation formatter changes.

Editor import completed successfully. It reports existing hammer-art UID path-fallback
warnings. French catalog generation verified unique keys, placeholder order/count, line-break
counts and agreement between the main table and the six plural appendices.

## Rendered review

Responsive capture and visual inspection are in progress. Final results will be recorded here
after reviewing all contact sheets at 540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600.
