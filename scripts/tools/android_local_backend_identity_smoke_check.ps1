<#
.SYNOPSIS
  GAME-004 emulator smoke check: real guest bootstrap and restart-session-resumption proof.

.DESCRIPTION
  Builds on the GAME-003 connectivity/bridge smoke check (android_local_backend_smoke_check.ps1)
  and additionally proves the identity acceptance criteria from GAME-004:

    - A new installation completes the signed guest challenge/bootstrap flow and receives a real
      guest player, device, and session (namespace_kind flips from installation_guest to player).
    - The installation guest namespace is rebound exactly once (the player id does not change).
    - Killing and restarting the app resumes the same player session without creating a second
      guest (same player_id and device_id are observed after a force-stop and relaunch).

  It reads the `[LocalBackendDebug] identity diagnostics: ...` line emitted by
  scripts/save/local_backend_debug_bootstrap.gd (GAME-004), which surfaces only non-secret,
  already-opaque identifiers (player id, device id, generation, retry/error state, correlation
  id) -- never tokens, signatures, or key material.

  Malformed, expired, replayed, and binding-mismatched bootstrap/session responses are covered by
  the automated headless suite at tests/save/test_game_004.gd, not by this device script; forcing
  those exact conditions from a live backend is impractical to script deterministically.

.PARAMETER ApkPath
  Path to the exported debug APK. Defaults to the preset's export_path under build\android\.

.PARAMETER PackageName
  Must match package/unique_name in export_presets.cfg.

.PARAMETER AdbPath
  Optional explicit path to adb.exe. When omitted, checks PATH, ANDROID_SDK_ROOT, ANDROID_HOME,
  and the standard per-user Windows Android SDK location.

.PARAMETER HostPort
  Host API port mapped to emulator tcp:8080. Defaults to 8080.

.PARAMETER TimeoutSeconds
  How long to wait for the initial connectivity/bridge/bootstrap diagnostics. Defaults to 90.

.PARAMETER RestartTimeoutSeconds
  How long to wait, after force-stop and relaunch, for the resumed identity diagnostics line.
  Defaults to 60.

.PARAMETER ClearAppData
  Clears this package's emulator data after installation so the gate starts from a clean Android
  installation namespace. GAME-010 uses this switch with its disposable database.

.PARAMETER ResultPath
  Optional JSON result path. Contains only opaque player/device identifiers and non-secret
  diagnostics needed by the GAME-010 backend assertions.
#>
param(
    [string]$ApkPath = "build\android\sorting_puzzle_local_backend_debug.apk",
    [string]$PackageName = "com.vbrus.sortingpuzzle",
    [string]$AdbPath = "",
    [int]$HostPort = 8080,
    [int]$TimeoutSeconds = 90,
    [int]$RestartTimeoutSeconds = 60,
    [switch]$ClearAppData,
    [string]$ResultPath = ""
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

function Read-IdentityDiagnostics {
    param([string]$AdbExe)

    $logcat = & $AdbExe logcat -d 2>$null
    $matchLine = $logcat |
        Select-String "\[LocalBackendDebug\] identity diagnostics: namespace_kind=(\S+) player_id=(\S*) device_id=(\S+) generation=(\d+) guest_phase=(\S*) guest_retry_attempt=(\d+) guest_terminal_error=(\S*) retry_attempt=(\d+) terminal_error=(\S*) last_correlation_id=(\S*)" |
        Select-Object -Last 1
    if ($null -eq $matchLine) {
        return $null
    }
    $groups = $matchLine.Matches[0].Groups
    return [pscustomobject]@{
        NamespaceKind      = $groups[1].Value
        PlayerId           = $groups[2].Value
        DeviceId           = $groups[3].Value
        Generation         = [int]$groups[4].Value
        GuestPhase         = $groups[5].Value
        GuestRetryAttempt  = [int]$groups[6].Value
        GuestTerminalError = $groups[7].Value
        RetryAttempt       = [int]$groups[8].Value
        TerminalError      = $groups[9].Value
        LastCorrelationId  = $groups[10].Value
    }
}

$adb = Resolve-AdbPath

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    Write-Error "Debug APK not found at $ApkPath. Export it first in Godot with the 'Android (Local Backend Debug)' preset (Project > Export > Export Debug)."
    exit 1
}

Write-Host "Waiting for an adb device..."
& $adb wait-for-device
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "adb reverse tcp:8080 tcp:$HostPort"
& $adb reverse tcp:8080 "tcp:$HostPort"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "adb reverse failed. Falling back to the documented http://10.0.2.2:8080 route -- update local/backend_debug.cfg accordingly (see local/backend_debug.example.cfg)."
}

Write-Host "Installing $ApkPath"
& $adb install -r $ApkPath
if ($LASTEXITCODE -ne 0) { exit 1 }

if ($ClearAppData) {
    Write-Host "Clearing app data for clean-start verification"
    & $adb shell pm clear $PackageName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clear app data for $PackageName."
        exit 1
    }
}

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
$firstIdentity = $null

while ((Get-Date) -lt $deadline) {
    $logcat = & $adb logcat -d 2>$null
    $provenanceFailure = $logcat |
        Select-String "Backend synchronization disabled \[content_manifest\." |
        Select-Object -First 1
    if ($null -ne $provenanceFailure) {
        Write-Error "The packaged content manifest was rejected: $($provenanceFailure.Line)"
        exit 1
    }
    foreach ($entry in ($logcat | Select-String "\[LocalBackendDebug\]")) {
        if ($entry -match "local override active") { $sawOverride = $true }
        if ($entry -match "health probe result=0 response_code=200") { $sawHealthyResponse = $true }
        if ($entry -match "secure_bridge_available=true") { $sawBridge = $true }
    }

    $identity = Read-IdentityDiagnostics -AdbExe $adb
    if ($null -ne $identity -and $identity.NamespaceKind -eq "player" -and $identity.PlayerId -ne "") {
        $firstIdentity = $identity
    }

    if ($sawOverride -and $sawHealthyResponse -and $sawBridge -and $null -ne $firstIdentity) {
        break
    }
    Start-Sleep -Seconds 2
}

if (-not ($sawOverride -and $sawHealthyResponse -and $sawBridge)) {
    Write-Error "Timed out after ${TimeoutSeconds}s waiting for connectivity diagnostics (override=$sawOverride healthy_response=$sawHealthyResponse bridge=$sawBridge)."
    exit 1
}
if ($null -eq $firstIdentity) {
    Write-Error "Timed out after ${TimeoutSeconds}s waiting for a real guest bootstrap. Run 'adb logcat | Select-String LocalBackendDebug' manually to inspect."
    exit 1
}

Write-Host "Guest bootstrap observed: player_id=$($firstIdentity.PlayerId) device_id=$($firstIdentity.DeviceId) generation=$($firstIdentity.Generation)"

Write-Host "Force-stopping $PackageName to simulate app kill"
& $adb shell am force-stop $PackageName
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Clearing logcat and relaunching $PackageName"
& $adb logcat -c
& $adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to relaunch $PackageName."
    exit 1
}

$restartDeadline = (Get-Date).AddSeconds($RestartTimeoutSeconds)
$resumedIdentity = $null
while ((Get-Date) -lt $restartDeadline) {
    $identity = Read-IdentityDiagnostics -AdbExe $adb
    if ($null -ne $identity -and $identity.NamespaceKind -eq "player" -and $identity.PlayerId -ne "") {
        $resumedIdentity = $identity
        break
    }
    Start-Sleep -Seconds 2
}

if ($null -eq $resumedIdentity) {
    Write-Error "Timed out after ${RestartTimeoutSeconds}s waiting for identity diagnostics after restart."
    exit 1
}

if ($resumedIdentity.PlayerId -ne $firstIdentity.PlayerId) {
    Write-Error "Restart created a different player (before=$($firstIdentity.PlayerId) after=$($resumedIdentity.PlayerId)) -- a second guest was registered instead of resuming the session."
    exit 1
}
if ($resumedIdentity.DeviceId -ne $firstIdentity.DeviceId) {
    Write-Error "Restart reported a different device id (before=$($firstIdentity.DeviceId) after=$($resumedIdentity.DeviceId))."
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    $resultDirectory = Split-Path -Parent $ResultPath
    if (-not [string]::IsNullOrWhiteSpace($resultDirectory)) {
        New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null
    }
    @{
        schema = "sorting-puzzle-game010-android-result/1"
        player_id = $firstIdentity.PlayerId
        device_id = $firstIdentity.DeviceId
        generation = $resumedIdentity.Generation
        last_correlation_id = $resumedIdentity.LastCorrelationId
    } | ConvertTo-Json | Set-Content -LiteralPath $ResultPath -Encoding utf8
}

Write-Host "Smoke check passed: real guest bootstrap observed (player_id=$($firstIdentity.PlayerId)), and killing/restarting the app resumed the same player session without creating a second guest."
exit 0
