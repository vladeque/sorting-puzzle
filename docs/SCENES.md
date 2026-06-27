# Scenes

This file maps scenes to their responsibilities, scripts, important nodes, and runtime relationships.

## `scenes/main_menu.tscn`

Root:
- `MainMenu` (`Control`)

Script:
- `scripts/main_menu.gd`

Purpose:
- Main project entry scene.
- Displays title and level selector.
- Provides a `%LevelGrid` container that the script fills with level buttons.

Important nodes:
- `Background`: fullscreen menu background.
- `ShelfBackdrop` and `ShelfLip`: static decorative shelf art.
- `Content`: centered menu layout container.
- `Content/LevelGrid`: unique-name `GridContainer` used by the script.

Depends on:
- `level.tscn` through `scripts/main_menu.gd`.

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

Important nodes:
- `Background`: fullscreen gameplay background.
- `Shelves`: parent for generated shelf nodes.
- `DragLayer`: temporary parent for dragged items, drawn above shelves.
- `UI`: `CanvasLayer` for gameplay labels, ability buttons, and overlays.
- `UI/TimerLabel`: countdown display.
- `UI/LevelLabel`: current level display.
- `UI/PauseMenuButton`: circular top-right button that pauses the active level and opens the pause menu overlay.
- `UI/AbilityBar/HBoxContainer/HammerButton`: hammer ability button.
- `UI/AbilityBar/HBoxContainer/ShuffleButton`: shuffle ability button.
- `UI/AbilityBar/HBoxContainer/HighlightButton`: highlight ability button.
- `UI/FailurePanel`: shown when time runs out.
- `UI/CompletionPanel`: shown after all items clear.
- `UI/PauseMenuOverlay`: `scenes/pause_menu.tscn` instance used for the modal pause menu.

Runtime-created nodes:
- `ShelfXX`: `scenes/shelf.tscn` instances generated under `Shelves`.
- `ShelfLayerXX`: generated back layers for hidden or upcoming item rows.
- `ShelfItem` instances from `scenes/item.tscn`.
- `ItemPlaceAudio` and `TripleClearAudio`: `AudioStreamPlayer` nodes created by `scripts/level.gd`.

Depends on:
- `scenes/shelf.tscn`
- `scenes/item.tscn`
- `scenes/pause_menu.tscn`
- `assets/audio/*.wav`
- `configs/item_sprites.json`
- `configs/levels/level_*.json`
- `assets/abilities/*.png`

Do not use for:
- Static shelf cell visuals. Put those in `scenes/shelf.tscn`.

## `scenes/pause_menu.tscn`

Root:
- `PauseMenuOverlay` (`ColorRect`)

Script:
- `scripts/pause_menu.gd`

Purpose:
- Reusable in-level pause menu overlay instanced by `level.tscn`.
- Owns the modal dimmer, popup panel styling, `Pause` title, music / sound-effects / vibration icon buttons, their crossed-out toggle visuals, and `Leave` / `Continue` buttons.

Important nodes:
- `PauseMenuPanel`: centered popup panel.
- `PauseMenuPanel/MarginContainer/VBoxContainer/TitleLabel`: pause menu title.
- `PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/MusicButton`: circular music toggle placeholder.
- `PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/SoundEffectsButton`: circular sound effects toggle that disables or enables gameplay sound effects.
- `PauseMenuPanel/MarginContainer/VBoxContainer/IconRow/VibrationButton`: circular phone vibration toggle placeholder.
- `PauseMenuPanel/MarginContainer/VBoxContainer/ButtonRow/LeaveButton`: button wired by `scripts/level.gd` to return to the main menu.
- `PauseMenuPanel/MarginContainer/VBoxContainer/ButtonRow/ContinueButton`: button wired by `scripts/level.gd` to resume the level.

Depends on:
- `assets/ui/icon_music.png`, `assets/ui/icon_sound_effects.png`, and `assets/ui/icon_vibration.png` for settings icon art.
- `assets/ui/pause_menu_option_a_sheet.png` and `assets/ui/pause_menu_option_b_sheet.png` are archived alternate visual directions for these icons.
- Runtime button wiring from `scripts/level.gd`.
- Local settings-button visual toggles from `scripts/pause_menu.gd`.

Do not use for:
- Timer state, scene navigation, gameplay pause rules, music playback, or actual vibration settings. Those stay in owning runtime systems.

## `scenes/shelf.tscn`

Root:
- `Shelf` (`Node2D`)

Purpose:
- Reusable shelf cell instantiated by `scripts/level.gd` for each configured shelf.
- Owns the visible shelf back wall, floor, frame, front slot positions, and item snap markers.
- Uses wide, slightly shorter cell bounds so three generated shelves span most of the 720 px gameplay viewport with compact row spacing.

Important nodes:
- `BackWall`: muted panel behind shelf items.
- `Ceiling`, `LeftWall`, and `RightWall`: wooden cell frame.
- `FloorSurface` and `FloorFrontLip`: wooden floor where items visually rest.
- `FloorGrain*`: subtle line details on the floor.
- `Slot01`, `Slot02`, `Slot03`: front slots used by runtime movement and matching logic, positioned so default item silhouettes sit next to each other.
- `SlotXX/ItemSlotXX`: marker positions used by `scripts/level.gd` for snap targeting.

Depends on:
- Runtime item spawning from `scripts/level.gd`.

Do not use for:
- Level timing, matching, input handling, or back-layer promotion. Those stay in `scripts/level.gd`.

## `scenes/item.tscn`

Root:
- `Item` (`Area2D`)

Script:
- `scripts/item.gd`

Purpose:
- Reusable sortable item scene.
- Gives each spawned item a collision area and sprite.
- Uses a default visual scale and hitbox sized for the wide shelf cell slots.

Important nodes:
- `OutlineSprite`: hidden sprite used by `ShelfItem` to draw alpha-based highlight borders.
- `Sprite2D`: main item sprite; texture and visual scale are controlled by `ShelfItem`.
- `CollisionShape2D`: rectangular item hitbox used by runtime interaction.

Depends on:
- Texture assignment from `scripts/level.gd`.
- Highlight outline color and width assignment from `scripts/level.gd`.
- Item IDs defined in `configs/item_sprites.json`.

Do not use for:
- Shelf placement rules, matching logic, or level progression.
