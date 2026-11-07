{
  =============================================================================
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  =============================================================================
}

unit uDBase;

{$INCLUDE ../../ProjectDefines.inc}

interface

uses
  SysUtils,
  Generics.Collections,
  Classes,
  SyncObjs,
  FireDAC.Phys.SQLite,
  Data.DB,
  FireDAC.Stan.Def,
  FireDAC.Phys.SQLiteWrapper,
  FireDAC.Comp.Client,
  FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.Intf,
  FireDAC.Phys,
  Forms;

type
  LongIntArray = array of LongInt;

  IntegerArray = LongIntArray;

procedure LoadWordDatabase;
procedure UnloadWordDatabase;
procedure LoadSuffix;
procedure LoadOneDatabase(FileName: string; var Arr: TStringList; var Dict: TDictionary<string, Boolean>);

// Voice Commands & Lexicon Integration
procedure LoadVoiceCommands;
function ApplyVoicePunctuationCommands(const InputText: string): string;
function CheckWordInLexicon(const SpokenWord: string; var CorrectedWord: string): Boolean;
procedure AddOrUpdateUserLexicon(const SpokenWord, CorrectedWord: string);
function IsValidBanglaWord(const Word: string): Boolean;

var
  DBCriticalSection:                 TCriticalSection;
  VoiceCommandsDict:                 TDictionary<string, string>;
  VoiceUserLexiconDict:              TDictionary<string, string>;
  FDatabase:                         TSQLiteDatabase;
  FDatabaseLoaded, FDatabaseLoading: Boolean;
  FDPhysSQLiteDriverLink1:           TFDPhysSQLiteDriverLink;
  FDConnection1:                     TFDConnection;
  W_A:                               TStringList;
  W_AA:                              TStringList;
  W_I:                               TStringList;
  W_II:                              TStringList;
  W_U:                               TStringList;
  W_UU:                              TStringList;
  W_RRI:                             TStringList;
  W_E:                               TStringList;
  W_OI:                              TStringList;
  W_O:                               TStringList;
  W_OU:                              TStringList;
  W_B:                               TStringList;
  W_BH:                              TStringList;
  W_C:                               TStringList;
  W_CH:                              TStringList;
  W_D:                               TStringList;
  W_Dh:                              TStringList;
  W_Dd:                              TStringList;
  W_Ddh:                             TStringList;
  W_G:                               TStringList;
  W_Gh:                              TStringList;
  W_H:                               TStringList;
  W_J:                               TStringList;
  W_Jh:                              TStringList;
  W_K:                               TStringList;
  W_Kh:                              TStringList;
  W_L:                               TStringList;
  W_M:                               TStringList;
  W_N:                               TStringList;
  W_NGA:                             TStringList;
  W_NYA:                             TStringList;
  W_Nn:                              TStringList;
  W_P:                               TStringList;
  W_Ph:                              TStringList;
  W_R:                               TStringList;
  W_Rr:                              TStringList;
  W_Rrh:                             TStringList;
  W_S:                               TStringList;
  W_Sh:                              TStringList;
  W_Ss:                              TStringList;
  W_T:                               TStringList;
  W_Th:                              TStringList;
  W_Tt:                              TStringList;
  W_Tth:                             TStringList;
  W_Y:                               TStringList;
  W_Z:                               TStringList;
  W_Khandatta:                       TStringList;
  Suffix_Spell:                      TStringList;
  Suffix:                            TDictionary<string, string>;

  // Hashtables/dictionaries
var
  W_Hash_A:         TDictionary<string, Boolean>;
  W_Hash_AA:        TDictionary<string, Boolean>;
  W_Hash_I:         TDictionary<string, Boolean>;
  W_Hash_II:        TDictionary<string, Boolean>;
  W_Hash_U:         TDictionary<string, Boolean>;
  W_Hash_UU:        TDictionary<string, Boolean>;
  W_Hash_RRI:       TDictionary<string, Boolean>;
  W_Hash_E:         TDictionary<string, Boolean>;
  W_Hash_OI:        TDictionary<string, Boolean>;
  W_Hash_O:         TDictionary<string, Boolean>;
  W_Hash_OU:        TDictionary<string, Boolean>;
  W_Hash_B:         TDictionary<string, Boolean>;
  W_Hash_BH:        TDictionary<string, Boolean>;
  W_Hash_C:         TDictionary<string, Boolean>;
  W_Hash_CH:        TDictionary<string, Boolean>;
  W_Hash_D:         TDictionary<string, Boolean>;
  W_Hash_Dh:        TDictionary<string, Boolean>;
  W_Hash_Dd:        TDictionary<string, Boolean>;
  W_Hash_Ddh:       TDictionary<string, Boolean>;
  W_Hash_G:         TDictionary<string, Boolean>;
  W_Hash_Gh:        TDictionary<string, Boolean>;
  W_Hash_H:         TDictionary<string, Boolean>;
  W_Hash_J:         TDictionary<string, Boolean>;
  W_Hash_Jh:        TDictionary<string, Boolean>;
  W_Hash_K:         TDictionary<string, Boolean>;
  W_Hash_Kh:        TDictionary<string, Boolean>;
  W_Hash_L:         TDictionary<string, Boolean>;
  W_Hash_M:         TDictionary<string, Boolean>;
  W_Hash_N:         TDictionary<string, Boolean>;
  W_Hash_NGA:       TDictionary<string, Boolean>;
  W_Hash_NYA:       TDictionary<string, Boolean>;
  W_Hash_Nn:        TDictionary<string, Boolean>;
  W_Hash_P:         TDictionary<string, Boolean>;
  W_Hash_Ph:        TDictionary<string, Boolean>;
  W_Hash_R:         TDictionary<string, Boolean>;
  W_Hash_Rr:        TDictionary<string, Boolean>;
  W_Hash_Rrh:       TDictionary<string, Boolean>;
  W_Hash_S:         TDictionary<string, Boolean>;
  W_Hash_Sh:        TDictionary<string, Boolean>;
  W_Hash_Ss:        TDictionary<string, Boolean>;
  W_Hash_T:         TDictionary<string, Boolean>;
  W_Hash_Th:        TDictionary<string, Boolean>;
  W_Hash_Tt:        TDictionary<string, Boolean>;
  W_Hash_Tth:       TDictionary<string, Boolean>;
  W_Hash_Y:         TDictionary<string, Boolean>;
  W_Hash_Z:         TDictionary<string, Boolean>;
  W_Hash_Khandatta: TDictionary<string, Boolean>;

implementation

uses

  {$IF Not (Defined(SpellChecker) OR (Defined(SpellCheckerDll))))}
  uForm1,

  {$ENDIF}
  StrUtils,
  HashTable,
  uFileFolderHandling,
  windows;

procedure LoadSuffix;
var
  FirstPart, SecondPart: string;
  Stmt:                  TSQLiteStatement;
  SelectSQL:             string;
begin
  SelectSQL := 'SELECT English, Bangla FROM Suffix;';

  Suffix_Spell := TStringList.Create;
  Suffix_Spell.Sorted := True;
  Suffix_Spell.Duplicates := dupIgnore;

  Suffix := TDictionary<string, string>.Create;

  Stmt := TSQLiteStatement.Create(FDatabase);
  Stmt.Prepare(SelectSQL);

  Suffix_Spell.BeginUpdate;

  while Stmt.Fetch do
  begin

    FirstPart := Stmt.Columns[0].AsString;  // English
    SecondPart := Stmt.Columns[1].AsString; // Bangla

    Suffix_Spell.Add(SecondPart);

    Suffix.AddOrSetValue(FirstPart, SecondPart);
  end;

  Suffix_Spell.EndUpdate;

  FreeAndNil(Stmt);
end;

procedure UnloadWordDatabase;
begin
  if (not FDatabaseLoading) and FDatabaseLoaded then
  begin

    FDatabaseLoading := True;

    W_A.Clear;
    FreeAndNil(W_A);
    W_AA.Clear;
    FreeAndNil(W_AA);
    W_I.Clear;
    FreeAndNil(W_I);
    W_II.Clear;
    FreeAndNil(W_II);
    W_U.Clear;
    FreeAndNil(W_U);
    W_UU.Clear;
    FreeAndNil(W_UU);
    W_RRI.Clear;
    FreeAndNil(W_RRI);
    W_E.Clear;
    FreeAndNil(W_E);
    W_OI.Clear;
    FreeAndNil(W_OI);
    W_O.Clear;
    FreeAndNil(W_O);
    W_OU.Clear;
    FreeAndNil(W_OU);

    W_B.Clear;
    FreeAndNil(W_B);
    W_BH.Clear;
    FreeAndNil(W_BH);
    W_C.Clear;
    FreeAndNil(W_C);
    W_CH.Clear;
    FreeAndNil(W_CH);
    W_D.Clear;
    FreeAndNil(W_D);
    W_Dh.Clear;
    FreeAndNil(W_Dh);
    W_Dd.Clear;
    FreeAndNil(W_Dd);
    W_Ddh.Clear;
    FreeAndNil(W_Ddh);
    W_G.Clear;
    FreeAndNil(W_G);
    W_Gh.Clear;
    FreeAndNil(W_Gh);
    W_H.Clear;
    FreeAndNil(W_H);
    W_J.Clear;
    FreeAndNil(W_J);
    W_Jh.Clear;
    FreeAndNil(W_Jh);
    W_K.Clear;
    FreeAndNil(W_K);
    W_Kh.Clear;
    FreeAndNil(W_Kh);
    W_L.Clear;
    FreeAndNil(W_L);
    W_M.Clear;
    FreeAndNil(W_M);
    W_N.Clear;
    FreeAndNil(W_N);
    W_NGA.Clear;
    FreeAndNil(W_NGA);
    W_NYA.Clear;
    FreeAndNil(W_NYA);
    W_Nn.Clear;
    FreeAndNil(W_Nn);
    W_P.Clear;
    FreeAndNil(W_P);
    W_Ph.Clear;
    FreeAndNil(W_Ph);
    W_R.Clear;
    FreeAndNil(W_R);
    W_Rr.Clear;
    FreeAndNil(W_Rr);
    W_Rrh.Clear;
    FreeAndNil(W_Rrh);
    W_S.Clear;
    FreeAndNil(W_S);
    W_Sh.Clear;
    FreeAndNil(W_Sh);
    W_Ss.Clear;
    FreeAndNil(W_Ss);
    W_T.Clear;
    FreeAndNil(W_T);
    W_Th.Clear;
    FreeAndNil(W_Th);
    W_Tt.Clear;
    FreeAndNil(W_Tt);
    W_Tth.Clear;
    FreeAndNil(W_Tth);
    W_Y.Clear;
    FreeAndNil(W_Y);
    W_Z.Clear;
    FreeAndNil(W_Z);
    W_Khandatta.Clear;
    FreeAndNil(W_Khandatta);

    // Clear dictionaries
    W_Hash_A.Clear;
    W_Hash_AA.Clear;
    W_Hash_I.Clear;
    W_Hash_II.Clear;
    W_Hash_U.Clear;
    W_Hash_UU.Clear;
    W_Hash_RRI.Clear;
    W_Hash_E.Clear;
    W_Hash_OI.Clear;
    W_Hash_O.Clear;
    W_Hash_OU.Clear;
    W_Hash_B.Clear;
    W_Hash_BH.Clear;
    W_Hash_C.Clear;
    W_Hash_CH.Clear;
    W_Hash_D.Clear;
    W_Hash_Dh.Clear;
    W_Hash_Dd.Clear;
    W_Hash_Ddh.Clear;
    W_Hash_G.Clear;
    W_Hash_Gh.Clear;
    W_Hash_H.Clear;
    W_Hash_J.Clear;
    W_Hash_Jh.Clear;
    W_Hash_K.Clear;
    W_Hash_Kh.Clear;
    W_Hash_L.Clear;
    W_Hash_M.Clear;
    W_Hash_N.Clear;
    W_Hash_NGA.Clear;
    W_Hash_NYA.Clear;
    W_Hash_Nn.Clear;
    W_Hash_P.Clear;
    W_Hash_Ph.Clear;
    W_Hash_R.Clear;
    W_Hash_Rr.Clear;
    W_Hash_Rrh.Clear;
    W_Hash_S.Clear;
    W_Hash_Sh.Clear;
    W_Hash_Ss.Clear;
    W_Hash_T.Clear;
    W_Hash_Th.Clear;
    W_Hash_Tt.Clear;
    W_Hash_Tth.Clear;
    W_Hash_Y.Clear;
    W_Hash_Z.Clear;
    W_Hash_Khandatta.Clear;

    Suffix_Spell.Clear;
    FreeAndNil(Suffix_Spell);

    Suffix.Clear;
    FreeAndNil(Suffix);

    FDatabaseLoaded := False;
    FDatabaseLoading := False;
  end;

  {$IF Not (Defined(SpellChecker) OR (Defined(SpellCheckerDll))))}
  AvroMainForm1.TrimAppMemorySize;

  {$ENDIF}
end;

procedure LoadWordDatabase;
begin
  if FDatabaseLoaded or FDatabaseLoading then
    exit;
  FDatabaseLoading := True;

  FDPhysSQLiteDriverLink1 := TFDPhysSQLiteDriverLink.Create(nil);
  FDPhysSQLiteDriverLink1.EngineLinkage := slstatic;
  FDConnection1 := TFDConnection.Create(nil);

  FDConnection1.DriverName := 'SQLITE';

  if FileExists(GetAvroDataDir + 'Database.db3') then
  begin
    FDConnection1.Params.Values['Database'] := GetAvroDataDir + 'Database.db3';

    try
      FDConnection1.Open;
      try
        FDConnection1.ExecSQL('PRAGMA journal_mode = WAL;');
        FDConnection1.ExecSQL('PRAGMA synchronous = NORMAL;');
        FDConnection1.ExecSQL('CREATE TABLE IF NOT EXISTS VoiceCommands (CommandText TEXT PRIMARY KEY, ReplacementText TEXT NOT NULL);');
        FDConnection1.ExecSQL('CREATE INDEX IF NOT EXISTS idx_voice_command ON VoiceCommands(CommandText);');
        FDConnection1.ExecSQL('CREATE TABLE IF NOT EXISTS VoiceUserLexicon (SpokenWord TEXT PRIMARY KEY, CorrectedWord TEXT NOT NULL, Frequency INTEGER DEFAULT 1, LastUsed DATETIME DEFAULT CURRENT_TIMESTAMP);');
        FDConnection1.ExecSQL('CREATE INDEX IF NOT EXISTS idx_voice_lexicon ON VoiceUserLexicon(SpokenWord);');
      except
        // Silently continue if PRAGMA or table creation is restricted
      end;

      FDatabase := TSQLiteDatabase(FDConnection1.CliObj);

      try

        LoadOneDatabase('A', W_A, W_Hash_A);
        LoadOneDatabase('AA', W_AA, W_Hash_AA);
        LoadOneDatabase('I', W_I, W_Hash_I);
        LoadOneDatabase('II', W_II, W_Hash_II);
        LoadOneDatabase('U', W_U, W_Hash_U);
        LoadOneDatabase('UU', W_UU, W_Hash_UU);
        LoadOneDatabase('RRI', W_RRI, W_Hash_RRI);
        LoadOneDatabase('E', W_E, W_Hash_E);
        LoadOneDatabase('OI', W_OI, W_Hash_OI);
        LoadOneDatabase('O', W_O, W_Hash_O);
        LoadOneDatabase('OU', W_OU, W_Hash_OU);

        LoadOneDatabase('B', W_B, W_Hash_B);
        LoadOneDatabase('BH', W_BH, W_Hash_BH);
        LoadOneDatabase('C', W_C, W_Hash_C);
        LoadOneDatabase('CH', W_CH, W_Hash_CH);
        LoadOneDatabase('D', W_D, W_Hash_D);
        LoadOneDatabase('Dd', W_Dd, W_Hash_Dd);
        LoadOneDatabase('Dh', W_Dh, W_Hash_Dh);
        LoadOneDatabase('Ddh', W_Ddh, W_Hash_Ddh);
        LoadOneDatabase('G', W_G, W_Hash_G);
        LoadOneDatabase('Gh', W_Gh, W_Hash_Gh);
        LoadOneDatabase('H', W_H, W_Hash_H);
        LoadOneDatabase('J', W_J, W_Hash_J);
        LoadOneDatabase('Jh', W_Jh, W_Hash_Jh);
        LoadOneDatabase('K', W_K, W_Hash_K);
        LoadOneDatabase('Kh', W_Kh, W_Hash_Kh);
        LoadOneDatabase('L', W_L, W_Hash_L);
        LoadOneDatabase('M', W_M, W_Hash_M);
        LoadOneDatabase('N', W_N, W_Hash_N);
        LoadOneDatabase('NN', W_Nn, W_Hash_Nn);
        LoadOneDatabase('NGA', W_NGA, W_Hash_NGA);
        LoadOneDatabase('NYA', W_NYA, W_Hash_NYA);
        LoadOneDatabase('P', W_P, W_Hash_P);
        LoadOneDatabase('Ph', W_Ph, W_Hash_Ph);
        LoadOneDatabase('R', W_R, W_Hash_R);
        LoadOneDatabase('Rr', W_Rr, W_Hash_Rr);
        LoadOneDatabase('Rrh', W_Rrh, W_Hash_Rrh);
        LoadOneDatabase('S', W_S, W_Hash_S);
        LoadOneDatabase('Sh', W_Sh, W_Hash_Sh);
        LoadOneDatabase('Ss', W_Ss, W_Hash_Ss);
        LoadOneDatabase('T', W_T, W_Hash_T);
        LoadOneDatabase('TT', W_Tt, W_Hash_Tt);
        LoadOneDatabase('TH', W_Th, W_Hash_Th);
        LoadOneDatabase('TTH', W_Tth, W_Hash_Tth);
        LoadOneDatabase('Y', W_Y, W_Hash_Y);
        LoadOneDatabase('Z', W_Z, W_Hash_Z);
        LoadOneDatabase('Khandatta', W_Khandatta, W_Hash_Khandatta);

        LoadSuffix;
        LoadVoiceCommands;

        FDatabase.Close;

        {$IF Not (Defined(SpellChecker) OR (Defined(SpellCheckerDll))))}
        AvroMainForm1.TrimAppMemorySize;

        {$ENDIF}
        FDatabaseLoaded := True;
        FDatabaseLoading := False;
      except
        on E: Exception do
        begin
          Application.MessageBox(Pchar('Cannot load Avro database!' + #10 + '' + #10 + '-> Make sure ''Database.db3'' file is present in ' + GetAvroDataDir +
                ' folder, or' + #10 + '-> ''Database.db3'' file is not corrupt.' + #10 + '' + #10 + 'Reinstalling Avro Keyboard may solve this problem.'),
            'Avro Keyboard', MB_OK + MB_ICONHAND + MB_DEFBUTTON1 + MB_APPLMODAL);
        end;
      end;
    finally
      FreeAndNil(FDatabase);
    end;
  end;

end;

procedure LoadOneDatabase(FileName: string; var Arr: TStringList; var Dict: TDictionary<string, Boolean>);
var
  Stmt:      TSQLiteStatement;
  SelectSQL: string;
  i:         Integer;
begin
  SelectSQL := 'SELECT Words FROM ' + FileName + ';';
  // Inititialize Data
  Arr := TStringList.Create;

  Stmt := TSQLiteStatement.Create(FDatabase);
  Stmt.Prepare('select Words from ' + FileName);
  Arr.BeginUpdate;

  for i := 1 to Stmt.ColumnDefsCount do
    TSQLiteColumn.Create(Stmt.Columns).Index := i - 1;
  Stmt.Execute;

  while Stmt.Fetch do
    Arr.Add(Stmt.Columns[0].AsString);

  Arr.EndUpdate;

  BuildOneHashTable(Arr, Dict);

  Stmt.Free;

  {$IFNDEF SpellChecker}
  Application.ProcessMessages;

  {$ENDIF}
end;

procedure InitDefaultVoiceCommands;
begin
  if VoiceCommandsDict = nil then
    VoiceCommandsDict := TDictionary<string, string>.Create;

  VoiceCommandsDict.AddOrSetValue('দাঁড়ি', '।');
  VoiceCommandsDict.AddOrSetValue('দাড়ি', '।');
  VoiceCommandsDict.AddOrSetValue('পূর্ণচ্ছেদ', '।');
  VoiceCommandsDict.AddOrSetValue('কমা', ',');
  VoiceCommandsDict.AddOrSetValue('প্রশ্নবোধক', '?');
  VoiceCommandsDict.AddOrSetValue('প্রশ্নচিহ্ন', '?');
  VoiceCommandsDict.AddOrSetValue('জিজ্ঞাসাচিহ্ন', '?');
  VoiceCommandsDict.AddOrSetValue('জিজ্ঞাসা চিহ্ন', '?');
  VoiceCommandsDict.AddOrSetValue('প্রশ্নবোধক চিহ্ন', '?');
  VoiceCommandsDict.AddOrSetValue('বিস্ময়চিহ্ন', '!');
  VoiceCommandsDict.AddOrSetValue('বিস্ময়বোধক', '!');
  VoiceCommandsDict.AddOrSetValue('বিস্ময়সূচক', '!');
  VoiceCommandsDict.AddOrSetValue('কোলন', ':');
  VoiceCommandsDict.AddOrSetValue('ক্লোন', ':');
  VoiceCommandsDict.AddOrSetValue('সেমিকোলন', ';');
  VoiceCommandsDict.AddOrSetValue('হাইফেন', '-');
  VoiceCommandsDict.AddOrSetValue('ড্যাশ', '—');
  VoiceCommandsDict.AddOrSetValue('নতুন লাইন', sLineBreak);
  VoiceCommandsDict.AddOrSetValue('নতুন প্যারা', sLineBreak + sLineBreak);
  VoiceCommandsDict.AddOrSetValue('উদ্ধৃতি চিহ্ন', '"');
end;

procedure LoadVoiceCommands;
var
  Stmt: TSQLiteStatement;
  CmdText, ReplText: string;
begin
  DBCriticalSection.Enter;
  try
    InitDefaultVoiceCommands;

    if VoiceUserLexiconDict = nil then
      VoiceUserLexiconDict := TDictionary<string, string>.Create;

    if FDatabase <> nil then
    begin
      try
        Stmt := TSQLiteStatement.Create(FDatabase);
        try
          Stmt.Prepare('SELECT CommandText, ReplacementText FROM VoiceCommands');
          while Stmt.Fetch do
          begin
            CmdText := Stmt.Columns[0].AsString;
            ReplText := Stmt.Columns[1].AsString;
            if (CmdText <> '') and (ReplText <> '') then
              VoiceCommandsDict.AddOrSetValue(CmdText, ReplText);
          end;
        finally
          Stmt.Free;
        end;

        Stmt := TSQLiteStatement.Create(FDatabase);
        try
          Stmt.Prepare('SELECT SpokenWord, CorrectedWord FROM VoiceUserLexicon');
          while Stmt.Fetch do
          begin
            CmdText := Stmt.Columns[0].AsString;
            ReplText := Stmt.Columns[1].AsString;
            if (CmdText <> '') and (ReplText <> '') then
              VoiceUserLexiconDict.AddOrSetValue(CmdText, ReplText);
          end;
        finally
          Stmt.Free;
        end;
      except
        // Fall back to default memory dictionaries
      end;
    end;
  finally
    DBCriticalSection.Leave;
  end;
end;

function ApplyVoicePunctuationCommands(const InputText: string): string;
var
  Pair: TPair<string, string>;
  S: string;
begin
  S := InputText;
  if (S = '') or (VoiceCommandsDict = nil) then
  begin
    Result := S;
    Exit;
  end;

  DBCriticalSection.Enter;
  try
    for Pair in VoiceCommandsDict do
    begin
      // Replace with space prefix first, then raw token
      S := StringReplace(S, ' ' + Pair.Key, Pair.Value, [rfReplaceAll, rfIgnoreCase]);
      S := StringReplace(S, Pair.Key, Pair.Value, [rfReplaceAll, rfIgnoreCase]);
    end;
  finally
    DBCriticalSection.Leave;
  end;

  // Normalize spacing around punctuation
  S := StringReplace(S, ' ।', '।', [rfReplaceAll]);
  S := StringReplace(S, ' ,', ',', [rfReplaceAll]);
  S := StringReplace(S, ' ?', '?', [rfReplaceAll]);
  S := StringReplace(S, ' !', '!', [rfReplaceAll]);
  S := StringReplace(S, ' :', ':', [rfReplaceAll]);
  S := StringReplace(S, ' ;', ';', [rfReplaceAll]);

  Result := S;
end;

function CheckWordInLexicon(const SpokenWord: string; var CorrectedWord: string): Boolean;
var
  W: string;
begin
  Result := False;
  W := Trim(SpokenWord);
  if (W = '') or (VoiceUserLexiconDict = nil) then Exit;

  DBCriticalSection.Enter;
  try
    if VoiceUserLexiconDict.TryGetValue(W, CorrectedWord) then
      Result := True;
  finally
    DBCriticalSection.Leave;
  end;
end;

procedure AddOrUpdateUserLexicon(const SpokenWord, CorrectedWord: string);
var
  SW, CW: string;
begin
  SW := Trim(SpokenWord);
  CW := Trim(CorrectedWord);
  if (SW = '') or (CW = '') then Exit;

  DBCriticalSection.Enter;
  try
    if VoiceUserLexiconDict = nil then
      VoiceUserLexiconDict := TDictionary<string, string>.Create;
    VoiceUserLexiconDict.AddOrSetValue(SW, CW);
  finally
    DBCriticalSection.Leave;
  end;
end;

function IsValidBanglaWord(const Word: string): Boolean;
var
  W: string;
  FirstChar: Char;
begin
  Result := False;
  W := Trim(Word);
  if W = '' then Exit;

  DBCriticalSection.Enter;
  try
    if (VoiceUserLexiconDict <> nil) and VoiceUserLexiconDict.ContainsKey(W) then
    begin
      Result := True;
      Exit;
    end;

    FirstChar := W[1];
    case FirstChar of
      'অ': Result := (W_Hash_A <> nil) and W_Hash_A.ContainsKey(W);
      'আ': Result := (W_Hash_AA <> nil) and W_Hash_AA.ContainsKey(W);
      'ই': Result := (W_Hash_I <> nil) and W_Hash_I.ContainsKey(W);
      'ঈ': Result := (W_Hash_II <> nil) and W_Hash_II.ContainsKey(W);
      'উ': Result := (W_Hash_U <> nil) and W_Hash_U.ContainsKey(W);
      'ঊ': Result := (W_Hash_UU <> nil) and W_Hash_UU.ContainsKey(W);
      'ঋ': Result := (W_Hash_RRI <> nil) and W_Hash_RRI.ContainsKey(W);
      'এ': Result := (W_Hash_E <> nil) and W_Hash_E.ContainsKey(W);
      'ঐ': Result := (W_Hash_OI <> nil) and W_Hash_OI.ContainsKey(W);
      'ও': Result := (W_Hash_O <> nil) and W_Hash_O.ContainsKey(W);
      'ঔ': Result := (W_Hash_OU <> nil) and W_Hash_OU.ContainsKey(W);
      'ক': Result := (W_Hash_K <> nil) and W_Hash_K.ContainsKey(W);
      'খ': Result := (W_Hash_Kh <> nil) and W_Hash_Kh.ContainsKey(W);
      'গ': Result := (W_Hash_G <> nil) and W_Hash_G.ContainsKey(W);
      'ঘ': Result := (W_Hash_Gh <> nil) and W_Hash_Gh.ContainsKey(W);
      'ঙ': Result := (W_Hash_NGA <> nil) and W_Hash_NGA.ContainsKey(W);
      'চ': Result := (W_Hash_C <> nil) and W_Hash_C.ContainsKey(W);
      'ছ': Result := (W_Hash_CH <> nil) and W_Hash_CH.ContainsKey(W);
      'জ': Result := (W_Hash_J <> nil) and W_Hash_J.ContainsKey(W);
      'ঝ': Result := (W_Hash_Jh <> nil) and W_Hash_Jh.ContainsKey(W);
      'ঞ': Result := (W_Hash_NYA <> nil) and W_Hash_NYA.ContainsKey(W);
      'ট': Result := (W_Hash_Tt <> nil) and W_Hash_Tt.ContainsKey(W);
      'ঠ': Result := (W_Hash_Tth <> nil) and W_Hash_Tth.ContainsKey(W);
      'ড': Result := (W_Hash_Dd <> nil) and W_Hash_Dd.ContainsKey(W);
      'ঢ': Result := (W_Hash_Ddh <> nil) and W_Hash_Ddh.ContainsKey(W);
      'ণ': Result := (W_Hash_Nn <> nil) and W_Hash_Nn.ContainsKey(W);
      'ত': Result := (W_Hash_T <> nil) and W_Hash_T.ContainsKey(W);
      'থ': Result := (W_Hash_Th <> nil) and W_Hash_Th.ContainsKey(W);
      'দ': Result := (W_Hash_D <> nil) and W_Hash_D.ContainsKey(W);
      'ধ': Result := (W_Hash_Dh <> nil) and W_Hash_Dh.ContainsKey(W);
      'ন': Result := (W_Hash_N <> nil) and W_Hash_N.ContainsKey(W);
      'প': Result := (W_Hash_P <> nil) and W_Hash_P.ContainsKey(W);
      'ফ': Result := (W_Hash_Ph <> nil) and W_Hash_Ph.ContainsKey(W);
      'ব': Result := (W_Hash_B <> nil) and W_Hash_B.ContainsKey(W);
      'ভ': Result := (W_Hash_BH <> nil) and W_Hash_BH.ContainsKey(W);
      'ম': Result := (W_Hash_M <> nil) and W_Hash_M.ContainsKey(W);
      'য': Result := (W_Hash_Y <> nil) and W_Hash_Y.ContainsKey(W);
      'র': Result := (W_Hash_R <> nil) and W_Hash_R.ContainsKey(W);
      'ল': Result := (W_Hash_L <> nil) and W_Hash_L.ContainsKey(W);
      'শ': Result := (W_Hash_Sh <> nil) and W_Hash_Sh.ContainsKey(W);
      'ষ': Result := (W_Hash_Ss <> nil) and W_Hash_Ss.ContainsKey(W);
      'স': Result := (W_Hash_S <> nil) and W_Hash_S.ContainsKey(W);
      'হ': Result := (W_Hash_H <> nil) and W_Hash_H.ContainsKey(W);
      'ড়': Result := (W_Hash_Rr <> nil) and W_Hash_Rr.ContainsKey(W);
      'ঢ়': Result := (W_Hash_Rrh <> nil) and W_Hash_Rrh.ContainsKey(W);
      'য়': Result := (W_Hash_Z <> nil) and W_Hash_Z.ContainsKey(W);
      'ৎ': Result := (W_Hash_Khandatta <> nil) and W_Hash_Khandatta.ContainsKey(W);
    end;
  finally
    DBCriticalSection.Leave;
  end;
end;

// ------------------------------------------------------------------------------

initialization

DBCriticalSection := TCriticalSection.Create;
InitDefaultVoiceCommands;

{ Initialize the DISQLite3 library prior to using any other DISQLite3
  functionality. See also sqlite3_shutdown() below. }
sqlite3_initialize;
FDatabaseLoaded := False;
FDatabaseLoading := False;

finalization

{ Deallocate any resources that were allocated by
  sqlite3_initialize() above. }
sqlite3_shutdown;

if VoiceCommandsDict <> nil then
  FreeAndNil(VoiceCommandsDict);
if VoiceUserLexiconDict <> nil then
  FreeAndNil(VoiceUserLexiconDict);
if DBCriticalSection <> nil then
  FreeAndNil(DBCriticalSection);

end.
