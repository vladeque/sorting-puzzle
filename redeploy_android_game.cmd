@echo off
setlocal

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tools\redeploy_android_game.ps1"
set "redeploy_exit_code=%ERRORLEVEL%"

if not "%redeploy_exit_code%"=="0" (
    echo.
    echo Sorting Puzzle Android redeploy failed. Review the error above.
    pause
)

exit /b %redeploy_exit_code%
