{
  =============================================================================
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  =============================================================================
}

{$INCLUDE ../ProjectDefines.inc}

unit ufrmPrevW;

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
  GIFImg,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Dialogs,
  Buttons,
  Generics.Collections,
  StrUtils,
  Menus,
  OleAcc,
  DebugLog,
  System.Threading,
  System.SyncObjs,
  uGlassmorphism,
  WindowsDarkMode;

type
  TCandidateChip = record
    Index:     Integer;
    Text:      string;
    Rect:      TRect;
    BadgeRect: TRect;
    TextRect:  TRect;
  end;

  TfrmPrevW = class(TForm)
    Shape1: TShape;
    ImgTitleBar: TImage;
    imgPin: TImage;
    lblCaption: TLabel;
    Button: TImage;
    ImgButtonUp: TImage;
    ImgButtonOver: TImage;
    imgPinOpen: TImage;
    imgPinClose: TImage;
    lblPreview: TLabel;
    PopupMenu: TPopupMenu;
    ransparency1: TMenuItem;
    Notransparency1: TMenuItem;
    N101: TMenuItem;
    N201: TMenuItem;
    N301: TMenuItem;
    N401: TMenuItem;
    N501: TMenuItem;
    N601: TMenuItem;
    ShowPreviewWindow1: TMenuItem;
    ShowPreviewWindow2: TMenuItem;
    List: TListBox;
    procedure FormCreate(Sender: TObject);
    procedure ButtonMouseEnter(Sender: TObject);
    procedure ButtonMouseLeave(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure imgPinClick(Sender: TObject);
    procedure ImgTitleBarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure lblCaptionMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ImgTitleBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ImgTitleBarMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure lblCaptionMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure lblCaptionMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ButtonMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ListClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  private
    { Private declarations }
    PreviewWCurrentlyVisible: Boolean;
    MouseDown:                Boolean;
    FCandidateChips:          array of TCandidateChip;
    FSelectedIndex:           Integer;
    FHoverIndex:              Integer;
    FPinHover:                Boolean;
    FPinRect:                 TRect;
    FDragStart:               TPoint;
    FIsDragging:              Boolean;

    function FindCaretPosWindow(out X, Y: Integer): Boolean;
    function GetCaretScreenPos_MSAA(out X, Y: Integer): Boolean;
    function GetCaretScreenPos_Raw(out X, Y: Integer): Boolean;
    procedure FindCaretAndMoveWindow;

    procedure InitPreviewWindowAtAppStart;
    procedure DelayedExecute(DelayMs: Integer; Proc: TThreadMethod);

    function ShouldShowWindow: Boolean;
    function ShouldFollowCaret(hforewnd: HWND): Boolean;
    procedure ToggleFollowCaret;
    procedure TurnOffFollowingCaret;
    procedure RefreshPinIcon;
    procedure DrawPinGlyph(ACanvas: TCanvas; R: TRect; IsPinned, IsDark, IsHover: Boolean);

    procedure MoveWindow(X, Y: Integer);

    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  public
    { Public declarations }
    function IsPreviewVisible: Boolean;
    procedure UpdatePreviewCaption(const EnglishT: string);

    procedure HidePreview;
    procedure ShowPreview;
    procedure UpdateListHeight;
    procedure RefreshGlassStyle;

    procedure SelectFirstItem;
    procedure SelectNItem(const ItemNumber: Integer);
    procedure SelectItem(const Item: string);
    procedure SelectNextItem;
    procedure SelectPrevItem;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;

var
  frmPrevW: TfrmPrevW;

implementation

{$R *.dfm}

uses
  uWindowHandlers,
  uTopBar,
  uForm1,
  BanglaChars,
  uRegistrySettings;

{ =============================================================================== }

// MSAA works with Chrome, Firefox etc.
function TfrmPrevW.GetCaretScreenPos_MSAA(out X, Y: Integer): Boolean;
var
  Acc:                                     IAccessible;
  VarChild:                                OleVariant;
  CaretX, CaretY, CaretWidth, CaretHeight: Integer;
  Handle:                                  HWND;
  LocResult:                               HRESULT;
begin
  Result := False;
  X := -1;
  Y := -1;

  Handle := GetForegroundWindow;
  if (Handle = 0) or (Handle = self.Handle) then
  begin
    Log('Ignoring Handle in GetCaretScreenPos_MSAA. Handle = ', Handle);
    Exit;
  end;

  if AccessibleObjectFromWindow(Handle, OBJID_CARET, IID_IAccessible, Acc) <> S_OK then
  begin
    Log('Error: failed to get accessibility object');
    Exit;
  end;

  if Acc = nil then
  begin
    Log('Error: accessibility object is nil');
    Exit;
  end;

  VarChild := CHILDID_SELF;
  LocResult := Acc.accLocation(CaretX, CaretY, CaretWidth, CaretHeight, VarChild);
  if (LocResult = S_OK) then
  begin
    X := CaretX;
    Y := CaretY + CaretHeight; // Move Y to bottom of caret
    Result := True;
  end
  else
    Log('Error: accLocation. LocResult = ', LocResult);
end;

{ =============================================================================== }

// Fallback: Raw Caret Position, works with classic win32 applications
function TfrmPrevW.GetCaretScreenPos_Raw(out X, Y: Integer): Boolean;
var
  ThreadID:      DWORD;
  GUIInfo:       TGUIThreadInfo;
  CaretPos:      TPoint;
  ForegroundWnd: HWND;
begin
  Result := False;
  X := -1;
  Y := -1;

  ForegroundWnd := GetForegroundWindow;
  if (ForegroundWnd = 0) or (ForegroundWnd = self.Handle) then
    Exit;

  FillChar(GUIInfo, SizeOf(GUIInfo), 0);
  GUIInfo.cbSize := SizeOf(GUIInfo);

  ThreadID := GetWindowThreadProcessId(ForegroundWnd, nil);
  if (ThreadID = 0) or (not GetGUIThreadInfo(ThreadID, GUIInfo)) then
    Exit;

  if GUIInfo.hwndCaret = 0 then
    Exit;

  CaretPos.X := GUIInfo.rcCaret.Left;
  CaretPos.Y := GUIInfo.rcCaret.Bottom;

  if Windows.ClientToScreen(GUIInfo.hwndCaret, CaretPos) then
  begin
    X := CaretPos.X;
    Y := CaretPos.Y;
    Result := True;
  end;
end;

{ =============================================================================== }

function TfrmPrevW.FindCaretPosWindow(out X, Y: Integer): Boolean;
begin
  if GetCaretScreenPos_MSAA(X, Y) then
  begin
    Result := True;
    Log('Caret found using MSAA. X = ' + IntToStr(X) + ', Y = ' + IntToStr(Y));
  end
  else if GetCaretScreenPos_Raw(X, Y) then
  begin
    Result := True;
    Log('Caret found using Raw. X = ' + IntToStr(X) + ', Y = ' + IntToStr(Y));
  end
  else
    Result := False;
end;

{ =============================================================================== }

procedure TfrmPrevW.MoveWindow(X, Y: Integer);
const
  VerticalOffset = 5;
var
  TargetTop, TargetLeft: Integer;
  Mon: TMonitor;
begin
  TargetTop := Y - self.Height - VerticalOffset;
  TargetLeft := X;

  Mon := Screen.MonitorFromPoint(Point(X, Y));
  if Mon <> nil then
  begin
    if TargetTop < Mon.WorkareaRect.Top then
      TargetTop := Y + VerticalOffset;

    if TargetTop + self.Height > Mon.WorkareaRect.Bottom then
      TargetTop := Mon.WorkareaRect.Bottom - self.Height;

    if TargetLeft + self.Width > Mon.WorkareaRect.Right then
      TargetLeft := Mon.WorkareaRect.Right - self.Width;
    if TargetLeft < Mon.WorkareaRect.Left then
      TargetLeft := Mon.WorkareaRect.Left;
  end;

  self.Top := TargetTop;
  self.Left := TargetLeft;
end;

{ =============================================================================== }

function TfrmPrevW.ShouldFollowCaret(hforewnd: HWND): Boolean;
begin
  if not(ShowPrevWindow = 'YES') then
  begin
    Result := False;
    Exit;
  end;

  if (hforewnd = 0) or (hforewnd = self.Handle) then
  begin
    Result := False;
    Exit;
  end;

  if FollowCaretByDefault = 'YES' then
    Result := True
  else
    Result := False;
end;

{ =============================================================================== }

function TfrmPrevW.ShouldShowWindow: Boolean;
begin
  if ShowPrevWindow = 'YES' then
    Result := True
  else
    Result := False;
end;

{ =============================================================================== }

procedure TfrmPrevW.FindCaretAndMoveWindow;
var
  Handle:     HWND;
  X, Y:       Integer;
  FoundCaret: Boolean;
begin
  Handle := GetForegroundWindow;
  if ShouldFollowCaret(Handle) then
  begin
    FoundCaret := FindCaretPosWindow(X, Y);
    if FoundCaret then
      MoveWindow(X, Y);
  end;

  if ShouldShowWindow then
    ShowPreview;
end;

{ =============================================================================== }

procedure TfrmPrevW.UpdatePreviewCaption(const EnglishT: string);
begin
  lblPreview.Caption := EnglishT;
  DelayedExecute(20, FindCaretAndMoveWindow);
end;

{ =============================================================================== }

procedure TfrmPrevW.RefreshPinIcon;
begin
  if FollowCaretByDefault = 'YES' then
    imgPin.Picture := imgPinClose.Picture
  else
    imgPin.Picture := imgPinOpen.Picture;
  Invalidate;
end;

{ =============================================================================== }

procedure TfrmPrevW.ToggleFollowCaret;
begin
  if FollowCaretByDefault = 'YES' then
    FollowCaretByDefault := 'NO'
  else
    FollowCaretByDefault := 'YES';

  RefreshPinIcon;
end;

{ =============================================================================== }

procedure TfrmPrevW.TurnOffFollowingCaret;
begin
  FollowCaretByDefault := 'NO';
  RefreshPinIcon;
end;

{ =============================================================================== }

procedure TfrmPrevW.DelayedExecute(DelayMs: Integer; Proc: TThreadMethod);
begin
  TThread.ForceQueue(nil, Proc, DelayMs);
end;

{ =============================================================================== }

procedure TfrmPrevW.InitPreviewWindowAtAppStart;
begin
  self.Show;
  self.AlphaBlendValue := 255;
  self.AlphaBlendValue := 0;
  Application.ProcessMessages;
end;

{ =============================================================================== }

procedure TfrmPrevW.ButtonMouseEnter(Sender: TObject);
begin
  Button.Picture := ImgButtonOver.Picture;
end;

{ =============================================================================== }

procedure TfrmPrevW.ButtonMouseLeave(Sender: TObject);
begin
  Button.Picture := ImgButtonUp.Picture;
end;

{ =============================================================================== }

procedure TfrmPrevW.ButtonMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  PopupMenu.Popup(self.Left + (Sender as TImage).Left, self.Top + (Sender as TImage).Top + (Sender as TImage).Height);
end;

{ =============================================================================== }

procedure TfrmPrevW.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := Params.ExStyle or WS_EX_TOPMOST or WS_EX_NOACTIVATE or WS_EX_TOOLWINDOW;
  Params.WndParent := GetDesktopWindow;
end;

{ =============================================================================== }

procedure TfrmPrevW.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  frmPrevW := nil;
end;

{ =============================================================================== }

procedure TfrmPrevW.RefreshGlassStyle;
begin
  EnableWindowAcrylicBlur(Handle, DarkModeIsEnabled, 160);
  if not EnableWindowRoundedCorners(Handle) then
    ApplyPillWindowRegion(Handle, Width, Height);
  Invalidate;
end;

{ =============================================================================== }

procedure TfrmPrevW.FormCreate(Sender: TObject);
begin
  DoubleBuffered := True;
  Color := clBlack;

  // Set modern typography
  Font.Name := 'Segoe UI';
  Font.Size := 10;

  // Hide obsolete legacy win32 controls
  Shape1.Visible := False;
  ImgTitleBar.Visible := False;
  lblCaption.Visible := False;
  Button.Visible := False;
  lblPreview.Visible := False;
  imgPin.Visible := False;
  List.Visible := False;

  FHoverIndex := -1;
  FSelectedIndex := 0;
  FPinHover := False;
  FIsDragging := False;

  Height := 42;
  Width := 260;
  FPinRect := Rect(Width - 28, 9, Width - 6, 33);

  RefreshGlassStyle;
  RefreshPinIcon;
  DelayedExecute(200, InitPreviewWindowAtAppStart);
  HidePreview;
end;

{ =============================================================================== }

procedure TfrmPrevW.imgPinClick(Sender: TObject);
begin
  ToggleFollowCaret;
end;

{ =============================================================================== }

procedure TfrmPrevW.ImgTitleBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseDown := True;
end;

procedure TfrmPrevW.ImgTitleBarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if MouseDown then
  begin
    MoveWindow(self.Left + X, self.Top + Y);
    TurnOffFollowingCaret;
  end;
end;

procedure TfrmPrevW.ImgTitleBarMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseDown := False;
end;

procedure TfrmPrevW.lblCaptionMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseDown := True;
end;

procedure TfrmPrevW.lblCaptionMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if MouseDown then
  begin
    MoveWindow(self.Left + X, self.Top + Y);
    TurnOffFollowingCaret;
  end;
end;

procedure TfrmPrevW.lblCaptionMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseDown := False;
end;

{ =============================================================================== }

procedure TfrmPrevW.ListClick(Sender: TObject);
begin
  if (List.ItemIndex >= 0) and (List.ItemIndex < List.Count) then
  begin
    FSelectedIndex := List.ItemIndex;
    AvroMainForm1.KeyLayout.SelectCandidate(List.Items[List.ItemIndex]);
    Invalidate;
  end;
end;

{ =============================================================================== }

function TfrmPrevW.IsPreviewVisible: Boolean;
begin
  Result := PreviewWCurrentlyVisible;
end;

{ =============================================================================== }

procedure TfrmPrevW.ShowPreview;
begin
  TopMost(frmPrevW.Handle);
  self.AlphaBlendValue := 255;
  PreviewWCurrentlyVisible := True;
  RefreshGlassStyle;
  Application.ProcessMessages;
end;

{ =============================================================================== }

procedure TfrmPrevW.HidePreview;
begin
  self.AlphaBlendValue := 0;
  PreviewWCurrentlyVisible := False;
end;

{ =============================================================================== }

procedure TfrmPrevW.SelectFirstItem;
begin
  if List.Count > 0 then
  begin
    List.ItemIndex := 0;
    FSelectedIndex := 0;
    ListClick(nil);
  end;
end;

{ =============================================================================== }

procedure TfrmPrevW.SelectItem(const Item: string);

  function EscapeSpecialCharacters(const inputT: string): string;
  var
    T: string;
  begin
    T := inputT;
    T := ReplaceStr(T, '\', '');
    T := ReplaceStr(T, '|', '');
    T := ReplaceStr(T, '(', '');
    T := ReplaceStr(T, ')', '');
    T := ReplaceStr(T, '[', '');
    T := ReplaceStr(T, ']', '');
    T := ReplaceStr(T, '{', '');
    T := ReplaceStr(T, '}', '');
    T := ReplaceStr(T, '^', '');
    T := ReplaceStr(T, '$', '');
    T := ReplaceStr(T, '*', '');
    T := ReplaceStr(T, '+', '');
    T := ReplaceStr(T, '?', '');
    T := ReplaceStr(T, '.', '');
    T := ReplaceStr(T, '~', '');
    T := ReplaceStr(T, '!', '');
    T := ReplaceStr(T, '@', '');
    T := ReplaceStr(T, '#', '');
    T := ReplaceStr(T, '%', '');
    T := ReplaceStr(T, '&', '');
    T := ReplaceStr(T, '-', '');
    T := ReplaceStr(T, '_', '');
    T := ReplaceStr(T, '=', '');
    T := ReplaceStr(T, #39, '');
    T := ReplaceStr(T, '"', '');
    T := ReplaceStr(T, ';', '');
    T := ReplaceStr(T, '<', '');
    T := ReplaceStr(T, '>', '');
    T := ReplaceStr(T, '/', '');
    T := ReplaceStr(T, ',', '');
    T := ReplaceStr(T, ':', '');
    T := ReplaceStr(T, '`', '');
    T := ReplaceStr(T, b_Taka, '');
    T := ReplaceStr(T, b_Dari, '');
    Result := T;
  end;

var
  I, J: Integer;
begin
  J := -1;
  for I := 0 to List.Count - 1 do
  begin
    if EscapeSpecialCharacters(List.Items[I]) = Item then
    begin
      List.ItemIndex := I;
      FSelectedIndex := I;
      J := I;
      Break;
    end;
  end;

  if J < 0 then
  begin
    List.ItemIndex := 0;
    FSelectedIndex := 0;
  end;

  ListClick(nil);
end;

{ =============================================================================== }

procedure TfrmPrevW.SelectNextItem;
var
  I:     Integer;
  Total: Integer;
begin
  I := List.ItemIndex;
  if I < 0 then
    I := 0;
  Total := List.Count - 1;
  I := I + 1;
  if I <= Total then
    List.ItemIndex := I
  else
    List.ItemIndex := 0;

  FSelectedIndex := List.ItemIndex;
  ListClick(nil);
end;

{ =============================================================================== }

procedure TfrmPrevW.SelectNItem(const ItemNumber: Integer);
begin
  if (ItemNumber >= 0) and (ItemNumber < List.Count) then
    List.ItemIndex := ItemNumber
  else
    List.ItemIndex := 0;

  FSelectedIndex := List.ItemIndex;
  ListClick(nil);
end;

{ =============================================================================== }

procedure TfrmPrevW.SelectPrevItem;
var
  I:     Integer;
  Total: Integer;
begin
  I := List.ItemIndex;
  if I < 0 then
    I := 0;
  Total := List.Count - 1;
  I := I - 1;
  if I < 0 then
    List.ItemIndex := Total
  else
    List.ItemIndex := I;

  FSelectedIndex := List.ItemIndex;
  ListClick(nil);
end;

{ =============================================================================== }

procedure TfrmPrevW.UpdateListHeight;
var
  I, XPos, TextW, ChipW, TotalW: Integer;
  ItemText: string;
begin
  SetLength(FCandidateChips, List.Items.Count);
  FSelectedIndex := List.ItemIndex;
  if FSelectedIndex < 0 then FSelectedIndex := 0;

  Canvas.Font.Assign(self.Font);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Size := 10;
  XPos := 10;

  for I := 0 to List.Items.Count - 1 do
  begin
    ItemText := List.Items[I];
    TextW := Canvas.TextWidth(ItemText);
    ChipW := TextW + 36;
    if ChipW < 48 then ChipW := 48;

    FCandidateChips[I].Index := I;
    FCandidateChips[I].Text := ItemText;
    FCandidateChips[I].Rect := Rect(XPos, 5, XPos + ChipW, 37);
    FCandidateChips[I].BadgeRect := Rect(XPos + 4, 8, XPos + 22, 34);
    FCandidateChips[I].TextRect := Rect(XPos + 26, 6, XPos + ChipW - 4, 36);

    XPos := XPos + ChipW + 6;
  end;

  TotalW := XPos + 34;
  if TotalW < 180 then TotalW := 180;
  if TotalW > 850 then TotalW := 850;

  self.Width := TotalW;
  self.Height := 42;

  FPinRect := Rect(Width - 28, 9, Width - 6, 33);

  RefreshGlassStyle;
end;

{ =============================================================================== }

procedure TfrmPrevW.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

{ =============================================================================== }

procedure TfrmPrevW.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if (FHoverIndex <> -1) or FPinHover then
  begin
    FHoverIndex := -1;
    FPinHover := False;
    Invalidate;
  end;
end;

{ =============================================================================== }

procedure TfrmPrevW.DrawPinGlyph(ACanvas: TCanvas; R: TRect; IsPinned, IsDark, IsHover: Boolean);
var
  MidX, MidY: Integer;
begin
  MidX := (R.Left + R.Right) div 2;
  MidY := (R.Top + R.Bottom) div 2;

  ACanvas.Brush.Style := bsSolid;
  if IsHover then
  begin
    if IsDark then
      ACanvas.Brush.Color := RGB(55, 65, 80)
    else
      ACanvas.Brush.Color := RGB(225, 235, 248);
    ACanvas.Pen.Color := clNone;
    ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);
  end;

  if IsPinned then
  begin
    // Solid active pin in accent color
    if IsDark then
      ACanvas.Pen.Color := RGB(0, 168, 255)
    else
      ACanvas.Pen.Color := RGB(0, 120, 215);
    ACanvas.Brush.Color := ACanvas.Pen.Color;

    // Pin head and needle
    ACanvas.RoundRect(MidX - 4, MidY - 5, MidX + 4, MidY, 3, 3);
    ACanvas.Pen.Width := 2;
    ACanvas.MoveTo(MidX, MidY);
    ACanvas.LineTo(MidX, MidY + 6);
  end
  else
  begin
    // Muted outline pin
    if IsDark then
      ACanvas.Pen.Color := RGB(130, 140, 155)
    else
      ACanvas.Pen.Color := RGB(120, 130, 145);
    ACanvas.Brush.Style := bsClear;

    ACanvas.RoundRect(MidX - 4, MidY - 5, MidX + 4, MidY, 3, 3);
    ACanvas.Pen.Width := 1;
    ACanvas.MoveTo(MidX, MidY);
    ACanvas.LineTo(MidX, MidY + 6);
  end;
end;

{ =============================================================================== }

procedure TfrmPrevW.WMPaint(var Message: TWMPaint);
var
  DC: HDC;
  PS: TPaintStruct;
  ACanvas: TCanvas;
  R, ChipR, BadgeR, TextR: TRect;
  I: Integer;
  IsDark: Boolean;
  NumStr: string;
begin
  DC := BeginPaint(Handle, PS);
  try
    ACanvas := TCanvas.Create;
    try
      ACanvas.Handle := DC;
      R := ClientRect;
      IsDark := DarkModeIsEnabled;

      // Draw Glassmorphism Frosted Backdrop
      ACanvas.Brush.Style := bsSolid;
      if IsDark then
        ACanvas.Brush.Color := RGB(24, 26, 32)
      else
        ACanvas.Brush.Color := RGB(246, 248, 252);
      ACanvas.FillRect(R);

      // Draw Specular Glassmorphism Border
      DrawGlassmorphismBorder(ACanvas, R, IsDark);

      // Draw Candidate Chips
      for I := 0 to High(FCandidateChips) do
      begin
        ChipR := FCandidateChips[I].Rect;

        if I = FSelectedIndex then
        begin
          // Active Selected Candidate Capsule
          ACanvas.Brush.Style := bsSolid;
          if IsDark then
          begin
            ACanvas.Brush.Color := RGB(0, 122, 255);
            ACanvas.Pen.Color := RGB(64, 169, 255);
          end
          else
          begin
            ACanvas.Brush.Color := RGB(0, 120, 215);
            ACanvas.Pen.Color := RGB(0, 90, 180);
          end;
          ACanvas.Pen.Width := 1;
          ACanvas.RoundRect(ChipR.Left, ChipR.Top, ChipR.Right, ChipR.Bottom, 14, 14);

          // Active Number Badge
          BadgeR := FCandidateChips[I].BadgeRect;
          if IsDark then
            ACanvas.Brush.Color := RGB(0, 90, 200)
          else
            ACanvas.Brush.Color := RGB(0, 85, 170);
          ACanvas.Pen.Color := ACanvas.Brush.Color;
          ACanvas.RoundRect(BadgeR.Left, BadgeR.Top, BadgeR.Right, BadgeR.Bottom, 6, 6);

          ACanvas.Font.Assign(self.Font);
          ACanvas.Font.Size := 8;
          ACanvas.Font.Style := [fsBold];
          ACanvas.Font.Color := clWhite;
          NumStr := IntToStr(I + 1);
          DrawText(ACanvas.Handle, PChar(NumStr), Length(NumStr), BadgeR, DT_CENTER or DT_VCENTER or DT_SINGLELINE);

          // Active Bengali Text
          TextR := FCandidateChips[I].TextRect;
          ACanvas.Font.Size := 10;
          ACanvas.Font.Style := [fsBold];
          ACanvas.Font.Color := clWhite;
          DrawText(ACanvas.Handle, PChar(FCandidateChips[I].Text), Length(FCandidateChips[I].Text), TextR, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
        end
        else if I = FHoverIndex then
        begin
          // Hovered Candidate Capsule
          ACanvas.Brush.Style := bsSolid;
          if IsDark then
          begin
            ACanvas.Brush.Color := RGB(45, 52, 65);
            ACanvas.Pen.Color := RGB(75, 88, 110);
          end
          else
          begin
            ACanvas.Brush.Color := RGB(225, 235, 248);
            ACanvas.Pen.Color := RGB(190, 210, 235);
          end;
          ACanvas.Pen.Width := 1;
          ACanvas.RoundRect(ChipR.Left, ChipR.Top, ChipR.Right, ChipR.Bottom, 14, 14);

          // Hover Number Badge
          BadgeR := FCandidateChips[I].BadgeRect;
          ACanvas.Font.Assign(self.Font);
          ACanvas.Font.Size := 8;
          ACanvas.Font.Style := [fsBold];
          if IsDark then
            ACanvas.Font.Color := RGB(180, 190, 205)
          else
            ACanvas.Font.Color := RGB(80, 90, 110);
          NumStr := IntToStr(I + 1);
          DrawText(ACanvas.Handle, PChar(NumStr), Length(NumStr), BadgeR, DT_CENTER or DT_VCENTER or DT_SINGLELINE);

          // Hover Bengali Text
          TextR := FCandidateChips[I].TextRect;
          ACanvas.Font.Size := 10;
          ACanvas.Font.Style := [];
          if IsDark then
            ACanvas.Font.Color := clWhite
          else
            ACanvas.Font.Color := clBlack;
          DrawText(ACanvas.Handle, PChar(FCandidateChips[I].Text), Length(FCandidateChips[I].Text), TextR, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
        end
        else
        begin
          // Normal Candidate
          ACanvas.Brush.Style := bsClear;
          ACanvas.Pen.Color := clNone;

          // Normal Number Badge
          BadgeR := FCandidateChips[I].BadgeRect;
          ACanvas.Font.Assign(self.Font);
          ACanvas.Font.Size := 8;
          ACanvas.Font.Style := [fsBold];
          if IsDark then
            ACanvas.Font.Color := RGB(130, 140, 155)
          else
            ACanvas.Font.Color := RGB(110, 120, 135);
          NumStr := IntToStr(I + 1);
          DrawText(ACanvas.Handle, PChar(NumStr), Length(NumStr), BadgeR, DT_CENTER or DT_VCENTER or DT_SINGLELINE);

          // Normal Bengali Text
          TextR := FCandidateChips[I].TextRect;
          ACanvas.Font.Size := 10;
          ACanvas.Font.Style := [];
          if IsDark then
            ACanvas.Font.Color := RGB(220, 225, 235)
          else
            ACanvas.Font.Color := RGB(30, 35, 45);
          DrawText(ACanvas.Handle, PChar(FCandidateChips[I].Text), Length(FCandidateChips[I].Text), TextR, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
        end;
      end;

      // Draw Pin Button
      DrawPinGlyph(ACanvas, FPinRect, FollowCaretByDefault = 'YES', IsDark, FPinHover);

    finally
      ACanvas.Free;
    end;
  finally
    EndPaint(Handle, PS);
  end;
end;

{ =============================================================================== }

procedure TfrmPrevW.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if Button = mbRight then
  begin
    PopupMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
    Exit;
  end;

  // Check candidate click
  for I := 0 to High(FCandidateChips) do
  begin
    if PtInRect(FCandidateChips[I].Rect, Point(X, Y)) then
    begin
      SelectNItem(I);
      Exit;
    end;
  end;

  // Check pin button click
  if PtInRect(FPinRect, Point(X, Y)) then
  begin
    ToggleFollowCaret;
    Exit;
  end;

  // Click on empty bar: start drag
  FIsDragging := True;
  FDragStart := Point(X, Y);
end;

procedure TfrmPrevW.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  I, NewHover: Integer;
  NewPinHover: Boolean;
begin
  if FIsDragging then
  begin
    MoveWindow(self.Left + (X - FDragStart.X), self.Top + (Y - FDragStart.Y));
    TurnOffFollowingCaret;
    Exit;
  end;

  NewHover := -1;
  for I := 0 to High(FCandidateChips) do
  begin
    if PtInRect(FCandidateChips[I].Rect, Point(X, Y)) then
    begin
      NewHover := I;
      Break;
    end;
  end;

  NewPinHover := PtInRect(FPinRect, Point(X, Y));

  if (NewHover <> FHoverIndex) or (NewPinHover <> FPinHover) then
  begin
    FHoverIndex := NewHover;
    FPinHover := NewPinHover;
    Invalidate;
  end;
end;

procedure TfrmPrevW.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FIsDragging := False;
end;

end.
