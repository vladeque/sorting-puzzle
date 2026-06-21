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

### Scripts

Scripts should be kept focused and attached only to the scene or node that owns the related behavior.

Avoid placing unrelated game logic into a single large script.

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

## Agent Behavior

### Clarifications

If any requirement, expected behavior, or implementation detail is unclear or ambiguous, do not make assumptions. Ask a clarifying question before proceeding.

When asking for clarification, briefly explain what is unclear and identify the specific decision or information needed.

