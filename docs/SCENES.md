# Scenes

This file maps scenes to their responsibilities, scripts, important nodes, and runtime relationships.

## `scenes/main_menu.tscn`

Root:
- `ProductionMainMenu` (`Control`)

Script:
- `scripts/production_main_menu.gd`

Purpose:
- Main project entry scene.
- Displays `assets/backgrounds/main_menu.jpeg` as a fullscreen production menu background.
- Provides a top status row for profile, coins, saved campaign lives, and settings.
- Provides a bottom `%LevelButton` labeled with the saved campaign level, such as `Level 1`, or disabled as `No Lives` when lives are empty.
- Starts the saved campaign level when the bottom button is pressed.

Important nodes:
- `Background`: fullscreen `TextureRect` using `assets/backgrounds/main_menu.jpeg`.
- `TopStatusBar`: top-anchored safe-area-aware container for `scenes/ui/main_menu_top_status.tscn`.
- `BottomBar`: bottom-anchored responsive container for the play button.
- `BottomBar/LevelButton`: `scenes/ui/level_button.tscn` instance that launches the saved campaign level.

Depends on:
- `level.tscn` through `scripts/production_main_menu.gd`.
- `PlayerProgress` autoload for the saved campaign level, lives count, and life restore countdown.
- `assets/backgrounds/main_menu.jpeg`.
- `scenes/ui/main_menu_top_status.tscn` for top status icons and labels.
- `scenes/ui/level_button.tscn` for the reusable production level button visuals.

Do not use for:
- Dev/test level selection. Use `scenes/main_menu_testing.tscn`.
- Runtime puzzle rules or shelf state. Put those in `level.tscn` and `scripts/level.gd`.

## `scenes/ui/main_menu_top_status.tscn`

Root:
- `MainMenuTopStatus` (`HBoxContainer`)

Purpose:
- Reusable top status row for the production main menu.
- Displays four non-interactive UI groups from left to right: player profile, gold coins, lives remaining, and settings.
- Provides labels that the owning menu script updates for campaign lives and life restore status.

Important nodes:
- `ProfileWidget`: circular avatar icon.
- `CoinsWidget`: generated gold coin icon, placeholder amount label, and plus badge.
- `LivesWidget`: generated heart icon, current life count label, and `Full` or countdown status label.
- `SettingsWidget`: smaller `PauseMenuButton`-style button with a small alert badge.

Depends on:
- `assets/ui/main_menu_coin.png`.
- `assets/ui/main_menu_lives.png`.
- Owning menu scene for placement and safe-area layout.

Do not use for:
- Player inventory, lives logic, settings behavior, or profile data ownership. The owning menu script writes display values.

## `scenes/ui/level_button.tscn`

Root:
- `LevelButton` (`Button`)

Purpose:
- Reusable production level-entry button.
- Owns the generated glossy green rounded-button texture inspired by the selected generated concept.
- Keeps the button text dynamic through the normal Godot `Button.text` property, so callers can set labels such as `Level 1` or `Complete`.
- Uses `scripts/press_scale_button.gd` so the button scales slightly smaller from its center while a click or touch is held.

Important nodes:
- `LevelButton`: clickable button root with the generated texture style, white outlined text, and dynamic pressed/hover/disabled states.

Depends on:
- `assets/ui/level_button_blank.png`.
- `assets/ui/level_button_blank_red.png`, `assets/ui/level_button_blank_light_blue.png`, and `assets/ui/level_button_blank_yellow_orange.png` are matching alternate color blanks for future button states or variants.
- `scripts/press_scale_button.gd` for the default held-press scale behavior expected by future blank-image buttons.
- Caller scenes or scripts for placement, click wiring, and label updates.

Do not use for:
- Scene navigation, campaign progress lookup, or level launching. Those stay in the owning menu script.

## `scenes/main_menu_testing.tscn`

Root:
- `MainMenu` (`Control`)

Script:
- `scripts/main_menu.gd`

Purpose:
- Preserves the previous testing menu layout.
- Displays title and campaign progress.
- Provides a campaign play button.
- Provides a `%LevelGrid` container that the script fills with isolated dev/test level buttons when dev selection is enabled.

Important nodes:
- `Background`: fullscreen menu background.
- `ShelfBackdrop` and `ShelfLip`: static decorative shelf art.
- `Content`: centered menu layout container.
- `Content/SelectorLabel`: campaign current-level label in normal flow, or dev selector label in dev/test mode.
- `Content/PlayButton`: unique-name button that launches the saved campaign level from the testing menu.
- `Content/LevelGrid`: unique-name `GridContainer` used by the script for dev/test level selection.

Depends on:
- `level.tscn` through `scripts/main_menu.gd`.
- `PlayerProgress` autoload for the saved campaign level and lives gate.

Do not use for:
- Runtime puzzle rules or shelf state. Put those in `level.tscn` and `scripts/level.gd`.

## `level.tscn`

Root:
- `Level` (`Node2D`)

Script:
- `scripts/level.gd`

Purpose:
- Playable puzzle scene.
- Provides stable top-level nodes that `scripts/level.gd` fills and controls at runtime.
- Normal campaign launches save completion when the level clears, then wait on the completion reward overlay's `Next` button before loading the next level; dev/test launches return to their configured menu from that button and do not touch campaign save data.

Important nodes:
- `Background`: fullscreen procedural gameplay backdrop with child nodes for the top HUD strip, simple shop wall, baseboard, and bottom floor band.
- `Background/HudCenterSlot/ComboFill`: rounded green combo-window strip that shrinks as the time left to extend the combo runs out.
- `Background/HudCenterSlot/ComboLabel`: hidden until the player clears a triple, then shows the active combo count.
- `Shelves`: parent for generated shelf nodes and optional moving shelf row containers; `scripts/level.gd` scales and centers it in the available play area for the current viewport size.
- `DragLayer`: temporary parent for dragged items, drawn above shelves.
- `UI`: `CanvasLayer` for gameplay labels, ability buttons, and overlays; top-level controls are anchored or positioned at runtime for non-720x1280 portrait screens.
- `UI/TimerLabel`: countdown display.
- `UI/LevelLabel`: current level display.
- `UI/StarCounterLabel`: top HUD star total panel, positioned between the timer area and pause button, with a small `reward_star.png` icon and numeric `CountLabel`.
- `UI/PauseMenuButton`: circular top-right button that pauses the active level and opens the pause menu overlay.
- `UI/AbilityBar/HBoxContainer/HammerButton`: hammer ability button.
- `UI/AbilityBar/HBoxContainer/ShuffleButton`: shuffle ability button.
- `UI/AbilityBar/HBoxContainer/HighlightButton`: highlight ability button.
- `UI/AbilityBar/HBoxContainer/HighlightButton/TimerLabel`: active highlight ability countdown.
- `UI/FailurePanel`: shown when time runs out.
- `UI/CompletionPanel`: shown after all items clear; contains the `Great job!` title, generated reward star image, earned star count label, and green `Next` button.
- `UI/CompletionPanel/NextButton`: green blank-image button with `scripts/press_scale_button.gd` so it visually shrinks while held.
- `UI/PauseMenuOverlay`: `scenes/pause_menu.tscn` instance used for the modal pause menu.
- `UI/LeaveConfirmationOverlay`: `scenes/leave_confirmation_menu.tscn` instance shown after the pause menu's Leave button, before spending a campaign life and returning to the menu.

Runtime-created nodes:
- `ShelfXX`: `scenes/shelf.tscn` instances generated under `Shelves`.
- `MovingShelfRowXX`: `scenes/moving_shelf_row.tscn` instances generated under `Shelves` when a level config or layout template defines moving rows.
- `ShelfLayerXX`: generated back layers for hidden or upcoming item rows.
- `ShelfItem` instances from `scenes/item.tscn`.
- `ItemPlaceAudio` and `TripleClearAudio`: `AudioStreamPlayer` nodes created by `scripts/level.gd`.

Depends on:
- `scenes/shelf.tscn`
- `scenes/moving_shelf_row.tscn`
- `scenes/layouts/layout_*.tscn`
- `scenes/item.tscn`
- `scenes/pause_menu.tscn`
- `scenes/leave_confirmation_menu.tscn`
- `assets/audio/*.wav`
- `configs/item_sprites.json`
- `configs/levels/level_*.json`
- `assets/abilities/*.png`

Do not use for:
- Static shelf cell visuals. Put those in `scenes/shelf.tscn`.

## `scenes/layouts/layout_*.tscn`

Root:
- `Node2D`

Purpose:
- Editor-authored shelf placement templates for `layout_preset` values in level JSON.
- Keep each preset's shelf markers easy to nudge, align, and review visually in Godot.
- Own static shelf marker positions and optional moving-row marker positions.
- Static shelf markers are grouped into horizontal rows by runtime marker position so `scripts/level.gd` can assign left/middle/right shelf visuals from the actual authored layout.

Important nodes:
- `ShelfXX`: `Marker2D` nodes consumed in scene order by `scripts/level.gd`; their positions become runtime `scenes/shelf.tscn` positions.
- `MovingRowXX`: optional `Node2D` nodes with `scripts/shelf_layout_row.gd`; their positions become the visible moving-row center.

Existing presets:
- `scenes/layouts/layout_grid_2x3.tscn`
- `scenes/layouts/layout_grid_3x3.tscn`
- `scenes/layouts/layout_grid_3x4.tscn`
- `scenes/layouts/layout_grid_3x5.tscn`
- `scenes/layouts/layout_grid_4x3.tscn`
- `scenes/layouts/layout_grid_3x3_moving_5_bottom.tscn`
- `scenes/layouts/layout_staggered_5_4_5.tscn`
- `scenes/layouts/layout_staggered_4_5_4.tscn`

Depends on:
- Runtime shelf instantiation from `scripts/level.gd`.
- `scripts/shelf_layout_row.gd` for moving-row template metadata.

Do not use for:
- Shelf contents, item layers, locks, matching rules, or runtime state. Those stay in level JSON and `scripts/level.gd`.

## `scenes/moving_shelf_row.tscn`

Root:
- `MovingShelfRow` (`Control`)

Script:
- `scripts/moving_shelf_row.gd`

Purpose:
- Runtime row container for shelf rows with horizontal wrap motion.
- Clips child shelf rendering to the configured visible shelf window.
- Keeps moving-row bounds separate from individual shelf cell visuals.

Important properties:
- `clip_contents`: enabled so off-window shelves are hidden by the row rectangle.
- `mouse_filter`: ignored so gameplay input remains owned by `scripts/level.gd`.

Runtime-created nodes:
- `ShelfXX`: `scenes/shelf.tscn` instances parented under the row and registered with `MovingShelfRow.add_shelf()`.

Depends on:
- Runtime configuration from `scripts/level.gd`.
- Child shelf scenes from `scenes/shelf.tscn`.

Do not use for:
- Puzzle rules, item movement rules, matching, abilities, or lock progression. Those stay in `scripts/level.gd`.

## `scenes/pause_menu.tscn`

Root:
- `PauseMenuOverlay` (`ColorRect`)

Script:
- `scripts/pause_menu.gd`

Purpose:
- Reusable in-level pause menu overlay instanced by `level.tscn`.
- Owns the modal dimmer, warm outer popup panel, cream inner settings panel, `Pause` title, protruding top-right red close button, music / sound-effects / vibration rectangular icon slots, their crossed-out toggle visuals, and `Leave` / `Continue` buttons.
- Uses full-rect overlay anchors and a centered popup panel so it tracks the stretched viewport.

Important nodes:
- `PauseMenuPanel`: centered popup panel.
- `PauseMenuPanel/TitleLabel`: pause menu title.
- `PauseMenuPanel/CloseButton`: protruding top-right red close button wired by `scripts/level.gd` to resume the level.
- `PauseMenuPanel/InnerPanel`: cream settings area inside the warm outer popup.
- `PauseMenuPanel/InnerPanel/IconRow/MusicOption/MusicButton`: rectangular music toggle slot.
- `PauseMenuPanel/InnerPanel/IconRow/SoundEffectsOption/SoundEffectsButton`: rectangular sound effects toggle slot that disables or enables gameplay sound effects.
- `PauseMenuPanel/InnerPanel/IconRow/VibrationOption/VibrationButton`: rectangular phone vibration toggle slot.
- `PauseMenuPanel/ButtonRow/LeaveButton`: red image button wired by `scripts/level.gd` to open leave confirmation.
- `PauseMenuPanel/ButtonRow/ContinueButton`: green image button wired by `scripts/level.gd` to resume the level.
- The bottom red and green image buttons use `scripts/press_scale_button.gd` so they visually shrink while held.

Depends on:
- `assets/ui/icon_music.png`, `assets/ui/icon_sound_effects.png`, and `assets/ui/icon_vibration.png` for settings icon art.
- `assets/ui/level_button_blank_red.png` and `assets/ui/level_button_blank.png` for pause action buttons.
- `scripts/press_scale_button.gd` for the default held-press shrink on the bottom image buttons.
- `assets/ui/pause_menu_option_a_sheet.png` and `assets/ui/pause_menu_option_b_sheet.png` are archived alternate visual directions for these icons.
- Runtime button wiring from `scripts/level.gd`.
- Local settings-button visual toggles from `scripts/pause_menu.gd`.

Do not use for:
- Timer state, scene navigation, gameplay pause rules, music playback, or actual vibration settings. Those stay in owning runtime systems.

## `scenes/leave_confirmation_menu.tscn`

Root:
- `LeaveConfirmationOverlay` (`ColorRect`)

Purpose:
- Reusable in-level leave confirmation overlay instanced by `level.tscn`.
- Reuses the pause popup panel treatment with a dimmed fullscreen modal background, warm outer area, cream inner loss area, and an explicitly top-right anchored protruding red close button.
- Shows a `Leaving the Level` title, warning text, crossed-out life and star reward icons, readable bottom-right count badges layered above the icons, and red `Leave` / green `Continue` image buttons.

Important nodes:
- `ConfirmationPanel`: centered popup panel.
- `ConfirmationPanel/TitleLabel`: leave confirmation title.
- `ConfirmationPanel/CloseButton`: protruding top-right red close button wired by `scripts/level.gd` to resume the level.
- `ConfirmationPanel/InnerPanel`: cream content area with warning copy and lost-reward icons.
- `ConfirmationPanel/InnerPanel/MessageLabel`: warning copy shown above the lost-reward icons.
- `ConfirmationPanel/InnerPanel/LossRow/LifeLoss`: rectangular crossed-out life slot with a bottom-right static count of `1`.
- `ConfirmationPanel/InnerPanel/LossRow/StarLoss`: rectangular crossed-out star slot.
- `ConfirmationPanel/InnerPanel/LossRow/StarLoss/CountLabel`: bottom-right current run star count written by `scripts/level.gd`.
- `ConfirmationPanel/ButtonRow/ConfirmLeaveButton`: red image button that confirms leaving.
- `ConfirmationPanel/ButtonRow/ContinueButton`: green image button that resumes the level.
- The bottom red and green image buttons use `scripts/press_scale_button.gd` so they visually shrink while held.

Depends on:
- `assets/ui/main_menu_lives.png`.
- `assets/ui/reward_star.png`.
- `assets/ui/level_button_blank_red.png`.
- `assets/ui/level_button_blank.png`.
- `scripts/press_scale_button.gd` for the default held-press shrink on the bottom image buttons.
- Runtime button wiring and star-count updates from `scripts/level.gd`.

Do not use for:
- Spending lives, scene navigation, or pause state ownership. Those stay in `scripts/level.gd`.

## `scenes/shelf.tscn`

Root:
- `Shelf` (`Node2D`)

Script:
- `scripts/shelf.gd`

Purpose:
- Reusable shelf cell instantiated by `scripts/level.gd` for each configured shelf.
- Owns the visible shelf back wall, floor, frame, front slot positions, and item snap markers.
- Owns generated back-layer slot layout and preview styling defaults through `scripts/shelf.gd`.
- Owns soft internal left/top wall shadows, the diagonal bottom cast shadow, the hidden top ceiling cap, and the right-column cast shadow toggled by `scripts/level.gd`.
- Uses opaque pre-blended shadow colors so overlapping shadow polygons do not compound into darker patches.
- Owns the hidden locked-shelf overlay visuals shown by `scripts/level.gd` when a level config gates the shelf behind cleared triples.
- Uses wide, slightly shorter cell bounds so three generated shelves span most of the 720 px gameplay viewport with compact row spacing.
- Runtime shelf instances are scaled slightly by `scripts/level.gd`, with layout template markers and moving-row windows authored to match the scaled cell footprint.
- Can be switched by `scripts/level.gd` to a `floor_only` visual variant for moving rows by hiding wall and ceiling nodes at runtime.
- Can be switched by `scripts/level.gd` to `left`, `middle`, or `right` row-placement visuals for static shelves. Moving-row shelves currently stay on the neutral `middle` row-placement visual.

Important nodes:
- `BackWall`: muted panel behind shelf items.
- `BackWallTopShade`: soft interior wall shadow layer behind items.
- `PlacementVisuals`: editable role-specific shelf art groups toggled by `scripts/shelf.gd`.
- `PlacementVisuals/Left`: left shelf role visuals. Contains `BackWallLeftShade`, `LeftWall`, `RightWall`, and the left-specific `TopCeilingCap`.
- `PlacementVisuals/Middle`: middle shelf role visuals. Contains row divider art and the middle-specific `TopCeilingCap`.
- `PlacementVisuals/Right`: right shelf role visuals. Contains right edge art and the right-specific `TopCeilingCap`.
- `Ceiling`: shared wooden top frame. Placement-specific `TopCeilingCap` nodes are shown at runtime only for top shelves.
- `Shadow` and `RightColumnShadow`: solid-color perspective cast shadows, shown at runtime for full shelf visuals and drawn below shelf bodies, items, and generated back-layer item previews so they remain visible only on exposed wall/background areas.
- `FloorSurface` and `FloorFrontLip`: wooden floor where items visually rest.
- `FloorGrain*`: subtle line details on the floor; generated back-layer item previews draw above the floor and grain, while active front items draw above back-layer previews.
- `LockedOverlay`: hidden lock overlay used for triple-gated shelves.
- `LockedOverlay/LockSprite`: transparent lock image from `assets/ui/lock_shelf_cutout.png`, scaled to fit the shelf overlay.
- `LockedOverlay/RemainingLabel`: runtime-updated count of triples still needed to unlock the shelf, optically centered over the lock's clear center panel.
- `Slot01`, `Slot02`, `Slot03`: front slots used by runtime movement and matching logic, positioned so default item silhouettes sit next to each other.
- `SlotXX/ItemSlotXX`: marker positions used by `scripts/level.gd` for snap targeting.

Depends on:
- `scripts/shelf.gd` for generated back-layer preview setup.
- `assets/ui/lock_shelf_cutout.png` for locked shelf overlay art with a clear center panel for the count label.
- Runtime item spawning from `scripts/level.gd`.

Do not use for:
- Level timing, matching, input handling, lock progression, item identity assignment, or back-layer promotion timing. Those stay in `scripts/level.gd`.

## `scenes/item.tscn`

Root:
- `Item` (`Area2D`)

Script:
- `scripts/item.gd`

Purpose:
- Reusable sortable item scene.
- Gives each spawned item a collision area and sprite.
- Uses a default visual scale and hitbox sized for the wide shelf cell slots.
- In generated shelves, the owning shelf cell scale enlarges the item sprite, shadow, and hit area together with the shelf visuals.

Important nodes:
- `Shadow`: solid-color up-right cast shadow behind front-layer item sprites; generated back-layer previews and active player drags disable it.
- `OutlineSprite`: hidden sprite used by `ShelfItem` to draw alpha-based highlight borders.
- `Sprite2D`: main item sprite; texture and visual scale are controlled by `ShelfItem`.
- `CollisionShape2D`: rectangular item hitbox used by runtime interaction.

Depends on:
- Texture assignment from `scripts/level.gd`.
- Highlight outline color and width assignment from `scripts/level.gd`.
- Item IDs defined in `configs/item_sprites.json`.

Do not use for:
- Shelf placement rules, matching logic, or level progression.
