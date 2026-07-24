# Android secure-store plugin

This Godot Android plugin v2 exposes the `SortingPuzzleSecureStoreBridge` singleton used by
`scripts/save/secure_session_store.gd`.

It stores the installation P-256 private key and the AES-GCM session-encryption key in Android
Keystore. SharedPreferences contains only AES-GCM ciphertext and public installation metadata.
The signing API signs the protocol-v2 domain plus the lowercase operation hash using
`SHA256withECDSA`. `sign_installation_payload()` signs the exact UTF-8
`guest-registration-proof/1` payload without adding that operation domain.

## Building the AAR

Build on a machine with JDK 17 and Android SDK Platform 36 (`compileSdk` 36, `minSdk` 24):

```text
platform/android/secure-store-plugin> ./gradlew :plugin:assembleDebug :plugin:assembleRelease
```

The wrapper (`gradlew`/`gradlew.bat`/`gradle/wrapper/`) is checked in so the build doesn't depend
on a system-wide Gradle install; it downloads Gradle 8.14.3 on first run if it isn't already cached.

This produces two AARs under `plugin/build/outputs/aar/`:

- `SortingPuzzleSecureStoreBridge-debug.aar` -- requests `android.permission.INTERNET` and sets
  `android:usesCleartextTraffic="true"` (from `plugin/src/debug/AndroidManifest.xml`), so a debug
  build can reach a developer-hosted plain-`http://` backend.
- `SortingPuzzleSecureStoreBridge-release.aar` -- built from `plugin/src/main/AndroidManifest.xml`
  only. It requests neither permission, so it stays safe by default even if left enabled for a
  release export.

## Packaging into a Godot export (GAME-003)

The AARs above are consumed by the `addons/sorting_puzzle_secure_store_bridge/` Godot Android
plugin (v2, `EditorExportPlugin`-based -- not the older `.gdap` format), which is enabled under
`Project > Project Settings > Plugins` and referenced from `project.godot`'s `[editor_plugins]`
section. It selects the debug AAR for debug Godot exports and the release AAR otherwise; nothing
needs to be copied into `addons/`.

To produce a backend-enabled debug build:

1. Build both AARs as above.
2. In the Godot editor, `Project > Install Android Build Template` once if you haven't already
   (creates the gitignored `res://android/build` Gradle project Godot's export uses).
3. Confirm `Project > Project Settings > Plugins` shows "Sorting Puzzle Secure Store Bridge"
   enabled.
4. Open `Project > Export`. The committed `export_presets.cfg` defines an
   "Android (Local Backend Debug)" preset with Gradle Build and `arm64-v8a`/`x86_64`
   architectures enabled. It targets Android SDK 35, matching Godot 4.6.2's build template. Leave
   the preset's Internet permission disabled: the debug AAR supplies INTERNET and cleartext HTTP,
   while the release AAR supplies neither.
5. Copy `local/backend_debug.example.cfg` to `local/backend_debug.cfg` (gitignored) and set your
   backend URL and whether sync should be on. See `scripts/save/local_backend_debug_bootstrap.gd`
   and `docs/CONFIGS.md`.
6. `Export Debug` (or one-click deploy) to produce/install the APK. Because the export used the
   debug AAR, `application/config/backend_base_url` and `save_sync_v2_enabled` in the committed
   `project.godot` stay empty/`false` for every other build -- only this local override changes
   behavior, and only in a debug build. The export plugin injects the gitignored override file
   explicitly; a release export does not package it.

## Local host routing

The documented default routes the emulator to your development machine via:

```text
adb reverse tcp:8080 tcp:8080
```

with `local/backend_debug.cfg` pointing at `http://127.0.0.1:8080`. If `adb reverse` isn't
available, use `http://10.0.2.2:8080` as the fallback (the emulator's alias for the host loopback
interface) instead.

## Emulator smoke check

`scripts/tools/android_local_backend_smoke_check.ps1` automates `adb reverse`, install, launch, and
tails `adb logcat` for the non-secret `[LocalBackendDebug]` lines emitted by
`local_backend_debug_bootstrap.gd` (local override applied, `/health/live` probe result, and
`SortingPuzzleSecureStoreBridge` availability) so you don't have to read logcat by hand:

```powershell
.\scripts\tools\android_local_backend_smoke_check.ps1
```

It only covers the Android-side half of the flow (your backend must already be running locally);
the script resolves adb from an explicit `-AdbPath`, PATH, Android SDK environment variables, or
the standard Windows user SDK location. It succeeds only after observing the local override,
`/health/live` HTTP 200, and the secure bridge in logcat. Full PostgreSQL/API/emulator
orchestration is `GAME-010`, not this script.

Verified on 2026-07-24 with Godot 4.6.2, JDK 17, Android SDK Platforms 35/36, and an Android
emulator against the live local backend. An unsigned release verification build also confirmed
that the release artifact contains neither the local config, INTERNET permission, nor cleartext
opt-in; producing a signed release APK still requires the project's release keystore.

## Device verification (release gate)

Package `plugin/build/outputs/aar/SortingPuzzleSecureStoreBridge-release.aar` through the same
`addons/sorting_puzzle_secure_store_bridge/` plugin for release builds; `set_installation_id()`
must still be called before synchronization with the public installation UUID. Device verification
must confirm key persistence across process death/reboot, session ciphertext unreadability outside
the app, signature verification against the registered public key, and expected loss of local keys
after uninstall.
