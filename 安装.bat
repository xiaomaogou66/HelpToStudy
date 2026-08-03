@echo off
title AI Learning Workflow - One-Click Install

echo ================================================
echo   AI Learning Workflow - One-Click Install
echo   Starting the installer...
echo ================================================
echo.

rem Run install.ps1 bypassing the PowerShell execution policy.
rem The bypass applies to this invocation only and changes no system settings.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*

echo.
if errorlevel 1 (
    echo [FAILED] Installation failed. Please send the error messages above to the AI.
) else (
    echo [DONE] Installation finished.
)
echo.
pause
