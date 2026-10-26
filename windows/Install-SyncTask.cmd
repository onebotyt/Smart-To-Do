@echo off
title Installing SyncTask...
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-SyncTask.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Installation failed with exit code %ERRORLEVEL%.
    pause
)
