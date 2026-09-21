#define MyAppName "AI VOC Assistant"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "Easternwood"
#define MyAppExeName "ai_voc_assistant.exe"

[Setup]
AppId={{C4268CC0-4815-49EE-B2DA-9A7364B2706E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\AI VOC Assistant
DefaultGroupName=AI VOC Assistant
DisableProgramGroupPage=yes
OutputDir=..\..\release_artifacts\windows
OutputBaseFilename=AI-VOC-Assistant-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
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
Name: "{group}\AI VOC Assistant"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\AI VOC Assistant"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,AI VOC Assistant}"; Flags: nowait postinstall skipifsilent
