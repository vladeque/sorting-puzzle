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

All 28 French contact sheets in ignored `tmp/ui_capture/` were inspected. Each contains exact
540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: 140 images, zero resolution
mismatches and zero manifest failures. No additional scene, layout or font changes were needed.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_fr`, `shop_fr` | Level action, navigation, `Max`, `PACK`, offer titles, grouped coin amounts and unchanged percentage/`OFF` markers. |
| `starter_fr`, `claimed_boosters_fr`, `purchase_reward_fr` | Offer title/ribbons, four booster names, `+3 ×` claimed captions, unchanged provider prices and collection prompt. |
| `support_fr` | All FAQ questions and expand icons, expanded five-step ad-report instructions, email action and payment/password warning. |
| `deletion_fr`, `deletion_scrolled_fr` | Complete irreversible warning, account re-creation paragraph and reachable final retained-records/30-day paragraph. |
| `deletion_accepted_fr`, `deletion_failure_fr`, `deletion_cleanup_fr` | French deadline, explicit nothing-deleted message, revised finalization wording and complete action captions. |
| `language_fr`, `settings_fr`, `profile_fr` | Selected Français row, `ENREGISTRER`, `Vibrations`, privacy action, profile/frame labels and unchanged player names. |
| `failure_fr`, `complete_fr`, `pause_fr`, `leave_fr` | `NIVEAU RATÉ` and `Rejouer`, `BRAVO !`/`Continuer`, gameplay `Reprendre`, and leave-confirmation losses. |
| `chapter_fr` | `CHAPITRES`, `Coin des bonbons`, full unlock sentence quoting `Quartier des épiceries`, progress and locked action. |
| `timeup_fr`, `shelf_unlock_fr`, `shelf_pending_fr`, `ability_fr` | Accented modal titles, complete wrapped descriptions, two-line disabled ad caption, ready/pending actions, status clearance and unchanged `AD` marker. |
| `chest_fr`, `weekly_reward_fr`, `lives_fr` | Full chest title/banner, weekly title and reviewed `n°` message, life-refill caption/timer and action buttons. |
| `gameplay_fr`, `leaderboard_fr` | French level HUD, unchanged numeric combo, native player names, weekly reset duration and full ranking tabs/navigation. |

French captions remain inside their banners, buttons and panels at every inspected resolution.
Long shelf descriptions and pending status wrap vertically while staying inside the cream
region; the complete `Voir une pub · Débloquer` and `Vérifier la récompense` actions fit.
Deletion confirmation intentionally scrolls: the final reviewed retention paragraph is fully
reachable, including at 540x960. The selected language and all accented capitals render correctly.
The Settings privacy action and all claimed booster names fit without shortening the supplied text.

Final captures contain no script errors. Gameplay captures retain pre-existing hammer-art
UID path-fallback, synthetic board-layout and anchor warnings. The isolated purchase-reward
capture reports an ObjectDB leak and four resources still in use at shutdown, matching the
existing German/English capture-teardown limitation documented in
`GERMAN_LOCALIZATION_QA.md`. All five requested purchase-reward images were nevertheless saved;
this is not a clean capture-shutdown claim. Captures use isolated temporary saves and do not
change the real player's language or perform purchases/account deletion.
