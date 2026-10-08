# Typography

The game uses a project-wide typography theme at
`assets/themes/game_typography.tres`, configured through
`gui/theme/custom` in `project.godot`.

## Font Families

- `assets/fonts/DynaPuff-Variable.ttf` is the primary game face. It is used for
  controls, screen and modal titles, section headings, HUD labels, counters,
  prices, ranks, scores, and other short high-emphasis text.
- `assets/fonts/Nunito-Variable.ttf` is the supporting reading face. It is used
  for instructions, statuses, player names, navigation captions, small settings
  captions, and editable text.
- The corresponding `DynaPuff-OFL.txt` and `Nunito-OFL.txt` files must remain
  beside the fonts in distributed source copies.

Both font files are vendored from the official Google Fonts repository. Do not
replace them with system fonts: mobile system-font availability and metrics are
not consistent across devices.

The bundled DynaPuff file has no Cyrillic glyphs, and none are coming: it is the final 2.000
release (the upstream repository was archived in 2023), and Google Fonts tags it `cyrillic-ext`
only because it contains ₴. Its theme variations therefore include heavier Nunito fallback
variations: 900 for the 700-weight DynaPuff roles (titles, sections, buttons, counters), 800 for
the 600-weight HUD role and 700 for the 500-weight default label font. A per-glyph fallback alone
would still draw digits, `×` and Latin text in DynaPuff beside Nunito letters (`УРОВЕНЬ 12`), so
while Russian or Ukrainian is active `scripts/localization/locale_typography.gd` makes that
Nunito variation the primary face of every DynaPuff role. Whole display strings then use one
face, at the same scene sizes, colors and outlines. Other locales restore DynaPuff; the heavier
Nunito fallbacks remain for Cyrillic display text there, such as native language names.
Characters used as icons are not text, so they must not follow this swap: Nunito would turn
DynaPuff's puffy close `X` into a plain letter and has no `✓` at all. Controls whose text is an
icon character therefore use the `GameGlyphButton`, `GameGlyphLabel` or `GameGlyphBoldLabel`
roles. Their DynaPuff variations have no Cyrillic fallback, which is what
`locale_typography.gd` keys the swap on, so they render identically in every locale. Give any new
icon-character control one of these roles. The level HUD pause `II` already uses its own
scene-local DynaPuff variation.
The Russian localization test verifies the entire Russian alphabet, digits and × against the
display face itself, including Ё/ё, plus each role's face and weight in Russian and English.
The Ukrainian localization test verifies its full alphabet, including Ґ/ґ, Є/є, І/і, Ї/ї,
the typographic apostrophe and the № symbol, the same way.
The Brazilian Portuguese localization test verifies accented vowels, Ç/ç, curly quotation marks
and the ordinal indicator º through the bundled title font; it uses the existing Latin fonts.
The German localization test verifies Ä/ä, Ö/ö, Ü/ü, ß, German quotation marks and × through
the bundled title font. German uses the existing Latin fonts and scene-owned text fitting.
The French localization test checks accented lower/uppercase Latin letters, French quotation
marks, curly apostrophes, the reviewed degree sign in `n°`, and × through the bundled title font.
French uses the existing Latin fonts and scene-owned text fitting; no new font resource is needed.
The Turkish localization test checks Ç/ç, Ğ/ğ, İ/ı, Ö/ö, Ş/ş, Ü/ü, circumflex vowels and every
reviewed non-ASCII character across display, reading, rich-text and editing theme roles using
bundled fonts. Uppercase Turkish copy preserves the distinction between İ and I.

## Theme Roles

Japanese, Korean and Traditional Chinese follow the same split as Arabic. The DynaPuff display
roles (titles, sections, buttons, HUD and counters) fall back to a rounded display face per
script: M PLUS Rounded 1c ExtraBold for Japanese, Jua for Korean and Huninn for Traditional
Chinese. Each display face is a `FontVariation` whose own fallback is the matching-weight Noto
variation, so a glyph it lacks (rare hanzi or Hangul in player names, `₩` in Jua) still renders
from a bundled font. The Nunito reading roles keep Noto directly. All three display faces are
single-weight static files. M PLUS Rounded 1c is already ExtraBold, but Jua and Huninn are
regular weights that drew titles and buttons visibly lighter than the bold Noto they replaced, so
their 700/600/500 display tiers use synthetic `variation_embolden`: 0.4/0.25/0.1 for Jua and
0.5/0.35/0.2 for Huninn. Heavier values (1.0 was tried) fill in dense hanzi such as 闖關 and
繼續 at button sizes. Each face's vertical metrics also differ from Noto's, so every display
variation sets a `baseline_offset` (M PLUS Rounded 1c 0.04, Jua 0.15, Huninn 0.06, as a fraction
of font height). This puts text back at the same height inside buttons and title plates as
before, within about 1.5 px at 720×1280. Re-measure both values from captures if a face is
replaced. Digits, `×` and Latin text in mixed strings continue to use DynaPuff.

| Display face | File | Bytes | SHA-256 | Source |
| --- | --- | --- | --- | --- |
| M PLUS Rounded 1c ExtraBold | `MPLUSRounded1c-ExtraBold.ttf` | 3,628,512 | `8E7C15901DCA87F1451B356DDA594F7D092BA252A5DCC47DA74523A242493C36` | [ofl/mplusrounded1c](https://github.com/google/fonts/tree/main/ofl/mplusrounded1c) |
| Jua | `Jua-Regular.ttf` | 2,119,352 | `769677AEF240BFC3B9965F2B50748075BFF885E6C6992FC591A3FB268279F898` | [ofl/jua](https://github.com/google/fonts/tree/main/ofl/jua) |
| Huninn | `Huninn-Regular.ttf` | 4,683,972 | `1BD770A5FFC0C06723B567686F8B5DB5ABF9AB54227F3BBC4E6FD648F4698805` | [ofl/huninn](https://github.com/google/fonts/tree/main/ofl/huninn) |

The unmodified files were downloaded from the official Google Fonts repository on October 8,
2026. Keep `MPLUSRounded1c-OFL.txt`, `Jua-OFL.txt` and `Huninn-OFL.txt` beside them.
`Jua-OFL.txt` and `Huninn-OFL.txt` are the repository's `OFL.txt` files. The
`ofl/mplusrounded1c` directory carries no `OFL.txt`, so its license file combines the font's
embedded copyright (`Copyright 2016 The Rounded M+ Project Authors.`, name ID 0) and its
embedded SIL Open Font License 1.1 notice (name IDs 13–14) with the standard OFL 1.1 text.
Each display face covers every character its locale's catalog uses at the time of adoption:
362 Japanese, all Hangul syllables of the Korean catalog and 451 Traditional Chinese characters.
Verified October 8, 2026: all 13 localization tests and the locale-switching UI tests pass, and
23 screens (the set in the Japanese QA record) were captured in `ru`, `uk`, `ja`, `ko` and
`zh_Hant` at all five target viewports and compared with captures taken before the change.

Traditional Chinese uses bundled `assets/fonts/NotoSansTC-Variable.ttf` fallback variations
at matching 500/600/700 weights across all reading, rich-text and editing roles, and behind
Huninn in the display roles.
`scripts/localization/locale_typography.gd` moves the Chinese fallbacks (Huninn in display
roles, Noto Sans TC in reading roles) before the Japanese ones while `zh_Hant` is active,
retaining Latin/Cyrillic/Arabic priority and restoring the original order
for other locales. `LocaleManager` applies the order before translating screens on startup
and live language changes. The font remains a fallback in every locale for mixed player names.

The unmodified 11,941,968-byte variable font and its SIL Open Font License were vendored
from the official [Google Fonts Noto Sans TC directory](https://github.com/google/fonts/tree/main/ofl/notosanstc).
Its weight axis covers 100–900. Keep `NotoSansTC-OFL.txt` beside the font. Font SHA-256:
`864727D210D54F2537BBE23B3A839436C3992AF72DE9322AF5270897246BD44F`.
`tests/ui/test_traditional_chinese_localization.gd` checks all reviewed non-ASCII characters
through bundled font inventories and Huninn itself, and verifies Taiwan priority (Huninn for
display roles, Noto Sans TC for reading roles) plus its restoration when switching to Japanese,
independently of system fonts.

Japanese glyphs use bundled `assets/fonts/NotoSansJP-Variable.ttf` fallback variations at
matching 500/600/700 weights in every body, rich-text and editing role, and behind M PLUS
Rounded 1c in the display, button and HUD roles.
They follow the existing Latin, Cyrillic and Arabic faces and precede the Korean fallbacks,
providing Japanese regional glyph forms without relying on desktop or mobile system fonts.
Keep `NotoSansJP-OFL.txt` beside the font. The unmodified 9,589,900-byte variable font and its
SIL Open Font License were downloaded from the official
[Google Fonts Noto Sans JP directory](https://github.com/google/fonts/tree/main/ofl/notosansjp).
Its weight axis covers 100–900. Font SHA-256:
`C2F3B4D463500A2DDCD3849CDED1FCEEB9FD6D1C32E6CBECD568453BA50FC68F`.
`tests/ui/test_japanese_localization.gd` checks all reviewed non-ASCII characters, decomposed
kana, date units and yen symbols through every theme role's bundled font inventory, that M PLUS
Rounded 1c itself draws every kana, kanji and full-width mark, and which face draws Japanese in
each role.

Korean glyphs use bundled `assets/fonts/NotoSansKR-Variable.ttf` fallback variations at matching
500/600/700 weights throughout the body, rich-text and editing roles, and behind Jua in the
display, button and HUD roles.
They follow the existing Latin, Cyrillic, Arabic and Japanese fonts in each fallback chain, supporting
mixed player names and native language labels in every locale. Keep `NotoSansKR-OFL.txt`
beside the font. The unmodified variable font (10,414,588 bytes) and its SIL Open Font License
were downloaded from the official [Google Fonts Noto Sans KR directory](https://github.com/google/fonts/tree/main/ofl/notosanskr).
Its weight axis covers 100–900; no system font is required for Hangul. Font SHA-256:
`194018E6B2B293A7964F037B25C0249CE1418BC9AB3C971060A03AA57861E252`.
`tests/ui/test_korean_localization.gd` checks every reviewed non-ASCII character and decomposed
Hangul through all theme roles' bundled font inventories, independently of desktop fallbacks,
that Jua itself draws every Hangul syllable in the catalog, and which face draws Hangul in each
role.

Arabic glyphs use bundled Baloo Bhaijaan 2 for display/button/HUD roles at matching 500/600/700
weights and Noto Sans Arabic for reading/editing roles at 600/700 weights. The theme keeps the
existing Latin and Cyrillic primary faces. Arabic fallbacks are always available, including when
English is active. Keep `BalooBhaijaan2-OFL.txt` and `NotoSansArabic-OFL.txt` beside the fonts.
Arabic joining/mark features are retained; scene font fitting measures the complete shaped text.

The vendored files came from Google Fonts' `ofl/baloobhaijaan2` and `ofl/notosansarabic` directories.
Pinned SHA-256 checksums:

- `BalooBhaijaan2-Variable.ttf`: `3E9F07FBC796C0DDCB3E6E0AA26F9C86741D9F5B7F5CB72F4ED3C06E55A19336`
- `NotoSansArabic-Variable.ttf`: `63111B5B2E074DD48CC67692E0A2726D86EE94C1C37FE8598257B7B4E87E869E`

`tests/ui/test_arabic_localization.gd` checks Arabic letters and combining marks through all theme
roles using bundled character inventories, independently of desktop system fallback.

Use the global theme instead of attaching font files directly to individual
scenes.

| Theme type variation | Owner type | Intended use |
| --- | --- | --- |
| `GameTitleLabel` | `Label` | Screen, popup, and result titles |
| `GameSectionLabel` | `Label` | Section and card headings |
| `GameHudLabel` | `Label` | Short medium-emphasis gameplay labels |
| `GameNumberLabel` | `Label` | Timers, counters, prices, ranks, scores, and progress |
| `GameBodyLabel` | `Label` | Instructions, status text, and player names |
| `GameSmallLabel` | `Label` | Navigation and compact option captions |
| `GameBodyButton` | `Button` | Buttons whose text is a readable sentence or question rather than a short action, such as the Support FAQ question rows (bold Nunito) |
| `GameBodyRichText` | `RichTextLabel` | Multi-line reading text, such as the Support FAQ answers (semibold Nunito, bold Nunito for `[b]`) |
| `GameGlyphButton` | `Button` | Buttons whose text is an icon character: close `X`, back/pager `<` `>`, Main Menu settings `II` (bold DynaPuff in every locale) |
| `GameGlyphLabel` | `Label` | Icon-character labels at the default label weight: selection `✓` marks and the FAQ `+`/`−` chevron (medium DynaPuff in every locale) |
| `GameGlyphBoldLabel` | `Label` | Bold icon-character labels, such as the Main Menu coin shortcut's `+` badge (bold DynaPuff in every locale) |

Ordinary `Button` text uses bold DynaPuff. `LineEdit` and `TextEdit` use semibold
Nunito. Labels without a variation inherit medium DynaPuff. A `RichTextLabel`
without a variation also inherits medium DynaPuff, so long-form text should set
`GameBodyRichText`. Title and section
roles use DynaPuff's 92% width axis so long uppercase headings retain comfortable
side margins without scene-specific font substitutions. Other DynaPuff roles use
the natural 100% width.

DynaPuff's contextual alternates (`calt`) deliberately move successive letters
to different vertical positions. They are disabled for buttons and the
`GameTitleLabel`, `GameSectionLabel`, `GameHudLabel`, and `GameNumberLabel`
roles so functional, high-emphasis text keeps an even baseline. Unclassified
labels inherit medium DynaPuff with the playful contextual alternates intact.

Existing scene-owned font sizes, colors, outlines, and shadows remain local to
the component because they depend on the background and control art.

## Gameplay Modal And Result Title Roles (UI-003)

The playable level defines its own title-size roles in `scripts/gameplay_ui_theme.gd`
(`GameplayUITheme`), separate from the menu system's 48/40 screen-title sizing, because gameplay
modals and terminal results use a denser layout at a different scale:

- Modal-title regular (44px): the default role for gameplay modal titles, such as `PAUSE`.
- Modal-title long (40px): for titles needing to fit more text at the same panel width, such as
  `LEAVING THE LEVEL`. `scenes/ui/gameplay_modal_shell.tscn`'s `configure(title, is_long_title)`
  selects between the two.
- Terminal-result hero (58px): the single role shared by Completion's `GREAT JOB!` and Failure's
  `LEVEL FAILED`, unifying what were previously two unrelated sizes (58/70). Scales responsively
  with `GameplayUITheme.get_result_title_scale()` (the same formula Completion already used, so its
  on-screen size is unchanged).

All three still use `GameTitleLabel` and remain uppercase per the casing rule below.

## Locked-Shelf Label Roles

`scenes/ui/shelf_lock_overlay.tscn` keeps both pieces of lock copy as live labels so they remain
crisp over the raster chains and lock:

- `AdLabel` uses `GameNumberLabel` for the decorative uppercase `AD` plate. It does not represent an
  ad action and has no input or gameplay behavior.
- `RemainingLabel` uses `GameNumberLabel` for the cleared-triples countdown. It reuses
  `style_box_gameplay_count_badge.tres` and the same `GameplayUITheme.COUNT_BADGE_*` font-fitting
  contract as `AbilityBar/UsesLabel`, including long numeric values.

The decorative `AD` keeps lock-specific colors and outline; the remaining-clear counter deliberately
uses the project-wide orange-red/gold gameplay count role instead of lock-specific styling.

## Reward-Star Variants

Three reward-star raster sizes are used across the project, each a documented named role -- do not
introduce a fourth asset for a new reward-star use; reuse the variant whose role matches:

- **Compact** -- `assets/ui/reward_star_34_glossy_b.png` (34px): the level HUD's star-total pill
  icon (`scenes/ui/level_top_hud.tscn`) and Leaderboard row reward icons.
- **Regular** -- `assets/ui/reward_star_84x84.png` (84px): the reward-chest flight
  (`scenes/ui/main_menu_reward_star_flyer.tscn`), the Main Menu reward chest widgets, and the
  in-level Leave Confirmation's lost-star slot.
- **Hero** -- `assets/ui/reward_star.png` (large): the Level Completion screen's centerpiece art.

## Casing And Numeric Style

- Screen titles, popup titles, result titles, section headings, and special
  level-launch labels use uppercase text.
- Action buttons, tabs, navigation captions, settings options, instructions,
  statuses, and player names remain title or sentence case.
- Use the multiplication sign `×`, never the letter `x`, for reward and combo
  multipliers.
- Use `GameNumberLabel` for changing values. It requests tabular figures where
  the font supports them and uses DynaPuff's bold weight for a solid silhouette.
- Preserve store-provided localized price strings rather than rebuilding price
  punctuation or currency placement in the UI.

Dynamic titles must apply the same rules as authored scene text. For example,
Shop bundle titles and purchase-dialog titles are uppercased when bound, while
player names preserve user-entered casing.

## Responsive Verification

Typography changes must be checked at the project target resolutions:

- 540×960
- 720×1280
- 1080×1920
- 1080×2400
- a squarer tablet-like viewport such as 1200×1600

Pay particular attention to `LEADERBOARD`, `LEAVING THE LEVEL`, Shop bundle
titles, regional prices, long player names, the main level button, and compact
ability timers. Prefer container expansion or responsive font sizing over
condensing individual strings.
