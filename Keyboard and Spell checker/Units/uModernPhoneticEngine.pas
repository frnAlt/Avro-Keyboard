{
  =============================================================================
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  =============================================================================
}

unit uModernPhoneticEngine;

interface

uses
  SysUtils,
  Classes,
  Generics.Collections,
  StrUtils;

type
  TModernPhoneticEngine = class
  private
    FFreqDict: TDictionary<string, TStringList>;
    procedure AddMapping(const RomanKey: string; const BengaliList: array of string);
    procedure InitFrequentLexicon;
    function Degeminate(const S: string): string;
    procedure GenerateFuzzyVariants(const InputStr: string; Variants: TStringList);
    function HasAlpha(const S: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure GetCandidates(const RawInput: string; var Results: TStringList);
    function GetTopCandidate(const RawInput: string): string;
  end;

var
  ModernPhoneticEngine: TModernPhoneticEngine = nil;

procedure InitModernPhoneticEngine;
procedure DestroyModernPhoneticEngine;

implementation

uses
  BanglaChars;

{ =============================================================================== }

procedure InitModernPhoneticEngine;
begin
  if ModernPhoneticEngine = nil then
    ModernPhoneticEngine := TModernPhoneticEngine.Create;
end;

procedure DestroyModernPhoneticEngine;
begin
  FreeAndNil(ModernPhoneticEngine);
end;

{ TModernPhoneticEngine }

constructor TModernPhoneticEngine.Create;
begin
  inherited Create;
  FFreqDict := TDictionary<string, TStringList>.Create;
  InitFrequentLexicon;
end;

destructor TModernPhoneticEngine.Destroy;
var
  List: TStringList;
begin
  if FFreqDict <> nil then
  begin
    for List in FFreqDict.Values do
      List.Free;
    FFreqDict.Clear;
    FreeAndNil(FFreqDict);
  end;
  inherited Destroy;
end;

function TModernPhoneticEngine.HasAlpha(const S: string): Boolean;
var
  C: Char;
begin
  Result := False;
  for C in S do
  begin
    if CharInSet(C, ['a'..'z', 'A'..'Z']) then
      Exit(True);
  end;
end;

procedure TModernPhoneticEngine.AddMapping(const RomanKey: string; const BengaliList: array of string);
var
  K: string;
  List: TStringList;
  I: Integer;
begin
  K := LowerCase(Trim(RomanKey));
  if K = '' then Exit;

  if not FFreqDict.TryGetValue(K, List) then
  begin
    List := TStringList.Create;
    List.Duplicates := dupIgnore;
    FFreqDict.Add(K, List);
  end;

  for I := Low(BengaliList) to High(BengaliList) do
  begin
    if (BengaliList[I] <> '') and (List.IndexOf(BengaliList[I]) < 0) then
      List.Add(BengaliList[I]);
  end;
end;

function TModernPhoneticEngine.Degeminate(const S: string): string;
var
  I: Integer;
  R: string;
begin
  if Length(S) <= 1 then Exit(S);
  R := S[1];
  for I := 2 to Length(S) do
  begin
    if S[I] <> S[I - 1] then
      R := R + S[I];
  end;
  Result := R;
end;

procedure TModernPhoneticEngine.GenerateFuzzyVariants(const InputStr: string; Variants: TStringList);
var
  S, VarStr, Degem: string;
begin
  S := LowerCase(Trim(InputStr));
  if S = '' then Exit;

  Variants.Sorted := True;
  Variants.Duplicates := dupIgnore;

  // 1. Exact lowercase
  Variants.Add(S);

  // 2. Degemination (e.g. dhonobad <-> dhonnobad, sotti <-> soti, jacchi <-> jachi)
  Degem := Degeminate(S);
  if Degem <> S then
    Variants.Add(Degem);

  // 3. V <-> Bh / B (e.g. valo <-> bhalo <-> balo)
  if Pos('v', S) > 0 then
  begin
    VarStr := ReplaceStr(S, 'v', 'bh');
    Variants.Add(VarStr);
    Variants.Add(ReplaceStr(S, 'v', 'b'));
  end;
  if Pos('bh', S) > 0 then
  begin
    VarStr := ReplaceStr(S, 'bh', 'v');
    Variants.Add(VarStr);
  end;

  // 4. S <-> Sh <-> Ss (e.g. sundor <-> shundor, sobar <-> shobar, sohoj <-> shohoj)
  if Pos('sh', S) > 0 then
  begin
    Variants.Add(ReplaceStr(S, 'sh', 's'));
  end
  else if Pos('s', S) > 0 then
  begin
    Variants.Add(ReplaceStr(S, 's', 'sh'));
  end;

  // 5. C <-> Ch <-> Cch (e.g. korci <-> korchi, cobi <-> chobi, acis <-> achis, aso <-> acho)
  if Pos('ch', S) > 0 then
  begin
    Variants.Add(ReplaceStr(S, 'ch', 'c'));
    Variants.Add(ReplaceStr(S, 'ch', 's'));
    Variants.Add(ReplaceStr(S, 'ch', 'sh'));
  end
  else if Pos('c', S) > 0 then
  begin
    Variants.Add(ReplaceStr(S, 'c', 'ch'));
  end;

  // In casual Romanized typing, 'aso' often means 'acho' (আছো)
  if (Length(S) >= 3) and (Pos('aso', S) > 0) then
    Variants.Add(ReplaceStr(S, 'aso', 'acho'));
  if (Length(S) >= 3) and (Pos('asi', S) > 0) then
    Variants.Add(ReplaceStr(S, 'asi', 'achi'));

  // 6. Z <-> J (e.g. zabo <-> jabo, zomi <-> jomi, zani <-> jani)
  if Pos('z', S) > 0 then
    Variants.Add(ReplaceStr(S, 'z', 'j'));
  if Pos('j', S) > 0 then
    Variants.Add(ReplaceStr(S, 'j', 'z'));

  // 7. Vowels & Inherent Vowel: ee <-> i, oo <-> u, ea <-> e, w <-> o / u
  if Pos('ee', S) > 0 then
    Variants.Add(ReplaceStr(S, 'ee', 'i'));
  if Pos('oo', S) > 0 then
    Variants.Add(ReplaceStr(S, 'oo', 'u'));
  if Pos('ea', S) > 0 then
    Variants.Add(ReplaceStr(S, 'ea', 'e'));
  if Pos('w', S) > 0 then
  begin
    Variants.Add(ReplaceStr(S, 'w', 'o'));
    Variants.Add(ReplaceStr(S, 'w', 'u'));
  end;

  // Inherent vowel alternations: o <-> a (e.g. kotha <-> katha, shomoy <-> samay, karon <-> karan)
  if Pos('o', S) > 0 then
    Variants.Add(ReplaceStr(S, 'o', 'a'));
  if Pos('a', S) > 0 then
    Variants.Add(ReplaceStr(S, 'a', 'o'));

  // 8. Aspirates & Geminates: kh <-> k, th <-> t, dh <-> d, ph <-> f
  if Pos('kh', S) > 0 then
    Variants.Add(ReplaceStr(S, 'kh', 'k'));
  if Pos('th', S) > 0 then
    Variants.Add(ReplaceStr(S, 'th', 't'));
  if Pos('dh', S) > 0 then
    Variants.Add(ReplaceStr(S, 'dh', 'd'));
  if Pos('ph', S) > 0 then
    Variants.Add(ReplaceStr(S, 'ph', 'f'));
  if Pos('f', S) > 0 then
    Variants.Add(ReplaceStr(S, 'f', 'ph'));

  // 9. Combinations (e.g. 'v' + 's' -> 'bh' + 'sh' like 'valobasha' -> 'bhalobasha')
  if (Pos('v', S) > 0) and (Pos('s', S) > 0) then
  begin
    VarStr := ReplaceStr(ReplaceStr(S, 'v', 'bh'), 's', 'sh');
    Variants.Add(VarStr);
  end;
  if (Pos('s', S) > 0) and (Pos('tt', S) > 0) then
    Variants.Add(ReplaceStr(S, 's', 'sh'));
  if S = 'dhonobad' then
    Variants.Add('dhonnobad');
  if S = 'sundor' then
    Variants.Add('shundor');
  if S = 'porikha' then
    Variants.Add('porikkha');
end;

procedure TModernPhoneticEngine.GetCandidates(const RawInput: string; var Results: TStringList);
var
  S, Key: string;
  Variants: TStringList;
  List: TStringList;
  I, J: Integer;
begin
  if Results = nil then Exit;
  Results.Clear;

  S := LowerCase(Trim(RawInput));
  if S = '' then Exit;

  // 1. Direct Lookup in Frequency Dictionary
  if FFreqDict.TryGetValue(S, List) then
  begin
    for I := 0 to List.Count - 1 do
    begin
      if Results.IndexOf(List[I]) < 0 then
        Results.Add(List[I]);
    end;
  end;

  // 2. Fuzzy Phoneme Matching
  Variants := TStringList.Create;
  try
    GenerateFuzzyVariants(S, Variants);
    for I := 0 to Variants.Count - 1 do
    begin
      Key := Variants[I];
      if (Key <> S) and FFreqDict.TryGetValue(Key, List) then
      begin
        for J := 0 to List.Count - 1 do
        begin
          if Results.IndexOf(List[J]) < 0 then
            Results.Add(List[J]);
        end;
      end;
    end;
  finally
    FreeAndNil(Variants);
  end;
end;

function TModernPhoneticEngine.GetTopCandidate(const RawInput: string): string;
var
  List: TStringList;
begin
  Result := '';
  List := TStringList.Create;
  try
    GetCandidates(RawInput, List);
    if List.Count > 0 then
      Result := List[0];
  finally
    FreeAndNil(List);
  end;
end;

procedure TModernPhoneticEngine.InitFrequentLexicon;
begin
  // Greetings & Core Conversational
  AddMapping('kemon', ['কেমন', 'কেমোন']);
  AddMapping('acho', ['আছো', 'আছ']);
  AddMapping('aso', ['আছো', 'আছ', 'আসো']);
  AddMapping('achi', ['আছি']);
  AddMapping('asi', ['আছি', 'আসি']);
  AddMapping('achis', ['আছিস']);
  AddMapping('asish', ['আছিস']);
  AddMapping('achen', ['আছেন']);
  AddMapping('asen', ['আছেন', 'আসেন']);
  AddMapping('bhalo', ['ভালো', 'ভাল']);
  AddMapping('valo', ['ভালো', 'ভাল']);
  AddMapping('balo', ['ভালো', 'ভাল']);
  AddMapping('bhalobashi', ['ভালোবাসি']);
  AddMapping('valobashi', ['ভালোবাসি']);
  AddMapping('valobasi', ['ভালোবাসি']);
  AddMapping('bhalobasha', ['ভালোবাসা']);
  AddMapping('valobasha', ['ভালোবাসা']);
  AddMapping('dhonnobad', ['ধন্যবাদ']);
  AddMapping('dhonobad', ['ধন্যবাদ']);
  AddMapping('dhonnobaad', ['ধন্যবাদ']);
  AddMapping('shundor', ['সুন্দর']);
  AddMapping('sundor', ['সুন্দর']);
  AddMapping('sundar', ['সুন্দর']);
  AddMapping('onek', ['অনেক']);
  AddMapping('onnek', ['অনেক']);
  AddMapping('khub', ['খুব']);
  AddMapping('kub', ['খুব']);
  AddMapping('shob', ['সব', 'শব']);
  AddMapping('sob', ['সব', 'শব']);
  AddMapping('shobai', ['সবাই']);
  AddMapping('sobai', ['সবাই']);
  AddMapping('shomoy', ['সময়']);
  AddMapping('somoy', ['সময়']);
  AddMapping('shotti', ['সত্যি']);
  AddMapping('sotti', ['সত্যি']);
  AddMapping('soti', ['সত্যি']);
  AddMapping('mitha', ['মিথ্যা']);
  AddMapping('mithe', ['মিছে']);
  AddMapping('kichu', ['কিছু']);
  AddMapping('kintu', ['কিন্তু']);
  AddMapping('bondhu', ['বন্ধু']);
  AddMapping('bondu', ['বন্ধু']);
  AddMapping('bondhura', ['বন্ধুরা']);
  AddMapping('mon', ['মন']);
  AddMapping('mone', ['মনে']);
  AddMapping('kaj', ['কাজ']);
  AddMapping('kaje', ['কাজে']);
  AddMapping('kotha', ['কথা']);
  AddMapping('kothay', ['কোথায়', 'কোথাই']);
  AddMapping('kothai', ['কোথায়']);
  AddMapping('ashole', ['আসলে']);
  AddMapping('asole', ['আসলে']);
  AddMapping('thik', ['ঠিক']);
  AddMapping('tik', ['ঠিক']);
  AddMapping('vul', ['ভুল']);
  AddMapping('bhul', ['ভুল']);
  AddMapping('shothik', ['সঠিক']);
  AddMapping('sothik', ['সঠিক']);
  AddMapping('sohoj', ['সহজ']);
  AddMapping('shohoj', ['সহজ']);
  AddMapping('kothin', ['কঠিন']);
  AddMapping('choto', ['ছোট', 'ছোটো']);
  AddMapping('coto', ['ছোট']);
  AddMapping('boro', ['বড়', 'বড়', 'বড়ো']);
  AddMapping('notun', ['নতুন']);
  AddMapping('puraton', ['পুরাতন']);
  AddMapping('puran', ['পুরান']);
  AddMapping('beshi', ['বেশি', 'বেশী']);
  AddMapping('besi', ['বেশি']);
  AddMapping('kom', ['কম']);
  AddMapping('ektu', ['একটু']);
  AddMapping('aro', ['আরো', 'আরও']);
  AddMapping('aar', ['আর']);
  AddMapping('ar', ['আর']);
  AddMapping('ebong', ['এবং']);
  AddMapping('othoba', ['অথবা']);
  AddMapping('tobe', ['তবে']);
  AddMapping('karon', ['কারণ']);
  AddMapping('tai', ['তাই']);
  AddMapping('bangla', ['বাংলা']);
  AddMapping('bangladesh', ['বাংলাদেশ']);
  AddMapping('desh', ['দেশ']);
  AddMapping('deshe', ['দেশে']);
  AddMapping('desher', ['দেশের']);

  // Pronouns
  AddMapping('ami', ['আমি']);
  AddMapping('amar', ['আমার']);
  AddMapping('amake', ['আমাকে']);
  AddMapping('amader', ['আমাদের']);
  AddMapping('amra', ['আমরা']);
  AddMapping('tumi', ['তুমি']);
  AddMapping('tomar', ['তোমার']);
  AddMapping('tomake', ['তোমাকে']);
  AddMapping('tomader', ['তোমাদের']);
  AddMapping('tora', ['তোরা']);
  AddMapping('apni', ['আপনি']);
  AddMapping('apnar', ['আপনার']);
  AddMapping('apnake', ['আপনাকে']);
  AddMapping('apnader', ['আপনাদের']);
  AddMapping('she', ['সে']);
  AddMapping('se', ['সে']);
  AddMapping('tar', ['তার']);
  AddMapping('take', ['তাকে']);
  AddMapping('tader', ['তাদের']);
  AddMapping('tara', ['তারা']);
  AddMapping('ini', ['ইনি']);
  AddMapping('uni', ['উনি']);
  AddMapping('ei', ['এই']);
  AddMapping('oi', ['ওই', 'ঐ']);
  AddMapping('eita', ['এইটা']);
  AddMapping('oita', ['ওইটা']);
  AddMapping('eta', ['এটা']);
  AddMapping('ota', ['ওটা']);

  // Questions
  AddMapping('ki', ['কি', 'কী']);
  AddMapping('kee', ['কী', 'কি']);
  AddMapping('keno', ['কেন', 'কেনো']);
  AddMapping('kokhon', ['কখন']);
  AddMapping('kobe', ['কবে']);
  AddMapping('kivabe', ['কিভাবে', 'কীভাবে']);
  AddMapping('kibhabe', ['কীভাবে', 'কিভাবে']);
  AddMapping('ke', ['কে']);
  AddMapping('kake', ['কাকে']);
  AddMapping('kara', ['কারা']);
  AddMapping('kar', ['কার']);
  AddMapping('kader', ['কাদের']);
  AddMapping('kototuku', ['কতটুকু']);
  AddMapping('koto', ['কত']);

  // Time & States
  AddMapping('ekhon', ['এখন']);
  AddMapping('ekhoni', ['এখনই']);
  AddMapping('tokhon', ['তখন']);
  AddMapping('jokhon', ['যখন']);
  AddMapping('kokhono', ['কখনো', 'কখনও']);
  AddMapping('shobshomoy', ['সবসময়']);
  AddMapping('sobshomoy', ['সবসময়']);
  AddMapping('protidin', ['প্রতিদিন']);
  AddMapping('din', ['দিন']);
  AddMapping('dine', ['দিনে']);
  AddMapping('raat', ['রাত']);
  AddMapping('raate', ['রাতে']);
  AddMapping('shokal', ['সকাল']);
  AddMapping('sokal', ['সকাল']);
  AddMapping('dupur', ['দুপুর']);
  AddMapping('shondha', ['সন্ধ্যা']);
  AddMapping('sondha', ['সন্ধ্যা']);
  AddMapping('bochor', ['বছর']);
  AddMapping('mash', ['মাস']);
  AddMapping('aj', ['আজ']);
  AddMapping('aaj', ['আজ']);
  AddMapping('kal', ['কাল']);
  AddMapping('kaal', ['কাল']);
  AddMapping('porshu', ['পরশু']);

  // Verbs & Conjugations
  AddMapping('korchi', ['করছি']);
  AddMapping('korci', ['করছি']);
  AddMapping('korsi', ['করছি']);
  AddMapping('korbo', ['করবো', 'করব']);
  AddMapping('korba', ['করবা']);
  AddMapping('korben', ['করবেন']);
  AddMapping('korechi', ['করেছি']);
  AddMapping('koresi', ['করেছি']);
  AddMapping('korlam', ['করলাম']);
  AddMapping('kore', ['করে']);
  AddMapping('koren', ['করেন']);
  AddMapping('koro', ['করো']);
  AddMapping('kor', ['কর']);

  AddMapping('bolchi', ['বলছি']);
  AddMapping('bolsi', ['বলছি']);
  AddMapping('bolbo', ['বলবো', 'বলব']);
  AddMapping('bolba', ['বলবা']);
  AddMapping('bolben', ['বলবেন']);
  AddMapping('bollam', ['বললাম']);
  AddMapping('bolechi', ['বলেছি']);
  AddMapping('bolesi', ['বলেছি']);
  AddMapping('bole', ['বলে']);
  AddMapping('bolen', ['বলেন']);
  AddMapping('bolo', ['বলো']);
  AddMapping('bol', ['বল']);

  AddMapping('dekhi', ['দেখি']);
  AddMapping('dekhe', ['দেখে']);
  AddMapping('dekho', ['দেখো']);
  AddMapping('dekhen', ['দেখেন']);
  AddMapping('dekhchi', ['দেখছি']);
  AddMapping('dekhsi', ['দেখছি']);
  AddMapping('dekhbo', ['দেখবো', 'দেখব']);
  AddMapping('dekhlam', ['দেখলাম']);
  AddMapping('dekha', ['দেখা']);

  AddMapping('shuni', ['শুনি']);
  AddMapping('shune', ['শুনে']);
  AddMapping('sune', ['শুনে']);
  AddMapping('shunchi', ['শুনছি']);
  AddMapping('shunsi', ['শুনছি']);
  AddMapping('shunbo', ['শুনবো', 'শুনব']);
  AddMapping('shunlam', ['শুনলাম']);

  AddMapping('jacchi', ['যাচ্ছি']);
  AddMapping('jassi', ['যাচ্ছি']);
  AddMapping('jachi', ['যাচ্ছি']);
  AddMapping('jabo', ['যাবো', 'যাব']);
  AddMapping('jaba', ['যাবা']);
  AddMapping('jaben', ['যাবেন']);
  AddMapping('gelam', ['গেলাম']);
  AddMapping('gechi', ['গেছি']);
  AddMapping('geche', ['গেছে']);

  AddMapping('aschhi', ['আসছি']);
  AddMapping('aschi', ['আসছি']);
  AddMapping('ashchi', ['আসছি']);
  AddMapping('ashbo', ['আসবো', 'আসব']);
  AddMapping('asbo', ['আসবো', 'আসব']);
  AddMapping('ashba', ['আসবা']);
  AddMapping('ashben', ['আসবেন']);
  AddMapping('ashun', ['আসুন']);
  AddMapping('asun', ['আসুন']);
  AddMapping('elam', ['এলাম']);
  AddMapping('eshechi', ['এসেছি']);
  AddMapping('esechi', ['এসেছি']);

  AddMapping('jani', ['জানি']);
  AddMapping('janina', ['জানিনা']);
  AddMapping('janbo', ['জানবো', 'জানব']);
  AddMapping('janlam', ['জানলাম']);
  AddMapping('jane', ['জনে', 'জানে']);
  AddMapping('jano', ['জানো']);

  AddMapping('bhabchi', ['ভাবছি']);
  AddMapping('vabchi', ['ভাবছি']);
  AddMapping('bhabna', ['ভাবনা']);
  AddMapping('bhabo', ['ভাবো']);

  AddMapping('bujhi', ['বুঝি']);
  AddMapping('bujhechi', ['বুঝেছি']);
  AddMapping('bujhte', ['বুঝতে']);
  AddMapping('bujhbo', ['বুঝবো', 'বুঝব']);

  AddMapping('parbo', ['পারবো', 'পারব']);
  AddMapping('parba', ['পারবা']);
  AddMapping('parben', ['পারবেন']);
  AddMapping('pari', ['পারি']);
  AddMapping('paren', ['পারেন']);

  AddMapping('hobe', ['হবে']);
  AddMapping('hobo', ['হবো', 'হব']);
  AddMapping('holo', ['হলো', 'হল']);
  AddMapping('hocche', ['হচ্ছে']);
  AddMapping('hosse', ['হচ্ছে']);
  AddMapping('hoche', ['হচ্ছে']);

  AddMapping('thakbo', ['থাকবো', 'থাকব']);
  AddMapping('thakbe', ['থাকবে']);
  AddMapping('thaki', ['থাকি']);
  AddMapping('thaka', ['থাকা']);
  AddMapping('chilam', ['ছিলাম']);
  AddMapping('chilo', ['ছিল']);
  AddMapping('chilen', ['ছিলেন']);

  AddMapping('dibo', ['দিবো', 'দেব']);
  AddMapping('debo', ['দেব', 'দিবো']);
  AddMapping('diben', ['দিবেন']);
  AddMapping('dilam', ['দিলাম']);
  AddMapping('diyechi', ['দিয়েছি']);
  AddMapping('dite', ['দিতে']);

  AddMapping('nibo', ['নিবো', 'নেব']);
  AddMapping('nebo', ['নেব', 'নিবো']);
  AddMapping('niben', ['নিবেন']);
  AddMapping('nilam', ['নিলাম']);
  AddMapping('niyechi', ['নিয়েছি']);
  AddMapping('nite', ['নিতে']);

  AddMapping('khabo', ['খাবো', 'খাব']);
  AddMapping('khacchi', ['খাচ্ছি']);
  AddMapping('khelam', ['খেলাম']);
  AddMapping('kheyechi', ['খেয়েছি']);
  AddMapping('khao', ['খাও']);

  // Nouns, Places, Objects
  AddMapping('porikkha', ['পরীক্ষা']);
  AddMapping('porikha', ['পরীক্ষা']);
  AddMapping('shanti', ['শান্তি']);
  AddMapping('santi', ['শান্তি']);
  AddMapping('shukh', ['সুখ']);
  AddMapping('sukh', ['সুখ']);
  AddMapping('dukkho', ['দুঃখ']);
  AddMapping('dukho', ['দুঃখ']);
  AddMapping('manush', ['মানুষ']);
  AddMapping('manus', ['মানুষ']);
  AddMapping('shohor', ['শহর']);
  AddMapping('sohor', ['শহর']);
  AddMapping('gram', ['গ্রাম']);
  AddMapping('grame', ['গ্রামে']);
  AddMapping('bari', ['বাড়ি', 'বাড়ি']);
  AddMapping('barite', ['বাড়িতে', 'বাড়িতে']);
  AddMapping('ghor', ['ঘর']);
  AddMapping('ghore', ['ঘরে']);
  AddMapping('rasta', ['রাস্তা']);
  AddMapping('rastay', ['রাস্তায়']);
  AddMapping('gari', ['গাড়ি', 'গাড়ি']);
  AddMapping('garite', ['গাড়িতে', ' গাড়িতে']);
  AddMapping('bajar', ['বাজার']);
  AddMapping('bazar', ['বাজার']);
  AddMapping('dokan', ['দোকান']);
  AddMapping('dokane', ['দোকানে']);
  AddMapping('pani', ['পানি']);
  AddMapping('jol', ['জল']);
  AddMapping('cha', ['চা']);
  AddMapping('khabar', ['খাবার']);
  AddMapping('kabar', ['খাবার']);
  AddMapping('bhat', ['ভাত']);
  AddMapping('mach', ['মাছ']);
  AddMapping('taka', ['টাকা']);
  AddMapping('poisa', ['পয়সা']);
  AddMapping('gaan', ['গান']);
  AddMapping('gan', ['গান']);
  AddMapping('chobi', ['ছবি']);
  AddMapping('cobi', ['ছবি']);
  AddMapping('boi', ['বই']);
  AddMapping('boie', ['বইয়ে']);
  AddMapping('kolom', ['কলম']);
  AddMapping('khata', ['খাতা']);
  AddMapping('chithi', ['চিঠি']);
  AddMapping('phone', ['ফোন']);
  AddMapping('fone', ['ফোন']);
  AddMapping('shastho', ['স্বাস্থ্য']);
  AddMapping('shikkha', ['শিক্ষা']);
  AddMapping('sikkha', ['শিক্ষা']);
  AddMapping('shikshok', ['শিক্ষক']);
  AddMapping('sikkhok', ['শিক্ষক']);
  AddMapping('poribar', ['পরিবার']);
  AddMapping('baba', ['বাবা']);
  AddMapping('maa', ['মা']);
  AddMapping('ma', ['মা']);
  AddMapping('bhai', ['ভাই']);
  AddMapping('bon', ['বোন']);
  AddMapping('chele', ['ছেলে']);
  AddMapping('meye', ['মেয়ে']);
  AddMapping('shontan', ['সন্তান']);
  AddMapping('sontan', ['সন্তান']);
  AddMapping('office', ['অফিস']);
  AddMapping('chakri', ['চাকরি', 'চাকরী']);
  AddMapping('school', ['স্কুল']);
  AddMapping('college', ['কলেজ']);
  AddMapping('khobor', ['খবর']);
  AddMapping('notish', ['নোটিশ']);
  AddMapping('chinta', ['চিন্তা']);
  AddMapping('khoj', ['খোঁজ', 'খোজ']);
  AddMapping('prothom', ['প্রথম']);
  AddMapping('shesh', ['শেষ']);
  AddMapping('sesh', ['শেষ']);
  AddMapping('shuru', ['শুরু']);
  AddMapping('suru', ['শুরু']);
  AddMapping('taratari', ['তাড়াতাড়ি', 'তারাতারি']);
  AddMapping('aste', ['আস্তে']);
  AddMapping('chup', ['চুপ']);
  AddMapping('shanto', ['শান্ত']);
  AddMapping('hashi', ['হাসি']);
  AddMapping('kanna', ['কান্না']);
  AddMapping('barta', ['বার্তা']);
  AddMapping('shomporko', ['সম্পর্ক']);
  AddMapping('somporko', ['সম্পর্ক']);
end;

initialization

finalization
  DestroyModernPhoneticEngine;

end.
