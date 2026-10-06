# Localization

## Runtime ownership

- `scripts/localization/locale_catalog.gd` owns the release-language allowlist, native language
  labels, locale validation, and first-run device-locale mapping.
- `LocaleManager` (`scripts/localization/locale_manager.gd`) applies the saved choice through
  `TranslationServer` and is the only runtime entry point for changing locale.
- `PlayerProgress` stores `locale` in the local `preferences` partition. It is excluded from the
  authoritative gameplay snapshot and backend journal operations.
- `scenes/ui/language_selection_modal.tscn` owns pending selection, scrolling, confirmation, and
  cancellation. Selecting a row does not change runtime state until Save is pressed. Touch and
  wheel scrolling remain enabled without showing a scrollbar.

## Release locale allowlist

| Language-list label | Godot locale |
| --- | --- |
| English | `en` |
| Español | `es` |
| Português (Brasil) | `pt_BR` |
| Deutsch | `de` |
| Français | `fr` |
| Italiano | `it` |
| 日本語 | `ja` |
| 한국어 | `ko` |
| 繁體中文 | `zh_Hant` |
| Bahasa Indonesia | `id` |
| Türkçe | `tr` |
| Русский | `ru` |
| Українська | `uk` |
| العربية | `ar` |

On a fresh save, a supported device language is selected; unsupported and Simplified Chinese
device locales fall back to English. Any explicit player selection is persisted and wins on later
starts.

## Translation catalogs

`assets/translations/en.po`, `assets/translations/ru.po`, `assets/translations/uk.po`,
`assets/translations/it.po`, `assets/translations/ar.po`, `assets/translations/es.po`,
`assets/translations/pt_BR.po` and `assets/translations/de.po` are
registered in `project.godot`.
Russian includes all 251 reviewed keys from
`docs/localization/RUSSIAN_TRANSLATIONS.md`, the user's corrected October 4, 2026 inventory.
The inventory is a copy of the approved translation text, not runtime configuration.
English remains the fallback for the other six selectable locales until their catalogs exist.

Ukrainian includes all 251 entries from the owner's reviewed October 5, 2026 document archived
at `docs/localization/UKRAINIAN_TRANSLATIONS.md`. `uk.po` preserves the edited captions and
support/deletion messages, the five sentence plural tables, four counted booster-name tables,
twelve genitive month names and supplementary email labels. The archive retains the supplied
document's pre-integration notes; this page describes the implemented runtime behavior.
`tests/localization/ukrainian_inventory.json` records the reviewed content for engine verification.
The Ukrainian badge reads `НАБІР`, and `Українська` is available in the native-name language picker.
A Ukrainian device locale such as `uk_UA` maps to `uk` on a fresh save.

Italian includes all 251 entries from the owner's reviewed October 5, 2026 document archived
verbatim at `docs/localization/ITALIAN_TRANSLATIONS.md`. `tests/localization/italian_inventory.json`
records that reviewed wording, the six supplied plural pairs, the additional singular coin-prize
tooltip and supplementary email labels. `it.po` registers stable keys and English scene aliases.
The native-name language picker exposes `Italiano`, and Italian device locales such as `it_IT`
and `it_CH` map to `it` on a fresh save. Counts use periods (`1.234.567`), and deadlines use
lowercase Italian month names with a day/month/year pattern (`2 novembre 2026`).

The reviewed Italian main tables show plural wording; gettext selects their supplied singular
form when the numeric count is one. Counted booster context supplies `Martello` / `Martelli`,
`Lanterna` / `Lanterne`, and `Congelatore` / `Congelatori`; the verb name `Rimescola` stays fixed.
The coin-prize tooltip uses the coin amount to select `moneta` / `monete`; existing English,
Russian and Ukrainian tooltip wording is unchanged across their plural forms.
Pause and leave-confirmation owners explicitly resolve `common.resume` (`Riprendi`) on startup
and live language changes, while the shared `Continue` scene alias uses `Continua`.
The reviewed `Home`, `LIVELLO NON SUPERATO`, `Verifica in corso...`, `Acquista per %s` and revised
account-deletion messages are preserved exactly. The archived document's review notes describe
the supplied file, while this page and `docs/localization/ITALIAN_LOCALIZATION_QA.md` record
runtime integration and verification.

Spanish includes all 251 entries from the owner's improved October 6, 2026 document archived
verbatim at `docs/localization/SPANISH_TRANSLATIONS.md`. `tests/localization/spanish_inventory.json`
retains the reviewed English/Spanish wording, six supplied plural pairs, singular coin-prize
tooltip, counted booster names and supplementary email labels. `es.po` supplies stable keys,
English scene aliases and uppercase product/card aliases through the existing localization hooks.
The existing `Español` option and regional Spanish device locales such as `es_ES`, `es_MX`,
`es_AR` and `es_CO` resolve to the neutral Spanish catalog.

Spanish counts use period grouping (`1.234.567`); store prices retain their provider formatting.
Deadlines use lowercase Spanish month names and `date.day_month_year` (`2 de noviembre de 2026`).
Counted booster context supplies `Martillo` / `Martillos`, `Mezcla` / `Mezclas`,
`Linterna` / `Linternas` and `Congelador` / `Congeladores`. Gameplay resume uses `Reanudar`,
while move-on actions use `Continuar`. The reviewed `NIVEL NO SUPERADO`,
`OFERTA DE UNA SOLA COMPRA`, `Verificando oferta…` and revised support/deletion wording are
preserved exactly. `AD`, `OFF`, native language names and player/reference values retain their
existing behavior. The archive retains its pre-integration notes; runtime verification is
recorded in `docs/localization/SPANISH_LOCALIZATION_QA.md`.

Brazilian Portuguese includes all 251 entries from the owner's improved October 6, 2026 document
archived verbatim at `docs/localization/PORTUGUESE_BRAZIL_TRANSLATIONS.md`.
`tests/localization/portuguese_brazil_inventory.json` preserves that revised text, all seven supplied
singular/plural pairs and supplementary email labels. `pt_BR.po` supplies stable keys, English
scene aliases and uppercase card/product aliases through the existing localization hooks.
The existing `Português (Brasil)` language option now resolves the catalog. Portuguese device
locales, including `pt_BR` and `pt_PT`, continue to map to `pt_BR` on a fresh save.

Brazilian Portuguese counts use periods (`1.234.567`); dates use lowercase month names with
`date.day_month_year` (`2 de novembro de 2026`). Store-formatted prices remain unchanged.
Gettext selects the supplied singular for one and plural for other integer counts. The reviewed
quantity labels deliberately retain fixed product names: `Martelo`, `Embaralhar`, `Lanterna` and
`Congelador`, including in the `booster.counted` context. The reviewed failure action uses
`Tentar de novo` through the `Retry` scene alias; the destination status panel explicitly uses
`common.retry_load` (`Recarregar`). Both gameplay resume and move-on actions use `Continuar`.
The improved chest banner, `Toque para resgatar`, `Pedir ajuda`, deletion failure/cleanup messages
and all warning paragraphs retain the supplied wording. `AD`, `OFF`, native language names and
player/reference values retain their existing behavior. The archive keeps its pre-integration
notes; runtime verification is recorded in `docs/localization/PORTUGUESE_BRAZIL_LOCALIZATION_QA.md`.

German includes all 251 entries from the owner's improved October 6, 2026 document archived
at `docs/localization/GERMAN_TRANSLATIONS.md`. `tests/localization/german_inventory.json`
retains the reviewed English/German wording, six supplied plural pairs, fixed counted booster
names and supplementary email labels. `de.po` supplies stable keys, English scene aliases and
uppercase card/product aliases through the existing localization hooks. The existing Deutsch
option now resolves this catalog; regional German device locales such as `de_DE`, `de_AT`,
`de_CH` and `de_LI` continue to select `de` on a fresh save.

German counts use period grouping (`1.234.567`), and `GameText.format_date()` uses numeric
day/month/year dates with leading zeros (`02.11.2026`). Store-formatted prices remain unchanged.
Gettext selects the supplied singular for one and plural for other integer counts. The four
booster product names stay fixed after quantities: `Hammer`, `Mischen`, `Laterne`, `Zeitstopp`.
The invariant coin-prize tooltip `Wochenbelohnung in Münzen: %s` works with either quantity.
Gameplay resume uses `Weiterspielen`, move-on actions use `Weiter`, replay uses `Nochmal spielen`
through the `Retry` scene alias, and destination reload explicitly uses `common.retry_load`
(`Neu laden`). The revised `Wird geladen…`, `Wird geprüft...`, `Freischaltfortschritt`, `LEBEN VOLL`,
profile unlock and deletion messages preserve the supplied wording exactly. `AD`, `OFF`, native
language names and player/reference values retain their existing behavior. The archive retains
its pre-integration notes; runtime verification is recorded in
`docs/localization/GERMAN_LOCALIZATION_QA.md`.

The owner's October 5, 2026 review supersedes three rows of that original inventory:

| Key / English alias | Current Russian display | Reason |
| --- | --- | --- |
| `menu.starter_badge` / `BUNDLE` | `НАБОР` | Names the package; `СТАРТ` suggested starting gameplay. |
| `ad.badge` / `AD` | `AD` | Preserve the compact locked-shelf marker. |
| `shop.discount_off` / `OFF` | `OFF` | Preserve the short second line of the percentage tag. |

These updates live in both the stable-key and English-alias entries of `ru.po`, and in the
reviewed test fixture. The original inventory remains an archive of the supplied document.
The full offer/card title remains `Стартовый набор` (uppercased where authored).
The badge's English scene text, catalog value and alias are `BUNDLE`, matching Russian `НАБОР`.

Keep the game name, actual player names, platform names, native language names, addresses,
references/IDs and platform-formatted prices unchanged. Translate regular player-facing copy,
including ad descriptions/actions, booster names, `КОМБО`, `Макс.` and bundle descriptions.
Across locales, keep the locked-shelf `AD` marker and percentage discount tags such as `67% OFF`
unchanged. `shop.discount_off` must remain `OFF`; the percentage comes from the offer and keeps
its existing digits and `%` sign. These are compact visual markers; regular ad actions and
descriptions still translate. The translator inventory records this rule in its guidelines,
individual rows and implementation notes.

The catalogs expose stable inventory keys for dynamic text and English aliases for scene-authored
labels, buttons, tooltips, exported component titles and config-supplied chapter/bundle names.
Keeping those scene values readable preserves editor previews and existing scene consumers.
English aliases with identical wording share one translation. The destination status panel
explicitly uses `common.retry_load` to distinguish refreshing data from replaying a failed level.
Uppercase bundle aliases preserve the authored card presentation. Shop info dialogs translate
their product/error title before uppercasing it.

Formatted HUD, chapter, timer, leaderboard, profile, offer and support strings translate their
patterns before interpolation. Russian and Ukrainian `tr_n()` calls select from three reviewed forms using the
underlying integer count, including when the inserted amount is a formatted `%s`. For rows and
weekly rewards, the plural count is the stars/coins rather than the rank. Italian selects its two
forms using `n != 1`, as do Spanish, Brazilian Portuguese and German. Claimed booster chips
use gettext context `booster.counted` for the reviewed quantity-aware product names.

`scripts/localization/game_text.gd` owns presentation-only grouped numbers, localized dates,
counted booster names and safe purchase-error copy. Italian counts use periods and localized
month names without a year suffix. Spanish uses period grouping and a day/month/year pattern
with `de` between its parts. Brazilian Portuguese also uses period grouping and this date pattern,
with its own month names. German uses period grouping and numeric `DD.MM.YYYY` dates.
Russian and Ukrainian counts use spaces and
deadlines use genitive month names with the catalog's `date.day_month_year` pattern (`г.` / `р.`);
store prices pass through unchanged. Purchase/load presentation maps
unreviewed technical errors to the existing player-facing fallback messages. Provider errors,
IDs, authorization, eligibility, economy and protocol values are not translated or rewritten.

Dynamic scene owners handle `NOTIFICATION_TRANSLATION_CHANGED` by refreshing displayed text from
retained presentation inputs. Refreshing a language never replays purchases, grants, animations,
catalog requests or reward actions. Static English scene text is retranslated by Godot itself.
Leaderboard player-name labels and the profile name field disable automatic translation; the
profile placeholder is translated separately. Native language names and the app brand remain
unchanged.

Additional catalog entries cover the four email field labels referenced without keys in the
inventory, localized month names and the existing empty-leaderboard status (`Поки що немає результатів`
in Ukrainian). Loading screens reuse
the reviewed `common.loading` wording.

## Cyrillic and layout

The bundled DynaPuff font does not contain Cyrillic. Its theme variations use bundled Nunito
fallback variations at matching 500/600/700 weights, so Russian and Ukrainian do not depend on mobile system
fonts. `docs/TYPOGRAPHY.md` records this ownership.

Awning headers, ribbons and shared font fitting measure the translated text. Booster chips fit
their localized name within the authored chip width, down to the exported
`minimum_name_font_size`, rather than widening the reward row.
The failure screen fits its result message; `PauseMenu` fits the Settings privacy button within
its authored width. Support FAQ action buttons reserve 384 pixels for the reviewed Ukrainian copy.
The lives modal's next-life caption wraps within its timer column instead of widening the status row.
Its owner fits rewarded-action captions within the authored button width, with configurable
24px maximum / 16px minimum sizes and 24px horizontal text padding, including after language changes.
`shelf_unlock_menu.gd` applies the same configurable bounds to its rewarded-action caption after
state, size and language changes. This keeps the full reviewed Spanish
`Ver anuncio · Desbloquear estante` inside the button padding without widening its action row.
The shelf owner also grows the cream region and preferred modal height to the row's measured
minimum height plus its authored vertical padding, including a visible reward-status message.
The shared shell still scales the whole modal to the safe viewport. The failure-screen owner fits
its replay caption at configurable 32px down to 20px with 32px horizontal padding. Both refinements
preserve the complete reviewed Brazilian Portuguese text on resize and live language changes.
`reward_chest_menu.gd` fits the translated hero caption within its banner at 28px down to 16px,
with `HeroTitleLabel` retaining the existing banner bounds instead of expanding its container.
FAQ question styles reserve trailing room for the expand/collapse icon; `support_faq_item.gd`
fits complete translated captions from configurable 22px down to 16px on resize and live language
changes. `account_deletion_modal.gd` fits both action captions from configurable 22px down to 16px
with 24px horizontal padding after state, size and locale changes. These refinements preserve
the reviewed German wording and existing touch targets.

## Arabic

Arabic (`ar`) is registered and selectable as العربية. Regional device locales such as `ar_SA`
and `ar_EG` resolve to `ar`. The revised copy is archived verbatim in
`docs/localization/ARABIC_TRANSLATIONS.md`; `tests/localization/arabic_inventory.json` retains
all 251 reviewed strings, 42 plural variants, fixed booster names and supplementary email labels.
The only new caption outside that source is `leaderboard.empty` (لا توجد نتائج بعد).

Arabic gettext uses six forms: zero, one, two, few (integer remainder 3–10), many (11–99), other.
Ordinary counts, ranks, timers and dates retain 0–9. `GameText.format_date()` uses numeric Gregorian
day/month/year dates. Store prices retain provider formatting. Bundled Arabic glyph fallbacks are
available in every locale, including the native language row and mixed player names; see
`docs/TYPOGRAPHY.md`.

`GameText.isolate_ltr()` adds display-only isolation around emails, deadline dates and operation
references embedded in Arabic prose. Combo/claimed-booster caption helpers also protect `×count`
and `+count` runs; the weekly dialog isolates its `#rank`. `GameText.isolate_price()` uses
content-sensitive isolation for a store price embedded in the Starter Bundle caption.
Use these helpers only at a UI formatting boundary: raw names, IDs,
email templates, mailto URLs, saved preferences and protocol data retain their original content.

The implementation ownership and verification scope are recorded in
`docs/localization/ARABIC_LOCALIZATION_PLAN.md` and `docs/localization/ARABIC_LOCALIZATION_QA.md`.

## Verification

- `tests/ui/test_language_selection.gd` covers the allowlist, locale mapping, pending/confirmed
  selection, persistence, snapshot exclusion, cancellation, and Main Menu stacking.
- `tests/ui/test_arabic_localization.gd` verifies reviewed copy, six plural forms, fonts,
  0–9/date formatting, price/name preservation, live state and purchase-status clearance.
- `tests/ui/test_arabic_direction.gd` verifies pager gestures, asymmetric physical safe insets,
  paragraph alignment, mixed-name selection, timeout text fitting and numeric direction.
- `scripts/tools/captures/language_selection_setup.gd` opens Settings and Language for responsive
  screenshot capture.
- `scripts/tools/captures/starter_bundle_claimed_boosters_setup.gd` opens the existing offer and
  previews claimed booster labels for count/name fitting without purchasing or granting rewards.
- `tests/ui/test_russian_localization.gd` checks the 251-entry reviewed fixture, Russian/English
  resolution, untranslated-locale fallback, plural boundaries, font coverage, unchanged player
  names/prices, live screen refreshes, preserved reward states and local-only locale persistence.
- `tests/ui/test_ukrainian_localization.gd` checks all 251 reviewed Ukrainian entries, English
  fallback, every plural table and counted booster at integer boundaries, the Ukrainian alphabet
  and apostrophe, all twelve dates, names/prices, static badge aliases and live screen refreshes.
- `tests/ui/test_italian_localization.gd` checks all 251 reviewed Italian entries and English
  scene aliases, fallback, singular/plural counts including quantities ending in one, counted
  boosters, accented glyphs, all twelve dates, names/prices, live resume actions and screen
  refreshes, preserved pending ad state and local-only locale persistence.
- `tests/ui/test_spanish_localization.gd` checks all 251 reviewed Spanish entries and English
  scene aliases, English fallback, integer plural boundaries, counted boosters, Spanish glyphs,
  twelve localized dates, unchanged names/prices, live screen/resume updates, preserved pending
  ad state, regional device-locale mapping and local-only preference persistence.
- `tests/ui/test_portuguese_brazil_localization.gd` checks all 251 reviewed Brazilian Portuguese
  entries and English aliases, fallback, seven plural pairs, fixed counted booster names,
  accented glyphs, all twelve dates, period grouping, unchanged names/prices/markers, reload vs
  replay copy, live screen/resume changes, pending ad state and local-only preference persistence.
- `tests/ui/test_german_localization.gd` checks all 251 revised German entries and English
  aliases, fallback, six supplied plural pairs, fixed counted booster names, German glyphs,
  twelve numeric dates, period grouping, preserved names/prices/markers, distinct reload/replay
  and resume/move-on actions, live screen changes, pending ad state, regional device mapping and
  local-only preference persistence. It measures FAQ questions and deletion, shelf and replay
  actions at all five viewports.
- Capture any screen in an isolated Russian session with:

  ```powershell
  & .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/shop_screen.tscn -Name shop_ru -Locale ru
  ```

  `capture_ui.ps1 -Locale` passes the locale to `capture_scene.gd`, which applies it before the
  scene is instantiated. It does not change the real player's saved preference.
  Use `-Locale uk` for Ukrainian captures.
  Use `-Locale it` for Italian captures.
  Use `-Locale ar` for Arabic captures.
  Use `-Locale es` for Spanish captures.
  Use `-Locale pt_BR` for Brazilian Portuguese captures.
  Use `-Locale de` for German captures.

The October 4–5, 2026 test results, rendered-screen reviews and capture limitations are recorded in
`docs/localization/RUSSIAN_LOCALIZATION_QA.md`.
Ukrainian integration results are recorded in `docs/localization/UKRAINIAN_LOCALIZATION_QA.md`.
Italian integration results are recorded in `docs/localization/ITALIAN_LOCALIZATION_QA.md`.
Arabic integration results are recorded in `docs/localization/ARABIC_LOCALIZATION_QA.md`.
Spanish integration results are recorded in `docs/localization/SPANISH_LOCALIZATION_QA.md`.
Brazilian Portuguese integration results are recorded in `docs/localization/PORTUGUESE_BRAZIL_LOCALIZATION_QA.md`.
German integration results are recorded in `docs/localization/GERMAN_LOCALIZATION_QA.md`.
