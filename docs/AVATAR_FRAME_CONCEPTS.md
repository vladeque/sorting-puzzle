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

After a design is selected, its production pass needs a transparent 256x256 canvas, an inner aperture
aligned with the existing frames, and visual verification in the profile editor and other profile
views. Achievement criteria and unlock flow are separate design decisions.
