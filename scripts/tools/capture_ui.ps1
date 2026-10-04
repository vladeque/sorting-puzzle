<#
.SYNOPSIS
Captures a scene at the project's responsive resolutions and builds a single contact sheet.

.DESCRIPTION
Renders the requested scene through a windowed isolated Godot run and writes one PNG per resolution
to tmp/ui_capture, then stitches them into <name>_contact_sheet.png so every resolution can be
reviewed in one image.

Capture requires a windowed run: a headless Godot resolves the viewport texture to null and produces
no image at all, which is why this wrapper always passes -Windowed.

.EXAMPLE
& .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/shop_screen.tscn -Name shop

.EXAMPLE
& .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/shelf_lock_overlay.tscn `
    -Setup scripts/tools/captures/shelf_lock_overlay_setup.gd -Background '#2b2f3a'
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Scene,

    [string]$Name,

    [string]$Locale,

    [string[]]$Resolutions = @(),

    [string]$Setup,

    [string]$Background,

    [string]$Position,

    [double]$Zoom = 0,

    [int]$Settle = 0,

    [string]$OutputDirectory,

    [string]$GodotPath = 'D:\Godot\godot.exe',

    [string]$MagickPath,

    [switch]$NoMontage,

    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function ConvertTo-ProjectRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return ($Path -replace '^res://', '') -replace '\\', '/'
}

function Resolve-MagickExecutable {
    param([string]$Preferred)

    if ($Preferred) {
        if (-not (Test-Path -LiteralPath $Preferred -PathType Leaf)) {
            throw "ImageMagick was not found at the requested path: $Preferred"
        }
        return $Preferred
    }

    $command = Get-Command 'magick' -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    # Verified location recorded in AGENTS.md for this workspace.
    $fallback = 'C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe'
    if (Test-Path -LiteralPath $fallback -PathType Leaf) {
        return $fallback
    }

    return $null
}

$sceneRelativePath = ConvertTo-ProjectRelativePath -Path $Scene
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $sceneRelativePath) -PathType Leaf)) {
    throw "Scene to capture was not found in the project: $sceneRelativePath"
}

if (-not $Name) {
    $Name = [System.IO.Path]::GetFileNameWithoutExtension($sceneRelativePath)
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot 'tmp\ui_capture'
}
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Capture output is review material, not game content. A .gdignore keeps Godot from importing these
# PNGs and littering the project with .import siblings on every capture run.
$gdignorePath = Join-Path $OutputDirectory '.gdignore'
if (-not (Test-Path -LiteralPath $gdignorePath)) {
    New-Item -ItemType File -Path $gdignorePath | Out-Null
}

$manifestPath = Join-Path $OutputDirectory "$($Name)_manifest.json"
$contactSheetPath = Join-Path $OutputDirectory "$($Name)_contact_sheet.png"

# Remove exactly what the previous run recorded, so a capture that now produces fewer resolutions
# cannot leave stale PNGs behind for review.
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $previousManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($previousCapture in @($previousManifest.captures)) {
        if ($previousCapture.path -and (Test-Path -LiteralPath $previousCapture.path -PathType Leaf)) {
            Remove-Item -LiteralPath $previousCapture.path -Force
        }
    }
    Remove-Item -LiteralPath $manifestPath -Force
}
if (Test-Path -LiteralPath $contactSheetPath -PathType Leaf) {
    Remove-Item -LiteralPath $contactSheetPath -Force
}

$userArguments = @(
    '--scene', "res://$sceneRelativePath",
    '--out', ($OutputDirectory -replace '\\', '/'),
    '--name', $Name
)
if ($Resolutions.Count -gt 0) {
    $userArguments += @('--resolutions', ($Resolutions -join ','))
}
if ($Locale) {
    $userArguments += @('--locale', $Locale)
}
if ($Setup) {
    $setupRelativePath = ConvertTo-ProjectRelativePath -Path $Setup
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $setupRelativePath) -PathType Leaf)) {
        throw "Capture setup script was not found in the project: $setupRelativePath"
    }
    $userArguments += @('--setup', "res://$setupRelativePath")
}
if ($Background) {
    $userArguments += @('--background', $Background)
}
if ($Position) {
    $userArguments += @('--position', $Position)
}
if ($Zoom -gt 0) {
    $userArguments += @('--zoom', $Zoom.ToString([System.Globalization.CultureInfo]::InvariantCulture))
}
if ($Settle -gt 0) {
    $userArguments += @('--settle', "$Settle")
}

$runnerPath = Join-Path $PSScriptRoot 'run_isolated_godot_test.ps1'
$runnerParameters = @{
    Script = 'scripts/tools/capture_scene.gd'
    GodotPath = $GodotPath
    UserArguments = $userArguments
    Windowed = $true
}
if ($KeepArtifacts) {
    $runnerParameters['KeepArtifacts'] = $true
}

& $runnerPath @runnerParameters
$runnerExitCode = $LASTEXITCODE

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Capture produced no manifest at $manifestPath (Godot exited with $runnerExitCode)."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$captures = @($manifest.captures)
$failures = @($manifest.failures)

foreach ($capture in $captures) {
    if ($capture.requested -ne $capture.actual) {
        Write-Warning ("Requested $($capture.requested) but the window manager produced " +
            "$($capture.actual); this capture does not represent the requested resolution.")
    }
    Write-Output "Captured $($capture.actual) -> $($capture.path)"
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "Scene capture reported $($failures.Count) failure(s)."
}

if ($captures.Count -eq 0) {
    throw 'Scene capture produced no images.'
}

if ($NoMontage) {
    exit 0
}

$magick = Resolve-MagickExecutable -Preferred $MagickPath
if (-not $magick) {
    Write-Warning 'ImageMagick was not found; skipping the contact sheet. Individual PNGs are ready.'
    exit 0
}

# One row, each resolution normalised to the same height, so a single image stays readable while the
# individual PNGs remain available at full size for detail work.
$montageArguments = @(
    'montage',
    '-background', '#1b1d23',
    '-fill', '#e8eaf0',
    '-pointsize', '16',
    '-label', '%f'
)
$montageArguments += ($captures | ForEach-Object { $_.path })
$montageArguments += @('-tile', 'x1', '-geometry', 'x900+12+12', $contactSheetPath)

& $magick @montageArguments
if ($LASTEXITCODE -ne 0) {
    throw "ImageMagick montage failed with exit code $LASTEXITCODE."
}

Write-Output "Contact sheet: $contactSheetPath"
exit 0
