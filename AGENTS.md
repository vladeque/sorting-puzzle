# AGENTS.md

## Project Overview

This is a 2D casual mobile puzzle game built in Godot. The player sorts 3D-looking items on shelves and matches identical goods to clear them.

The gameplay is built around "triple sorting": the player organizes objects such as snacks, drinks, toys, figurines, and everyday items, usually under time pressure, turning messy shelves into ordered sets.

## Project Structure

```text
/assets   Image and audio files required by the game
/scenes   Godot scene files
/configs  Configuration files
/scripts  GDScript files used by scenes
```

## Related Backend Repository

The authoritative backend repository is expected as a sibling at `../sorting-puzzle-backend`.

Before changing networking, authentication, save synchronization, authoritative progression, economy, inventory, the Shop, purchases, leaderboards, player profiles, or gameplay-proof generation, read the backend repository's `AGENTS.md` and the relevant canonical documents:

- `../sorting-puzzle-backend/BACKEND_REQUIREMENTS.md`
- `../sorting-puzzle-backend/docs/PROTOCOL_BOUNDARY.md`
- `../sorting-puzzle-backend/docs/GAMEPLAY_VALIDATOR_BOUNDARY.md`
- `../sorting-puzzle-backend/docs/IMPLEMENTATION_TICKETS.md`

The backend copy of `BACKEND_REQUIREMENTS.md` is canonical. Any copy retained in this game repository is a client-facing snapshot and must not be edited independently.

For cross-repository work:

- Read and follow the sibling repository's `AGENTS.md` before changing its files.
- Keep game and backend changes in separate commits in their respective repositories.
- Make protocol changes backward-compatible with supported released clients unless an approved migration explicitly says otherwise.
- Do not modify the sibling repository unless the task explicitly includes backend or cross-repository changes.
- Keep shared protocol and gameplay-validator behavior synchronized through versioned schemas and conformance fixtures once those boundaries are approved.

## Godot Version

This project uses Godot 4.6.2. Do not introduce APIs that are only available in incompatible Godot versions.

## Core Patterns

### Scene Structure

The game should be divided into scenes.

There should be:

* One main scene
* Separate scenes for each independent object
* Separate scenes for menus and UI screens

Examples of independent objects may include balls, walls, score displays, upgrades, buttons, and menus.

### Implementation Guidelines

Use 2D scenes and nodes for gameplay, UI, drag-and-drop, slots, shelves, and level logic. The 3D appearance should come from item art, shading, animations, and visual polish rather than real 3D physics or 3D scene structure.

Prefer implementing behavior directly in scene files and node configuration when possible.

Use scripts only when:

* The behavior cannot reasonably be implemented through scene configuration
* The logic is reused across multiple scenes
* The behavior is unique or complex enough to require custom GDScript
* The scene needs runtime state, input handling, scoring logic, spawning logic, or game progression logic

### Scene Extraction Rule

Default to a separate scene when a feature has its own visual hierarchy, lifecycle, inputs, signals, or reusable behavior.

This especially applies to:
* Result screens such as level complete, level failed, rewards, win/loss, and summary screens
* Menus, popups, overlays, confirmation dialogs, settings panels, and modals
* Ability effects, HUD widgets, counters, buttons, item views, shelf rows, and other multi-node UI/gameplay components
* Any functionality currently built as several nodes inside a larger scene or assembled directly in a script

Scripts such as `scripts/level.gd` should orchestrate these components, not own their internal UI structure. For example, a level script may show a completion screen, pass it earned stars, and listen for its `next_pressed` signal, but the completion screen's labels, buttons, art, layout, and button wiring should live in its own scene and focused script.

Only keep functionality embedded in a larger scene when it is a trivial single node with no independent behavior. If a multi-node feature is intentionally not extracted, document why in the relevant docs.

### Scripts

Scripts should be kept focused and attached only to the scene or node that owns the related behavior.

Avoid placing unrelated game logic into a single large script.

Do not build multi-node UI screens or overlays directly inside broad gameplay scripts; create a dedicated scene with a focused owner script and have the gameplay script communicate through exported properties, methods, and signals.

### Git Workflow

After every meaningful batch of changes, commit the work to Git.

Commit messages should clearly describe what changed.

Examples:

```text
Add ball spawning scene
Update wall collision scoring
Add main menu scene
Refactor score counter logic
```

## Development Notes

Keep scenes small, reusable, and easy to test independently.

Prefer clear names for scenes, nodes, scripts, and configuration files.

Avoid hardcoding values in scripts when they should be configurable through exported variables or config files.

After every meaningful code, scene, script, or config change, update the relevant docs in `docs/` so future contributors and AI agents can quickly identify which module, scene, or script owns the changed behavior.

### Responsive UI

All UI and gameplay layouts should support multiple mobile screen resolutions, not only the 720x1280 design resolution.

Use anchors, containers, stretch settings, safe-area padding, and runtime scaling where appropriate so menus, HUD, shelves, items, overlays, touch targets, and drag/drop hit areas remain usable on smaller, taller, wider, and tablet-like portrait screens.

When changing UI or gameplay layout, test representative resolutions such as 540x960, 720x1280, 1080x1920, 1080x2400, and a squarer tablet-like viewport.

### Image Conversion

For generated project assets that need transparency, prefer ImageMagick for chroma-key removal and PNG alpha cleanup.

Do not use Python/Pillow helper scripts for image conversion or alpha cleanup unless:
- ImageMagick is unavailable,
- ImageMagick produces visibly poor results, or
- the user explicitly approves the fallback.

If a Codex skill recommends a different conversion helper, pause and ask before using it.

In this workspace, ImageMagick has been verified at `C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe`; use that full path if plain `magick` is not available in the current shell.

For transparent output, preserve or create alpha explicitly. Example:

```powershell
& 'C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe' input.webp -background none output.png
```

## Agent Behavior

### Clarifications

If any requirement, expected behavior, or implementation detail is unclear or ambiguous, do not make assumptions. Ask a clarifying question before proceeding.

When asking for clarification, briefly explain what is unclear and identify the specific decision or information needed.

### Generated Assets

When a task involves generating images or audio:
1. First present 2-4 art direction options and ask which direction to use.
2. After the user chooses a direction, generate 2-3 candidate assets for review.
3. Do not implement a generated asset until the user selects one candidate, unless the user explicitly asks to proceed with the best candidate.

