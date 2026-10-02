# iOS secure-store plugin

This source builds an iOS static library/xcframework and `.gdip` plugin that registers the
`SortingPuzzleSecureStoreBridge` singleton.

`SortingPuzzleSecureStore.swift` keeps the P-256 private key and player-session JSON in Keychain
with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. The bridge signs the protocol-v2 domain
plus operation hash with ECDSA/SHA-256, signs raw UTF-8 guest-registration proof payloads, and
exports only the DER SubjectPublicKeyInfo public key.

Build both device and simulator archives with Xcode using the Godot 4.6.2 export-template headers,
combine them as `SortingPuzzleSecureStore.xcframework`, and copy the xcframework plus
`SortingPuzzleSecureStore.gdip` under `ios/plugins/SortingPuzzleSecureStore/`.

For GAME-012 account deletion, `destroy_installation_key(installation_id)` deletes that
installation's Keychain signing key and, when it matches, the stored installation id. It is
idempotent, and returns `false` only for a Keychain failure. Other players' session items stay.
The Swift, header, and binding changes were written on Windows and have not been compiled: build
both archives with Xcode and confirm the packaged library exports `destroy_installation_key` before
an iOS release.

Device verification must cover process death/reboot, background/resume after first unlock,
Keychain accessibility, signature verification against the registered public key, account A/B
session isolation, the chosen uninstall/reinstall Keychain policy, and key removal by
`destroy_installation_key()` that survives process death before the next launch.
