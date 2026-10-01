# Premium Avatar Frame Concepts

The current selectable frame catalog is `configs/profile_frames.json`. Its nine production textures
are 256x256 transparent PNGs with a shared avatar opening. The premium concepts in
`assets/ui/avatar_frames/candidates/` are **review images only**: 1254x1254 opaque RGB PNGs on a
dark charcoal backdrop. The directory contains `.gdignore` so Godot does not import them as runtime
assets. They are not listed in the catalog and have no achievement unlock behavior.

The generated art brief asked for one front-facing circular frame in the game's glossy, rounded
mobile-UI style, a clear center for an avatar, bold details visible at 92 pixels, and an opaque dark
charcoal backdrop. The generated backgrounds have subtle shading despite the flat-color request.
No transparency conversion, 256x256 normalization, or aperture alignment has been applied.

| Direction | Candidate | Distinguishing prompt |
| --- | --- | --- |
| Champion Laurel | `champion_laurel_01.png` | Gold medal ring, paired lower laurel leaves, five-point star crest. |
| Champion Laurel | `champion_laurel_02.png` | Platinum and gold ring, silver laurel clusters, small crown crest. |
| Champion Laurel | `champion_laurel_03.png` | Emerald enamel, gold half-wreath, sunburst medal crest. |
| Starfall | `starfall_01.png` | Midnight-blue and silver ring with constellation details and stars. |
| Starfall | `starfall_02.png` | Violet and teal aurora enamel with a crescent and large star glints. |
| Starfall | `starfall_03.png` | Cobalt and gold ring with orbit arcs and a compass-star crest. |
| Crystal Collector | `crystal_collector_01.png` | Rose gold, violet enamel, amethyst gems. |
| Crystal Collector | `crystal_collector_02.png` | Platinum and aqua enamel with outward turquoise crystal clusters. |
| Crystal Collector | `crystal_collector_03.png` | Gold and opalescent enamel with large pastel gems. |
| Flame Mastery | `flame_mastery_01.png` | Ruby red and gold ring with a flame crest and small flame inlays. |
| Flame Mastery | `flame_mastery_02.png` | Graphite and copper ring with molten channels and an orange flame emblem. |
| Flame Mastery | `flame_mastery_03.png` | Scarlet and rose gold ring with broad phoenix-like feather flames. |

`contact_sheet.png` presents all twelve at 240 pixels per candidate. `thumbnail_sheet.png` presents
the same order at 92 pixels, matching the minimum size of `ProfileAvatarView` in the profile scene.
Rows are Champion Laurel, Starfall, Crystal Collector, and Flame Mastery; columns are variants 01,
02, and 03.

## Shape-only premium exploration

These three additional opaque concepts were prompted to signal premium status entirely through the
continuous ring's silhouette, materials, color, and highlights. The prompt explicitly excluded
stars, gems, crowns, leaves, wings, flames, other attached objects, symbols, and text.

| Candidate | Distinguishing prompt |
| --- | --- |
| `premium_shape_01.png` | Rounded twelve-sided onyx silhouette, broad lacquered band, stepped champagne-gold bevels. |
| `premium_shape_02.png` | Flowing, softly undulating ribbon band in iridescent violet, indigo, and teal with a platinum edge. |
| `premium_shape_03.png` | Broad scalloped platinum contour, cobalt-blue inset band, satin and glossy metal surfaces. |

`shape_only_contact_sheet.png` compares them at 240 pixels, and
`shape_only_thumbnail_sheet.png` compares them at 92 pixels. All three source files are 1254x1254
opaque RGB PNGs. Their centers remain backdrop-colored until a selected design receives a production
transparency and aperture-alignment pass.

Five further shape-only candidates use the same opaque backdrop and object-free brief:

| Candidate | Distinguishing prompt |
| --- | --- |
| `premium_shape_04.png` | Ivory pearl and champagne gold, with twelve broad flutes forming a soft scalloped outer edge. |
| `premium_shape_05.png` | Emerald lacquer and platinum, with six smooth waves and a continuous concave channel. |
| `premium_shape_06.png` | Burgundy lacquer and rose gold, with a rounded-square outer silhouette and circular opening. |
| `premium_shape_07.png` | Graphite titanium and electric cyan, with a sixteen-facet outer contour and bright inner channel. |
| `premium_shape_08.png` | Smoky plum and antique bronze, with three broad swelling arcs forming a soft triangular contour. |

`shape_only_04_08_contact_sheet.png` compares these five at 220 pixels, and
`shape_only_04_08_thumbnail_sheet.png` compares them at 92 pixels. Each source file is a 1254x1254
opaque RGB PNG.

`shape_only_all_contact_sheet.png` and `shape_only_all_thumbnail_sheet.png` compare all eight
shape-only candidates in numeric order, at 220 and 92 pixels respectively.

## Champion Laurel metal variants

`champion_laurel_01.png` was used as the edit reference for two additional variants. The prompt kept
the same centered ring, five-point star, leaf placement, clear circular opening, and opaque charcoal
backdrop while changing the metal color and lighting response:

| Candidate | Material prompt |
| --- | --- |
| `champion_laurel_silver.png` | Cool polished silver and platinum highlights with steel-gray shadows. |
| `champion_laurel_bronze.png` | Warm burnished bronze, copper highlights, and deeper chestnut shadows. |

Both are 1254x1254 opaque RGB PNGs. `champion_laurel_metals_contact_sheet.png` compares gold,
silver, and bronze at 240 pixels; `champion_laurel_metals_thumbnail_sheet.png` compares them at
92 pixels. These remain review concepts outside the runtime frame catalog.

The selected gold, silver, and bronze art has also been prepared as transparent 256x256 textures at
`assets/ui/avatar_frames/frame_weekly_gold.png`, `frame_weekly_silver.png`, and
`frame_weekly_bronze.png`. ImageMagick derived a shared alpha silhouette from the gold reference
and applied it to each metal variant. These production-size textures are registered in
`configs/profile_frames.json` with a minimum earned Weekly competition rank. The backend persists
completed-week awards and rejects unearned selections through both profile update paths.

`scripts/tools/captures/profile_weekly_frame_art_setup.gd` previews the three prepared textures in
the profile editor. Windowed captures showed readable
avatar faces and distinct metals at 540x960, 720x1280, 1080x1920, and 1080x2400. A requested
900x1200 tablet capture rendered at 675x1200 instead and is not a faithful tablet-layout check.

The frame picker always shows all three weekly frames after the nine standard choices. Unearned
frames keep their full-color art with a darkened avatar and a small gold padlock in the middle.
Tapping one leaves the selection unchanged and shows a two-second toast in the middle of the
screen, such as `Finish 1st on the Weekly leaderboard to unlock` (`top 2` for silver, `top 3` for
bronze). A best finish of third unlocks bronze, second unlocks silver and bronze, and first unlocks
all three.
`scripts/tools/captures/profile_weekly_frame_locked_setup.gd` captures the unearned gold tile after
it is tapped, holding the toast open for every resolution. The padlocks and the one-line toast are
legible at 540x960, 720x1280, 1080x1920, and 1080x2400. The requested 1200x1600 tablet capture
rendered at 900x1600, so it does not verify that exact viewport.
`scripts/tools/captures/profile_weekly_frame_unlocked_setup.gd` captures the real first-place
picker state. The three metals are distinct and the selected gold frame remains legible at
540x960, 720x1280, 1080x1920, and 1080x2400. The requested 900x1200 tablet render again came
back as 675x1200, so that viewport remains unverified.

## Combo achievement frames

The selected fire-ring and phoenix images are installed as transparent 256x256 textures at
`assets/ui/avatar_frames/frame_combo_20.png` and `frame_combo_50.png`. The profile picker always
shows both after the weekly frames. A locked tile keeps the frame art visible, darkens the avatar,
and explains the requirement when tapped.

Reaching a ×20 combo in any normal campaign run permanently unlocks the fire ring. Reaching ×50
also unlocks the phoenix. The milestone is saved immediately, including if the run later fails or
the player leaves. `PlayerProgress.record_combo_milestone()` records the signed local journal entry;
the backend verifies its device signature and published level provenance, persists the best tier,
and rejects unearned frame selections. A development-mode level does not grant the achievement.
Windowed captures with `profile_combo_frame_locked_setup.gd` show both tiles and a readable unlock
toast at 540x960, 720x1280, 1080x1920, and 1080x2400. The requested 1200x1600 tablet viewport
rendered at 900x1600, so that exact size remains unverified. The earned ×50 selection was also
checked at 720x1280 with `profile_combo_frame_unlocked_setup.gd`; its avatar and phoenix frame align.

## Shared frame opening

All 19 runtime frame textures use a 256x256 canvas and a common 190 px transparent center circle.
The weekly and combo art is gently expanded outward before the shared opening is cleared, preserving
the metal leaves, flames, and phoenix wings while giving avatars the same minimum visible space as
the standard frames. This is an alpha and geometry adjustment to the existing selected art.

`tests/ui/test_profile_menu.gd` checks every imported texture's canvas and samples the clear center
at 24 angles. Windowed profile captures with `profile_frame_geometry_setup.gd` show a penguin avatar
under all five premium frames at 540x960, 720x1280, 1080x1920, and 1080x2400; a deer with antlers
was also checked at 720x1280. The requested 1200x1600 tablet window rendered at 900x1600 and does
not verify that exact resolution.

## Campaign level milestone frames

Five selected opaque color variants of the same flowing silver-edged ring were converted with
ImageMagick to transparent 256x256 textures. They share the 190 px clear center used by the other
runtime frames. The attachment order sets the milestone mapping:

| Completed level | Texture | Colors |
| --- | --- | --- |
| 20 | `frame_level_20.png` | Violet, blue, and teal |
| 50 | `frame_level_50.png` | Emerald and gold |
| 100 | `frame_level_100.png` | Crimson and amber |
| 200 | `frame_level_200.png` | Sunset coral and violet |
| 500 | `frame_level_500.png` | Obsidian and gold |

The picker shows all five even before they are earned. A locked tile explains the exact level
requirement when tapped. Unlocks use the saved per-level completion map, so frames for levels beyond
the current campaign are ready when those levels are published. The frame ID remains stable across
future level additions.

Windowed profile captures using `profile_level_frame_locked_setup.gd` and
`profile_level_frame_unlocked_setup.gd` show the locked level-500 hint and earned level-20 preview
at 540x960, 720x1280, 1080x1920, and 1080x2400. The art and avatar opening align at those
sizes. The requested 1200x1600 tablet capture rendered at 900x1600, so that exact viewport remains
unverified.
