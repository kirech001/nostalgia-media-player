#requires -RunAsAdministrator
<#
.SYNOPSIS
    Nostalgia Player — Windows installer (PowerShell)
.DESCRIPTION
    Installs Nostalgia Player to Program Files, creates a desktop shortcut,
    registers the app as default handler for common audio/video extensions,
    and adds an entry in the Start menu.
.NOTES
    Run this script elevated (right-click → Run as administrator) or via
    install.bat which self-elevates.
#>

$ErrorActionPreference = 'Stop'

$appName            = "Nostalgia Player"
$srcExe             = Join-Path $PSScriptRoot "kirech-media-player.exe"
$installDir         = Join-Path $env:ProgramFiles $appName
$destExe            = Join-Path $installDir "kirech-media-player.exe"
$desktopShortcut    = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
$startMenuShortcut  = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\$appName.lnk"

Write-Host "=== Nostalgia Player Installer ===" -ForegroundColor Cyan

# --- 1. Verify source exe exists ---
if (-not (Test-Path $srcExe)) {
    Write-Error "Source executable not found: $srcExe`nPlace kirech-media-player.exe next to this script."
    exit 1
}

# --- 2. Create install directory ---
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Host "Created install directory: $installDir" -ForegroundColor Green
}

# --- 3. Copy executable ---
Copy-Item -Path $srcExe -Destination $destExe -Force
Write-Host "Installed: $destExe" -ForegroundColor Green

# --- 4. Create desktop shortcut ---
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut($desktopShortcut)
$shortcut.TargetPath = $destExe
$shortcut.WorkingDirectory = $installDir
$shortcut.Description = "Nostalgia Player — Windows XP era media player"
$shortcut.IconLocation = $destExe
$shortcut.Save()
Write-Host "Desktop shortcut created." -ForegroundColor Green

# --- 5. Create Start Menu shortcut ---
$startMenuDir = Split-Path $startMenuShortcut -Parent
if (-not (Test-Path $startMenuDir)) {
    New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
}
$smShortcut = $ws.CreateShortcut($startMenuShortcut)
$smShortcut.TargetPath = $destExe
$smShortcut.WorkingDirectory = $installDir
$smShortcut.Description = "Nostalgia Player — Windows XP era media player"
$smShortcut.IconLocation = $destExe
$smShortcut.Save()
Write-Host "Start Menu shortcut created." -ForegroundColor Green

# --- 6. Register file associations (default handler for audio/video) ---
$audioExts = @(".mp3", ".wav", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".aac", ".wma")
$videoExts = @(".mp4", ".m4v", ".webm", ".mkv", ".avi", ".wmv", ".mov", ".mpg", ".mpeg")
$allExts   = $audioExts + $videoExts

$progId = "NostalgiaPlayer.File"
$regBase = "HKCU:\Software\Classes\$progId"

# Set ProgId description and icon
New-Item -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name "" -Value "Nostalgia Player Media File" -Force
New-Item -Path "$regBase\DefaultIcon" -Force | Out-Null
Set-ItemProperty -Path "$regBase\DefaultIcon" -Name "" -Value "$destExe,0" -Force
New-Item -Path "$regBase\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "$regBase\shell\open\command" -Name "" -Value """$destExe`" `"%1`"" -Force

# UserChoice for each extension (makes it the default handler)
foreach ($ext in $allExts) {
    $ucPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
    New-Item -Path $ucPath -Force | Out-Null
    Set-ItemProperty -Path $ucPath -Name "ProgId" -Value $progId -Force
}

Write-Host "File associations registered for: $($allExts -join ', ')" -ForegroundColor Green

# --- 7. Done ---
Write-Host ""
Write-Host "=== Installation complete ===" -ForegroundColor Cyan
Write-Host "You can now launch Nostalgia Player from the desktop shortcut or Start Menu."
Write-Host "It is registered as the default player for: $($allExts -join ', ')"
Write-Host ""
Read-Host "Press Enter to exit"
