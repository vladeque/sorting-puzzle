# Spanish localization verification — October 6, 2026

## Reviewed copy and runtime ownership

`assets/translations/es.po` includes all 251 keyed entries from the owner's improved
`Sorting_Puzzle_Spanish_Translations.md`. `SPANISH_TRANSLATIONS.md` archives that supplied
document verbatim; its pre-integration notes remain part of the archive.
`tests/localization/spanish_inventory.json` retains the reviewed English/Spanish text and
the six supplied singular/plural pairs as an independent engine-test fixture.

The existing `Español` language option now resolves the registered neutral Spanish catalog.
Regional device locales including `es_ES`, `es_MX`, `es_AR` and `es_CO` resolve to `es`.
The catalog supplies stable inventory keys, English scene aliases and uppercase card/product
aliases through the existing localization hooks. It preserves the reviewed
`NIVEL NO SUPERADO`, `OFERTA DE UNA SOLA COMPRA`, `Verificando oferta…`, support questions
and deletion messages, along with placeholders, explicit line breaks, `AD` and `OFF`.

Gettext selects singular for one and plural for other integer counts. Claimed booster context
supplies `Martillo` / `Martillos`, `Mezcla` / `Mezclas`, `Linterna` / `Linternas`, and
`Congelador` / `Congeladores`. The supplied one-coin prize tooltip is included.
Supplementary entries cover the four deletion-email field labels, twelve lowercase month names,
the date pattern and the existing empty-leaderboard status (`Aún no hay puntuaciones`).

`GameText` formats Spanish counts with periods (`1.234.567`) and deadlines as
`2 de noviembre de 2026`. Provider-formatted prices and actual player/reference values pass
through unchanged. Gameplay resume uses `Reanudar`; move-on actions use `Continuar`.
Language changes remain local preferences and preserve pending rewarded-action state.
Runtime ownership is recorded in `docs/LOCALIZATION.md`.

## Automated verification

Passed using Godot 4.6.2 and `scripts/tools/run_isolated_godot_test.ps1`:

- `test_spanish_localization`: all 251 reviewed keys and English scene aliases; English and
  untranslated-locale fallback; seven sentence/tooltip plural tables at
  0/1/2/3/10/11/21/101/1000/1000000; four counted booster names; Spanish glyphs; twelve dates;
  number grouping; preserved names, prices and compact markers; live Main Menu, offer and resume
  refreshes; pending-ad state and local-only preference persistence; regional device mapping.
- The Spanish test also measures the complete shelf-unlock action against its button width and
  padding at all five representative viewports, and checks that a shorter English caption
  restores the maximum font size after a live language switch.
- `test_language_selection`, `test_italian_localization`, `test_russian_localization` and
  `test_ukrainian_localization` passed after adding the catalog and Spanish formatting.
- `test_arabic_localization` and `test_level_ui_consistency` passed after the shelf-action fitting
  change, covering existing live state and English gameplay-modal behavior.

The editor import completed successfully. Saved Spanish capture logs contain no engine/script
errors. Gameplay imports/captures retain existing hammer-art UID path-fallback, synthetic
board-layout and anchor warnings; the level-consistency test retains its existing ObjectDB
shutdown warning.

## Rendered review

All 21 PNG contact sheets in ignored `tmp/ui_capture/` were inspected. Each set contains exact
540x960, 720x1280, 1080x1920, 1080x2400 and 1200x1600 renders: 105 images, no size mismatches.

| Capture prefix | Reviewed content |
| --- | --- |
| `main_menu_es`, `shop_es` | Home badge, lives caption, navigation, level action, offer headings, prices, number grouping and `67% OFF`. |
| `starter_es`, `claimed_boosters_es` | Reviewed one-time ribbon, coin caption, four booster names, counted chip plurals and buy action. |
| `support_es` | Revised FAQ questions, expanded five-step ad report, email action and account row. |
| `deletion_es`, `deletion_scrolled_es` | Confirmation, irreversible loss warning, reachable retained-records paragraph and 30-day period. |
| `deletion_accepted_es` | Accepted-state title, localized deadline and new-game action. |
| `language_es`, `profile_es` | Native Español selection, Spanish profile labels, name preservation and `GUARDAR`. |
| `failure_es`, `complete_es` | Reviewed failure banner, retry action, completion praise and continue action. |
| `pause_es`, `leave_es` | Settings labels, loss caption and both `Reanudar` actions. |
| `chapter_es` | Chapter title, quoted preceding chapter name and plural unlock requirement. |
| `timeup_es`, `shelf_unlock_es` | Timeout offer, two-line unavailable ad action, shelf requirement and full rewarded-unlock action. |
| `chest_es`, `weekly_reward_es`, `lives_es` | Chest banner/hint, ranked weekly coin reward and life-refill offer. |
| `gameplay_es` | Spanish level HUD, numeric combo and ability counters on a populated board. |

The initial shelf-unlock capture showed `Ver anuncio · Desbloquear estante` extending beyond
the button padding. `scripts/shelf_unlock_menu.gd` now fits the translated action after state,
size and language changes using exported 24px maximum / 16px minimum sizes and 24px horizontal
padding, matching the lives-modal approach. The recaptured action fits at all five sizes and
retains the complete reviewed wording. `docs/SCENES.md` records component ownership.
No other translated caption needed a production layout or font-resource change.

Pause and Leave Confirmation reuse existing diagnostic capture setups that override stretch
aspect in their isolated processes; those images do not establish production tablet geometry
for those two overlays. Other captures use the existing production aspect policy. Desktop
rendering and engine tests do not establish native mobile SDK, platform-price or physical-device
acceptance.
