#define MyAppName "VoC Mate"
#ifndef MyAppVersion
  #define MyAppVersion "1.1.3"
#endif
#ifndef MyAppBuild
  #define MyAppBuild "5"
#endif
#define MyAppPublisher "Easternwood"
#define MyAppExeName "ai_voc_assistant.exe"
#define MyArtifactName "VoC-Mate-v" + MyAppVersion + "-build" + MyAppBuild + "-Setup"

[Setup]
SetupIconFile=..\runner\resources\app_icon.ico
AppId={{C4268CC0-4815-49EE-B2DA-9A7364B2706E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\AI VOC Assistant
DefaultGroupName=VoC Mate
DisableProgramGroupPage=yes
OutputDir=..\..\release_artifacts\windows
OutputBaseFilename={#MyArtifactName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\VoC Mate"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\VoC Mate"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,VoC Mate}"; Flags: nowait postinstall skipifsilent


[InstallDelete]
Type: files; Name: "{autodesktop}\AI VOC Assistant.lnk"
Type: files; Name: "{userprograms}\AI VOC Assistant\AI VOC Assistant.lnk"
