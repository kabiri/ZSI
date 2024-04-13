unit untMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  System.IOUtils,
  Vcl.Imaging.pngimage, Vcl.ExtCtrls, Uni, ABSMain, StrUtils, MSI_Common,
  MSI_CPU, SQLServerUniProvider, System.Generics.Collections;

type
  WinIsWow64 = function(Handle: THandle; var Iret: BOOL): BOOL; stdcall;

  TfrmMain = class(TForm)
    btnInstall: TButton;
    ProgressBar1: TProgressBar;
    Image1: TImage;
    lblTitle: TLabel;
    lblsubTitle: TLabel;
    lblSite: TLabel;
    btnSetup: TButton;
    btnExit: TButton;
    Memo64: TMemo;
    Memo32: TMemo;
    procedure btnInstallClick(Sender: TObject);
    function ExecuteProcess(const FileName, Params: string; Folder: string;
      WaitUntilTerminated, WaitUntilIdle, RunMinimized: boolean;
      var ErrorCode: integer): boolean;
    procedure lblSiteClick(Sender: TObject);
    procedure btnSetupClick(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    CPUSerialNumber: string;
    dbSupportEndDate: string;
    DBPass: string;
    ServerPassword: string;
    DataBaseName: string;
    ServerName: string;
    INSTANCENAME: string;
    function Is64bit: boolean;
    function DatabseExist: boolean;
    function loginDatabase(Co: TUniConnection; dbn, server, username,
      password: string; StayConnected: boolean): boolean;
    function FixDatabaseLogins: boolean;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  ShellApi;

{$R *.dfm}


procedure TfrmMain.btnSetupClick(Sender: TObject);
begin
  if FixDatabaseLogins then
    ShowMessage('انجام شد')
  else
    ShowMessage('انجام نشد');
end;

function TfrmMain.DatabseExist: boolean;
var
  DBConnection: TUniConnection;
  qry: TUniQuery;
begin
  Result := False;
  DBConnection := TUniConnection.Create(Self);
  DBConnection.LoginPrompt := False;
  try
    Result := loginDatabase(DBConnection, 'Master', ServerName, 'sa',
      DBPass, False);
    if Result = False then
      Exit;
    qry := TUniQuery.Create(nil);
    qry.Connection := DBConnection;
    qry.SQL.Add('SELECT name FROM master.dbo.sysdatabases');
    qry.SQL.Add('where name = '+QuotedStr(DataBaseName));
    qry.Open;
    if not qry.IsEmpty then
    begin
      Result := True;
    end;
    qry.Close;
    qry.Free;
  finally
    DBConnection.Free;
  end;
end;

function TfrmMain.FixDatabaseLogins: boolean;
var
  DBConnection: TUniConnection;
  qry: TUniQuery;
  qq: TUniQuery;
begin
  Result := False;
  DBConnection := TUniConnection.Create(Self);
  Result := loginDatabase(DBConnection, 'Master', ServerName, 'sa',
    DBPass, False);
  try
    if Result = False then
      Exit;

    qry := TUniQuery.Create(nil);
    qry.Connection := DBConnection;

    qq := TUniQuery.Create(nil);
    qq.Connection := DBConnection;

    try
      {$REGION 'ایجاد دسترسی مد مخلوط'}
      qry.Close;
      qry.SQL.Clear;
      qry.SQL.Add('EXEC xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', ' +
        'N''Software\Microsoft\MSSQLServer\MSSQLServer'',' +
        'N''LoginMode'', REG_DWORD, 2');
      qry.ExecSQL;

      qry.Close;
      qry.SQL.Clear;
      qry.SQL.Add('ALTER LOGIN sa ENABLE;');
      qry.ExecSQL;

      qry.Close;
      qry.SQL.Clear;
      qry.SQL.Add('ALTER LOGIN [sa] WITH PASSWORD=N' +
        QuotedStr(ServerPassword));
      qry.ExecSQL;
      {$ENDREGION}
      {$REGION 'حذف دسترسی ویندوز'}
      qry.Close;
      qry.SQL.Clear;
      qry.SQL.Add
        ('select * from sys.server_principals where type_desc=''WINDOWS_LOGIN''');
      qry.Open;
      while not qry.Eof do
      begin
        qq.SQL.Clear;
        qq.SQL.Add('ALTER LOGIN [' + qry.FieldByName('name').AsString +
          '] DISABLE');
        try
          qq.ExecSQL;
        except
        end;
        qry.Next;
      end;
      {$ENDREGION}
    finally
      qq.Free;
      qry.Close;
      qry.Free;
    end;
    Result := True;
  finally
    DBConnection.Free;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  ServerPassword := ''; //Set your Sql Password
  //پسوردی که می خواهید با آن به سکوال سرور لاگین کنید
  DataBaseName := ''; //Set your Database Name

  DBPass := '!QAZ2wsx#eDc';  //My Defualt Pass For install SQL
  //اگر پسورد فوق تغییر داده شد در مموها هم تغییر داده شود
  //این پسورد مهم نیست و فقط در موقع نصب توسط اینستالر استفاده می شود

  INSTANCENAME := 'ZigSoftware'; //Sql server INSTANCENAME
  //اگر نام اینستنس تغییر یافت در مموها هم تغییر داده شود
  ServerName := '.\'+INSTANCENAME; //Sql server name
end;

function TfrmMain.loginDatabase(Co: TUniConnection; dbn, server, username,
  password: string; StayConnected: boolean): boolean;
var
  cs: string;
begin
  try
    Co.Close;
    Result := False;
    cs := 'Provider Name=SQL Server;';
    cs := cs + 'Initial Catalog=' + dbn + ';Port=0;';
    cs := cs + 'Data Source=' + server + ';';
    cs := cs + 'User ID=' + username + ';';
    cs := cs + 'Password=' + password;
    Co.ConnectString := cs;
    Co.Open;
    Result := True;
  except
    on E: Exception do
    begin
    end;
  end;
  if not StayConnected then
    Co.Close;
end;

procedure TfrmMain.btnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.btnInstallClick(Sender: TObject);
var
  FileName, Parameters, WorkingFolder: string;
  Error: integer;
  OK: boolean;
begin
  if DatabseExist then
  begin
    ShowMessage('قبلا نصب شده است');
    Exit;
  end;

  ProgressBar1.Style := TProgressBarStyle.pbstMarquee;

  FileName := ExtractFileDir(ParamStr(0)) + '\Files\';
  WorkingFolder := ''; // if empty function will extract path from FileName
  Parameters := '/QS /ConfigurationFile="' + TPath.GetTempPath +
    '\Configuration.ini"';

  if Is64bit then
  begin
    Memo64.Lines.SaveToFile(TPath.GetTempPath + '\Configuration.ini');
    FileName := FileName + 'SQLEXPR_x64_ENU.exe';
  end
  else
  begin
    Memo32.Lines.SaveToFile(TPath.GetTempPath + '\Configuration.ini');
    FileName := FileName + 'SQLEXPR_x86_ENU.exe';
  end;
  OK := ExecuteProcess(FileName, Parameters, WorkingFolder, True, False,
    False, Error);
  if not OK then
    ShowMessage('Error: ' + IntToStr(Error))
  else
    ShowMessage('Done');
  DeleteFile(TPath.GetTempPath + '\Configuration.ini');
  ProgressBar1.Style := TProgressBarStyle.pbstNormal;
end;

function TfrmMain.ExecuteProcess(const FileName, Params: string; Folder: string;
  WaitUntilTerminated, WaitUntilIdle, RunMinimized: boolean;
  var ErrorCode: integer): boolean;
var
  CmdLine: string;
  WorkingDirP: PChar;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  Result := True;
  CmdLine := '"' + FileName + '" ' + Params;
  if Folder = '' then
    Folder := ExcludeTrailingPathDelimiter(ExtractFilePath(FileName));
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  if RunMinimized then
  begin
    StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow := SW_SHOWMINIMIZED;
  end;
  if Folder <> '' then
    WorkingDirP := PChar(Folder)
  else
    WorkingDirP := nil;
  if not CreateProcess(nil, PChar(CmdLine), nil, nil, False, 0, nil,
    WorkingDirP, StartupInfo, ProcessInfo) then
  begin
    Result := False;
    ErrorCode := GetLastError;
    Exit;
  end;
  with ProcessInfo do
  begin
    CloseHandle(hThread);
    if WaitUntilIdle then
      WaitForInputIdle(hProcess, INFINITE);
    if WaitUntilTerminated then
      repeat
        Application.ProcessMessages;
      until MsgWaitForMultipleObjects(1, hProcess, False, INFINITE, QS_ALLINPUT)
        <> WAIT_OBJECT_0 + 1;
    CloseHandle(hProcess);
  end;
end;

function TfrmMain.Is64bit: boolean;
var
  HandleTo64BitsProcess: WinIsWow64;
  Iret: BOOL;
begin
  Result := False;
  HandleTo64BitsProcess := GetProcAddress(GetModuleHandle('kernel32.dll'),
    'IsWow64Process');
  if Assigned(HandleTo64BitsProcess) then
  begin
    if not HandleTo64BitsProcess(GetCurrentProcess, Iret) then
      Raise Exception.Create('Invalid handle');
    Result := Iret;
  end;
end;

procedure TfrmMain.lblSiteClick(Sender: TObject);
var
  URL: WideString;
begin
  URL := 'http://www.zigsoftware.ir';
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
end;

end.
