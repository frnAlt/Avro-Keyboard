unit uOfflineSTTWrapper;

interface

uses
  Windows,
  SysUtils,
  Classes,
  DateUtils;

type
  MEMORYSTATUSEX = record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    ullTotalPhys: UInt64;
    ullAvailPhys: UInt64;
    ullTotalPageFile: UInt64;
    ullAvailPageFile: UInt64;
    ullTotalVirtual: UInt64;
    ullAvailVirtual: UInt64;
    ullAvailExtendedVirtual: UInt64;
  end;

function GlobalMemoryStatusEx(var lpBuffer: MEMORYSTATUSEX): BOOL; stdcall; external kernel32;

function GetSystemTotalRAM_MB: Int64;
function IsLowSpecPC: Boolean;
function IsAcrylicSupported: Boolean;
function IsOfflineSTTAvailable: Boolean;
function TranscribeOfflinePCM16(const AudioData: PSmallInt; SampleCount: Integer; const Lang: string = 'bn'): string;
procedure TouchOfflineSTTActivity;
procedure CheckIdleUnload;

implementation

uses
  uFileFolderHandling,
  WindowsVersion;

type
  // Vosk C-ABI Function Signatures
  TVoskModelNew = function(const model_path: PAnsiChar): Pointer; cdecl;
  TVoskModelFree = procedure(model: Pointer); cdecl;
  TVoskRecognizerNew = function(model: Pointer; sample_rate: Single): Pointer; cdecl;
  TVoskRecognizerFree = procedure(recognizer: Pointer); cdecl;
  TVoskRecognizerAcceptWaveform = function(recognizer: Pointer; const data: PSmallInt; length: Integer): Integer; cdecl;
  TVoskRecognizerResult = function(recognizer: Pointer): PAnsiChar; cdecl;
  TVoskRecognizerFinalResult = function(recognizer: Pointer): PAnsiChar; cdecl;

  // Whisper C-ABI Function Signatures
  TWhisperInit = function(const path_model: PAnsiChar): Pointer; cdecl;
  TWhisperFree = procedure(ctx: Pointer); cdecl;

var
  hVoskDLL: HMODULE = 0;
  pVoskModel: Pointer = nil;
  pVoskRecognizer: Pointer = nil;
  LastActivity: TDateTime = 0;

  VoskModelNew: TVoskModelNew = nil;
  VoskModelFree: TVoskModelFree = nil;
  VoskRecognizerNew: TVoskRecognizerNew = nil;
  VoskRecognizerFree: TVoskRecognizerFree = nil;
  VoskRecognizerAcceptWaveform: TVoskRecognizerAcceptWaveform = nil;
  VoskRecognizerResult: TVoskRecognizerResult = nil;
  VoskRecognizerFinalResult: TVoskRecognizerFinalResult = nil;

function GetSystemTotalRAM_MB: Int64;
var
  MemStatus: MEMORYSTATUSEX;
begin
  FillChar(MemStatus, SizeOf(MEMORYSTATUSEX), 0);
  MemStatus.dwLength := SizeOf(MEMORYSTATUSEX);
  if GlobalMemoryStatusEx(MemStatus) then
    Result := MemStatus.ullTotalPhys div (1024 * 1024)
  else
    Result := 4096; // Assume 4GB default fallback
end;

function IsLowSpecPC: Boolean;
begin
  // Lower than 2048 MB RAM or older than Windows 10
  Result := (GetSystemTotalRAM_MB < 2048) or (TOSVersion.Major < 10);
end;

function IsAcrylicSupported: Boolean;
begin
  // Acrylic blur is supported on Windows 10 and Windows 11
  Result := (TOSVersion.Major >= 10);
end;

function FindModelDirectory: string;
var
  Candidate: string;
begin
  Candidate := GetAvroDataDir + 'models\';
  if DirectoryExists(Candidate) then
  begin
    Result := Candidate;
    Exit;
  end;

  Candidate := ExtractFilePath(ParamStr(0)) + 'models\';
  if DirectoryExists(Candidate) then
  begin
    Result := Candidate;
    Exit;
  end;

  Result := '';
end;

function FindOfflineDLL: string;
var
  Candidate, ModelDir: string;
begin
  ModelDir := FindModelDirectory;
  if ModelDir <> '' then
  begin
    Candidate := ModelDir + 'libvosk.dll';
    if FileExists(Candidate) then Exit(Candidate);
    Candidate := ModelDir + 'whisper.dll';
    if FileExists(Candidate) then Exit(Candidate);
  end;

  Candidate := ExtractFilePath(ParamStr(0)) + 'libvosk.dll';
  if FileExists(Candidate) then Exit(Candidate);

  Candidate := ExtractFilePath(ParamStr(0)) + 'whisper.dll';
  if FileExists(Candidate) then Exit(Candidate);

  Result := '';
end;

function IsOfflineSTTAvailable: Boolean;
begin
  Result := (FindOfflineDLL <> '') and (FindModelDirectory <> '');
end;

function LoadOfflineSTTEngine: Boolean;
var
  DLLPath, ModelDir: string;
begin
  Result := False;
  if (hVoskDLL <> 0) and (pVoskModel <> nil) then
  begin
    Result := True;
    Exit;
  end;

  DLLPath := FindOfflineDLL;
  ModelDir := FindModelDirectory;
  if (DLLPath = '') or (ModelDir = '') then Exit;

  hVoskDLL := LoadLibrary(PChar(DLLPath));
  if hVoskDLL = 0 then Exit;

  @VoskModelNew := GetProcAddress(hVoskDLL, 'vosk_model_new');
  @VoskModelFree := GetProcAddress(hVoskDLL, 'vosk_model_free');
  @VoskRecognizerNew := GetProcAddress(hVoskDLL, 'vosk_recognizer_new');
  @VoskRecognizerFree := GetProcAddress(hVoskDLL, 'vosk_recognizer_free');
  @VoskRecognizerAcceptWaveform := GetProcAddress(hVoskDLL, 'vosk_recognizer_accept_waveform_s');
  @VoskRecognizerResult := GetProcAddress(hVoskDLL, 'vosk_recognizer_result');
  @VoskRecognizerFinalResult := GetProcAddress(hVoskDLL, 'vosk_recognizer_final_result');

  if Assigned(VoskModelNew) and Assigned(VoskRecognizerNew) then
  begin
    pVoskModel := VoskModelNew(PAnsiChar(AnsiString(ModelDir)));
    if pVoskModel <> nil then
    begin
      pVoskRecognizer := VoskRecognizerNew(pVoskModel, 16000.0);
      Result := (pVoskRecognizer <> nil);
    end;
  end;

  if not Result then
  begin
    if hVoskDLL <> 0 then
    begin
      FreeLibrary(hVoskDLL);
      hVoskDLL := 0;
    end;
  end;
end;

procedure UnloadOfflineSTTEngine;
begin
  if Assigned(VoskRecognizerFree) and (pVoskRecognizer <> nil) then
  begin
    VoskRecognizerFree(pVoskRecognizer);
    pVoskRecognizer := nil;
  end;

  if Assigned(VoskModelFree) and (pVoskModel <> nil) then
  begin
    VoskModelFree(pVoskModel);
    pVoskModel := nil;
  end;

  if hVoskDLL <> 0 then
  begin
    FreeLibrary(hVoskDLL);
    hVoskDLL := 0;
  end;

  VoskModelNew := nil;
  VoskModelFree := nil;
  VoskRecognizerNew := nil;
  VoskRecognizerFree := nil;
  VoskRecognizerAcceptWaveform := nil;
  VoskRecognizerResult := nil;
  VoskRecognizerFinalResult := nil;
end;

procedure TouchOfflineSTTActivity;
begin
  LastActivity := Now;
end;

procedure CheckIdleUnload;
begin
  if (hVoskDLL <> 0) and (LastActivity > 0) then
  begin
    if SecondsBetween(Now, LastActivity) >= 120 then
    begin
      UnloadOfflineSTTEngine;
      LastActivity := 0;
    end;
  end;
end;

function TranscribeOfflinePCM16(const AudioData: PSmallInt; SampleCount: Integer; const Lang: string = 'bn'): string;
var
  JsonResult: PAnsiChar;
  RawJSON: string;
  PosText, StartPos, EndPos: Integer;
begin
  Result := '';
  TouchOfflineSTTActivity;

  if not LoadOfflineSTTEngine then Exit;

  if Assigned(VoskRecognizerAcceptWaveform) and (pVoskRecognizer <> nil) and (AudioData <> nil) and (SampleCount > 0) then
  begin
    VoskRecognizerAcceptWaveform(pVoskRecognizer, AudioData, SampleCount);
    if Assigned(VoskRecognizerFinalResult) then
    begin
      JsonResult := VoskRecognizerFinalResult(pVoskRecognizer);
      if JsonResult <> nil then
      begin
        RawJSON := UTF8ToString(JsonResult);
        // Extract "text" from {"text" : "..."}
        PosText := Pos('"text"', RawJSON);
        if PosText > 0 then
        begin
          StartPos := Pos(':', Copy(RawJSON, PosText, Length(RawJSON)));
          if StartPos > 0 then
          begin
            StartPos := PosText + StartPos;
            while (StartPos <= Length(RawJSON)) and ((RawJSON[StartPos] = ' ') or (RawJSON[StartPos] = '"')) do
              Inc(StartPos);
            EndPos := StartPos;
            while (EndPos <= Length(RawJSON)) and (RawJSON[EndPos] <> '"') do
              Inc(EndPos);
            if EndPos > StartPos then
              Result := Trim(Copy(RawJSON, StartPos, EndPos - StartPos));
          end;
        end;
      end;
    end;
  end;
end;

initialization

finalization
  UnloadOfflineSTTEngine;

end.
