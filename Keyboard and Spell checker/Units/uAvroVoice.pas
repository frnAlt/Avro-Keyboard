unit uAvroVoice;

interface

uses
  Classes,
  SysUtils,
  Windows,
  MMSystem,
  WinInet;

type
  TVoiceState = (vsIdle, vsListening, vsTranscribing, vsError);
  TTranscriptionEvent = procedure(const RecognizedText: string) of object;
  TVoiceStateEvent = procedure(State: TVoiceState; const StatusMessage: string) of object;

  TAvroVoiceEngine = class
  private
    FState: TVoiceState;
    FRecording: Boolean;
    FBufferStream: TMemoryStream;
    FWaveInHandle: HWAVEIN;
    FWaveHeader: WAVEHDR;
    FBuffer: PAnsiChar;
    FBufferSize: DWORD;
    FOnTranscription: TTranscriptionEvent;
    FOnStateChanged: TVoiceStateEvent;

    procedure SetState(const Value: TVoiceState; const Msg: string = '');
    function IsInternetAvailable: Boolean;
    function RecognizeOnline(AudioStream: TMemoryStream): string;
    function RecognizeOffline(AudioStream: TMemoryStream): string;
  public
    constructor Create;
    destructor Destroy; override;

    function StartListening: Boolean;
    function StopListeningAndTranscribe: string;
    procedure CancelListening;

    property State: TVoiceState read FState;
    property IsRecording: Boolean read FRecording;
    property OnTranscription: TTranscriptionEvent read FOnTranscription write FOnTranscription;
    property OnStateChanged: TVoiceStateEvent read FOnStateChanged write FOnStateChanged;
  end;

implementation

uses
  KeyboardFunctions;

const
  SAMPLE_RATE = 16000;
  CHANNELS = 1;
  BITS_PER_SAMPLE = 16;
  BUFFER_SECONDS = 10;

procedure WaveInCallback(hwi: HWAVEIN; uMsg: UINT; dwInstance, dwParam1, dwParam2: DWORD_PTR); stdcall;
var
  Engine: TAvroVoiceEngine;
  pHdr: PWAVEHDR;
begin
  if (uMsg = WIM_DATA) and (dwInstance <> 0) then
  begin
    Engine := TAvroVoiceEngine(dwInstance);
    pHdr := PWAVEHDR(dwParam1);
    if (pHdr <> nil) and (pHdr.dwBytesRecorded > 0) and Engine.FRecording then
    begin
      Engine.FBufferStream.WriteBuffer(pHdr.lpData^, pHdr.dwBytesRecorded);
      if Engine.FRecording then
      begin
        waveInAddBuffer(hwi, pHdr, SizeOf(WAVEHDR));
      end;
    end;
  end;
end;

constructor TAvroVoiceEngine.Create;
begin
  inherited Create;
  FState := vsIdle;
  FRecording := False;
  FBufferStream := TMemoryStream.Create;
  FBufferSize := SAMPLE_RATE * (BITS_PER_SAMPLE div 8) * BUFFER_SECONDS;
  GetMem(FBuffer, FBufferSize);
end;

destructor TAvroVoiceEngine.Destroy;
begin
  CancelListening;
  if FBuffer <> nil then
  begin
    FreeMem(FBuffer);
    FBuffer := nil;
  end;
  FreeAndNil(FBufferStream);
  inherited Destroy;
end;

procedure TAvroVoiceEngine.SetState(const Value: TVoiceState; const Msg: string = '');
begin
  FState := Value;
  if Assigned(FOnStateChanged) then
    FOnStateChanged(FState, Msg);
end;

function TAvroVoiceEngine.IsInternetAvailable: Boolean;
var
  Flags: DWORD;
begin
  Flags := 0;
  Result := InternetGetConnectedState(@Flags, 0);
end;

function TAvroVoiceEngine.StartListening: Boolean;
var
  WaveFormat: TWaveFormatEx;
  MMResult: MMRESULT;
begin
  Result := False;
  if FRecording then Exit;

  FBufferStream.Clear;

  FillChar(WaveFormat, SizeOf(TWaveFormatEx), 0);
  WaveFormat.wFormatTag := WAVE_FORMAT_PCM;
  WaveFormat.nChannels := CHANNELS;
  WaveFormat.nSamplesPerSec := SAMPLE_RATE;
  WaveFormat.wBitsPerSample := BITS_PER_SAMPLE;
  WaveFormat.nBlockAlign := (CHANNELS * BITS_PER_SAMPLE) div 8;
  WaveFormat.nAvgBytesPerSec := SAMPLE_RATE * WaveFormat.nBlockAlign;

  MMResult := waveInOpen(@FWaveInHandle, WAVE_MAPPER, @WaveFormat, DWORD_PTR(@WaveInCallback), DWORD_PTR(Self), CALLBACK_FUNCTION);
  if MMResult <> MMSYSERR_NOERROR then
  begin
    SetState(vsError, 'Cannot open microphone audio device');
    Exit;
  end;

  FillChar(FWaveHeader, SizeOf(WAVEHDR), 0);
  FWaveHeader.lpData := FBuffer;
  FWaveHeader.dwBufferLength := FBufferSize;

  waveInPrepareHeader(FWaveInHandle, @FWaveHeader, SizeOf(WAVEHDR));
  waveInAddBuffer(FWaveInHandle, @FWaveHeader, SizeOf(WAVEHDR));

  FRecording := True;
  waveInStart(FWaveInHandle);
  SetState(vsListening, 'Listening (শুনছি)...');
  Result := True;
end;

procedure TAvroVoiceEngine.CancelListening;
begin
  if FRecording then
  begin
    FRecording := False;
    waveInStop(FWaveInHandle);
    waveInReset(FWaveInHandle);
    waveInUnprepareHeader(FWaveInHandle, @FWaveHeader, SizeOf(WAVEHDR));
    waveInClose(FWaveInHandle);
    FWaveInHandle := 0;
  end;
  FBufferStream.Clear;
  SetState(vsIdle, '');
end;

function TAvroVoiceEngine.RecognizeOnline(AudioStream: TMemoryStream): string;
var
  hSession, hConnect, hRequest: HINTERNET;
  Url, Host, Path: string;
  Buffer: array[0..4095] of AnsiChar;
  BytesRead, BytesSent: DWORD;
  ResponseData: TMemoryStream;
  RawJSON: string;
  PosUtterance, StartPos, EndPos: Integer;
begin
  Result := '';
  Host := 'www.google.com';
  Path := '/speech-api/v2/recognize?output=json&lang=bn-BD&key=';

  hSession := InternetOpen('Avro-Voice/5.7', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hSession = nil then Exit;
  try
    hConnect := InternetConnect(hSession, PChar(Host), INTERNET_DEFAULT_HTTPS_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
    if hConnect = nil then Exit;
    try
      hRequest := HttpOpenRequest(hConnect, 'POST', PChar(Path), nil, nil, nil, INTERNET_FLAG_SECURE or INTERNET_FLAG_RELOAD, 0);
      if hRequest = nil then Exit;
      try
        HttpAddRequestHeaders(hRequest, 'Content-Type: audio/l16; rate=16000'#13#10, Length('Content-Type: audio/l16; rate=16000'#13#10), HTTP_ADDREQ_FLAG_REPLACE or HTTP_ADDREQ_FLAG_ADD);

        AudioStream.Position := 0;
        if HttpSendRequest(hRequest, nil, 0, AudioStream.Memory, AudioStream.Size) then
        begin
          ResponseData := TMemoryStream.Create;
          try
            repeat
              BytesRead := 0;
              if InternetReadFile(hRequest, @Buffer, SizeOf(Buffer), BytesRead) and (BytesRead > 0) then
                ResponseData.WriteBuffer(Buffer, BytesRead);
            until BytesRead = 0;

            if ResponseData.Size > 0 then
            begin
              RawJSON := TEncoding.UTF8.GetString(TBytes(ResponseData.Memory), 0, ResponseData.Size);
              // Extract transcript from {"transcript":"..."}
              PosUtterance := Pos('"transcript":"', RawJSON);
              if PosUtterance > 0 then
              begin
                StartPos := PosUtterance + Length('"transcript":"');
                EndPos := Pos('"', Copy(RawJSON, StartPos, Length(RawJSON)));
                if EndPos > 0 then
                  Result := Copy(RawJSON, StartPos, EndPos - 1);
              end;
            end;
          finally
            ResponseData.Free;
          end;
        end;
      finally
        InternetCloseHandle(hRequest);
      end;
    finally
      InternetCloseHandle(hConnect);
    end;
  finally
    InternetCloseHandle(hSession);
  end;
end;

function TAvroVoiceEngine.RecognizeOffline(AudioStream: TMemoryStream): string;
begin
  // Offline fallback: Sends Windows Voice Typing trigger (Win+H) or SAPI engine
  Result := '';
  // Emulate Windows Speech typing trigger
  keybd_event(VK_LWIN, 0, 0, 0);
  keybd_event(Ord('H'), 0, 0, 0);
  keybd_event(Ord('H'), 0, KEYEVENTF_KEYUP, 0);
  keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, 0);
end;

function TAvroVoiceEngine.StopListeningAndTranscribe: string;
var
  Transcribed: string;
begin
  Result := '';
  if not FRecording then Exit;

  FRecording := False;
  waveInStop(FWaveInHandle);
  waveInReset(FWaveInHandle);
  waveInUnprepareHeader(FWaveInHandle, @FWaveHeader, SizeOf(WAVEHDR));
  waveInClose(FWaveInHandle);
  FWaveInHandle := 0;

  SetState(vsTranscribing, 'Transcribing (রূপান্তর হচ্ছে)...');

  try
    if (FBufferStream.Size > 0) and IsInternetAvailable then
    begin
      Transcribed := RecognizeOnline(FBufferStream);
    end
    else
    begin
      Transcribed := RecognizeOffline(FBufferStream);
    end;

    Result := Trim(Transcribed);
    if Result <> '' then
    begin
      if Assigned(FOnTranscription) then
        FOnTranscription(Result);
      // Insert directly into active focused window at cursor
      SendKey_Char(Result);
    end;
  finally
    FBufferStream.Clear;
    SetState(vsIdle, '');
  end;
end;

end.
