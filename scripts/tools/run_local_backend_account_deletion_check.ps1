<#
.SYNOPSIS
  GAME-012 account-deletion validation against a disposable local backend.

.DESCRIPTION
  Starts the sibling backend's PostgreSQL service, recreates the fixed disposable database
  `sorting_puzzle_game010` (the only one the backend's disposable-database script manages),
  generates throwaway secrets under `local-secrets/game012`, bootstraps the development
  publication, builds and starts the API, then runs scripts/tools/local_backend_account_deletion_check.mjs
  before and after one worker execution: acceptance, immediate revocation, exact replay of the stored
  202, key reuse, the deleted installation refused before the worker, a fresh key bootstrapping a
  new guest, and worker anonymization.

  `pnpm bootstrap:local` regenerates `configs/backend/content_provenance.json` here and
  `contracts/configuration/v1/development-client-provenance.json` in the backend. Both are restored
  byte-for-byte afterwards, because other sessions commit from these working trees. With -Android,
  the debug APK is exported while the regenerated manifest is in place, so the app can register
  against this publication.

  -KeepRunning leaves the API and database up for manual emulator checks (the APK talks to
  http://127.0.0.1:8080 through `adb reverse`). Run again with -CleanupOnly afterwards.

  -GameRoot runs against another checkout of this repository, for example a clean worktree at HEAD
  next to a backend worktree, when the active checkouts carry uncommitted work that the backend's
  pinned launch candidate rejects. -BackendPath is resolved relative to that game root.

.EXAMPLE
  .\scripts\tools\run_local_backend_account_deletion_check.ps1 -SkipInstall -Android -KeepRunning
  .\scripts\tools\run_local_backend_account_deletion_check.ps1 -CleanupOnly
  .\scripts\tools\run_local_backend_account_deletion_check.ps1 -GameRoot D:\projects\game012-validation\sorting-puzzle
#>
param(
    [string]$GodotPath = "D:\Godot\godot.exe",
    [string]$GameRoot = "",
    [string]$BackendPath = "..\sorting-puzzle-backend",
    [int]$ApiPort = 8080,
    [switch]$SkipInstall,
    [switch]$SkipBuild,
    [switch]$Android,
    [switch]$KeepRunning,
    [switch]$CleanupOnly
)

$ErrorActionPreference = "Stop"
$currentPhase = "prerequisites"
$apiProcess = $null
$snapshots = @()
$debugConfigPath = $null
$debugConfigExisted = $false
$debugConfigBytes = $null
$failed = $false

function Invoke-NativeCommand {
    param([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory)
    $previousLocation = Get-Location
    try {
        Set-Location -LiteralPath $WorkingDirectory
        & $Executable @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Native command exited with code $LASTEXITCODE."
        }
    } finally {
        Set-Location -LiteralPath $previousLocation
    }
}

function Set-Phase {
    param([string]$Name)
    $script:currentPhase = $Name
    Write-Host "[GAME-012] phase=$Name"
}

function Read-DotEnvValue {
    param([string]$Path, [string]$Name, [string]$DefaultValue)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $DefaultValue
    }
    $match = Get-Content -LiteralPath $Path |
        Where-Object { $_ -match "^\s*$([regex]::Escape($Name))=(.*)$" } |
        Select-Object -Last 1
    if ($null -eq $match) {
        return $DefaultValue
    }
    return (($match -split "=", 2)[1]).Trim().Trim('"').Trim("'")
}

if ([string]::IsNullOrEmpty($GameRoot)) {
    $GameRoot = Join-Path $PSScriptRoot "..\.."
}
$gameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
$backendRoot = (Resolve-Path -LiteralPath (Join-Path $gameRoot $BackendPath)).Path
$artifactsRoot = Join-Path $gameRoot "build\game012"
$apiPidPath = Join-Path $artifactsRoot "api.pid"
$secretRoot = [IO.Path]::GetFullPath((Join-Path $backendRoot "local-secrets\game012"))
$pnpmCommand = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
if ($null -eq $pnpmCommand) {
    $pnpmCommand = Get-Command pnpm -ErrorAction Stop
}
$pnpm = $pnpmCommand.Source

$envFile = Join-Path $backendRoot ".env"
$postgresUser = Read-DotEnvValue $envFile "POSTGRES_USER" "sorting_puzzle"
$postgresPassword = Read-DotEnvValue $envFile "POSTGRES_PASSWORD" "local_only_change_me"
$postgresPort = Read-DotEnvValue $envFile "POSTGRES_PORT" "5432"
$encodedUser = [uri]::EscapeDataString($postgresUser)
$encodedPassword = [uri]::EscapeDataString($postgresPassword)
$env:GAME010_ADMIN_DATABASE_URL = "postgresql://${encodedUser}:${encodedPassword}@127.0.0.1:${postgresPort}/postgres"
$env:DATABASE_URL = "postgresql://${encodedUser}:${encodedPassword}@127.0.0.1:${postgresPort}/sorting_puzzle_game010"
$env:SORTING_PUZZLE_SECRET_ROOT = $secretRoot
$env:NODE_ENV = "development"
$env:PORT = "$ApiPort"
$env:REQUIRE_HTTPS = "false"
$env:TRUST_PROXY_HOPS = "0"
$env:OBSERVABILITY_EXPORTER = "none"
$env:DEPLOYMENT_ENVIRONMENT = "development"

function Invoke-Cleanup {
    if (Test-Path -LiteralPath $apiPidPath -PathType Leaf) {
        $apiPid = [int](Get-Content -LiteralPath $apiPidPath)
        Stop-Process -Id $apiPid -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $apiPidPath -Force
    }
    try {
        Invoke-NativeCommand $pnpm @("game010:database", "--", "cleanup") $backendRoot | Out-Null
    } catch {
        Write-Warning "[GAME-012] Cleanup could not drop sorting_puzzle_game010."
    }
    $expectedSecretRoot = [IO.Path]::GetFullPath((Join-Path $backendRoot "local-secrets\game012"))
    if ($secretRoot -eq $expectedSecretRoot -and (Test-Path -LiteralPath $secretRoot)) {
        Remove-Item -LiteralPath $secretRoot -Recurse -Force
    }
}

if ($CleanupOnly) {
    Invoke-Cleanup
    Write-Host "[GAME-012] cleanup complete"
    exit 0
}

try {
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot 4.6.2 was not found at the configured path."
    }
    Get-Command docker -ErrorAction Stop | Out-Null
    $existingListener = Get-NetTCPConnection -LocalPort $ApiPort -State Listen -ErrorAction SilentlyContinue
    if ($null -ne $existingListener) {
        throw "ApiPort $ApiPort is already in use."
    }
    New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
    $statePath = Join-Path $artifactsRoot "deletion-state.json"
    $apiStdout = Join-Path $artifactsRoot "api.stdout.log"
    $apiStderr = Join-Path $artifactsRoot "api.stderr.log"

    if (-not $SkipInstall) {
        Set-Phase "dependencies"
        Invoke-NativeCommand $pnpm @("install", "--frozen-lockfile") $backendRoot
    }

    Set-Phase "postgres"
    Invoke-NativeCommand $pnpm @("db:up") $backendRoot
    Invoke-NativeCommand $pnpm @("game010:database", "--", "reset") $backendRoot

    Set-Phase "secrets"
    Invoke-NativeCommand $pnpm @("generate:local-secrets", "--", "--force") $backendRoot | Out-Null

    Set-Phase "bootstrap"
    foreach ($path in @(
        (Join-Path $gameRoot "configs\backend\content_provenance.json"),
        (Join-Path $backendRoot "contracts\configuration\v1\development-client-provenance.json")
    )) {
        $snapshots += [pscustomobject]@{ Path = $path; Bytes = [IO.File]::ReadAllBytes($path) }
    }
    Invoke-NativeCommand $pnpm @("bootstrap:local") $backendRoot

    if (-not $SkipBuild) {
        Set-Phase "backend_build"
        Invoke-NativeCommand $pnpm @("build") $backendRoot
    }

    Set-Phase "api_start"
    $apiProcess = Start-Process -FilePath (Get-Command node -ErrorAction Stop).Source `
        -ArgumentList @("apps/api/dist/main.js") `
        -WorkingDirectory $backendRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $apiStdout `
        -RedirectStandardError $apiStderr `
        -PassThru
    Set-Content -LiteralPath $apiPidPath -Value $apiProcess.Id
    $ready = $false
    $readyDeadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $readyDeadline) {
        if ($apiProcess.HasExited) {
            throw "API process exited before readiness."
        }
        try {
            $response = Invoke-RestMethod "http://127.0.0.1:$ApiPort/health/ready" -TimeoutSec 2
            if ($response.status -eq "ready") {
                $ready = $true
                break
            }
        } catch {
            # Expected while the API is starting.
        }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) {
        throw "API readiness timed out."
    }

    $checkScript = Join-Path $PSScriptRoot "local_backend_account_deletion_check.mjs"
    $checkArguments = @(
        "--base-url", "http://127.0.0.1:$ApiPort",
        "--state-file", $statePath,
        "--backend-root", $backendRoot,
        "--database-user", $postgresUser
    )

    Set-Phase "server_before_worker"
    Invoke-NativeCommand "node" (@($checkScript, "--phase", "before-worker") + $checkArguments) $gameRoot

    Set-Phase "worker"
    Invoke-NativeCommand $pnpm @("start:worker") $backendRoot

    Set-Phase "server_after_worker"
    Invoke-NativeCommand "node" (@($checkScript, "--phase", "after-worker") + $checkArguments) $gameRoot

    if ($Android) {
        Set-Phase "android_export"
        New-Item -ItemType Directory -Force -Path (Join-Path $gameRoot "local") | Out-Null
        $debugConfigPath = Join-Path $gameRoot "local\backend_debug.cfg"
        $debugConfigExisted = Test-Path -LiteralPath $debugConfigPath -PathType Leaf
        if ($debugConfigExisted) {
            $debugConfigBytes = [IO.File]::ReadAllBytes($debugConfigPath)
        }
        @"
[backend]

base_url="http://127.0.0.1:8080"
sync_enabled=true
"@ | Set-Content -LiteralPath $debugConfigPath -Encoding utf8
        $apkPath = Join-Path $artifactsRoot "sorting_puzzle_account_deletion_debug.apk"
        $exportArguments = @("--headless", "--path", "`"$gameRoot`"")
        # A fresh worktree has no gitignored Android build template; an existing one is kept as is.
        if (-not (Test-Path -LiteralPath (Join-Path $gameRoot "android\build\build.gradle") -PathType Leaf)) {
            $exportArguments += "--install-android-build-template"
        }
        $exportArguments += @("--export-debug", "`"Android (Local Backend Debug)`"", "`"$apkPath`"")
        # godot.exe is a GUI-subsystem binary, so `&` would not wait for it and the debug config
        # below would be restored before the export reads it. Start-Process -Wait blocks until done.
        $export = Start-Process -FilePath $GodotPath -ArgumentList $exportArguments -Wait -NoNewWindow -PassThru
        if ($export.ExitCode -ne 0) {
            throw "Godot export exited with code $($export.ExitCode)."
        }
        if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
            throw "Godot export produced no APK."
        }
        Write-Host "[GAME-012] APK: $apkPath"
    }

    Set-Phase "complete"
    Write-Host "[GAME-012] PASS server-side account deletion checks"
    if ($KeepRunning) {
        Write-Host "[GAME-012] API left running on port $ApiPort (pid $($apiProcess.Id)); run -CleanupOnly when done."
    }
} catch {
    # Write-Host, not Write-Error: under ErrorActionPreference Stop, Write-Error would throw again
    # and skip the cleanup decision below.
    Write-Host "[GAME-012] FAIL phase=$currentPhase. See build/game012 logs for non-secret diagnostics. $($_.Exception.Message)"
    $failed = $true
    $KeepRunning = $false
} finally {
    foreach ($snapshot in $snapshots) {
        [IO.File]::WriteAllBytes($snapshot.Path, $snapshot.Bytes)
    }
    if ($null -ne $debugConfigPath) {
        if ($debugConfigExisted) {
            [IO.File]::WriteAllBytes($debugConfigPath, $debugConfigBytes)
        } elseif (Test-Path -LiteralPath $debugConfigPath -PathType Leaf) {
            Remove-Item -LiteralPath $debugConfigPath -Force
        }
    }
    if (-not $KeepRunning) {
        Invoke-Cleanup
    }
}
if ($failed) {
    exit 1
}
