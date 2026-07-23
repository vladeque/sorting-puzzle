# Android secure-store plugin

This Godot Android plugin v2 exposes the `SortingPuzzleSecureStoreBridge` singleton used by
`scripts/save/secure_session_store.gd`.

It stores the installation P-256 private key and the AES-GCM session-encryption key in Android
Keystore. SharedPreferences contains only AES-GCM ciphertext and public installation metadata.
The signing API signs the protocol-v2 domain plus the lowercase operation hash using
`SHA256withECDSA`. `sign_installation_payload()` signs the exact UTF-8
`guest-registration-proof/1` payload without adding that operation domain.

Build on a machine with JDK 17 and Android SDK 36:

```text
./gradlew :plugin:assembleRelease
```

Package `plugin/build/outputs/aar/SortingPuzzleSecureStoreBridge-release.aar` through a Godot
Android `EditorExportPlugin`, enable Gradle Build in the Android export preset, and set
`application/config/secure_storage_bridge_singleton` to `SortingPuzzleSecureStoreBridge`.

Before synchronization, call `set_installation_id()` with the public installation UUID. Device
verification must confirm key persistence across process death/reboot, session ciphertext
unreadability outside the app, signature verification against the registered public key, and
expected loss of local keys after uninstall.
