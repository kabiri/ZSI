program ZSI;

uses
  Vcl.Forms,
  untMain in 'untMain.pas' {frmMain},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Amakrits');
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
