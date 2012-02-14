[Setup]
AppName=Geoinformatica
AppVerName=Geoinformatica version $date
DefaultDirName={pf}\Geoinformatica
DefaultGroupName=Geoinformatica
UninstallDisplayIcon=
Compression=lzma
SolidCompression=yes
OutputBaseFilename=Geoinformatica-$date

[Tasks]
Name: desktopicon; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

[Icons]
Name: "{group}\Geoinformatica"; Filename: "{app}\bin\wperl.exe"; Parameters: "gui.pl"; WorkingDir: "{app}\bin"
Name: "{userdesktop}\Geoinformatica"; Filename: "{app}\bin\wperl.exe"; Parameters: "gui.pl"; Tasks: desktopicon; WorkingDir: "{app}\bin"
Name: "{group}\Perl modules documentation"; Filename: "{app}\doc\Perl modules\index.html";
Name: "{group}\GDAL Perl bindings documentation"; Filename: "{app}\doc\Perl GDAL\index.html";
Name: "{group}\libral documentation"; Filename: "{app}\doc\libral\index.html";
Name: "{group}\Perl documentation"; Filename: "{app}\html\pod\perl.html";

[Code]
function IsUpgrade(var uninst:String): Boolean;
begin
  uninst := '';
  if not RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Geoinformatica_is1', 'UninstallString', uninst) then
    RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Geoinformatica_is1', 'UninstallString', uninst);
  uninst := RemoveQuotes(uninst);
  Result := (uninst <> '');
end;

function InitializeSetup: Boolean;
var l: Boolean;
    s: Boolean;
var uninst:String;
var execres:Integer;
begin
  l := FileExists(ExpandConstant('{sys}\libeay32.dll'));
  s := FileExists(ExpandConstant('{sys}\ssleay32.dll'));
  if (s or l) then
      MsgBox('Please note! Directory Windows/system32 contains versions of libeay32.dll and/or ssleay32.dll which may be incompatible with those distributed with Geoinformatica.', mbInformation, MB_OK);
  if (IsUpgrade(uninst)) then
      Exec(uninst, '/SILENT', '', SW_SHOWNORMAL, ewWaitUntilTerminated, execres);
  Result := True;
end;

[Files]
