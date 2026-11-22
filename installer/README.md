# Nostalgia Player — Installer

This folder contains everything needed to build and distribute a Windows
installer for Nostalgia Player.

## Files

| File | Purpose |
|------|---------|
| `install.ps1` | Main installer script (PowerShell). Copies exe to Program Files, creates desktop + Start Menu shortcuts, registers file associations. |
| `install.bat` | Launcher for `install.ps1` that self-elevates to administrator. |
| `uninstall.ps1` | Removes program files, shortcuts and file associations. |
| `uninstall.bat` | Launcher for `uninstall.ps1` that self-elevates. |
| `make-release.ps1` | Build script: compiles the release exe and packages everything into a distributable zip. |

## Building a release package

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File installer\make-release.ps1
```

This produces:

```
dist\NostalgiaPlayer-<version>-win64.zip
```

Upload this zip to GitHub Releases. Users download it, extract, and run
`install.bat` (right-click → Run as administrator if UAC prompts).

## What the installer does

1. Copies `kirech-media-player.exe` to `C:\Program Files\Nostalgia Player\`
2. Creates a desktop shortcut
3. Creates a Start Menu shortcut
4. Registers the app as the default handler for common audio/video extensions:
   - Audio: `.mp3 .wav .flac .ogg .oga .opus .m4a .aac .wma`
   - Video: `.mp4 .m4v .webm .mkv .avi .wmv .mov .mpg .mpeg`
5. Adds a ProgId `NostalgiaPlayer.File` so file associations work cleanly

## What the uninstaller does

Removes everything the installer created (shortcuts, install directory,
file associations that still point to Nostalgia Player).

## Notes

- The app itself is a single portable `.exe` and does not require
  installation to run — users can just run `kirech-media-player.exe` directly.
- WebView2 Runtime is required (preinstalled on Windows 11 and most Windows 10
  systems via Edge). The installer does NOT install WebView2; if the target
  machine lacks it, download from Microsoft or install via winget:
  `winget install Microsoft.EdgeWebView2Runtime`.
