# Typography

The game uses a project-wide typography theme at
`assets/themes/game_typography.tres`, configured through
`gui/theme/custom` in `project.godot`.

## Font Families

- `assets/fonts/Fredoka-Variable.ttf` is the primary game face. It is used for
  controls, screen and modal titles, section headings, HUD labels, counters,
  prices, ranks, scores, and other short high-emphasis text.
- `assets/fonts/Nunito-Variable.ttf` is the supporting reading face. It is used
  for instructions, statuses, player names, navigation captions, small settings
  captions, and editable text.
- The corresponding `Fredoka-OFL.txt` and `Nunito-OFL.txt` files must remain
  beside the fonts in distributed source copies.

Both font files are vendored from the official Google Fonts repository. Do not
replace them with system fonts: mobile system-font availability and metrics are
not consistent across devices.

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

Ordinary `Button` text uses bold Fredoka. `LineEdit` and `TextEdit` use semibold
Nunito. Labels without a variation inherit medium Fredoka.

Existing scene-owned font sizes, colors, outlines, and shadows remain local to
the component because they depend on the background and control art.

## Casing And Numeric Style

- Screen titles, popup titles, result titles, section headings, and special
  level-launch labels use uppercase text.
- Action buttons, tabs, navigation captions, settings options, instructions,
  statuses, and player names remain title or sentence case.
- Use the multiplication sign `×`, never the letter `x`, for reward and combo
  multipliers.
- Use `GameNumberLabel` for changing values. It requests tabular figures where
  the font supports them and uses Fredoka's bold weight for a solid silhouette.
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
