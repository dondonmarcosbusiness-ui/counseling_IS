; Inno Setup script for Counseling IS (per-user, no admin required).
; Compile through scripts/build_windows_installer.ps1, which passes the
; version from pubspec.yaml:
;
;   powershell -ExecutionPolicy Bypass -File scripts\build_windows_installer.ps1
;
; Manual compilation (version defaults to 0.0.0):
;   ISCC scripts\windows_installer.iss

#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif

#define MyAppName "Counseling IS"
#define MyAppExeName "counseling_is.exe"

[Setup]
AppId={{3AE78FEB-A649-42FF-A735-3E1DFDFE2AC7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=CounselingIS-Setup-{#MyAppVersion}
OutputDir=..\build\windows\installer
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
