unit ufrmSymbolsPicker;

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
  ComCtrls,
  Grids;

type
  TfrmSymbolsPicker = class(TForm)
    PageControl: TPageControl;
    TabBangla: TTabSheet;
    GridBangla: TDrawGrid;
    TabSymbols: TTabSheet;
    GridSymbols: TDrawGrid;
    TabEmoji: TTabSheet;
    GridEmoji: TDrawGrid;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridBanglaDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure GridBanglaSelectCell(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
    procedure GridSymbolsDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure GridSymbolsSelectCell(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
    procedure GridEmojiDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure GridEmojiSelectCell(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
  private
    FBanglaItems: TArray<string>;
    FSymbolItems: TArray<string>;
    FEmojiItems: TArray<string>;

    procedure DrawCellText(Grid: TDrawGrid; Items: TArray<string>; ACol, ARow: Longint; Rect: TRect);
    procedure SendSelectedChar(Items: TArray<string>; ACol, ARow: Longint);
    procedure CreateParams(var Params: TCreateParams); override;
  public
  end;

var
  frmSymbolsPicker: TfrmSymbolsPicker;

implementation

uses
  KeyboardFunctions,
  uWindowHandlers;

{$R *.dfm}

procedure TfrmSymbolsPicker.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Do not steal focus so user can type continuously into their target application
  Params.ExStyle := Params.ExStyle or WS_EX_NOACTIVATE or WS_EX_TOPMOST;
end;

procedure TfrmSymbolsPicker.FormCreate(Sender: TObject);
begin
  MakeNeverActiveWindow(Self.Handle);

  FBanglaItems := [
    #$0964, #$0965, #$09F3, #$09CE, #$0982, #$0983,
    #$0981, #$09CD, #$200D, #$200C, #$09FA, #$09E6,
    #$09E7, #$09E8, #$09E9, #$09EA, #$09EB, #$09EC,
    #$09ED, #$09EE, #$09EF, #$09DC, #$09DD, #$09DF
  ];

  FSymbolItems := [
    '$', #$20AC, #$00A3, #$00A5, #$20B9, #$00B1,
    #$00D7, #$00F7, #$2260, #$2248, #$2264, #$2265,
    #$00B0, #$00B5, #$03C0, #$221E, '%', '&',
    '#', '@', '*', '^', '~', '\'
  ];

  FEmojiItems := [
    #$D83D#$DE00, #$D83D#$DE02, #$2764#$FE0F, #$D83D#$DC4D, #$D83D#$DE4F, #$D83C#$DF89,
    #$D83D#$DD25, #$2728, #$D83D#$DE0A, #$D83D#$DE0D, #$D83D#$DE0E, #$D83E#$DD14,
    #$D83D#$DCAA, #$D83C#$DF1F, #$2705, #$274C, #$26A0#$FE0F, #$D83D#$DCA1,
    #$D83C#$DF38, #$D83C#$DF08, #$2600#$FE0F, #$D83C#$DF19, #$2615, #$D83C#$DFBD
  ];
end;

procedure TfrmSymbolsPicker.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  frmSymbolsPicker := nil;
end;

procedure TfrmSymbolsPicker.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

procedure TfrmSymbolsPicker.DrawCellText(Grid: TDrawGrid; Items: TArray<string>; ACol, ARow: Longint; Rect: TRect);
var
  Idx: Integer;
  Text: string;
begin
  Idx := ARow * Grid.ColCount + ACol;
  if (Idx >= 0) and (Idx < Length(Items)) then
    Text := Items[Idx]
  else
    Text := '';

  Grid.Canvas.FillRect(Rect);
  DrawTextW(Grid.Canvas.Handle, PWideChar(Text), Length(Text), Rect, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

procedure TfrmSymbolsPicker.SendSelectedChar(Items: TArray<string>; ACol, ARow: Longint);
var
  Idx: Integer;
begin
  Idx := ARow * 6 + ACol;
  if (Idx >= 0) and (Idx < Length(Items)) then
  begin
    SendKey_Char(Items[Idx]);
  end;
end;

procedure TfrmSymbolsPicker.GridBanglaDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
begin
  DrawCellText(GridBangla, FBanglaItems, ACol, ARow, Rect);
end;

procedure TfrmSymbolsPicker.GridBanglaSelectCell(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
begin
  SendSelectedChar(FBanglaItems, ACol, ARow);
  CanSelect := True;
end;

procedure TfrmSymbolsPicker.GridSymbolsDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
begin
  DrawCellText(GridSymbols, FSymbolItems, ACol, ARow, Rect);
end;

procedure TfrmSymbolsPicker.GridSymbolsSelectCell(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
begin
  SendSelectedChar(FSymbolItems, ACol, ARow);
  CanSelect := True;
end;

procedure TfrmSymbolsPicker.GridEmojiDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
begin
  DrawCellText(GridEmoji, FEmojiItems, ACol, ARow, Rect);
end;

procedure TfrmSymbolsPicker.GridEmojiSelectCell(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
begin
  SendSelectedChar(FEmojiItems, ACol, ARow);
  CanSelect := True;
end;

end.
