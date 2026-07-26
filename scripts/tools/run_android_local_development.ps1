<#
.SYNOPSIS
  Starts the persistent local backend and Android emulator, exports the game, and runs it.

.DESCRIPTION
  Daily-development launcher for the Sorting Puzzle Android client. It:

    - starts or reuses the configured Android Virtual Device;
    - starts the backend PostgreSQL container with its persistent Compose volume;
    - reuses or creates the ignored persistent local backend secrets;
    - applies migrations and idempotently bootstraps development content;
    - starts the API when port 8080 does not already expose the expected ready service;
    - builds the Android secure-store debug AAR;
    - writes the ignored debug-only backend override;
    - exports, installs, launches, and smoke-checks the Android debug APK.

  The emulator, PostgreSQL container, and API are intentionally left running after this script
  exits. Re-running the launcher reuses a healthy emulator/API and preserves app/database state.

.PARAMETER AvdName
  Android Virtual Device to start or reuse. Defaults to sorting-puzzle-api36.

.PARAMETER GodotPath
  Godot 4.6.2 executable. Defaults to D:\Godot\godot.exe.

.PARAMETER BackendPath
  Sibling backend repository. Defaults to ..\sorting-puzzle-backend.

.PARAMETER ApiPort
  Host API port. Emulator tcp:8080 is mapped to this port with adb reverse. Defaults to 8080.

.PARAMETER SkipInstall
  Skips pnpm install when the backend workspace dependencies are already installed.

.PARAMETER SkipPluginBuild
  Skips rebuilding the Android secure-store debug AAR.

.PARAMETER EmulatorTimeoutSeconds
  Maximum wait for the selected AVD to finish booting. Defaults to 180 seconds.

.PARAMETER BackendTimeoutSeconds
  Maximum wait for a newly started API to become ready. Defaults to 60 seconds.
#>
param(
    [string]$AvdName = "sorting-puzzle-api36",
    [string]$GodotPath = "D:\Godot\godot.exe",
    [string]$BackendPath = "..\sorting-puzzle-backend",
    [int]$ApiPort = 8080,
    [switch]$SkipInstall,
    [switch]$SkipPluginBuild,
    [int]$EmulatorTimeoutSeconds = 180,
    [int]$BackendTimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
$currentPhase = "prerequisites"
$startedApiProcess = $null
$apiReady = $false

function Set-Phase {
    param([string]$Name)
    $script:currentPhase = $Name
    Write-Host "[local-android] phase=$Name"
}

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
            throw "$Executable exited with code $LASTEXITCODE."
        }
    } finally {
        Set-Location -LiteralPath $previousLocation
    }
}

function Invoke-GodotCommand {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [string]$LogName
    )

    $runtimeRoot = Join-Path $WorkingDirectory "build\local-development"
    New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
    $stdoutPath = Join-Path $runtimeRoot "$LogName.stdout.log"
    $stderrPath = Join-Path $runtimeRoot "$LogName.stderr.log"
    $processArguments = @(
        $Arguments | ForEach-Object {
            if ($_ -match '[\s"]') {
                '"' + $_.Replace('"', '\"') + '"'
            } else {
                $_
            }
        }
    )
    $process = Start-Process `
        -FilePath $Executable `
        -ArgumentList $processArguments `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -Wait `
        -PassThru
    if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
        Get-Content -LiteralPath $stdoutPath | Write-Host
    }
    if ($process.ExitCode -ne 0) {
        if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            Get-Content -LiteralPath $stderrPath | Write-Host
        }
        throw "Godot exited with code $($process.ExitCode). Inspect build\local-development\$LogName.*.log."
    }
}

function Resolve-CommandPath {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }
    throw "Required command was not found: $($Names -join ', ')"
}

function Resolve-AndroidToolPath {
    param([string]$RelativePath)

    $sdkRoots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    ) | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    } | Select-Object -Unique

    foreach ($sdkRoot in $sdkRoots) {
        $candidate = Join-Path $sdkRoot $RelativePath
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Android SDK tool was not found: $RelativePath"
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

function Test-BackendReady {
    param([int]$Port)

    try {
        $response = Invoke-RestMethod "http://127.0.0.1:$Port/health/ready" -TimeoutSec 2
        return (
            $response.service -eq "sorting-puzzle-backend-api" -and
            $response.status -eq "ready"
        )
    } catch {
        return $false
    }
}

function Get-AvdDeviceSerial {
    param(
        [string]$AdbExe,
        [string]$ExpectedAvdName
    )

    $deviceLines = & $AdbExe devices
    if ($LASTEXITCODE -ne 0) {
        throw "adb devices failed."
    }
    foreach ($line in $deviceLines) {
        if ($line -notmatch "^(\S+)\s+device$") {
            continue
        }
        $serial = $Matches[1]
        if ($serial -notlike "emulator-*") {
            continue
        }
        $reportedName = & $AdbExe -s $serial emu avd name 2>$null |
            Select-Object -First 1
        if (
            $LASTEXITCODE -eq 0 -and
            $null -ne $reportedName -and
            $reportedName.Trim() -eq $ExpectedAvdName
        ) {
            return $serial
        }
    }
    return $null
}

try {
    Set-Phase "prerequisites"
    $gameRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    $backendRoot = (Resolve-Path -LiteralPath (Join-Path $gameRoot $BackendPath)).Path
    if (-not (Test-Path -LiteralPath (Join-Path $backendRoot "AGENTS.md") -PathType Leaf)) {
        throw "Sibling backend repository is missing at $backendRoot."
    }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot 4.6.2 was not found at $GodotPath."
    }
    if ($ApiPort -lt 1 -or $ApiPort -gt 65535) {
        throw "ApiPort must be between 1 and 65535."
    }
    if ($EmulatorTimeoutSeconds -lt 1 -or $BackendTimeoutSeconds -lt 1) {
        throw "Timeout values must be positive."
    }

    $pnpm = Resolve-CommandPath @("pnpm.cmd", "pnpm")
    $node = Resolve-CommandPath @("node.exe", "node")
    $docker = Resolve-CommandPath @("docker.exe", "docker")
    $adb = Resolve-AndroidToolPath "platform-tools\adb.exe"
    $emulator = Resolve-AndroidToolPath "emulator\emulator.exe"
    $androidSdkRoot = Split-Path -Parent (Split-Path -Parent $adb)
    $env:ANDROID_HOME = $androidSdkRoot
    $env:ANDROID_SDK_ROOT = $androidSdkRoot

    $godotVersion = (Get-Item -LiteralPath $GodotPath).VersionInfo.ProductVersion
    if (
        [string]::IsNullOrWhiteSpace($godotVersion) -or
        -not $godotVersion.StartsWith("4.6.2")
    ) {
        throw "Expected Godot 4.6.2, found '$godotVersion'."
    }
    $nodeVersion = (& $node --version).Trim()
    if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch "^v24\.") {
        throw "Expected Node.js 24 LTS, found '$nodeVersion'."
    }
    Invoke-NativeCommand $docker @("info", "--format", "{{.ServerVersion}}") $backendRoot -SuppressOutput

    $availableAvds = & $emulator -list-avds
    if ($LASTEXITCODE -ne 0 -or $AvdName -notin $availableAvds) {
        throw "Android Virtual Device '$AvdName' is not installed."
    }

    Set-Phase "emulator"
    & $adb start-server | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "adb server failed to start."
    }
    $deviceSerial = Get-AvdDeviceSerial -AdbExe $adb -ExpectedAvdName $AvdName
    if ($null -eq $deviceSerial) {
        Write-Host "Starting Android Virtual Device '$AvdName'..."
        Start-Process -FilePath $emulator -ArgumentList @("-avd", $AvdName) | Out-Null
    } else {
        Write-Host "Reusing '$AvdName' on $deviceSerial."
    }

    $emulatorDeadline = (Get-Date).AddSeconds($EmulatorTimeoutSeconds)
    while ((Get-Date) -lt $emulatorDeadline) {
        if ($null -eq $deviceSerial) {
            $deviceSerial = Get-AvdDeviceSerial -AdbExe $adb -ExpectedAvdName $AvdName
        }
        if ($null -ne $deviceSerial) {
            $bootCompleted = (& $adb -s $deviceSerial shell getprop sys.boot_completed 2>$null).Trim()
            if ($LASTEXITCODE -eq 0 -and $bootCompleted -eq "1") {
                break
            }
        }
        Start-Sleep -Seconds 2
    }
    if ($null -eq $deviceSerial) {
        throw "Timed out waiting for '$AvdName' to connect to adb."
    }
    $bootCompleted = (& $adb -s $deviceSerial shell getprop sys.boot_completed 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $bootCompleted -ne "1") {
        throw "Timed out waiting for '$AvdName' to finish booting."
    }

    Set-Phase "backend_dependencies"
    if (-not $SkipInstall) {
        Invoke-NativeCommand $pnpm @("install", "--frozen-lockfile") $backendRoot
    }

    Set-Phase "postgres"
    Invoke-NativeCommand $docker @("compose", "up", "-d", "--wait", "postgres") $backendRoot

    $envFile = Join-Path $backendRoot ".env"
    $postgresUser = Read-DotEnvValue $envFile "POSTGRES_USER" "sorting_puzzle"
    $postgresPassword = Read-DotEnvValue $envFile "POSTGRES_PASSWORD" "local_only_change_me"
    $postgresDatabase = Read-DotEnvValue $envFile "POSTGRES_DB" "sorting_puzzle"
    $postgresPort = Read-DotEnvValue $envFile "POSTGRES_PORT" "5432"
    $defaultDatabaseUrl = "postgresql://$([uri]::EscapeDataString($postgresUser)):$([uri]::EscapeDataString($postgresPassword))@127.0.0.1:$postgresPort/$([uri]::EscapeDataString($postgresDatabase))"
    $databaseUrl = Read-DotEnvValue $envFile "DATABASE_URL" $defaultDatabaseUrl
    $secretRoot = [IO.Path]::GetFullPath((Join-Path $backendRoot "local-secrets"))

    $env:DATABASE_URL = $databaseUrl
    $env:SORTING_PUZZLE_SECRET_ROOT = $secretRoot
    $env:NODE_ENV = "development"
    $env:PORT = "$ApiPort"
    $env:REQUIRE_HTTPS = "false"
    $env:TRUST_PROXY_HOPS = "0"
    $env:OBSERVABILITY_EXPORTER = "none"
    $env:DEPLOYMENT_ENVIRONMENT = "development"

    Set-Phase "persistent_secrets"
    $secretFiles = @(
        "api-runtime\secret.json",
        "token-signing\secret.json",
        "offline-lease-signing\secret.json",
        "data-encryption\secret.json"
    )
    $presentSecretFiles = @(
        $secretFiles | Where-Object {
            Test-Path -LiteralPath (Join-Path $secretRoot $_) -PathType Leaf
        }
    )
    if ($presentSecretFiles.Count -eq 0) {
        Invoke-NativeCommand $pnpm @("generate:local-secrets") $backendRoot -SuppressOutput
        Write-Host "Created the persistent local-development secret set."
    } elseif ($presentSecretFiles.Count -ne $secretFiles.Count) {
        throw "The persistent local secret set is incomplete. Restore all four files or intentionally regenerate the entire ignored local-secrets directory."
    } else {
        $apiRuntimeSecret = Get-Content -Raw -LiteralPath (
            Join-Path $secretRoot "api-runtime\secret.json"
        ) | ConvertFrom-Json
        if ($apiRuntimeSecret.database_url -ne $databaseUrl) {
            throw "The persistent API runtime secret targets a different DATABASE_URL. Update .env or intentionally regenerate the ignored local secret set."
        }
        Write-Host "Reusing the persistent local-development secret set."
    }

    Set-Phase "backend_bootstrap"
    Invoke-NativeCommand $pnpm @("bootstrap:local") $backendRoot

    Set-Phase "backend_api"
    $apiReady = Test-BackendReady -Port $ApiPort
    if ($apiReady) {
        Write-Host "Reusing the ready Sorting Puzzle API on port $ApiPort."
    } else {
        $existingListener = Get-NetTCPConnection `
            -LocalPort $ApiPort `
            -State Listen `
            -ErrorAction SilentlyContinue
        if ($null -ne $existingListener) {
            throw "Port $ApiPort is occupied by a service that is not the ready Sorting Puzzle API."
        }

        Invoke-NativeCommand $pnpm @("build") $backendRoot
        $runtimeRoot = Join-Path $gameRoot "build\local-development"
        New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
        $apiStdout = Join-Path $runtimeRoot "backend-api.stdout.log"
        $apiStderr = Join-Path $runtimeRoot "backend-api.stderr.log"
        $apiPidPath = Join-Path $runtimeRoot "backend-api.pid"
        $startedApiProcess = Start-Process `
            -FilePath $node `
            -ArgumentList @("apps/api/dist/main.js") `
            -WorkingDirectory $backendRoot `
            -WindowStyle Hidden `
            -RedirectStandardOutput $apiStdout `
            -RedirectStandardError $apiStderr `
            -PassThru
        [IO.File]::WriteAllText(
            $apiPidPath,
            "$($startedApiProcess.Id)`n",
            [Text.UTF8Encoding]::new($false)
        )

        $backendDeadline = (Get-Date).AddSeconds($BackendTimeoutSeconds)
        while ((Get-Date) -lt $backendDeadline) {
            if ($startedApiProcess.HasExited) {
                throw "The backend API exited before readiness. Inspect build\local-development\backend-api.stderr.log."
            }
            if (Test-BackendReady -Port $ApiPort) {
                $apiReady = $true
                break
            }
            Start-Sleep -Seconds 1
        }
        if (-not $apiReady) {
            throw "Timed out waiting for the backend API. Inspect build\local-development backend logs."
        }
        Write-Host "Started the Sorting Puzzle API as process $($startedApiProcess.Id)."
    }

    Set-Phase "android_plugin"
    if (-not $SkipPluginBuild) {
        $pluginRoot = Join-Path $gameRoot "platform\android\secure-store-plugin"
        Invoke-NativeCommand (
            Join-Path $pluginRoot "gradlew.bat"
        ) @(":plugin:assembleDebug") $pluginRoot
    }
    $debugAar = Join-Path $gameRoot (
        "platform\android\secure-store-plugin\plugin\build\outputs\aar\" +
        "SortingPuzzleSecureStoreBridge-debug.aar"
    )
    if (-not (Test-Path -LiteralPath $debugAar -PathType Leaf)) {
        throw "The Android secure-store debug AAR was not produced."
    }

    Set-Phase "debug_config"
    $debugConfigPath = Join-Path $gameRoot "local\backend_debug.cfg"
    $debugConfig = @"
[backend]

base_url="http://127.0.0.1:8080"
sync_enabled=true
"@
    [IO.File]::WriteAllText(
        $debugConfigPath,
        "$debugConfig`n",
        [Text.UTF8Encoding]::new($false)
    )

    Set-Phase "android_export"
    $apkPath = Join-Path $gameRoot "build\android\sorting_puzzle_local_backend_debug.apk"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $apkPath) | Out-Null
    Invoke-GodotCommand $GodotPath @(
        "--headless",
        "--path",
        $gameRoot,
        "--export-debug",
        "Android (Local Backend Debug)",
        $apkPath
    ) $gameRoot "android-export"

    Set-Phase "android_install_and_launch"
    & (Join-Path $gameRoot "scripts\tools\android_local_backend_smoke_check.ps1") `
        -ApkPath $apkPath `
        -AdbPath $adb `
        -DeviceSerial $deviceSerial `
        -HostPort $ApiPort
    if ($LASTEXITCODE -ne 0) {
        throw "Android install/launch smoke check failed."
    }

    Set-Phase "complete"
    Write-Host ""
    Write-Host "Sorting Puzzle is running on '$AvdName' ($deviceSerial)."
    Write-Host "Backend: http://127.0.0.1:$ApiPort"
    Write-Host "APK: $apkPath"
    Write-Host "The emulator, PostgreSQL container, and backend API were left running."
} catch {
    Write-Error "[local-android] FAIL phase=$currentPhase message=$($_.Exception.Message)"
    if ($null -ne $startedApiProcess -and -not $apiReady -and -not $startedApiProcess.HasExited) {
        Stop-Process -Id $startedApiProcess.Id -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

exit 0
