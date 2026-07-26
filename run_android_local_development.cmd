@echo off
setlocal

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tools\run_android_local_development.ps1"
set "launcher_exit_code=%ERRORLEVEL%"

if not "%launcher_exit_code%"=="0" (
    echo.
    echo Sorting Puzzle local Android launch failed. Review the error above.
    pause
)

exit /b %launcher_exit_code%
