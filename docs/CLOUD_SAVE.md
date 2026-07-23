# Cloud Save

> Planned replacement: `GAME-001` in `docs/IMPLEMENTATION_TICKETS.md` introduces always-on local
> persistence plus unrestricted background backend synchronization. The provider selection below
> documents the current legacy implementation until that ticket ships.

This project uses `PlayerProgress` for campaign progression, lives, and ability inventory. `PlayerProgress` delegates persistence to a save provider selected by project settings.

## Provider Selection

Project settings:
- `application/config/save_provider`: `local` or `cloud`.
- `application/config/cloud_save_name`: save slot name passed to platform cloud APIs. Defaults to `player_progress`.
- `application/config/cloud_save_bridge_singleton`: optional override for the native Godot singleton used by `CloudSaveProvider`.

Development builds should use:

```text
application/config/save_provider = "local"
```

Release builds that require cloud-only progress should use:

```text
application/config/save_provider = "cloud"
```

## Local Provider

Files:
- `scripts/save_providers/local_save_provider.gd`

Behavior:
- Reads and writes `user://player_progress.json`.
- Works offline and in the editor.
- Does not survive normal mobile uninstall/reinstall flows.

## Cloud Provider

Files:
- `scripts/save_providers/cloud_save_provider.gd`

Behavior:
- Selects a platform bridge singleton:
  - Android: `GooglePlayGamesSaveBridge`
  - iOS: `GameCenterSaveBridge`
  - Fallback/testing: `CloudSaveBridge`
- Serializes the same progress dictionary as JSON.
- Expects native bridge code to convert the JSON string to the platform API's save payload format.

Native bridge methods:
- `is_signed_in() -> bool` or `is_authenticated() -> bool` is optional.
- `load_save(save_name: String)` is preferred. `load_game()`, `load_progress()`, and `load_data()` are also accepted.
- `save_save(save_name: String, json_payload: String)` is preferred. `save_game()`, `save_progress()`, and `save_data()` are also accepted.

Accepted load return values:
- A progress `Dictionary`.
- A JSON `String`.
- A UTF-8 `PackedByteArray`.
- A wrapper dictionary like `{ "ok": true, "data": "..." }`.

Accepted save return values:
- `true` / `false`.
- A wrapper dictionary like `{ "ok": true }` or `{ "ok": false, "error": "..." }`.
- `null` for native bridges that throw/report errors elsewhere.

## Android

Use Google Play Games Services Saved Games / Snapshots in the native Android bridge. Google documents Saved Games as binary save data plus metadata stored on Google's servers, with offline writes syncing later when connectivity returns.

Required release setup:
- Configure Play Games Services in Google Play Console.
- Enable Saved Games for the game.
- Authenticate the player before the first cloud load/save.
- Add a Godot Android plugin that exposes `GooglePlayGamesSaveBridge`.
- Implement conflict handling in native code or return the resolved payload to Godot.

Official references:
- Google Play Games Services cloud save overview: `https://developer.android.com/games/pgs/savedgames`
- Android saved games / snapshots guide: `https://developer.android.com/games/pgs/android/saved-games`

## iOS

Use Apple GameKit saved games from the native iOS bridge.

Required release setup:
- Enable the Game Center capability for the app.
- Authenticate the local player.
- Add a Godot iOS plugin that exposes `GameCenterSaveBridge`.
- Use GameKit saved-game APIs to read and write the JSON payload.
- Implement conflict handling in native code or return the resolved payload to Godot.

Official references:
- GameKit saved games guide: `https://developer.apple.com/documentation/gamekit/saving-the-player-s-game-data-to-an-icloud-account`
- `GKLocalPlayer` saved-game APIs: `https://developer.apple.com/documentation/gamekit/gklocalplayer`

## Conflict Policy

For the current progression schema:
- Prefer the save with the highest `highest_completed_level`.
- If levels tie, prefer the greater `current_level`.
- For lives, resolve each candidate through its `next_life_restore_unix` timestamp first, then prefer the greater `lives` count. If lives tie and are below full, prefer the earlier `next_life_restore_unix`.
- For non-refilling ability inventory, prefer the lower ability count when resolving conflicts to avoid duplicating spent inventory.

Shop mock purchases currently add paid coins and abilities through a locally persisted transaction-id ledger. This prevents duplicate mock callbacks but is not a production security boundary and can conflict across devices.

Before enabling real-money products, replace local Shop grants with a server-authoritative entitlement flow that verifies platform transactions, records every transaction idempotently, and returns the authoritative balance/inventory state. Cloud-save conflict rules must not be used to reconcile real-money purchases.
