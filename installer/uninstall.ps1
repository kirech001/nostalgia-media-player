<#
.SYNOPSIS
    Nostalgia Player — uninstaller (PowerShell)
#>

$ErrorActionPreference = 'Stop'
$appName            = "Nostalgia Player"
$installDir         = Join-Path $env:ProgramFiles $appName
$desktopShortcut    = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
$startMenuShortcut  = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\$appName.lnk"

Write-Host "=== Nostalgia Player Uninstaller ===" -ForegroundColor Cyan

# --- 1. Kill running process if any ---
Get-Process kirech-media-player -ErrorAction SilentlyContinue | ForEach-Object {
    $_.Kill(); $_.WaitForExit(2000)
}

# --- 2. Remove shortcuts ---
if (Test-Path $desktopShortcut)   { Remove-Item $desktopShortcut -Force;   Write-Host "Desktop shortcut removed." -ForegroundColor Green }
if (Test-Path $startMenuShortcut) { Remove-Item $startMenuShortcut -Force; Write-Host "Start Menu shortcut removed." -ForegroundColor Green }

# --- 3. Remove install directory ---
if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-Host "Install directory removed." -ForegroundColor Green
}

# --- 4. Remove file associations ---
$audioExts = @(".mp3", ".wav", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".aac", ".wma")
$videoExts = @(".mp4", ".m4v", ".webm", ".mkv", ".avi", ".wmv", ".mov", ".mpg", ".mpeg")
$allExts   = $audioExts + $videoExts

foreach ($ext in $allExts) {
    $ucPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
    if (Test-Path $ucPath) {
        $current = (Get-ItemProperty -Path $ucPath -ErrorAction SilentlyContinue).ProgId
        if ($current -eq "NostalgiaPlayer.File") {
            Remove-Item -Path $ucPath -Force
        }
    }
}

# Remove ProgId
$regBase = "HKCU:\Software\Classes\NostalgiaPlayer.File"
if (Test-Path $regBase) { Remove-Item -Path $regBase -Recurse -Force }

Write-Host "File associations removed." -ForegroundColor Green

Write-Host ""
Write-Host "=== Uninstall complete ===" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
