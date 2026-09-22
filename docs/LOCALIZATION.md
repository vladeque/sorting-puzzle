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

## Current boundary

No translation catalogs or translated interface strings exist yet; only language names use native
labels. Changing locale updates Godot's active `TranslationServer` locale and persists the choice,
but the rest of the current English UI remains visually unchanged. Future localization work must
add reviewed translation resources and make dynamic strings translation-aware.

## Verification

- `tests/ui/test_language_selection.gd` covers the allowlist, locale mapping, pending/confirmed
  selection, persistence, snapshot exclusion, cancellation, and Main Menu stacking.
- `scripts/tools/captures/language_selection_setup.gd` opens Settings and Language for responsive
  screenshot capture.
