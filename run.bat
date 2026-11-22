@echo off
setlocal
cd /d "%~dp0"

if not exist "target\release\kirech-media-player.exe" (
    echo Building Kirech Media Player 8...
    cargo build --release || goto :error
)

start "" "target\release\kirech-media-player.exe"
exit /b 0

:error
echo.
echo Build failed. See the output above.
pause
exit /b 1
