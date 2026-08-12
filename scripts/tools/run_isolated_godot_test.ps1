[CmdletBinding(DefaultParameterSetName = 'Scene')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Scene')]
    [string]$Scene,

    [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
    [string]$Script,

    [string]$GodotPath = 'D:\Godot\godot.exe',

    [string[]]$GodotArguments = @(),

    [string[]]$UserArguments = @(),

    [switch]$Windowed,

    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$testId = [guid]::NewGuid().ToString('N')
$testProjectName = "SortingPuzzleTest_$testId"
$scratchParent = [System.IO.Path]::GetTempPath()
$scratchRoot = Join-Path $scratchParent "sorting-puzzle-godot-$testId"
$userDataParent = Join-Path $env:APPDATA 'Godot\app_userdata'
$userDataPath = Join-Path $userDataParent $testProjectName
$exitCode = 1
$junctionPaths = @()
$stdoutPath = $null
$stderrPath = $null

function Assert-SafeCleanupPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedParent,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedLeafPrefix
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullParent = [System.IO.Path]::GetFullPath($ExpectedParent).TrimEnd('\') + '\'
    $leaf = Split-Path -Leaf $fullPath
    if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing cleanup outside $fullParent`: $fullPath"
    }
    if (-not $leaf.StartsWith($ExpectedLeafPrefix, [System.StringComparison]::Ordinal)) {
        throw "Refusing cleanup for unexpected directory name: $fullPath"
    }
}

try {
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot executable was not found: $GodotPath"
    }

    $target = if ($PSCmdlet.ParameterSetName -eq 'Script') { $Script } else { $Scene }
    $relativeTarget = $target -replace '^res://', ''
    $sourceTarget = Join-Path $projectRoot $relativeTarget
    if (-not (Test-Path -LiteralPath $sourceTarget -PathType Leaf)) {
        throw "Godot test target was not found in the project: $target"
    }

    New-Item -ItemType Directory -Path $scratchRoot | Out-Null
    Get-ChildItem -LiteralPath $projectRoot -File -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $scratchRoot
    }
    $importCache = Join-Path $projectRoot '.godot'
    if (Test-Path -LiteralPath $importCache -PathType Container) {
        Copy-Item -LiteralPath $importCache -Destination $scratchRoot -Recurse
    }

    $projectFile = Join-Path $scratchRoot 'project.godot'
    $projectText = [System.IO.File]::ReadAllText($projectFile)
    $originalName = 'config/name="SortingPuzzle"'
    if (-not $projectText.Contains($originalName)) {
        throw 'Could not find the expected project name in project.godot.'
    }
    $projectText = $projectText.Replace($originalName, "config/name=`"$testProjectName`"")
    [System.IO.File]::WriteAllText(
        $projectFile,
        $projectText,
        [System.Text.UTF8Encoding]::new($false)
    )

    $resourceDirectories = @('addons', 'assets', 'configs', 'platform', 'scenes', 'scripts', 'tests')
    foreach ($directoryName in $resourceDirectories) {
        $sourceDirectory = Join-Path $projectRoot $directoryName
        if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
            continue
        }
        $junctionPath = Join-Path $scratchRoot $directoryName
        New-Item -ItemType Junction -Path $junctionPath -Target $sourceDirectory | Out-Null
        $junctionPaths += $junctionPath
    }

    $godotTarget = "res://$($relativeTarget.Replace('\', '/'))"
    # Screenshot capture needs a real display server: a headless run resolves
    # get_viewport().get_texture() to a null texture and silently produces no image.
    $arguments = @()
    if (-not $Windowed) {
        $arguments += '--headless'
    }
    $arguments += @('--path', $scratchRoot) + $GodotArguments
    if ($PSCmdlet.ParameterSetName -eq 'Script') {
        $arguments += @('--script', $godotTarget)
    } else {
        $arguments += $godotTarget
    }
    # Everything after the separator reaches the target through OS.get_cmdline_user_args().
    if ($UserArguments.Count -gt 0) {
        $arguments += @('--') + $UserArguments
    }

    $modeLabel = if ($Windowed) { 'windowed' } else { 'headless' }
    Write-Output "Running isolated Godot test ($modeLabel) in $scratchRoot"
    $processArguments = @{
        FilePath = $GodotPath
        ArgumentList = $arguments
        NoNewWindow = $true
        Wait = $true
        PassThru = $true
    }
    # A windowed run normally uses Godot's GUI binary, which never attaches to this console. Without
    # redirection its engine errors -- script parse failures above all -- would be lost entirely.
    # Headless runs keep writing straight to the console so existing tests stream output unchanged.
    if ($Windowed) {
        $stdoutPath = Join-Path $scratchParent "sorting-puzzle-godot-$testId-stdout.txt"
        $stderrPath = Join-Path $scratchParent "sorting-puzzle-godot-$testId-stderr.txt"
        $processArguments['RedirectStandardOutput'] = $stdoutPath
        $processArguments['RedirectStandardError'] = $stderrPath
    }
    $process = Start-Process @processArguments
    $exitCode = $process.ExitCode
    foreach ($outputPath in @($stdoutPath, $stderrPath)) {
        if ($outputPath -and (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            Get-Content -LiteralPath $outputPath | ForEach-Object { Write-Output $_ }
            Remove-Item -LiteralPath $outputPath -Force
        }
    }
}
finally {
    if ($KeepArtifacts) {
        Write-Output "Kept isolated project: $scratchRoot"
        if (Test-Path -LiteralPath $userDataPath) {
            Write-Output "Kept isolated user data: $userDataPath"
        }
    } else {
        if (Test-Path -LiteralPath $scratchRoot) {
            $cleanupArguments = @{
                Path = $scratchRoot
                ExpectedParent = $scratchParent
                ExpectedLeafPrefix = 'sorting-puzzle-godot-'
            }
            Assert-SafeCleanupPath @cleanupArguments
            foreach ($junctionPath in $junctionPaths) {
                if (Test-Path -LiteralPath $junctionPath) {
                    # PowerShell 5.1 can throw a NullReferenceException for Remove-Item on
                    # directory junctions. Directory.Delete removes the junction itself and
                    # does not recurse into its target.
                    [System.IO.Directory]::Delete($junctionPath, $false)
                }
            }
            Remove-Item -LiteralPath $scratchRoot -Recurse -Force
        }
        if (Test-Path -LiteralPath $userDataPath) {
            $cleanupArguments = @{
                Path = $userDataPath
                ExpectedParent = $userDataParent
                ExpectedLeafPrefix = 'SortingPuzzleTest_'
            }
            Assert-SafeCleanupPath @cleanupArguments
            Remove-Item -LiteralPath $userDataPath -Recurse -Force
        }
    }
}

exit $exitCode
