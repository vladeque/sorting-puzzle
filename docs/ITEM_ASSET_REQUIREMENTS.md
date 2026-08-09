# Item Asset Requirements

This document is the authoritative specification for sortable item textures under
`assets/items/`. It applies to newly created items and to existing item art that is being
reworked.

## Final File Contract

Every item texture must:

- Be a PNG with an exact physical canvas size of `128x128` pixels.
- Use sRGB/RGBA color with a real alpha channel.
- Have a fully transparent background outside the item. Do not bake in a solid background,
  checkerboard, shelf, or chroma-key color.
- Contain one complete item silhouette with no cropping at the canvas edges.
- Avoid a baked contact or cast shadow outside the item silhouette. `scenes/item.tscn` owns the
  runtime ground shadow, and it is generated from this texture's own alpha, so any baked shadow
  would be projected a second time as part of the silhouette.
- Prefer source art generated or authored at `256x256` or larger and downsampled to the final
  `128x128` canvas. Never upscale a smaller source; upscaling does not restore lost detail.

When art must be resized or its alpha cleaned up, use ImageMagick as required by `AGENTS.md`.
Do not use Pillow unless one of the documented exceptions applies.

## Visible Artwork Bounds

Canvas size and visible item size are separate requirements. A `128x128` file whose item fills
the entire canvas will be too large for the shelf slots.

Measure the visible artwork using the bounding box of pixels whose alpha is greater than
approximately `5%`. Low-alpha antialiasing fringe outside this box is acceptable.

The visible artwork must:

- Fit within a maximum box of approximately `66x110` pixels.
- Preserve its original aspect ratio. Never stretch width and height independently.
- Be centered horizontally around canvas X=`64`, with a tolerance of about `1` pixel.
- End at canvas Y=`120`, with a tolerance of about `1` pixel. With the top-left coordinate system,
  this means `visible_y + visible_height = 120`. The runtime ground shadow anchors on this line
  (`ShelfItem.SHADOW_GROUND_TEXELS`), so art that ends short of it will appear to hover.
- Leave approximately `8` transparent pixels below the visible item.
- Remain bottom-aligned when it is shorter than `110` pixels. Do not vertically center short jars,
  tubs, boxes, or other squat items, because they will appear to float above the shelf.
- Use less than the maximum width or height when the item's natural silhouette calls for it.
  Narrow bottles should remain narrower than jars or cereal boxes.

At the default `ShelfItem` visual scale of `0.92`, the maximum visible bounds render at roughly
`61x101` logical pixels. This fits inside the shared `74x112` item hit area while leaving enough
horizontal separation for three shelf slots. The scale is twice the source canvas' halving from
`256x256`, so on-screen item size is unchanged from the earlier art generation.

## Visual Style

New items should:

- Match the bright, polished, 3D-looking casual mobile-game style of the existing catalog.
- Use a clear silhouette that remains recognizable at the in-game shelf scale.
- Use clean antialiased edges without light or dark color halos in transparent pixels.
- Keep outline weight, lighting, saturation, and detail density broadly consistent with nearby
  catalog items.
- Use a front-facing or gently elevated product view rather than an extreme perspective.
- Avoid relying on small text for identification.
- Avoid real-world trademarks, branded packaging, and copyrighted characters unless the project
  has explicit rights to use them.

When generating new art, also follow the asset-review workflow in `AGENTS.md`: agree on an art
direction, review candidates, and select an asset before implementation.

## Naming And Catalog Registration

- Use a stable lowercase snake-case item ID, such as `jam_jar_blueberry`.
- Put the shared product family first and the distinguishing flavor, color, or form afterward:
  `soda_can_lime`, `soda_can_strawberry`, and `juice_box_grape_tall`. Prefer meaningful suffixes
  over numbers; use a numeric suffix only when the artwork has no durable descriptive distinction.
- Name the texture `assets/items/item_<item_id>.png`.
- Do not rename or reuse an ID after it has appeared in a level or save/protocol data unless an
  explicit migration updates every authored/runtime reference in the same change.
- Add exactly one matching entry to `configs/item_sprites.json`.
- Set `texture` to `res://assets/items/item_<item_id>.png`.
- Use an existing category where appropriate: `drink`, `snack`, `everyday`, `toy`, or `figurine`.
  Adding a category is allowed only when the catalog/tooling contract is updated with it.
- Schedule the item exactly once in `configs/item_progression.json`.
- Rematerialize runtime levels when a progression change should affect an existing campaign level.

## Godot Import Contract

Use Godot `4.6.2` to import the final PNG. Commit the generated `.png.import` sidecar with the
texture.

Item texture imports should:

- Keep `process/size_limit=0`; the PNG is already authored at its final `128x128` size and Godot
  must not reduce it further.
- Keep mipmap generation disabled for these 2D shelf sprites.
- Preserve the alpha channel.
- Keep alpha-border fixing enabled to avoid dark or bright fringes during filtering.
- Avoid premultiplied alpha unless the complete item-rendering pipeline is intentionally changed.

Do not hand-edit generated import UIDs or `.godot/imported/*.ctex` cache files. Force a reimport
through Godot when the editor shows stale texture information:

```powershell
godot --headless --path . --import
```

## ImageMagick Normalization

The normalization operation must keep the final canvas at `128x128`; trimming is only an
intermediate measurement/processing step.

Use this sequence:

1. Ensure the source has a clean alpha channel.
2. Trim temporary transparent padding around the silhouette.
3. Resize the trimmed silhouette proportionally to fit within `66x110`.
4. Measure the resized width and height.
5. Place it on a new transparent `128x128` canvas at:
   - `x = floor((128 - visible_width) / 2)`
   - `y = 120 - visible_height`
6. Recheck the final alpha bounds after resampling.

Use the verified ImageMagick executable when `magick` is not on `PATH`:

```powershell
$magick = 'C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe'
```

Lanczos is the preferred filter for proportional resizing of these raster assets:

```powershell
& $magick input.png -alpha on -trim +repage -filter Lanczos -resize '66x110>' trimmed.png
```

Compose the processed silhouette onto a new transparent canvas using the calculated `x` and `y`
instead of vertically centering it.

## Validation

Check canvas size, channels, and alpha with ImageMagick:

```powershell
& $magick identify -format '%f canvas=%wx%h channels=%[channels] opaque=%[opaque]\n' item.png
```

Expected:

- `canvas=128x128`
- RGBA/sRGBA channels
- `opaque=False`

Check the meaningful alpha bounds:

```powershell
& $magick item.png -alpha extract -threshold 5% -trim `
  -format 'visible=%wx%h offset=%X,%Y\n' info:
```

Confirm that:

- Visible width is at most about `66`.
- Visible height is at most about `110`.
- The horizontal center is approximately X=`64`.
- `offset_y + visible_height` is approximately `120`.

Then:

1. Visually compare the item beside a tall bottle/can and a short jar/tub in a shelf.
2. Confirm no item overlaps a neighboring slot.
3. Confirm every item's visible bottom rests on the same shelf line.
4. Confirm outlines and the runtime contact shadow still look correct.
5. Run the Godot catalog texture-loading check:

   ```powershell
   & .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/gameplay/test_item_progression.gd
   ```

6. Run the progression tests:

   ```powershell
   py -m unittest tests.tools.test_level_item_progression
   ```

7. If progression or templates changed, verify materialized levels:

   ```powershell
   py scripts/tools/materialize_level_templates.py --check
   ```

Do not commit unrelated generated level changes merely to make the materialization check clean.
Resolve or preserve intentional authored changes separately.
