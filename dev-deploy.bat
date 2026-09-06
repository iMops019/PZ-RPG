@echo off
REM Double-click to deploy PZ RPG into the game's mod folder and enable it.
REM Pass through any flags, e.g.  dev-deploy.bat -Launch -Debug
powershell -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
pause
