@echo off
REM ============================================================
REM   LIMER RUN SCRIPT
REM   Run Limer in development mode
REM ============================================================

REM Limer targets the Limekit 2.0 engine (app.json declares "api": "2.0").
REM The old `python -c "from limekit import runner"` starts the 1.x engine,
REM which injects flat globals and has no module system -- Limer would die on
REM its first require("limekit.ui").
cd /d "%~dp0"
python -m limekit .
pause
