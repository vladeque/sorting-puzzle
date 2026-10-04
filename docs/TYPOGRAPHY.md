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

The bundled DynaPuff file has no Cyrillic glyphs. Its theme variations therefore
include Nunito fallback variations at matching 500, 600 and 700 weights. Russian and Ukrainian
titles, buttons, HUD text and counters retain the scene's sizing, color and outline
while using bundled Cyrillic glyphs; Latin characters continue to use DynaPuff.
The Russian localization test verifies the entire Russian alphabet against the
effective title font, including Ё/ё.
The Ukrainian localization test verifies its full alphabet, including Ґ/ґ, Є/є, І/і, Ї/ї,
the typographic apostrophe and the № symbol against the same effective title font.

## Theme Roles

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
