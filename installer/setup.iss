; ============================================================
; Nostalgia Player — Inno Setup script
; Compiles to: NostalgiaPlayer-Setup.exe
; Compiler: "C:\Users\киря\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
; ============================================================

#define MyAppName "Nostalgia Player"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Kirech Media Player"
#define MyAppURL "https://github.com/kirech001/kirech-media-player"
#define MyAppExeName "kirech-media-player.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableWelcomePage=no
DisableFinishedPage=no
OutputDir=output
OutputBaseFilename=NostalgiaPlayer-{#MyAppVersion}-Setup
SetupIconFile=app.ico
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
ChangesAssociations=yes
Uninstallable=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "assoc_audio"; Description: "Associate with audio files"; GroupDescription: "File associations:"; Flags: unchecked
Name: "assoc_video"; Description: "Associate with video files"; GroupDescription: "File associations:"; Flags: unchecked

[Files]
Source: "..\target\release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{commonprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Registry]
; File associations for audio
Root: HKCU; Subkey: "Software\Classes\NostalgiaPlayer.File"; ValueType: string; ValueName: ""; ValueData: "Nostalgia Player Media File"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\NostalgiaPlayer.File\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\NostalgiaPlayer.File\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

Root: HKCU; Subkey: "Software\Classes\.mp3"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.wav"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.flac"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.ogg"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.oga"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.opus"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.m4a"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.aac"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio
Root: HKCU; Subkey: "Software\Classes\.wma"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_audio

; File associations for video
Root: HKCU; Subkey: "Software\Classes\.mp4"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.m4v"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.webm"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.mkv"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.avi"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.wmv"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.mov"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.mpg"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video
Root: HKCU; Subkey: "Software\Classes\.mpeg"; ValueType: string; ValueName: ""; ValueData: "NostalgiaPlayer.File"; Flags: uninsdeletevalue; Tasks: assoc_video



[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
procedure CurStepChanged(CurStep: TSetupStep);
var
  ErrorCode: Integer;
begin
  // Windows 8+ protects the UserChoice registry key, so we cannot set
  // the default player programmatically. Instead we registered our ProgId;
  // now open the system "Default apps" page so the user can confirm with
  // two clicks. Only when association tasks were selected.
  if CurStep = ssPostInstall then
  begin
    if IsTaskSelected('assoc_audio') or IsTaskSelected('assoc_video') then
      ShellExecAsOriginalUser('open', 'ms-settings:defaultapps', '', '',
        SW_SHOWNORMAL, ewNoWait, ErrorCode);
  end;
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: dirifempty; Name: "{group}"

