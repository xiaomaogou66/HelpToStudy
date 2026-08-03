@echo off
title AI Learning Workflow - Environment Setup

echo ================================================
echo   AI Learning Workflow - Environment Setup
echo   Check and install: Python, Node.js, Git,
echo   Claude Code, cc-switch
echo   Version source priority: winget ^> official API ^> built-in list
echo ================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0environment.ps1" %*

echo.
if errorlevel 1 (
    echo [FAILED] Something went wrong. Please send the messages above to the AI.
) else (
    echo [DONE] Environment setup finished.
)
echo.
pause
