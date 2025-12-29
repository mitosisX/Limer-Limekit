@echo off
REM ============================================================
REM   LIMER BUILD SCRIPT
REM   Double-click this file to build Limer into an executable
REM ============================================================

echo.
echo ============================================================
echo   LIMER BUILD SYSTEM
echo ============================================================
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ and try again
    pause
    exit /b 1
)

REM Run the build script with console mode (easier debugging)
python build.py --console --clean

echo.
echo ============================================================
if errorlevel 1 (
    echo   BUILD FAILED - See errors above
) else (
    echo   BUILD COMPLETE - Check the 'dist' folder
)
echo ============================================================
echo.
pause
