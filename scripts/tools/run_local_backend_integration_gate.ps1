<#
.SYNOPSIS
  GAME-010 clean-start Android/local-backend integration gate.

.DESCRIPTION
  Runs the complete local gate against the fixed disposable PostgreSQL database
  `sorting_puzzle_game010`: installs dependencies, resets/migrates/bootstraps the database,
  generates disposable secrets, runs the Godot v1/v1.1/v2 fixture gate, builds and starts the API,
  exports and installs the Android debug APK, proves session resumption, executes two real signed
  protocol-v2 save scenarios, projects their distinct scores, and checks identity/session, cursor,
  checkpoint, outbox, catalog, and leaderboard persistence.

  Cleanup stops only processes started by this script, drops only `sorting_puzzle_game010`, removes
  only generated `local-secrets/game010`, and restores any pre-existing local backend debug config.
  Failures print the phase, a stable GAME-010 error code, and this run's correlation ID. Child
  request bodies, credentials, tokens, signatures, and secret paths are never printed by the gate.

.EXAMPLE
  .\scripts\tools\run_local_backend_integration_gate.ps1

.PARAMETER GodotPath
  Godot 4.6.2 executable. Defaults to D:\Godot\godot.exe.

.PARAMETER BackendPath
  Sibling backend repository. Defaults to ..\sorting-puzzle-backend.

.PARAMETER ApiPort
  Host port for the API. Defaults to the standard 8080. The Android route remains
  http://127.0.0.1:8080 through `adb reverse tcp:8080 tcp:<ApiPort>`.

.PARAMETER SkipInstall
  Skips `pnpm install --frozen-lockfile` when the backend workspace is already installed.

.PARAMETER SkipAndroid
  Runs only the contract/backend half. This is useful for diagnostics but is not the full L4 exit
  gate because it does not install the APK or prove Android session resumption.

.PARAMETER KeepIntegrationDatabase
  Explicitly retains the named disposable database and gate-generated secrets for troubleshooting.
#>
param(
    [string]$GodotPath = "D:\Godot\godot.exe",
    [string]$BackendPath = "..\sorting-puzzle-backend",
    [int]$ApiPort = 8080,
    [switch]$SkipInstall,
    [switch]$SkipAndroid,
    [switch]$KeepIntegrationDatabase
)

$ErrorActionPreference = "Stop"
$runCorrelationId = [guid]::NewGuid().ToString()
$currentPhase = "prerequisites"
$apiProcess = $null
$databaseWasCreated = $false
$generatedSecretRoot = $null
$debugConfigPath = $null
$debugConfigExisted = $false
$debugConfigBytes = $null

function Invoke-NativeCommand {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [switch]$SuppressOutput
    )
    $previousLocation = Get-Location
    try {
        Set-Location -LiteralPath $WorkingDirectory
        if ($SuppressOutput) {
            & $Executable @Arguments | Out-Null
        } else {
            & $Executable @Arguments
        }
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
    Write-Host "[GAME-010] phase=$Name correlation_id=$runCorrelationId"
}

function Read-DotEnvValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$DefaultValue
    )
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

try {
    $gameRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    $backendRoot = (Resolve-Path -LiteralPath (Join-Path $gameRoot $BackendPath)).Path
    if (-not (Test-Path -LiteralPath (Join-Path $backendRoot "AGENTS.md") -PathType Leaf)) {
        throw "Sibling backend repository is missing."
    }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot 4.6.2 was not found at the configured path."
    }
    $pnpmCommand = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
    if ($null -eq $pnpmCommand) {
        $pnpmCommand = Get-Command pnpm -ErrorAction Stop
    }
    $pnpm = $pnpmCommand.Source
    $nodeCommand = Get-Command node -ErrorAction Stop
    $node = $nodeCommand.Source
    Get-Command docker -ErrorAction Stop | Out-Null
    if ($ApiPort -lt 1 -or $ApiPort -gt 65535) {
        throw "ApiPort must be between 1 and 65535."
    }
    $existingListener = Get-NetTCPConnection -LocalPort $ApiPort -State Listen -ErrorAction SilentlyContinue
    if ($null -ne $existingListener) {
        throw "ApiPort $ApiPort is already in use; pass an unused -ApiPort."
    }

    $artifactsRoot = Join-Path $gameRoot "build\game010"
    New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
    $resultLow = Join-Path $artifactsRoot "save-low.json"
    $resultHigh = Join-Path $artifactsRoot "save-high.json"
    $androidResult = Join-Path $artifactsRoot "android.json"
    $apiStdout = Join-Path $artifactsRoot "api.stdout.log"
    $apiStderr = Join-Path $artifactsRoot "api.stderr.log"
    foreach ($artifact in @($resultLow, $resultHigh, $androidResult, $apiStdout, $apiStderr)) {
        if (Test-Path -LiteralPath $artifact -PathType Leaf) {
            Remove-Item -LiteralPath $artifact -Force
        }
    }

    $envFile = Join-Path $backendRoot ".env"
    $postgresUser = Read-DotEnvValue $envFile "POSTGRES_USER" "sorting_puzzle"
    $postgresPassword = Read-DotEnvValue $envFile "POSTGRES_PASSWORD" "local_only_change_me"
    $postgresPort = Read-DotEnvValue $envFile "POSTGRES_PORT" "5432"
    $encodedUser = [uri]::EscapeDataString($postgresUser)
    $encodedPassword = [uri]::EscapeDataString($postgresPassword)
    $env:GAME010_ADMIN_DATABASE_URL = "postgresql://${encodedUser}:${encodedPassword}@127.0.0.1:${postgresPort}/postgres"
    $env:DATABASE_URL = "postgresql://${encodedUser}:${encodedPassword}@127.0.0.1:${postgresPort}/sorting_puzzle_game010"
    $env:NODE_ENV = "development"
    $env:PORT = "$ApiPort"
    $env:REQUIRE_HTTPS = "false"
    $env:TRUST_PROXY_HOPS = "0"
    $env:OBSERVABILITY_EXPORTER = "none"
    $env:DEPLOYMENT_ENVIRONMENT = "development"

    Set-Phase "dependencies"
    if (-not $SkipInstall) {
        Invoke-NativeCommand $pnpm @("install", "--frozen-lockfile") $backendRoot
    }

    Set-Phase "postgres"
    Invoke-NativeCommand $pnpm @("db:up") $backendRoot
    Invoke-NativeCommand $pnpm @("game010:database", "--", "reset") $backendRoot
    $databaseWasCreated = $true

    Set-Phase "secrets"
    $generatedSecretRoot = [IO.Path]::GetFullPath((Join-Path $backendRoot "local-secrets\game010"))
    $env:SORTING_PUZZLE_SECRET_ROOT = $generatedSecretRoot
    Invoke-NativeCommand $pnpm @("generate:local-secrets", "--", "--force") $backendRoot -SuppressOutput

    Set-Phase "bootstrap"
    Invoke-NativeCommand $pnpm @("bootstrap:local") $backendRoot

    Set-Phase "contracts"
    Invoke-NativeCommand $GodotPath @(
        "--headless",
        "--path",
        $gameRoot,
        "--script",
        "tests/backend/test_game_010.gd",
        "--",
        $backendRoot
    ) $gameRoot

    Set-Phase "backend_build"
    Invoke-NativeCommand $pnpm @("build") $backendRoot

    Set-Phase "api_start"
    $apiProcess = Start-Process -FilePath $node `
        -ArgumentList @("apps/api/dist/main.js") `
        -WorkingDirectory $backendRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $apiStdout `
        -RedirectStandardError $apiStderr `
        -PassThru
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

    if (-not $SkipAndroid) {
        Set-Phase "android_export"
        $apkPath = Join-Path $gameRoot "build\android\sorting_puzzle_local_backend_debug.apk"
        Invoke-NativeCommand $GodotPath @(
            "--headless",
            "--path",
            $gameRoot,
            "--export-debug",
            "Android (Local Backend Debug)",
            $apkPath
        ) $gameRoot

        Set-Phase "android_identity"
        & (Join-Path $gameRoot "scripts\tools\android_local_backend_identity_smoke_check.ps1") `
            -ApkPath $apkPath `
            -HostPort $ApiPort `
            -ClearAppData `
            -ResultPath $androidResult
        if ($LASTEXITCODE -ne 0) {
            throw "Android identity smoke check failed."
        }
    }

    Set-Phase "save_scenarios"
    $saveRunner = Join-Path $gameRoot "scripts\tools\local_backend_save_sync_integration_check.mjs"
    Invoke-NativeCommand "node" @(
        $saveRunner,
        "--base-url", "http://127.0.0.1:$ApiPort",
        "--completion-stars", "1",
        "--result-file", $resultLow,
        "--redacted-output"
    ) $gameRoot
    Invoke-NativeCommand "node" @(
        $saveRunner,
        "--base-url", "http://127.0.0.1:$ApiPort",
        "--completion-stars", "3",
        "--result-file", $resultHigh,
        "--redacted-output"
    ) $gameRoot

    Set-Phase "leaderboard_projection"
    Invoke-NativeCommand $pnpm @(
        "game010:assert", "--",
        "--mode", "promote",
        "--fixture", $resultLow,
        "--fixture", $resultHigh
    ) $backendRoot
    $env:LEADERBOARD_PROJECTION_ENVIRONMENT = "production"
    Invoke-NativeCommand $pnpm @("start:worker") $backendRoot

    Set-Phase "persistence_assertions"
    $assertArguments = @(
        "game010:assert", "--",
        "--mode", "assert",
        "--fixture", $resultLow,
        "--fixture", $resultHigh
    )
    if (-not $SkipAndroid) {
        $assertArguments += @("--android", $androidResult)
    }
    Invoke-NativeCommand $pnpm $assertArguments $backendRoot

    Set-Phase "complete"
    $provenance = Get-Content -LiteralPath (Join-Path $gameRoot "configs\backend\content_provenance.json") |
        ConvertFrom-Json
    Write-Host (
        "[GAME-010] PASS correlation_id=$runCorrelationId configuration_version=$($provenance.publication.configuration_version) " +
        "content_manifest_sha256=$($provenance.digest_sha256) fixtures=v1:1.0.0,v1.1:1.1.6,v2:save-sync-fixtures/1"
    )
} catch {
    $stablePhase = ($currentPhase -replace "[^a-z0-9_]", "_").ToLowerInvariant()
    Write-Error (
        "[GAME-010] FAIL phase=$currentPhase code=game010.$stablePhase.failed " +
        "correlation_id=$runCorrelationId. See build/game010 logs for non-secret diagnostics."
    )
    exit 1
} finally {
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -Force -ErrorAction SilentlyContinue
        Wait-Process -Id $apiProcess.Id -Timeout 10 -ErrorAction SilentlyContinue
    }

    if ($null -ne $debugConfigPath) {
        if ($debugConfigExisted) {
            [IO.File]::WriteAllBytes($debugConfigPath, $debugConfigBytes)
        } elseif (Test-Path -LiteralPath $debugConfigPath -PathType Leaf) {
            Remove-Item -LiteralPath $debugConfigPath -Force
        }
    }

    if (-not $KeepIntegrationDatabase) {
        if ($databaseWasCreated) {
            try {
                Invoke-NativeCommand $pnpm @("game010:database", "--", "cleanup") $backendRoot -SuppressOutput
            } catch {
                Write-Warning "[GAME-010] Cleanup could not drop sorting_puzzle_game010."
            }
        }
        if ($null -ne $generatedSecretRoot -and (Test-Path -LiteralPath $generatedSecretRoot)) {
            $expectedSecretRoot = [IO.Path]::GetFullPath(
                (Join-Path $backendRoot "local-secrets\game010")
            )
            if ($generatedSecretRoot -ne $expectedSecretRoot) {
                Write-Warning "[GAME-010] Refused secret cleanup because the resolved target changed."
            } else {
                Remove-Item -LiteralPath $generatedSecretRoot -Recurse -Force
            }
        }
    }
}
