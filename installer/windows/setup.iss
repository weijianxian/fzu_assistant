; FZU Assistant Windows Installer Script (Inno Setup)
; Ported from zerx-lab/FluxDown (installer/windows/setup.iss).
;
; Built by GitHub Actions (.github/workflows/build.yaml) on the Flutter build output:
;   SourceDir = build\windows\x64\runner\Release  (fzu_assistant.exe + flutter_windows.dll
;   + plugin DLLs + data\app.so & data\flutter_assets)
;
; Layout notes copied from FluxDown:
;   - Per-user install ({autopf} + PrivilegesRequired=lowest): no UAC prompt ever, so the
;     silent auto-update path stays silent. Do NOT offer an "all users" override: once an
;     all-users install exists, UsePreviousPrivileges makes every later silent update elevate.
;   - CloseApplications=force + a taskkill fallback in [Code]: the app keeps .exe/DLLs locked,
;     so Inno would otherwise fail with "access denied" on upgrade.

#define MyAppName "FZU Assistant"
; Folder name kept ASCII so the install path stays shell-safe; the localized
; names live in [CustomMessages] as zh_AppName / en_AppName.
#define MyAppDirName "FZU Assistant"
#define MyAppPublisher "weijianxian"
#define MyAppURL "https://github.com/weijianxian/fzu_assistant"
#define MyAppExeName "fzu_assistant.exe"

; {autopf} (used by DefaultDirName below) requires Inno Setup 6.1 or newer.
#if VER < EncodeVer(6,1,0)
  #error Inno Setup 6.1 or newer is required ({autopf} is unavailable)
#endif

; Version is passed from CI via /DMyAppVersion=x.y.z (pubspec version without the +build suffix).
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

; Architecture is passed from CI via /DMyAppArch=x64 (installer artifact naming only).
#ifndef MyAppArch
  #define MyAppArch "x64"
#endif

; Flutter Windows release bundle, passed from CI via /DMySourceDir=<abs path>.
#ifndef MySourceDir
  #define MySourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; Fixed identity: never change it, otherwise upgrades install side by side
; instead of replacing and the uninstall entry is duplicated.
AppId={{9F2C4B7E-4A31-4C6D-8E52-7B1A0C3D5E84}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppDirName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=FZU-Assistant-{#MyAppVersion}-windows-{#MyAppArch}-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Per-user install: {autopf} resolves to %LOCALAPPDATA%\Programs, no UAC.
PrivilegesRequired=lowest
; The resident app holds its exe/DLLs open; force-close instead of asking.
CloseApplications=force
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}

[Languages]
; ChineseSimplified.isl is vendored next to this script (installer/windows/), because
; Inno Setup ships no Chinese translation in its Languages\ payload. Keeping it here
; means the build never has to write into the Inno Setup installation directory.
; Keep the file byte-for-byte as upstream: it is GBK-encoded (LanguageCodePage=936),
; so re-saving it as UTF-8 mangles the Chinese text.
; If the local Inno Setup is newer than the .isl, ISCC prints a few "message name not
; recognized / not defined" warnings — harmless here, no [Messages] entry of ours is affected.
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
chinesesimplified.AppName=福大助手
english.AppName=FZU Assistant
chinesesimplified.OtherTasks=其他：
english.OtherTasks=Other:
chinesesimplified.LaunchOnStartup=开机时自动启动
english.LaunchOnStartup=Launch at system startup

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "launchonstartup"; Description: "{cm:LaunchOnStartup}"; GroupDescription: "{cm:OtherTasks}"; Flags: unchecked

[InstallDelete]
; Drop leftovers from a previous install before the new bundle lands, so a removed
; plugin DLL or asset cannot be picked up by the new build.
Type: files; Name: "{app}\*.dll"
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; First install: only when the user ticks the task. Upgrade: refresh an existing shortcut.
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Check: DesktopIconAlreadyExists

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
; Silent auto-update: /SILENT install brings the app back up as the original user.
Filename: "{app}\{#MyAppExeName}"; Flags: nowait skipifdoesntexist skipifnotsilent runasoriginaluser

[Registry]
; Autostart (HKCU only — no elevation). uninsdeletevalue drops it on uninstall.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: launchonstartup

[UninstallDelete]
; Runtime caches written next to the exe by Flutter plugins, invisible to the
; uninstall log. Login credentials live in flutter_secure_storage and are left alone.
Type: filesandordirs; Name: "{app}\data"

[Code]
{ Keep an existing desktop shortcut working across upgrades even when the user
  never ticks the desktopicon task again. }
function DesktopIconAlreadyExists: Boolean;
begin
  Result := FileExists(ExpandConstant('{autodesktop}\{#MyAppName}.lnk'));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  { CloseApplications/Restart Manager handles the normal case; this is the
    fallback for a hung or elevated instance that still locks the exe. }
  Exec('taskkill', '/f /im {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  { A stray read-only attribute on the previous uninstaller makes the upgrade
    fail with access denied; clearing it is a no-op when the files are absent. }
  Exec('attrib', '-r "' + ExpandConstant('{app}\unins000.exe') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('attrib', '-r "' + ExpandConstant('{app}\unins000.dat') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  { Let the killed process release its file locks before [Files] runs. }
  Sleep(500);
  Result := '';
end;
