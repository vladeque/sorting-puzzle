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

On a fresh save, a supported device language is selected; unsupported and Simplified Chinese
device locales fall back to English. Any explicit player selection is persisted and wins on later
starts.

## Translation catalogs

`assets/translations/en.po`, `assets/translations/ru.po`, `assets/translations/uk.po` and `assets/translations/it.po` are
registered in `project.godot`.
Russian includes all 251 reviewed keys from
`docs/localization/RUSSIAN_TRANSLATIONS.md`, the user's corrected October 4, 2026 inventory.
The inventory is a copy of the approved translation text, not runtime configuration.
English remains the fallback for the other nine selectable locales until their catalogs exist.

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
forms using `n != 1`. Claimed booster chips
use gettext context `booster.counted` for the reviewed lowercase inflected product names.

`scripts/localization/game_text.gd` owns presentation-only grouped numbers, localized dates,
counted booster names and safe purchase-error copy. Italian counts use periods and localized
month names without a year suffix. Russian and Ukrainian counts use spaces and
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
`reward_chest_menu.gd` fits the translated hero caption within its banner at 28px down to 16px,
with `HeroTitleLabel` retaining the existing banner bounds instead of expanding its container.

## Verification

- `tests/ui/test_language_selection.gd` covers the allowlist, locale mapping, pending/confirmed
  selection, persistence, snapshot exclusion, cancellation, and Main Menu stacking.
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
- Capture any screen in an isolated Russian session with:

  ```powershell
  & .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/shop_screen.tscn -Name shop_ru -Locale ru
  ```

  `capture_ui.ps1 -Locale` passes the locale to `capture_scene.gd`, which applies it before the
  scene is instantiated. It does not change the real player's saved preference.
  Use `-Locale uk` for Ukrainian captures.
  Use `-Locale it` for Italian captures.

The October 4–5, 2026 test results, rendered-screen reviews and capture limitations are recorded in
`docs/localization/RUSSIAN_LOCALIZATION_QA.md`.
Ukrainian integration results are recorded in `docs/localization/UKRAINIAN_LOCALIZATION_QA.md`.
Italian integration results are recorded in `docs/localization/ITALIAN_LOCALIZATION_QA.md`.
