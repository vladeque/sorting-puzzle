[CmdletBinding()]
param(
    [string]$GodotPath = 'D:\Godot\godot.exe'
)

# Run the standalone listening scene with disposable user data, so previewing never touches the
# normal game's save. Close the Godot window to finish and clean up the isolated project.
& (Join-Path $PSScriptRoot 'run_isolated_godot_test.ps1') `
    -Scene 'scenes/testing/music_loop_preview.tscn' `
    -GodotPath $GodotPath `
    -Windowed
