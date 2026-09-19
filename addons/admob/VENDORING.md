# Poing Godot AdMob vendoring record

This directory contains the core Android/iOS bridge from Poing Studios Godot AdMob Plugin
**v5.1.0**, licensed under the adjacent MIT `LICENSE`.

Pinned upstream release inputs:

| Artifact | SHA-256 |
| --- | --- |
| `poing-godot-admob-v5.1.0.zip` | `8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f` |
| `android-template-v4.6.2.zip` | `f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee` |
| `ios-template-v4.6.2.zip` | `3ec209252ee75b43df81e651e2ca8b51df0967465c82e12bfdd3b16a57bce6c1` |

Included scope:

- upstream GDScript API, UMP API, export hooks, project-setting helpers, and version metadata;
- Android core/ads AARs and iOS core/ads XCFrameworks for Godot 4.6.2;
- upstream GDScript mediation value types referenced by the core request API, but no native
  mediation-network package;
- the upstream license and small plugin icon.

Project-local changes:

- `admob.gd` is a minimal entry point that registers settings and export hooks only;
- the upstream network downloader, editor menu, samples, C# surface, and AI skill files are omitted;
- upstream visual desktop mocks are omitted and `MobileSingletonPlugin.gd` returns `null` outside
  Android/iOS; game tests use `scripts/ads/mock_ad_provider.gd` instead;
- the vendored settings service/exporter fallbacks and all project settings default native
  integration flags and application IDs to disabled/empty.

The inspected Android package declares Google Mobile Ads SDK `1.4.0` and AndroidX ConstraintLayout
`2.2.0`. The inspected iOS package pins Google Mobile Ads `13.9.0`, UMP `3.1.0`, and iOS 15.

For an update, re-download the exact release artifacts in a controlled dependency step, verify all
hashes before extraction, reapply and review the local changes above, regenerate platform dependency
manifests, and repeat license, vulnerability, export, manifest, and physical-device tests. Never use
the upstream automatic downloader for a production or CI build.
