unit uSpellGoogleSearch;

interface

uses
  Classes,
  SysUtils,
  Windows,
  WinInet;

function QueryGoogleSuggestions(const QueryWord: string; var Suggestions: TStringList; TimeoutMs: Integer = 1500): Boolean;

implementation

function URLEncode(const S: string): string;
var
  I: Integer;
  B: Byte;
  UTF8Bytes: TBytes;
begin
  Result := '';
  UTF8Bytes := TEncoding.UTF8.GetBytes(S);
  for I := 0 to High(UTF8Bytes) do
  begin
    B := UTF8Bytes[I];
    if (B in [Ord('a')..Ord('z'), Ord('A')..Ord('Z'), Ord('0')..Ord('9'), Ord('-'), Ord('_'), Ord('.'), Ord('~')]) then
      Result := Result + Chr(B)
    else
      Result := Result + '%' + IntToHex(B, 2);
  end;
end;

function IsOnline: Boolean;
var
  Flags: DWORD;
begin
  Flags := 0;
  Result := InternetGetConnectedState(@Flags, 0);
end;

function QueryGoogleSuggestions(const QueryWord: string; var Suggestions: TStringList; TimeoutMs: Integer = 1500): Boolean;
var
  hSession, hURL: HINTERNET;
  Buffer: array[0..4095] of AnsiChar;
  BytesRead: DWORD;
  ResponseData: TMemoryStream;
  RawJSON: string;
  Url: string;
  StartPos, EndPos, NextPos: Integer;
  Candidate: string;
  SubStr: string;
begin
  Result := False;
  if (QueryWord = '') or (not IsOnline) then
    Exit; // Zero-delay return when offline

  Url := 'https://inputtools.google.com/request?text=' + URLEncode(QueryWord) + '&itc=bn-t-i0-und&num=5';

  hSession := InternetOpen('Avro-Spell/5.7', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hSession = nil then
    Exit;

  try
    InternetSetOption(hSession, INTERNET_OPTION_CONNECT_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));
    InternetSetOption(hSession, INTERNET_OPTION_RECEIVE_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));
    InternetSetOption(hSession, INTERNET_OPTION_DATA_RECEIVE_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));

    hURL := InternetOpenUrl(hSession, PChar(Url), nil, 0, INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_CACHE_WRITE, 0);
    if hURL = nil then
      Exit;

    try
      ResponseData := TMemoryStream.Create;
      try
        repeat
          BytesRead := 0;
          if InternetReadFile(hURL, @Buffer, SizeOf(Buffer), BytesRead) and (BytesRead > 0) then
            ResponseData.WriteBuffer(Buffer, BytesRead);
        until BytesRead = 0;

        if ResponseData.Size > 0 then
        begin
          RawJSON := TEncoding.UTF8.GetString(TBytes(ResponseData.Memory), 0, ResponseData.Size);

          // Fast JSON extraction for ["query",["sug1","sug2",...]]
          StartPos := Pos('[', RawJSON);
          if (StartPos > 0) and (Pos('"SUCCESS"', RawJSON) > 0) then
          begin
            StartPos := Pos('["', RawJSON);
            if StartPos > 0 then
            begin
              SubStr := Copy(RawJSON, StartPos + 2, Length(RawJSON));
              StartPos := Pos('[', SubStr);
              if StartPos > 0 then
              begin
                EndPos := Pos(']', SubStr);
                if EndPos > StartPos then
                begin
                  SubStr := Copy(SubStr, StartPos + 1, EndPos - StartPos - 1);
                  while Length(SubStr) > 0 do
                  begin
                    StartPos := Pos('"', SubStr);
                    if StartPos <= 0 then Break;
                    NextPos := Pos('"', Copy(SubStr, StartPos + 1, Length(SubStr)));
                    if NextPos <= 0 then Break;

                    Candidate := Copy(SubStr, StartPos + 1, NextPos - 1);
                    Candidate := Trim(Candidate);
                    if (Candidate <> '') and (Candidate <> QueryWord) then
                    begin
                      if Suggestions.IndexOf(Candidate) < 0 then
                      begin
                        Suggestions.Add(Candidate);
                        Result := True;
                      end;
                    end;
                    Delete(SubStr, 1, StartPos + NextPos);
                  end;
                end;
              end;
            end;
          end;
        end;
      finally
        ResponseData.Free;
      end;
    finally
      InternetCloseHandle(hURL);
    end;
  finally
    InternetCloseHandle(hSession);
  end;
end;

end.
