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

After a design is selected, its production pass needs a transparent 256x256 canvas, an inner aperture
aligned with the existing frames, and visual verification in the profile editor and other profile
views. Achievement criteria and unlock flow are separate design decisions.
