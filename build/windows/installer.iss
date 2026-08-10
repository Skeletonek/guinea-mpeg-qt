; GuineaMPEG InnoSetup Installer
; Requires InnoSetup 6+

#define MyAppName "GuineaMPEG"
#define MyAppPublisher "Skeletonek"
#define MyAppURL "https://gitlab.com/Skeletonek/guinea-mpeg-qt"
#define MyAppExeName "guinea-mpeg.exe"

#ifndef AppVersion
    #define AppVersion "0.8.0"
#endif

#ifndef SourceDir
    #define SourceDir "..\..\out\windows"
#endif

#ifndef OutputDir
    #define OutputDir "..\..\out"
#endif

#ifndef OutputFilename
    #define OutputFilename "guinea-mpeg-" + AppVersion + "-x86_64"
#endif

[Setup]
AppId={{B8A7C3D1-2E5F-4A9B-8C6D-1E3F5A7B9C0D}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename={#OutputFilename}
LicenseFile=..\..\LICENSE
SetupIconFile=..\..\media\logo\app.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: checkedonce

[Files]
; Main executable and all deployed DLLs/resources
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "CMakeCache.txt,cmake_install.cmake,build.ninja,.ninja_log,.ninja_deps,CMakeFiles,.qt,CMakeScripts"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Registry]
; File associations
Root: HKA; Subkey: "Software\Classes\.mp4\OpenWithProgids"; ValueType: string; ValueName: "GuineaMPEG.mp4"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.mkv\OpenWithProgids"; ValueType: string; ValueName: "GuineaMPEG.mkv"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.webm\OpenWithProgids"; ValueType: string; ValueName: "GuineaMPEG.webm"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.avi\OpenWithProgids"; ValueType: string; ValueName: "GuineaMPEG.avi"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.mov\OpenWithProgids"; ValueType: string; ValueName: "GuineaMPEG.mov"; ValueData: ""; Flags: uninsdeletevalue

Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mp4"; ValueType: string; ValueName: ""; ValueData: "MP4 Video"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mp4\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mp4\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mkv"; ValueType: string; ValueName: ""; ValueData: "MKV Video"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mkv\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mkv\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\GuineaMPEG.webm"; ValueType: string; ValueName: ""; ValueData: "WebM Video"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.webm\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.webm\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\GuineaMPEG.avi"; ValueType: string; ValueName: ""; ValueData: "AVI Video"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.avi\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.avi\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mov"; ValueType: string; ValueName: ""; ValueData: "MOV Video"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mov\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\GuineaMPEG.mov\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Code]
function InitializeSetup: Boolean;
begin
    Result := True;
end;
