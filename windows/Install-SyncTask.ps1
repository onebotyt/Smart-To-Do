# Install-SyncTask.ps1 - Windows App Installer for SyncTask
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "       Installing SyncTask on Windows" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$sourceDir = $PSScriptRoot
$targetDir = Join-Path $env:LOCALAPPDATA "Programs\SyncTask"

Write-Host "[1/4] Preparing installation directory: $targetDir" -ForegroundColor Green
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

Write-Host "[2/4] Copying application files..." -ForegroundColor Green
Get-ChildItem -Path $sourceDir -Exclude "Install-SyncTask.*" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $targetDir -Recurse -Force
}

$exePath = Join-Path $targetDir "synctask.exe"
if (-not (Test-Path $exePath)) {
    Write-Warning "synctask.exe was not found in $targetDir, checking root source..."
}

Write-Host "[3/4] Creating Desktop and Start Menu shortcuts..." -ForegroundColor Green
$ws = New-Object -ComObject WScript.Shell

# Desktop shortcut
$desktopDir = [Environment]::GetFolderPath('Desktop')
$desktopShortcutPath = Join-Path $desktopDir "SyncTask.lnk"
$desktopShortcut = $ws.CreateShortcut($desktopShortcutPath)
$desktopShortcut.TargetPath = $exePath
$desktopShortcut.WorkingDirectory = $targetDir
$desktopShortcut.IconLocation = "$exePath,0"
$desktopShortcut.Description = "SyncTask - Local-First Task Manager"
$desktopShortcut.Save()
Write-Host "  -> Created: $desktopShortcutPath" -ForegroundColor DarkGray

# Start Menu Programs shortcut
$programsDir = [Environment]::GetFolderPath('Programs')
$startMenuShortcutPath = Join-Path $programsDir "SyncTask.lnk"
$startMenuShortcut = $ws.CreateShortcut($startMenuShortcutPath)
$startMenuShortcut.TargetPath = $exePath
$startMenuShortcut.WorkingDirectory = $targetDir
$startMenuShortcut.IconLocation = "$exePath,0"
$startMenuShortcut.Description = "SyncTask - Local-First Task Manager"
$startMenuShortcut.Save()
Write-Host "  -> Created: $startMenuShortcutPath" -ForegroundColor DarkGray

Write-Host "[4/4] Registering in Windows Installed Apps..." -ForegroundColor Green
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SyncTask"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "SyncTask"
Set-ItemProperty -Path $regPath -Name "DisplayIcon" -Value "$exePath,0"
Set-ItemProperty -Path $regPath -Name "DisplayVersion" -Value "0.1.0"
Set-ItemProperty -Path $regPath -Name "Publisher" -Value "Girdhar Dhami (OneBotYT)"
Set-ItemProperty -Path $regPath -Name "InstallLocation" -Value $targetDir
Set-ItemProperty -Path $regPath -Name "UninstallString" -Value "powershell.exe -NoProfile -Command Remove-Item -Recurse -Force '$targetDir'; Remove-Item -Force '$desktopShortcutPath'; Remove-Item -Force '$startMenuShortcutPath'; Remove-Item -Recurse -Force '$regPath'"

Write-Host "[*] Configuring Windows Firewall for Wi-Fi Sync..." -ForegroundColor Green
try {
    Start-Process -FilePath "netsh" -ArgumentList "advfirewall firewall add rule name=`"SyncTask Sync Service (TCP)`" dir=in action=allow program=`"$exePath`" enable=yes profile=any" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    Start-Process -FilePath "netsh" -ArgumentList "advfirewall firewall add rule name=`"SyncTask Discovery (UDP)`" dir=in action=allow program=`"$exePath`" enable=yes profile=any" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
} catch {}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "       Installation Complete!" -ForegroundColor Cyan
Write-Host "       Launching SyncTask..." -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

if (Test-Path $exePath) {
    Start-Process -FilePath $exePath -WorkingDirectory $targetDir
}
