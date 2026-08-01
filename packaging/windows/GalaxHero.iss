#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif

#define MyAppName "Galax Hero"
#define MyAppPublisher "Galax Hero"
#define MyAppExeName "galax-hero-release.exe"

[Setup]
AppId={{A8D3DE25-8418-4DD8-A797-D9C5CE1F2B89}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Galax Hero
DefaultGroupName=Galax Hero
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#SourcePath}\..\..\builds\installer
OutputBaseFilename=galax-hero-{#MyAppVersion}-windows-x86_64-setup
SetupIconFile={#SourcePath}\galax_hero_app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern dynamic
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Windows Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
CloseApplications=yes
RestartApplications=no
AppMutex=GalaxHeroProductionRuntime

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourcePath}\..\..\builds\release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\LICENSE"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\KNOWN_ISSUES.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\docs\PLAYER_MANUAL.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\docs\TROUBLESHOOTING_AND_RECOVERY.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "{#SourcePath}\..\..\docs\SUPPORT_PRIVACY_AND_DIAGNOSTICS.md"; DestDir: "{app}\docs"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Galax Hero"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Galax Hero"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Galax Hero"; Flags: nowait postinstall skipifsilent
