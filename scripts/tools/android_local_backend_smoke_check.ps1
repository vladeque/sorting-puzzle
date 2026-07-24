<#
.SYNOPSIS
  GAME-003 emulator smoke check for the local-backend Android debug export.

.DESCRIPTION
  Waits for a running Android emulator/device, sets up `adb reverse tcp:8080 tcp:8080`, installs
  and launches the debug APK produced by the "Android (Local Backend Debug)" export preset, then
  tails logcat for the non-secret [LocalBackendDebug] diagnostic lines emitted by
  scripts/save/local_backend_debug_bootstrap.gd. Exits 0 once a local override, a health-probe
  HTTP 200 response, and secure_bridge_available=true have all been observed, or exits 1 after
  the timeout.

  This does not start the backend itself (see the sibling sorting-puzzle-backend repository's local
  bootstrap docs for that) and does not automate PostgreSQL/API/emulator provisioning end-to-end;
  that full orchestration is GAME-010. This script covers the Android-side half of GAME-003's own
  "adb reverse setup and an emulator smoke command/checklist" deliverable.

.PARAMETER ApkPath
  Path to the exported debug APK. Defaults to the preset's export_path under build\android\.

.PARAMETER PackageName
  Must match package/unique_name in export_presets.cfg.

.PARAMETER AdbPath
  Optional explicit path to adb.exe. When omitted, the script checks PATH, ANDROID_SDK_ROOT,
  ANDROID_HOME, and the standard per-user Windows Android SDK location.

.PARAMETER TimeoutSeconds
  How long to wait for the expected logcat lines before failing. Defaults to 60.
#>
param(
    [string]$ApkPath = "build\android\sorting_puzzle_local_backend_debug.apk",
    [string]$PackageName = "com.sortingpuzzle.game",
    [string]$AdbPath = "",
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"

function Resolve-AdbPath {
    if (-not [string]::IsNullOrWhiteSpace($AdbPath)) {
        if (Test-Path -LiteralPath $AdbPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $AdbPath).Path
        }
        throw "adb was not found at the explicit path: $AdbPath"
    }

    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $adbCommand) {
        return $adbCommand.Source
    }

    $sdkRoots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($sdkRoot in $sdkRoots) {
        $candidate = Join-Path $sdkRoot "platform-tools\adb.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "adb was not found. Install Android platform-tools or pass -AdbPath explicitly."
}

$adb = Resolve-AdbPath

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    Write-Error "Debug APK not found at $ApkPath. Export it first in Godot with the 'Android (Local Backend Debug)' preset (Project > Export > Export Debug)."
    exit 1
}

Write-Host "Waiting for an adb device..."
& $adb wait-for-device
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "adb reverse tcp:8080 tcp:8080"
& $adb reverse tcp:8080 tcp:8080
if ($LASTEXITCODE -ne 0) {
    Write-Warning "adb reverse failed. Falling back to the documented http://10.0.2.2:8080 route -- update local/backend_debug.cfg accordingly (see local/backend_debug.example.cfg)."
}

Write-Host "Installing $ApkPath"
& $adb install -r $ApkPath
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Clearing logcat and launching $PackageName"
& $adb logcat -c
& $adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to launch $PackageName."
    exit 1
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$sawOverride = $false
$sawHealthyResponse = $false
$sawBridge = $false

while ((Get-Date) -lt $deadline) {
    $matches = & $adb logcat -d 2>$null | Select-String "\[LocalBackendDebug\]"
    foreach ($entry in $matches) {
        if ($entry -match "local override active") { $sawOverride = $true }
        if ($entry -match "health probe result=0 response_code=200") {
            $sawHealthyResponse = $true
        }
        if ($entry -match "secure_bridge_available=true") { $sawBridge = $true }
    }
    if ($sawOverride -and $sawHealthyResponse -and $sawBridge) {
        Write-Host "Smoke check passed: local override active, /health/live returned 200, secure bridge available."
        exit 0
    }
    Start-Sleep -Seconds 2
}

Write-Error "Timed out after ${TimeoutSeconds}s waiting for [LocalBackendDebug] diagnostics (override=$sawOverride healthy_response=$sawHealthyResponse bridge=$sawBridge). Run 'adb logcat | Select-String LocalBackendDebug' manually to inspect."
exit 1
