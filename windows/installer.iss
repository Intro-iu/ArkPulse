#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

[Setup]
AppId={{0237C5EC-B046-4DB8-8C61-518D1612A093}
AppName=ArkPulse
AppVersion={#AppVersion}
DefaultDirName={autopf}\ArkPulse
DefaultGroupName=ArkPulse
OutputBaseFilename=arkpulse-windows-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\arkpulse.exe
SetupIconFile=runner\resources\app_icon.ico

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Note: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\ArkPulse"; Filename: "{app}\arkpulse.exe"
Name: "{autodesktop}\ArkPulse"; Filename: "{app}\arkpulse.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\arkpulse.exe"; Description: "Launch ArkPulse"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeUninstall(): Boolean;
begin
  if MsgBox('Do you want to completely remove ArkPulse database and user settings?', mbConfirmation, MB_YESNO) = idYes then
  begin
    DelTree(ExpandConstant('{userappdata}\com.lythen\arkpulse'), True, True, True);
    DelTree(ExpandConstant('{userdocs}\arkpulse'), True, True, True);
  end;
  Result := True;
end;
