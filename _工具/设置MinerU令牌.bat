@echo off
chcp 65001 >nul
title Save MinerU Token

set "TOKEN_FILE=%~dp0mineru_token.txt"

echo ================================================
echo   Save MinerU Token (free account: https://mineru.net)
echo   After login: API Token -^> Create Token -^> Copy
echo ================================================
echo.
set /p "TOKEN=Paste Token: "
if "%TOKEN%"=="" (
    echo No token entered. Exiting.
    pause
    exit /b 1
)

> "%TOKEN_FILE%" echo %TOKEN%
echo.
echo Saved to %TOKEN_FILE%
pause
