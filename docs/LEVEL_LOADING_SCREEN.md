# Level Loading Screen

The loading screen appears whenever the player starts a level from either Main Menu and whenever a
failed level is retried. It is a persistent scene transition, so it remains visible while the old
scene is removed and the fresh `level.tscn` instance enters the tree.

## Ownership

- `LevelTransition`, registered as an autoload in `project.godot`, is the only level-entry owner.
  `scripts/level_transition.gd` rejects duplicate launches, starts the threaded `level.tscn` load,
  keeps the overlay above both scenes, transfers launch properties, and activates gameplay after
  the reveal finishes.
- `scenes/ui/level_loading_screen.tscn` owns the visual hierarchy and input-blocking surface.
  `scripts/level_loading_screen.gd` owns the closing iris, mascot entrance, animated loading dots,
  minimum visible time, and opening reveal.
- `assets/shaders/loading_iris.gdshader` draws the responsive Golden Sunset burgundy-to-plum
  gradient, warm amber center glow, subtle dot pattern, and circular mask.
  `assets/ui/loading/loading_cat.png` is the selected transparent mascot artwork.
- `scripts/production_main_menu.gd`, `scripts/main_menu.gd`, and `scripts/level.gd::_restart_level()`
  send requests to `LevelTransition`; they do not instantiate `level.tscn` themselves.

## Gameplay boundary

`LevelTransition` calls `prepare_for_loading_transition()` before the new level enters the tree.
While that gate is active, `scripts/level.gd` blocks gameplay input and frame updates, pauses moving
shelf rows, and postpones initial shelf resolution. After the loading screen has completely
revealed the board, `activate_after_loading_transition()` resumes moving rows and performs the
initial match/completion checks. The level timer still follows its existing rule of starting only
after the player's first meaningful action.

The sequence lasts at least 1.43 seconds: a 0.24 second iris close, a 0.28 second mascot entrance,
enough hold time to reach 0.95 seconds from launch, a 0.16 second mascot exit, and a 0.32 second
iris reveal. A slow scene load extends the fully covered portion instead of exposing an incomplete
board.

## Verification

Render the static full-cover state at the required responsive resolutions:

```powershell
& .\scripts\tools\capture_ui.ps1 `
  -Scene scenes/ui/level_loading_screen.tscn `
  -Name level_loading_screen `
  -Setup scripts/tools/captures/level_loading_screen_setup.gd
```

Exercise both retry paths and the production-menu launch path:

```powershell
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_level_failure_screen.gd
& .\scripts\tools\run_isolated_godot_test.ps1 -Script tests/ui/test_out_of_lives_menu.gd
```
