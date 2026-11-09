{
  =============================================================================
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  =============================================================================
}

{$INCLUDE ../ProjectDefines.inc}
unit u_VirtualFontInstall;

interface

uses
  Windows,
  SysUtils,
  classes,
  Messages;

procedure InstallVirtualFont(FontFilePath: string);
procedure RemoveVirtualFont(FontFilePath: string);

// Privately used
function GetTempDirectory: string;
function GetFontName(TTF_Path: string): string;
procedure CheckDeleteTempFile(fname: string);

implementation

uses
  clsRegistry_XMLSetting;

{ =============================================================================== }

function GetTempDirectory: string;
var
  tempFolder: array [0 .. MAX_PATH] of Char;
begin
  GetTempPath(MAX_PATH, @tempFolder);
  result := StrPas(tempFolder);
end;

{ =============================================================================== }

procedure CheckDeleteTempFile(fname: string);
begin
  if fileexists(fname) then
    DeleteFile(fname);

end;

{ =============================================================================== }

function GetFontName(TTF_Path: string): string;
var
  TempName, FontName, AInfo: string;
  S:                         TFileStream;
  APos:                      Integer;
begin
  FontName := '';
  if (TTF_Path = '') or (not FileExists(TTF_Path)) then
  begin
    Result := '';
    Exit;
  end;

  TempName := IncludeTrailingPathDelimiter(GetTempDirectory) + 'tmpfntavro.tmp';
  CheckDeleteTempFile(TempName);

  try
    if CreateScalableFontResource(0, PChar(TempName), PChar(TTF_Path), nil) then
    begin
      if FileExists(TempName) then
      begin
        try
          S := TFileStream.Create(TempName, fmOpenRead or fmShareDenyWrite);
          try
            if S.Size > 0 then
            begin
              SetLength(AInfo, S.Size);
              S.Read(AInfo[1], S.Size);
              APos := Pos('FONTRES:', AInfo);
              if APos > 0 then
                FontName := PChar(@AInfo[APos + 8]);
            end;
          finally
            S.Free;
          end;
        except
          on E: Exception do
            FontName := '';
        end;
      end;
    end;
  finally
    CheckDeleteTempFile(TempName);
  end;

  Result := FontName;
end;

{ =============================================================================== }

procedure InstallVirtualFont(FontFilePath: string);
var
  ActualFontPath:                                             string;
  PrevDefaultFixedFont, PrevDefaultPropFont, VirtualFontName: string;
  Reg:                                                        TMyRegistry;
begin
  ActualFontPath := FontFilePath;
  if not FileExists(ActualFontPath) then
  begin
    if FileExists(ExtractFilePath(ParamStr(0)) + 'Virtual Font\Siyamrupali.ttf') then
      ActualFontPath := ExtractFilePath(ParamStr(0)) + 'Virtual Font\Siyamrupali.ttf'
    else if FileExists(ExtractFilePath(ParamStr(0)) + 'fonts\Siyamrupali.ttf') then
      ActualFontPath := ExtractFilePath(ParamStr(0)) + 'fonts\Siyamrupali.ttf'
    else if FileExists(ExtractFilePath(ParamStr(0)) + 'assets\fonts\Siyamrupali.ttf') then
      ActualFontPath := ExtractFilePath(ParamStr(0)) + 'assets\fonts\Siyamrupali.ttf'
    else
      Exit;
  end;

  AddFontResource(PChar(ActualFontPath));
  VirtualFontName := GetFontName(ActualFontPath);
  if VirtualFontName = '' then
    VirtualFontName := 'Siyam Rupali';

  Reg := TMyRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Software\Microsoft\Internet Explorer\International\Scripts\11', True) = True then
    begin
      PrevDefaultFixedFont := trim(Reg.ReadString('IEFixedFontName'));
      PrevDefaultPropFont := trim(Reg.ReadString('IEPropFontName'));

      if PrevDefaultFixedFont = '' then
        PrevDefaultFixedFont := 'none';
      if PrevDefaultPropFont = '' then
        PrevDefaultPropFont := 'none';

      if trim(Reg.ReadString('IEFixedFontName_Prev')) = '' then
        Reg.WriteString('IEFixedFontName_Prev', PrevDefaultFixedFont);

      if trim(Reg.ReadString('IEPropFontName_Prev')) = '' then
        Reg.WriteString('IEPropFontName_Prev', PrevDefaultPropFont);

      Reg.WriteString('IEFixedFontName', VirtualFontName);
      Reg.WriteString('IEPropFontName', VirtualFontName);
    end;
  finally
    FreeAndNil(Reg);
  end;

  SendMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0);
end;

{ =============================================================================== }

procedure RemoveVirtualFont(FontFilePath: string);
var
  ActualFontPath:                            string;
  PrevDefaultFixedFont, PrevDefaultPropFont: string;
  Reg:                                       TMyRegistry;
begin
  ActualFontPath := FontFilePath;
  if not FileExists(ActualFontPath) then
  begin
    if FileExists(ExtractFilePath(ParamStr(0)) + 'Virtual Font\Siyamrupali.ttf') then
      ActualFontPath := ExtractFilePath(ParamStr(0)) + 'Virtual Font\Siyamrupali.ttf'
    else if FileExists(ExtractFilePath(ParamStr(0)) + 'fonts\Siyamrupali.ttf') then
      ActualFontPath := ExtractFilePath(ParamStr(0)) + 'fonts\Siyamrupali.ttf'
    else if FileExists(ExtractFilePath(ParamStr(0)) + 'assets\fonts\Siyamrupali.ttf') then
      ActualFontPath := ExtractFilePath(ParamStr(0)) + 'assets\fonts\Siyamrupali.ttf';
  end;

  if FileExists(ActualFontPath) then
    RemoveFontResource(PChar(ActualFontPath));

  Reg := TMyRegistry.Create;
  try
    if Reg.OpenKey('Software\Microsoft\Internet Explorer\International\Scripts\11', True) = True then
    begin
      PrevDefaultFixedFont := trim(Reg.ReadString('IEFixedFontName_Prev'));
      PrevDefaultPropFont := trim(Reg.ReadString('IEPropFontName_Prev'));

      if PrevDefaultFixedFont = 'none' then
        PrevDefaultFixedFont := '';
      if PrevDefaultPropFont = 'none' then
        PrevDefaultPropFont := '';

      Reg.DeleteValue('IEFixedFontName_Prev');
      Reg.DeleteValue('IEPropFontName_Prev');

      Reg.WriteString('IEFixedFontName', PrevDefaultFixedFont);
      Reg.WriteString('IEPropFontName', PrevDefaultPropFont);
    end;
  finally
    FreeAndNil(Reg);
  end;

  SendMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0);
end;

end.
