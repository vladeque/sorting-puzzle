<#
.SYNOPSIS
  Exports the latest game build and restarts it on the already-running Android emulator.

.DESCRIPTION
  Fast iteration path for game-only changes. It does not start the emulator, Docker, PostgreSQL,
  backend API, install backend dependencies, bootstrap backend content, generate secrets, or build
  the native Android plugin.

  The script requires the configured AVD and backend to already be ready. It validates authored
  content provenance, exports the Android local-backend debug APK, installs it with `adb install -r`
  so app data is preserved, force-stops the previous game process, and launches the updated build.

.PARAMETER AvdName
  Already-running Android Virtual Device to target. Defaults to sorting-puzzle-api36.

.PARAMETER GodotPath
  Godot 4.6.2 executable. Defaults to D:\Godot\godot.exe.

.PARAMETER ApiPort
  Already-running host API port. Emulator tcp:8080 is mapped to this port. Defaults to 8080.

.PARAMETER PackageName
  Android package from export_presets.cfg. Defaults to com.sortingpuzzle.game.

.PARAMETER LaunchTimeoutSeconds
  Maximum wait for the relaunched Android process. Defaults to 20 seconds.
#>
param(
    [string]$AvdName = "sorting-puzzle-api36",
    [string]$GodotPath = "D:\Godot\godot.exe",
    [int]$ApiPort = 8080,
    [string]$PackageName = "com.sortingpuzzle.game",
    [int]$LaunchTimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"
$currentPhase = "prerequisites"

function Set-Phase {
    param([string]$Name)
    $script:currentPhase = $Name
    Write-Host "[android-redeploy] phase=$Name"
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

function Set-AdbReverse {
    param(
        [string]$AdbExe,
        [string]$DeviceSerial,
        [int]$HostPort,
        [int]$MaximumAttempts = 3
    )

    $lastExitCode = -1
    $lastDetail = "no diagnostic output"
    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        $process = New-Object System.Diagnostics.Process
        try {
            $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
            $process.StartInfo.FileName = $AdbExe
            $process.StartInfo.Arguments = (
                "-s $DeviceSerial reverse tcp:8080 tcp:$HostPort"
            )
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            if (-not $process.Start()) {
                throw "adb reverse process could not be started."
            }
            if (-not $process.WaitForExit(10000)) {
                $process.Kill()
                $process.WaitForExit()
                $lastExitCode = -1
                $reverseOutput = @("adb reverse timed out after 10 seconds")
            } else {
                $lastExitCode = $process.ExitCode
                $reverseOutput = @(
                    $process.StandardOutput.ReadToEnd(),
                    $process.StandardError.ReadToEnd()
                )
            }
        } finally {
            $process.Dispose()
        }

        $detailLines = @(
            $reverseOutput | ForEach-Object {
                "$_".Trim()
            } | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        )
        if ($detailLines.Count -gt 0) {
            $lastDetail = $detailLines -join " "
        }
        if ($lastExitCode -eq 0) {
            if ($attempt -gt 1) {
                Write-Host "adb reverse recovered on attempt $attempt."
            }
            return
        }
        if ($attempt -lt $MaximumAttempts) {
            Write-Warning (
                "adb reverse attempt $attempt failed for $DeviceSerial " +
                "(exit=$lastExitCode); retrying..."
            )
            Start-Sleep -Seconds 1
        }
    }

    throw (
        "adb reverse tcp:8080 tcp:$HostPort failed for $DeviceSerial after " +
        "$MaximumAttempts attempts (exit=$lastExitCode, detail=$lastDetail)."
    )
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

try {
    Set-Phase "prerequisites"
    $gameRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot 4.6.2 was not found at $GodotPath."
    }
    $godotVersion = (Get-Item -LiteralPath $GodotPath).VersionInfo.ProductVersion
    if (
        [string]::IsNullOrWhiteSpace($godotVersion) -or
        -not $godotVersion.StartsWith("4.6.2")
    ) {
        throw "Expected Godot 4.6.2, found '$godotVersion'."
    }
    if ($ApiPort -lt 1 -or $ApiPort -gt 65535) {
        throw "ApiPort must be between 1 and 65535."
    }
    if ($LaunchTimeoutSeconds -lt 1) {
        throw "LaunchTimeoutSeconds must be positive."
    }

    $adb = Resolve-AndroidToolPath "platform-tools\adb.exe"
    $androidSdkRoot = Split-Path -Parent (Split-Path -Parent $adb)
    $env:ANDROID_HOME = $androidSdkRoot
    $env:ANDROID_SDK_ROOT = $androidSdkRoot

    $debugConfigPath = Join-Path $gameRoot "local\backend_debug.cfg"
    if (-not (Test-Path -LiteralPath $debugConfigPath -PathType Leaf)) {
        throw "The ignored local backend debug config is missing. Run run_android_local_development.cmd once first."
    }
    $debugAar = Join-Path $gameRoot (
        "platform\android\secure-store-plugin\plugin\build\outputs\aar\" +
        "SortingPuzzleSecureStoreBridge-debug.aar"
    )
    if (-not (Test-Path -LiteralPath $debugAar -PathType Leaf)) {
        throw "The Android secure-store debug AAR is missing. Run run_android_local_development.cmd once first."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $gameRoot "android\build") -PathType Container)) {
        throw "The Godot Android build template is missing. Run the full local-development launcher after installing it."
    }

    Set-Phase "running_services"
    $deviceSerial = Get-AvdDeviceSerial -AdbExe $adb -ExpectedAvdName $AvdName
    if ($null -eq $deviceSerial) {
        throw "Android Virtual Device '$AvdName' is not running. Use run_android_local_development.cmd first."
    }
    $bootCompleted = (& $adb -s $deviceSerial shell getprop sys.boot_completed 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $bootCompleted -ne "1") {
        throw "Android Virtual Device '$AvdName' is not ready."
    }
    if (-not (Test-BackendReady -Port $ApiPort)) {
        throw "The Sorting Puzzle backend is not ready on port $ApiPort. Use run_android_local_development.cmd first."
    }

    Set-Phase "content_provenance"
    Invoke-GodotCommand $GodotPath @(
        "--headless",
        "--path",
        $gameRoot,
        "--script",
        "scripts/tools/check_content_provenance.gd"
    ) $gameRoot "content-provenance-check"

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
    ) $gameRoot "android-redeploy-export"

    Set-Phase "android_install"
    Set-AdbReverse `
        -AdbExe $adb `
        -DeviceSerial $deviceSerial `
        -HostPort $ApiPort
    & $adb -s $deviceSerial shell am force-stop $PackageName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to stop $PackageName on $deviceSerial."
    }
    & $adb -s $deviceSerial install -r $apkPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install the updated APK on $deviceSerial."
    }

    Set-Phase "android_restart"
    & $adb -s $deviceSerial shell monkey `
        -p $PackageName `
        -c android.intent.category.LAUNCHER `
        1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to launch $PackageName on $deviceSerial."
    }

    $launchDeadline = (Get-Date).AddSeconds($LaunchTimeoutSeconds)
    $gameProcessId = ""
    while ((Get-Date) -lt $launchDeadline) {
        $pidOutput = & $adb -s $deviceSerial shell pidof $PackageName 2>$null
        if ($null -eq $pidOutput) {
            $gameProcessId = ""
        } else {
            $gameProcessId = "$pidOutput".Trim()
        }
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gameProcessId)) {
            break
        }
        Start-Sleep -Milliseconds 500
    }
    if ([string]::IsNullOrWhiteSpace($gameProcessId)) {
        throw "The updated game process did not start within ${LaunchTimeoutSeconds}s."
    }

    Set-Phase "complete"
    Write-Host ""
    Write-Host "Updated Sorting Puzzle build is running on '$AvdName' ($deviceSerial)."
    Write-Host "Android process id: $gameProcessId"
    Write-Host "APK: $apkPath"
    Write-Host "Emulator app data was preserved."
} catch {
    Write-Error "[android-redeploy] FAIL phase=$currentPhase message=$($_.Exception.Message)"
    exit 1
}

exit 0
