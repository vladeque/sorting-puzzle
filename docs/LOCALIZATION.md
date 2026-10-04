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
| 日本語 | `ja` |
| 한국어 | `ko` |
| 繁體中文 | `zh_Hant` |
| Bahasa Indonesia | `id` |
| Türkçe | `tr` |
| Русский | `ru` |

On a fresh save, a supported device language is selected; unsupported and Simplified Chinese
device locales fall back to English. Any explicit player selection is persisted and wins on later
starts.

## Translation catalogs

`assets/translations/en.po` and `assets/translations/ru.po` are registered in `project.godot`.
Russian includes all 251 reviewed keys from
`docs/localization/RUSSIAN_TRANSLATIONS.md`, the user's corrected October 4, 2026 inventory.
The inventory is a copy of the approved translation text, not runtime configuration.
English remains the fallback for the other nine selectable locales until their catalogs exist.

The owner's October 5, 2026 review supersedes three rows of that original inventory:

| Key / English alias | Current Russian display | Reason |
| --- | --- | --- |
| `menu.starter_badge` / `STARTER` | `НАБОР` | Names the package; `СТАРТ` suggested starting gameplay. |
| `ad.badge` / `AD` | `AD` | Preserve the compact locked-shelf marker. |
| `shop.discount_off` / `OFF` | `OFF` | Preserve the short second line of the percentage tag. |

These updates live in both the stable-key and English-alias entries of `ru.po`, and in the
reviewed test fixture. The original inventory remains an archive of the supplied document.
The full offer/card title remains `Стартовый набор` (uppercased where authored).

Keep the game name, actual player names, platform names, native language names, addresses,
references/IDs and platform-formatted prices unchanged. Translate regular player-facing copy,
including ad descriptions/actions, booster names, `КОМБО`, `Макс.` and bundle descriptions.
`AD` and `OFF` are deliberate exceptions for compact visual markers, not a general preference
for English labels throughout the Russian UI.

The catalogs expose stable inventory keys for dynamic text and English aliases for scene-authored
labels, buttons, tooltips, exported component titles and config-supplied chapter/bundle names.
Keeping those scene values readable preserves editor previews and existing scene consumers.
English aliases with identical wording share one translation. The destination status panel
explicitly uses `common.retry_load` to distinguish refreshing data from replaying a failed level.
Uppercase bundle aliases preserve the authored card presentation. Shop info dialogs translate
their product/error title before uppercasing it.

Formatted HUD, chapter, timer, leaderboard, profile, offer and support strings translate their
patterns before interpolation. Russian `tr_n()` calls select from three reviewed forms using the
underlying integer count, including when the inserted amount is a formatted `%s`. For rows and
weekly rewards, the plural count is the stars/coins rather than the rank. Claimed booster chips
use gettext context `booster.counted` for the reviewed lowercase inflected product names.

`scripts/localization/game_text.gd` owns presentation-only grouped numbers, localized dates,
counted booster names and safe purchase-error copy. Russian counts use spaces and deadlines
use genitive month names; store prices pass through unchanged. Purchase/load presentation maps
unreviewed technical errors to the existing player-facing fallback messages. Provider errors,
IDs, authorization, eligibility, economy and protocol values are not translated or rewritten.

Dynamic scene owners handle `NOTIFICATION_TRANSLATION_CHANGED` by refreshing displayed text from
retained presentation inputs. Refreshing a language never replays purchases, grants, animations,
catalog requests or reward actions. Static English scene text is retranslated by Godot itself.
Leaderboard player-name labels and the profile name field disable automatic translation; the
profile placeholder is translated separately. Native language names and the app brand remain
unchanged.

Additional catalog entries cover the four email field labels referenced without keys in the
inventory, Russian month names and the existing empty-leaderboard status. Loading screens reuse
the reviewed `common.loading` wording.

## Cyrillic and layout

The bundled DynaPuff font does not contain Cyrillic. Its theme variations use bundled Nunito
fallback variations at matching 500/600/700 weights, so Russian does not depend on mobile system
fonts. `docs/TYPOGRAPHY.md` records this ownership.

Awning headers, ribbons and shared font fitting measure the translated text. Booster chips fit
their localized name within the authored chip width, down to the exported
`minimum_name_font_size`, rather than widening the reward row.
The failure screen fits its result message; `PauseMenu` fits the Settings privacy button within
its authored width. Support FAQ action buttons reserve 320 pixels for the reviewed Russian copy.

## Verification

- `tests/ui/test_language_selection.gd` covers the allowlist, locale mapping, pending/confirmed
  selection, persistence, snapshot exclusion, cancellation, and Main Menu stacking.
- `scripts/tools/captures/language_selection_setup.gd` opens Settings and Language for responsive
  screenshot capture.
- `tests/ui/test_russian_localization.gd` checks the 251-entry reviewed fixture, Russian/English
  resolution, untranslated-locale fallback, plural boundaries, font coverage, unchanged player
  names/prices, live screen refreshes, preserved reward states and local-only locale persistence.
- Capture any screen in an isolated Russian session with:

  ```powershell
  & .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/shop_screen.tscn -Name shop_ru -Locale ru
  ```

  `capture_ui.ps1 -Locale` passes the locale to `capture_scene.gd`, which applies it before the
  scene is instantiated. It does not change the real player's saved preference.

The October 4–5, 2026 test results, rendered-screen reviews and capture limitations are recorded in
`docs/localization/RUSSIAN_LOCALIZATION_QA.md`.
