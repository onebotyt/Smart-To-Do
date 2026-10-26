@echo off
title Installing SyncTask...
echo ==============================================
echo Installing SyncTask on your PC...
echo ==============================================

set "TARGET_DIR=%LOCALAPPDATA%\Programs\SyncTask"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

echo Copying files to %TARGET_DIR%...
xcopy /E /Y /I "%~dp0*" "%TARGET_DIR%\" >nul

echo Creating Desktop and Start Menu Shortcuts...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ws = New-Object -ComObject WScript.Shell; ^
   $sDesktop = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\SyncTask.lnk'); ^
   $sDesktop.TargetPath = '%TARGET_DIR%\synctask.exe'; ^
   $sDesktop.IconLocation = '%TARGET_DIR%\synctask.exe,0'; ^
   $sDesktop.Save(); ^
   $sStart = $ws.CreateShortcut([Environment]::GetFolderPath('StartMenu') + '\Programs\SyncTask.lnk'); ^
   $sStart.TargetPath = '%TARGET_DIR%\synctask.exe'; ^
   $sStart.IconLocation = '%TARGET_DIR%\synctask.exe,0'; ^
   $sStart.Save();"

echo ==============================================
echo Installation Complete!
echo Launching SyncTask...
echo ==============================================
start "" "%TARGET_DIR%\synctask.exe"
