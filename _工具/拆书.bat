@echo off
chcp 65001 >nul
set "SPLIT_OUTPUT_ENCODING=utf-8"
title Textbook Splitter - Split by Chapter

rem ==== All paths below are relative to this file, so the vault can be
rem       moved, copied or used on another computer without re-installing ====
set "VAULT=%~dp0.."
set "SCRIPT=%~dp0split_textbook.py"
set "OUT=%VAULT%\04-教材分块"
set "REQ=%~dp0requirements.txt"

rem ==== Pick Python: venv first, then python on PATH ====
if exist "%~dp0.venv\Scripts\python.exe" (
    set "PY=%~dp0.venv\Scripts\python.exe"
) else (
    set "PY=python"
)

echo ================================================
echo   Textbook Splitter: split by chapter
echo   Supports PDF / EPUB / Word (.docx)
echo ================================================
echo.

rem Method 1: drag the file onto this bat icon
set "FILE=%~1"
if defined FILE goto run

rem Method 2: paste the path into this window
echo Please drag the textbook file into this window, then press Enter:
set /p "FILE="
set "FILE=%FILE:"=%

:run
if not defined FILE set "FILE="
if "%FILE%"=="" (
    echo.
    echo No file path given. Exiting.
    pause
    exit /b 1
)

rem ==== Check Python and dependencies ====
"%PY%" -c "import sys" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Python not found. Please run the installer once on this computer,
    echo         or install Python 3.10+ from https://www.python.org/downloads/
    pause
    exit /b 1
)
"%PY%" -c "import pdfplumber, pypdf, docx, lxml" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Missing dependencies. Install them with:
    echo   "%PY%" -m pip install -r "%REQ%"
    echo or run the installer again to create _工具\.venv automatically.
    pause
    exit /b 1
)

echo.
echo Processing: %FILE%
echo Output: %OUT%
echo.

"%PY%" "%SCRIPT%" "%FILE%" --out "%OUT%"

if errorlevel 1 goto fail
echo.
echo [OK] Done! Files are in "%OUT%".
echo.
pause
exit /b 0

:fail
echo.
echo [FAILED] Please send the error messages above to the AI.
echo.
pause
exit /b 1
