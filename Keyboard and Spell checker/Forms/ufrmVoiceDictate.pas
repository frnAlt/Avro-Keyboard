unit ufrmVoiceDictate;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  ExtCtrls,
  StdCtrls,
  uAvroVoice;

type
  TfrmVoiceDictate = class(TForm)
    ShapeBackground: TShape;
    lblMic: TLabel;
    lblStatus: TLabel;
    lblHint: TLabel;
    btnStop: TButton;
    tmrPulse: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnStopClick(Sender: TObject);
    procedure tmrPulseTimer(Sender: TObject);
  private
    FVoiceEngine: TAvroVoiceEngine;
    FPulseState: Boolean;
    procedure OnStateChange(State: TVoiceState; const StatusMessage: string);
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure StartDictation;
    procedure StopDictation;
  end;

var
  frmVoiceDictate: TfrmVoiceDictate;

implementation

uses
  uWindowHandlers;

{$R *.dfm}

procedure TfrmVoiceDictate.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Do not steal focus from current active application
  Params.ExStyle := Params.ExStyle or WS_EX_NOACTIVATE or WS_EX_TOPMOST;
end;

procedure TfrmVoiceDictate.FormCreate(Sender: TObject);
begin
  FVoiceEngine := TAvroVoiceEngine.Create;
  FVoiceEngine.OnStateChanged := OnStateChange;
  FPulseState := False;
  MakeNeverActiveWindow(Self.Handle);
end;

procedure TfrmVoiceDictate.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FVoiceEngine <> nil then
  begin
    FVoiceEngine.CancelListening;
    FreeAndNil(FVoiceEngine);
  end;
  Action := caFree;
  frmVoiceDictate := nil;
end;

procedure TfrmVoiceDictate.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    if FVoiceEngine <> nil then
      FVoiceEngine.CancelListening;
    Close;
  end;
end;

procedure TfrmVoiceDictate.OnStateChange(State: TVoiceState; const StatusMessage: string);
begin
  if StatusMessage <> '' then
    lblStatus.Caption := StatusMessage;

  case State of
    vsListening:
      begin
        lblMic.Font.Color := clRed;
        tmrPulse.Enabled := True;
      end;
    vsTranscribing:
      begin
        lblMic.Font.Color := clBlue;
        tmrPulse.Enabled := False;
      end;
    vsIdle, vsError:
      begin
        lblMic.Font.Color := clGray;
        tmrPulse.Enabled := False;
      end;
  end;
end;

procedure TfrmVoiceDictate.StartDictation;
begin
  Show;
  if FVoiceEngine <> nil then
  begin
    if not FVoiceEngine.StartListening then
      lblStatus.Caption := 'Microphone not available';
  end;
end;

procedure TfrmVoiceDictate.StopDictation;
begin
  tmrPulse.Enabled := False;
  if FVoiceEngine <> nil then
  begin
    FVoiceEngine.StopListeningAndTranscribe;
  end;
  Close;
end;

procedure TfrmVoiceDictate.btnStopClick(Sender: TObject);
begin
  StopDictation;
end;

procedure TfrmVoiceDictate.tmrPulseTimer(Sender: TObject);
begin
  FPulseState := not FPulseState;
  if FPulseState then
    lblMic.Font.Color := clRed
  else
    lblMic.Font.Color := clMaroon;
end;

end.
