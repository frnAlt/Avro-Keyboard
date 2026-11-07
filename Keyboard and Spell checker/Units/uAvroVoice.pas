unit uAvroVoice;

interface

uses
  Classes,
  SysUtils,
  Windows,
  MMSystem,
  WinInet,
  SyncObjs,
  uOfflineSTTWrapper,
  uDBase;

type
  TVoiceState = (vsIdle, vsListening, vsTranscribing, vsError);
  TTranscriptionEvent = procedure(const RecognizedText: string) of object;
  TVoiceStateEvent = procedure(State: TVoiceState; const StatusMessage: string) of object;
  TAudioLevelEvent = procedure(Level: Single) of object;

  TAvroVoiceEngine = class;

  // Background worker thread for speech-to-text recognition
  TSTTWorkerThread = class(TThread)
  private
    FEngine: TAvroVoiceEngine;
    FAudioStream: TMemoryStream;
    FLang: string;
    FForceOffline: Boolean;
    FAutoPunctuation: Boolean;
    FRecognizedText: string;
    FStatusMsg: string;
    FHasResult: Boolean;
    procedure SyncNotifyState;
    procedure SyncNotifyResult;
  protected
    procedure Execute; override;
  public
    constructor Create(Engine: TAvroVoiceEngine; AudioData: TMemoryStream; const Lang: string; ForceOffline, AutoPunctuation: Boolean);
    destructor Destroy; override;
  end;

  TAvroVoiceEngine = class
  private
    FState: TVoiceState;
    FRecording: Boolean;
    FWaveInHandle: HWAVEIN;
    FWaveHeaders: array[0..2] of WAVEHDR;
    FWaveBuffers: array[0..2] of PAnsiChar;
    FBufferByteSize: DWORD;
    FActivePhraseStream: TMemoryStream;
    FVoiceLock: TCriticalSection;

    // VAD (Voice Activity Detection) parameters
    FSpeechDetected: Boolean;
    FSilenceFrames: Integer;
    FSpeechFrames: Integer;
    FCurrentAudioLevel: Single;

    // Configuration
    FAccentLocale: string;
    FAutoPunctuation: Boolean;
    FForceOfflineMode: Boolean;

    // Events
    FOnTranscription: TTranscriptionEvent;
    FOnStateChanged: TVoiceStateEvent;
    FOnAudioLevel: TAudioLevelEvent;

    procedure SetState(const Value: TVoiceState; const Msg: string = '');
    procedure ProcessIncomingAudio(pData: PSmallInt; SampleCount: Integer);
    procedure DispatchPhraseChunk;
    function IsInternetAvailable: Boolean;
    function RecognizeOnline(AudioStream: TMemoryStream; const Lang: string): string;
    function RecognizeOffline(AudioStream: TMemoryStream; const Lang: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    function StartListening: Boolean;
    procedure StopListeningAndTranscribe;
    procedure CancelListening;

    property State: TVoiceState read FState;
    property IsRecording: Boolean read FRecording;
    property CurrentAudioLevel: Single read FCurrentAudioLevel;
    property AccentLocale: string read FAccentLocale write FAccentLocale;
    property AutoPunctuation: Boolean read FAutoPunctuation write FAutoPunctuation;
    property ForceOfflineMode: Boolean read FForceOfflineMode write FForceOfflineMode;

    property OnTranscription: TTranscriptionEvent read FOnTranscription write FOnTranscription;
    property OnStateChanged: TVoiceStateEvent read FOnStateChanged write FOnStateChanged;
    property OnAudioLevel: TAudioLevelEvent read FOnAudioLevel write FOnAudioLevel;
  end;

implementation

uses
  KeyboardFunctions;

const
  SAMPLE_RATE = 16000;
  CHANNELS = 1;
  BITS_PER_SAMPLE = 16;
  FRAME_SAMPLES = 1600; // 100ms frame at 16kHz
  SILENCE_RMS_THRESHOLD = 450.0;
  MAX_SILENCE_FRAMES = 9; // ~900ms silence ends a phrase
  MIN_SPEECH_FRAMES = 2;  // At least 200ms speech to trigger recognition
  MAX_PHRASE_SECONDS = 12;

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
      Engine.ProcessIncomingAudio(PSmallInt(pHdr.lpData), pHdr.dwBytesRecorded div 2);
      if Engine.FRecording then
      begin
        waveInAddBuffer(hwi, pHdr, SizeOf(WAVEHDR));
      end;
    end;
  end;
end;

{ TSTTWorkerThread }

constructor TSTTWorkerThread.Create(Engine: TAvroVoiceEngine; AudioData: TMemoryStream; const Lang: string; ForceOffline, AutoPunctuation: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FEngine := Engine;
  FAudioStream := TMemoryStream.Create;
  FAudioStream.CopyFrom(AudioData, 0);
  FLang := Lang;
  FForceOffline := ForceOffline;
  FAutoPunctuation := AutoPunctuation;
  FHasResult := False;
  Resume;
end;

destructor TSTTWorkerThread.Destroy;
begin
  FAudioStream.Free;
  inherited Destroy;
end;

procedure TSTTWorkerThread.SyncNotifyState;
begin
  if Assigned(FEngine) then
    FEngine.SetState(vsTranscribing, FStatusMsg);
end;

procedure TSTTWorkerThread.SyncNotifyResult;
begin
  if Assigned(FEngine) and FHasResult and (FRecognizedText <> '') then
  begin
    if Assigned(FEngine.FOnTranscription) then
      FEngine.FOnTranscription(FRecognizedText);
    // Directly inject Unicode text into active window without focus desync
    SendUnicodeString(FRecognizedText);
    FEngine.SetState(vsListening, 'Listening (শুনছি)...');
  end
  else if Assigned(FEngine) then
  begin
    FEngine.SetState(vsListening, 'Listening (শুনছি)...');
  end;
end;

procedure TSTTWorkerThread.Execute;
var
  RawResult, FinalText: string;
begin
  if (FAudioStream = nil) or (FAudioStream.Size = 0) then Exit;

  FStatusMsg := 'Transcribing (রূপান্তর হচ্ছে)...';
  Synchronize(SyncNotifyState);

  RawResult := '';
  try
    if not FForceOffline and FEngine.IsInternetAvailable then
    begin
      RawResult := FEngine.RecognizeOnline(FAudioStream, FLang);
    end;

    // Automatic fallback to offline C-ABI engine when offline, timed out, or empty
    if (RawResult = '') then
    begin
      RawResult := FEngine.RecognizeOffline(FAudioStream, FLang);
    end;

    FinalText := Trim(RawResult);
    if FinalText <> '' then
    begin
      // Apply voice punctuation mapping ('দাঁড়ি' -> '।', 'কমা' -> ',', etc.)
      if FAutoPunctuation then
        FinalText := ApplyVoicePunctuationCommands(FinalText);

      FRecognizedText := FinalText;
      FHasResult := True;
    end;
  finally
    Synchronize(SyncNotifyResult);
  end;
end;

{ TAvroVoiceEngine }

constructor TAvroVoiceEngine.Create;
var
  I: Integer;
begin
  inherited Create;
  FState := vsIdle;
  FRecording := False;
  FAccentLocale := 'bn-BD';
  FAutoPunctuation := True;
  FForceOfflineMode := False;
  FVoiceLock := TCriticalSection.Create;
  FActivePhraseStream := TMemoryStream.Create;

  FBufferByteSize := FRAME_SAMPLES * (BITS_PER_SAMPLE div 8);
  for I := 0 to High(FWaveBuffers) do
    GetMem(FWaveBuffers[I], FBufferByteSize);
end;

destructor TAvroVoiceEngine.Destroy;
var
  I: Integer;
begin
  CancelListening;
  for I := 0 to High(FWaveBuffers) do
  begin
    if FWaveBuffers[I] <> nil then
    begin
      FreeMem(FWaveBuffers[I]);
      FWaveBuffers[I] := nil;
    end;
  end;
  FreeAndNil(FActivePhraseStream);
  FreeAndNil(FVoiceLock);
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

procedure TAvroVoiceEngine.ProcessIncomingAudio(pData: PSmallInt; SampleCount: Integer);
var
  I: Integer;
  Sum: Double;
  Rms: Single;
  NormalizedLevel: Single;
begin
  if (pData = nil) or (SampleCount <= 0) then Exit;

  // Compute Root Mean Square (RMS) energy for VAD & Level indicator
  Sum := 0;
  for I := 0 to SampleCount - 1 do
    Sum := Sum + (pData[I] * pData[I]);
  Rms := Sqrt(Sum / SampleCount);

  // Normalize level roughly between 0.0 and 1.0
  NormalizedLevel := Rms / 3000.0;
  if NormalizedLevel > 1.0 then NormalizedLevel := 1.0;
  FCurrentAudioLevel := NormalizedLevel;

  if Assigned(FOnAudioLevel) then
    FOnAudioLevel(NormalizedLevel);

  FVoiceLock.Enter;
  try
    // VAD decision
    if Rms >= SILENCE_RMS_THRESHOLD then
    begin
      Inc(FSpeechFrames);
      FSilenceFrames := 0;
      FSpeechDetected := True;
      FActivePhraseStream.WriteBuffer(pData^, SampleCount * SizeOf(SmallInt));
    end
    else
    begin
      Inc(FSilenceFrames);
      if FSpeechDetected then
      begin
        // Keep buffering a short trailing silence so words aren't abruptly clipped
        if FSilenceFrames <= 3 then
          FActivePhraseStream.WriteBuffer(pData^, SampleCount * SizeOf(SmallInt));

        // When silence threshold is reached and speech was long enough, chunk phrase
        if (FSilenceFrames >= MAX_SILENCE_FRAMES) and (FSpeechFrames >= MIN_SPEECH_FRAMES) then
        begin
          DispatchPhraseChunk;
          FSpeechDetected := False;
          FSpeechFrames := 0;
          FSilenceFrames := 0;
        end;
      end;
    end;

    // Safety limit: if phrase exceeds MAX_PHRASE_SECONDS, chunk it automatically
    if FActivePhraseStream.Size >= (SAMPLE_RATE * 2 * MAX_PHRASE_SECONDS) then
    begin
      DispatchPhraseChunk;
      FSpeechDetected := False;
      FSpeechFrames := 0;
      FSilenceFrames := 0;
    end;
  finally
    FVoiceLock.Leave;
  end;
end;

procedure TAvroVoiceEngine.DispatchPhraseChunk;
begin
  if FActivePhraseStream.Size > (SAMPLE_RATE * 2 div 3) then // At least 0.66s audio
  begin
    // Spawn non-blocking background recognition worker
    TSTTWorkerThread.Create(Self, FActivePhraseStream, FAccentLocale, FForceOfflineMode, FAutoPunctuation);
  end;
  FActivePhraseStream.Clear;
end;

function TAvroVoiceEngine.StartListening: Boolean;
var
  WaveFormat: TWaveFormatEx;
  MMResult: MMRESULT;
  I: Integer;
begin
  Result := False;
  if FRecording then Exit;

  FVoiceLock.Enter;
  try
    FActivePhraseStream.Clear;
    FSpeechDetected := False;
    FSpeechFrames := 0;
    FSilenceFrames := 0;
    FCurrentAudioLevel := 0;
  finally
    FVoiceLock.Leave;
  end;

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

  for I := 0 to High(FWaveHeaders) do
  begin
    FillChar(FWaveHeaders[I], SizeOf(WAVEHDR), 0);
    FWaveHeaders[I].lpData := FWaveBuffers[I];
    FWaveHeaders[I].dwBufferLength := FBufferByteSize;
    waveInPrepareHeader(FWaveInHandle, @FWaveHeaders[I], SizeOf(WAVEHDR));
    waveInAddBuffer(FWaveInHandle, @FWaveHeaders[I], SizeOf(WAVEHDR));
  end;

  FRecording := True;
  waveInStart(FWaveInHandle);
  SetState(vsListening, 'Listening (শুনছি)...');
  Result := True;
end;

procedure TAvroVoiceEngine.StopListeningAndTranscribe;
begin
  if not FRecording then Exit;

  FRecording := False;
  waveInStop(FWaveInHandle);
  waveInReset(FWaveInHandle);

  FVoiceLock.Enter;
  try
    if FActivePhraseStream.Size > 0 then
      DispatchPhraseChunk;
  finally
    FVoiceLock.Leave;
  end;

  CancelListening;
end;

procedure TAvroVoiceEngine.CancelListening;
var
  I: Integer;
begin
  if FRecording or (FWaveInHandle <> 0) then
  begin
    FRecording := False;
    waveInStop(FWaveInHandle);
    waveInReset(FWaveInHandle);
    for I := 0 to High(FWaveHeaders) do
      waveInUnprepareHeader(FWaveInHandle, @FWaveHeaders[I], SizeOf(WAVEHDR));
    waveInClose(FWaveInHandle);
    FWaveInHandle := 0;
  end;

  FVoiceLock.Enter;
  try
    FActivePhraseStream.Clear;
    FSpeechDetected := False;
    FCurrentAudioLevel := 0;
  finally
    FVoiceLock.Leave;
  end;

  SetState(vsIdle, '');
end;

function TAvroVoiceEngine.RecognizeOnline(AudioStream: TMemoryStream; const Lang: string): string;
var
  hSession, hConnect, hRequest: HINTERNET;
  Host, Path: string;
  Buffer: array[0..4095] of AnsiChar;
  BytesRead: DWORD;
  ResponseData: TMemoryStream;
  RawJSON: string;
  PosUtterance, StartPos, EndPos: Integer;
  TimeoutMs: DWORD;
begin
  Result := '';
  Host := 'www.google.com';
  Path := '/speech-api/v2/recognize?output=json&lang=' + Lang + '&key=';

  hSession := InternetOpen('Avro-Voice/5.8', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hSession = nil then Exit;
  try
    TimeoutMs := 4000; // 4-second timeout to prevent stalling
    InternetSetOption(hSession, INTERNET_OPTION_CONNECT_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));
    InternetSetOption(hSession, INTERNET_OPTION_RECEIVE_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));
    InternetSetOption(hSession, INTERNET_OPTION_SEND_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));

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
              // Safe UTF-8 decoding without pointer casting bug
              RawJSON := TEncoding.UTF8.GetString(PByte(ResponseData.Memory), ResponseData.Size);
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

function TAvroVoiceEngine.RecognizeOffline(AudioStream: TMemoryStream; const Lang: string): string;
var
  SampleCount: Integer;
begin
  Result := '';
  if (AudioStream = nil) or (AudioStream.Size < 2) then Exit;

  SampleCount := AudioStream.Size div 2;
  // Route to offline C-ABI engine
  Result := TranscribeOfflinePCM16(PSmallInt(AudioStream.Memory), SampleCount, Lang);
end;

end.
