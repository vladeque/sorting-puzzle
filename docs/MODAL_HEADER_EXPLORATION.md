# Modal header design exploration

The current gameplay modal shell (`scenes/ui/gameplay_modal_shell.tscn`) has a flat terracotta
top with the title directly on the panel. The supplied game screenshots use a protruding
banner or plaque to create a stronger silhouette and a clearer title hierarchy. This study
reuses the real Pause scene so the cream content region, buttons, spacing, typography, and
close target can be judged against the proposed headers.

## Concepts

| Option | Header | Benefit | Watch point |
| --- | --- | --- | --- |
| 1. Folded ribbon | Glossy blue band, folded ends, small fasteners | Strongest festive silhouette; closest to the first two references | Wide shape may compete with long translated titles |
| 2. Product tag | Amber tag hung from a blue loop, with small corner folds | Ties the modal to sorting physical goods; warm palette suits the current body | Narrow central title area; needs a compact long-title variant |
| 3. Shelf marquee | Blue enamel sign above a gold shelf lip | Connects to the game's shelves and offers a consistent frame for many modal types | More structural and less playful than the ribbon |

**Suggested direction:** Option 3 as the reusable system for Pause, Leave Confirmation, and
Ability Purchase; option 2 could become a distinct reward or offer title treatment. The
close control remains a full 72px target in all studies. The proposals use vector drawing
and the project's current font and modal body; there are no new raster assets.

## Prototype

- Open `scenes/testing/modal_header_study.tscn` in Godot; press `1`, `2`, or `3` to switch.
- `scripts/testing/modal_header_study.gd` composes the production Pause scene and places the
  vector study header beneath its real title and close control.
- `scripts/testing/modal_header_study_art.gd` owns the three disposable vector illustrations.
- These prototype files are not loaded by gameplay. Production shell changes should be made
  only after a direction is chosen.

Capture each option with `scripts/tools/capture_ui.ps1` and inspect the rendered contact
sheets for 540x960, 720x1280, 1080x1920, 1080x2400, and 1200x1600.

## Render review

All three studies were captured at all five requested sizes; each capture reported an exact
render size and no failures. The title and 72px close action remain visible and separate at the
narrowest 540x960 size. The ribbon ends stay inside the screen; the tag and marquee stay centered.
At 1200x1600, the study selects a 900x1200 logical canvas so the squarer comparison stays
proportional instead of stretching the round close action into an oval. The production project
still uses its own `keep_width` stretch policy. The previews only cover the short `PAUSE` title;
long translated titles need a separate fit pass before one of these treatments enters the shared
shell.
