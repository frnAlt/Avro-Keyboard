{
  =============================================================================
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  =============================================================================
}

unit ufrmTranslator;

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
  StdCtrls,
  ExtCtrls,
  Clipbrd,
  WinInet;

type
  TTranslationThread = class(TThread)
  private
    FSourceText: string;
    FSourceLang: string;
    FTargetLang: string;
    FResultText: string;
    FErrorMessage: string;
    FSuccess: Boolean;
    FOnComplete: TNotifyEvent;
    function HttpGet(const Url: string): string;
    function GoogleTranslate(const Text, SL, TL: string): string;
    function MyMemoryTranslate(const Text, SL, TL: string): string;
    function UrlEncode(const S: string): string;
    function DecodeJsonString(const S: string): string;
  protected
    procedure Execute; override;
  public
    constructor Create(const Text, SL, TL: string; OnComplete: TNotifyEvent);
    property ResultText: string read FResultText;
    property ErrorMessage: string read FErrorMessage;
    property Success: Boolean read FSuccess;
  end;

  TfrmTranslator = class(TForm)
    lblHeader: TLabel;
    lblStatus: TLabel;
    comboSourceLang: TComboBox;
    btnSwap: TButton;
    comboTargetLang: TComboBox;
    memoSource: TMemo;
    memoTarget: TMemo;
    btnTranslate: TButton;
    btnCopy: TButton;
    btnInsert: TButton;
    btnSpeak: TButton;
    btnClear: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnSwapClick(Sender: TObject);
    procedure btnTranslateClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnInsertClick(Sender: TObject);
    procedure btnSpeakClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
  private
    FWorkerThread: TTranslationThread;
    function GetLangCode(const LangName: string; IsSource: Boolean): string;
    procedure OnTranslationDone(Sender: TObject);
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure TranslateCurrentText;
    procedure SetSourceText(const Text: string);
  end;

var
  frmTranslator: TfrmTranslator;

implementation

uses
  uWindowHandlers,
  uGlassmorphism,
  WindowsDarkMode,
  KeyboardFunctions,
  ufrmVoiceDictate;

{$R *.dfm}

{ TTranslationThread }

constructor TTranslationThread.Create(const Text, SL, TL: string; OnComplete: TNotifyEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FSourceText := Text;
  FSourceLang := SL;
  FTargetLang := TL;
  FOnComplete := OnComplete;
  FSuccess := False;
  FResultText := '';
  FErrorMessage := '';
  Resume;
end;

function TTranslationThread.UrlEncode(const S: string): string;
var
  Bytes: TBytes;
  B: Byte;
begin
  Result := '';
  Bytes := TEncoding.UTF8.GetBytes(S);
  for B in Bytes do
  begin
    if Char(B) in ['0'..'9', 'A'..'Z', 'a'..'z', '-', '_', '.', '~'] then
      Result := Result + Char(B)
    else if Char(B) = ' ' then
      Result := Result + '+'
    else
      Result := Result + '%' + IntToHex(B, 2);
  end;
end;

function TTranslationThread.DecodeJsonString(const S: string): string;
var
  i, L: Integer;
  HexCode: string;
begin
  Result := '';
  i := 1;
  L := Length(S);
  while i <= L do
  begin
    if (S[i] = '\') and (i < L) then
    begin
      Inc(i);
      case S[i] of
        'u':
          begin
            if i + 4 <= L then
            begin
              HexCode := Copy(S, i + 1, 4);
              try
                Result := Result + WideChar(StrToInt('$' + HexCode));
                Inc(i, 4);
              except
                Result := Result + '\u' + HexCode;
                Inc(i, 4);
              end;
            end
            else
              Result := Result + 'u';
          end;
        'n': Result := Result + #13#10;
        'r': ; // omit CR since #13#10 is added on 'n'
        't': Result := Result + #9;
        '"': Result := Result + '"';
        '\': Result := Result + '\';
        '/': Result := Result + '/';
      else
        Result := Result + S[i];
      end;
    end
    else
      Result := Result + S[i];
    Inc(i);
  end;
end;

function TTranslationThread.HttpGet(const Url: string): string;
var
  hSession, hURL: HINTERNET;
  Buffer: array[0..4095] of Byte;
  BytesRead: DWORD;
  RawBytes: TBytes;
  TotalBytes: Integer;
begin
  Result := '';
  hSession := InternetOpen('Avro-Translator/5.8', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hSession = nil then Exit;
  try
    hURL := InternetOpenUrl(hSession, PChar(Url), nil, 0,
      INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_CACHE_WRITE or INTERNET_FLAG_SECURE, 0);
    if hURL = nil then Exit;
    try
      TotalBytes := 0;
      SetLength(RawBytes, 0);
      repeat
        BytesRead := 0;
        if InternetReadFile(hURL, @Buffer, SizeOf(Buffer), BytesRead) and (BytesRead > 0) then
        begin
          SetLength(RawBytes, TotalBytes + BytesRead);
          Move(Buffer[0], RawBytes[TotalBytes], BytesRead);
          Inc(TotalBytes, BytesRead);
        end
        else
          Break;
      until BytesRead = 0;

      if TotalBytes > 0 then
        Result := TEncoding.UTF8.GetString(RawBytes);
    finally
      InternetCloseHandle(hURL);
    end;
  finally
    InternetCloseHandle(hSession);
  end;
end;

function TTranslationThread.GoogleTranslate(const Text, SL, TL: string): string;
var
  Url, RawResponse: string;
  p, endP, idx: Integer;
  part: string;
begin
  Result := '';
  Url := 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=' +
         SL + '&tl=' + TL + '&dt=t&q=' + UrlEncode(Text);
  RawResponse := HttpGet(Url);
  if RawResponse = '' then Exit;

  // Extract sentences from [[["part1","src1"...],["part2","src2"...]]
  idx := 1;
  while idx <= Length(RawResponse) do
  begin
    p := PosEx('["', RawResponse, idx);
    if (p = 0) or (p > 50000) then Break;
    p := p + 2;

    endP := p;
    while endP <= Length(RawResponse) do
    begin
      if (RawResponse[endP] = '"') and (RawResponse[endP - 1] <> '\') then
        Break;
      Inc(endP);
    end;

    if endP > p then
    begin
      part := Copy(RawResponse, p, endP - p);
      Result := Result + DecodeJsonString(part);
    end;

    idx := PosEx('],["', RawResponse, endP);
    if idx = 0 then Break;
    idx := idx + 3;
  end;
end;

function TTranslationThread.MyMemoryTranslate(const Text, SL, TL: string): string;
var
  Url, RawResponse: string;
  EffectiveSL: string;
  PosStart, PosEnd: Integer;
begin
  Result := '';
  EffectiveSL := SL;
  if EffectiveSL = 'auto' then EffectiveSL := 'en';
  Url := 'https://api.mymemory.translated.net/get?q=' + UrlEncode(Text) +
         '&langpair=' + EffectiveSL + '|' + TL;
  RawResponse := HttpGet(Url);
  if RawResponse = '' then Exit;

  PosStart := Pos('"translatedText":"', RawResponse);
  if PosStart > 0 then
  begin
    Inc(PosStart, Length('"translatedText":"'));
    PosEnd := PosStart;
    while PosEnd <= Length(RawResponse) do
    begin
      if (RawResponse[PosEnd] = '"') and (RawResponse[PosEnd - 1] <> '\') then
        Break;
      Inc(PosEnd);
    end;
    Result := DecodeJsonString(Copy(RawResponse, PosStart, PosEnd - PosStart));
  end;
end;

procedure TTranslationThread.Execute;
begin
  try
    FResultText := GoogleTranslate(FSourceText, FSourceLang, FTargetLang);
    if Trim(FResultText) = '' then
      FResultText := MyMemoryTranslate(FSourceText, FSourceLang, FTargetLang);

    if Trim(FResultText) <> '' then
      FSuccess := True
    else
      FErrorMessage := 'Translation failed. Please check internet connection.';
  except
    on E: Exception do
    begin
      FSuccess := False;
      FErrorMessage := 'Error: ' + E.Message;
    end;
  end;

  if Assigned(FOnComplete) then
    Synchronize(procedure
    begin
      FOnComplete(Self);
    end);
end;

{ TfrmTranslator }

procedure TfrmTranslator.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := (Params.ExStyle or WS_EX_TOPMOST) and not WS_EX_APPWINDOW;
  Params.WndParent := GetDesktopWindow;
end;

procedure TfrmTranslator.FormCreate(Sender: TObject);
begin
  MakeNeverActiveWindow(Self.Handle);
  EnableWindowRoundedCorners(Self.Handle);
  EnableWindowAcrylicBlur(Self.Handle, DarkModeIsEnabled, 180);

  comboSourceLang.ItemIndex := 0; // Auto-Detect
  comboTargetLang.ItemIndex := 0; // Bengali
  lblStatus.Caption := 'Ready.';
  FWorkerThread := nil;
end;

procedure TfrmTranslator.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FWorkerThread <> nil then
  begin
    FWorkerThread.Terminate;
    FWorkerThread := nil;
  end;
  Action := caHide;
end;

procedure TfrmTranslator.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close
  else if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    TranslateCurrentText;
  end;
end;

function TfrmTranslator.GetLangCode(const LangName: string; IsSource: Boolean): string;
var
  L: string;
begin
  L := LowerCase(Trim(LangName));
  if Pos('auto', L) > 0 then Result := 'auto'
  else if Pos('bengali', L) > 0 then Result := 'bn'
  else if Pos('english', L) > 0 then Result := 'en'
  else if Pos('arabic', L) > 0 then Result := 'ar'
  else if Pos('hindi', L) > 0 then Result := 'hi'
  else if Pos('spanish', L) > 0 then Result := 'es'
  else if Pos('french', L) > 0 then Result := 'fr'
  else if Pos('german', L) > 0 then Result := 'de'
  else if Pos('chinese', L) > 0 then Result := 'zh-CN'
  else if Pos('japanese', L) > 0 then Result := 'ja'
  else if Pos('urdu', L) > 0 then Result := 'ur'
  else
  begin
    if IsSource then Result := 'auto' else Result := 'bn';
  end;
end;

procedure TfrmTranslator.btnSwapClick(Sender: TObject);
var
  TempIndex: Integer;
  TempText: string;
begin
  // If source was Auto-Detect, flip to English
  if comboSourceLang.ItemIndex = 0 then
    comboSourceLang.ItemIndex := comboSourceLang.Items.IndexOf('English');

  TempIndex := comboSourceLang.ItemIndex;
  comboSourceLang.ItemIndex := comboSourceLang.Items.IndexOf(comboTargetLang.Text);
  if comboSourceLang.ItemIndex < 0 then comboSourceLang.ItemIndex := 0;
  comboTargetLang.ItemIndex := comboTargetLang.Items.IndexOf(comboSourceLang.Items[TempIndex]);
  if comboTargetLang.ItemIndex < 0 then comboTargetLang.ItemIndex := 0;

  TempText := memoSource.Text;
  memoSource.Text := memoTarget.Text;
  memoTarget.Text := TempText;
end;

procedure TfrmTranslator.TranslateCurrentText;
var
  SrcText, SL, TL: string;
begin
  SrcText := Trim(memoSource.Text);
  if SrcText = '' then
  begin
    lblStatus.Caption := 'Please enter text to translate.';
    Exit;
  end;

  if FWorkerThread <> nil then
  begin
    lblStatus.Caption := 'Translation in progress...';
    Exit;
  end;

  SL := GetLangCode(comboSourceLang.Text, True);
  TL := GetLangCode(comboTargetLang.Text, False);

  lblStatus.Caption := 'Translating via Google API...';
  btnTranslate.Enabled := False;

  FWorkerThread := TTranslationThread.Create(SrcText, SL, TL, OnTranslationDone);
end;

procedure TfrmTranslator.OnTranslationDone(Sender: TObject);
begin
  if FWorkerThread <> nil then
  begin
    if FWorkerThread.Success then
    begin
      memoTarget.Text := FWorkerThread.ResultText;
      lblStatus.Caption := 'Translation complete.';
    end
    else
    begin
      lblStatus.Caption := FWorkerThread.ErrorMessage;
    end;
    FWorkerThread.Free;
    FWorkerThread := nil;
  end;
  btnTranslate.Enabled := True;
end;

procedure TfrmTranslator.btnTranslateClick(Sender: TObject);
begin
  TranslateCurrentText;
end;

procedure TfrmTranslator.btnCopyClick(Sender: TObject);
begin
  if Trim(memoTarget.Text) <> '' then
  begin
    Clipboard.AsText := memoTarget.Text;
    lblStatus.Caption := 'Copied to clipboard!';
  end
  else
    lblStatus.Caption := 'No translated text to copy.';
end;

procedure TfrmTranslator.btnInsertClick(Sender: TObject);
begin
  if Trim(memoTarget.Text) <> '' then
  begin
    Close;
    Sleep(50);
    SendUnicodeString(memoTarget.Text);
  end
  else
    lblStatus.Caption := 'No text to insert.';
end;

procedure TfrmTranslator.btnSpeakClick(Sender: TObject);
begin
  if frmVoiceDictate = nil then
    Application.CreateForm(TfrmVoiceDictate, frmVoiceDictate);
  frmVoiceDictate.StartDictation;
end;

procedure TfrmTranslator.btnClearClick(Sender: TObject);
begin
  memoSource.Clear;
  memoTarget.Clear;
  lblStatus.Caption := 'Cleared.';
end;

procedure TfrmTranslator.SetSourceText(const Text: string);
begin
  memoSource.Text := Text;
  TranslateCurrentText;
end;

end.
