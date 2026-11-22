<#
.SYNOPSIS
    Builds Nostalgia Player release package (zip) for GitHub Releases.
.DESCRIPTION
    Compiles release binary, copies exe + installers + README to a staging
    folder, and zips everything into dist/NostalgiaPlayer-<version>-win64.zip
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root

Write-Host "=== Nostalgia Player release builder ===" -ForegroundColor Cyan

# --- 1. Read version from Cargo.toml ---
$cargoToml = Get-Content "$root\Cargo.toml" -Raw
if ($cargoToml -match 'version\s*=\s*"([^"]+)"') {
    $version = $matches[1]
} else {
    $version = "0.0.0"
}
Write-Host "Version: $version" -ForegroundColor Yellow

# --- 2. Build release binary ---
Write-Host "Building release binary..." -ForegroundColor Yellow
cmd /c "cargo build --release 2>nul"
Write-Host "Build OK." -ForegroundColor Green

# --- 3. Prepare staging directory ---
$exe = "$root\target\release\kirech-media-player.exe"
if (-not (Test-Path $exe)) { Write-Error "Built exe not found at $exe"; exit 1 }

$stagingDir = "$root\dist\NostalgiaPlayer-$version-win64"
if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# --- 4. Copy files ---
Copy-Item $exe "$stagingDir\kirech-media-player.exe"
Copy-Item "$root\installer\install.ps1"  $stagingDir
Copy-Item "$root\installer\install.bat"  $stagingDir
Copy-Item "$root\installer\uninstall.ps1" $stagingDir
Copy-Item "$root\installer\uninstall.bat" $stagingDir
Copy-Item "$root\README.md" $stagingDir
Copy-Item "$root\docs\screenshot.png" $stagingDir
Write-Host "Staged files in $stagingDir" -ForegroundColor Green

# --- 5. Create zip ---
$zipPath = "$root\dist\NostalgiaPlayer-$version-win64.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath
$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host ("Created {0} ({1:N2} MB)" -f $zipPath, $zipSize) -ForegroundColor Green

Pop-Location
Write-Host ""
Write-Host "=== Release package ready ===" -ForegroundColor Cyan
Write-Host $zipPath
