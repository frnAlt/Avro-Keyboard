unit uGlassmorphism;

interface

uses
  Windows,
  SysUtils,
  Classes,
  Graphics,
  Controls,
  Forms,
  uOfflineSTTWrapper,
  WindowsDarkMode;

type
  AccentState = (
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
    ACCENT_ENABLE_HOSTBACKDROP = 5,
    ACCENT_INVALID_STATE = 6
  );

  AccentPolicy = packed record
    AccentState: Integer;
    AccentFlags: Integer;
    GradientColor: Integer;
    AnimationId: Integer;
  end;

  WindowCompositionAttribute = (
    WCA_UNDEFINED = 0,
    WCA_NCRENDERING_ENABLED = 1,
    WCA_NCRENDERING_POLICY = 2,
    WCA_TRANSITIONS_FORCEDISABLED = 3,
    WCA_ALLOW_NCPAINT = 4,
    WCA_CAPTION_BUTTON_BOUNDS = 5,
    WCA_NONCLIENT_RTL_LAYOUT = 6,
    WCA_FORCE_ICONIC_REPRESENTATION = 7,
    WCA_EXTENDED_FRAME_BOUNDS = 8,
    WCA_HAS_ICONIC_BITMAP = 9,
    WCA_THEME_ATTRIBUTES = 10,
    WCA_NCRENDERING_EXULTATION = 11,
    WCA_EXCLUDED_FROM_LIVEPREVIEW = 12,
    WCA_VIDEO_OVERLAY_ACTIVE = 13,
    WCA_FORCE_ACTIVEWINDOW_APPEARANCE = 14,
    WCA_DISALLOW_PEEK = 15,
    WCA_CLOAK = 16,
    WCA_CLOAKED = 17,
    WCA_ACCENT_POLICY = 19,
    WCA_FREEZE_REPRESENTATION = 20,
    WCA_EVER_UNCLOAKED = 21,
    WCA_VISUAL_OWNER = 22,
    WCA_HOLOGRAPHIC = 23,
    WCA_EXCLUDED_FROM_DDA = 24,
    WCA_PASSIVEUPDATEMODE = 25,
    WCA_USEDARKMODECOLORS = 26,
    WCA_CORNER_STYLE = 27,
    WCA_PART_COLOR = 28,
    WCA_DISABLE_MOVESIZE_FEEDBACK = 29,
    WCA_SYSTEMBACKDROP_TYPE = 30
  );

  WindowCompositionAttributeData = packed record
    Attribute: Integer;
    Data: Pointer;
    SizeOfData: Integer;
  end;

const
  DWMWA_WINDOW_CORNER_PREFERENCE = 33;
  DWMWCP_ROUND                   = 2;
  DWMWA_BORDER_COLOR             = 34;
  DWMWA_USE_IMMERSIVE_DARK_MODE  = 20;

function EnableWindowAcrylicBlur(hWnd: HWND; IsDark: Boolean = True; TintOpacity: Byte = 140): Boolean;
function EnableWindowRoundedCorners(hWnd: HWND): Boolean;
procedure ApplyPillWindowRegion(hWnd: HWND; Width, Height: Integer);
procedure DrawGlassmorphismBorder(Canvas: TCanvas; R: TRect; IsDark: Boolean = True; GlowIntensity: Single = 0.0);

implementation

type
  TSetWindowCompositionAttribute = function(Wnd: HWND; var Data: WindowCompositionAttributeData): BOOL; stdcall;
  TDwmSetWindowAttribute = function(hwnd: HWND; dwAttribute: DWORD; pvAttribute: LPCVOID; cbAttribute: DWORD): HRESULT; stdcall;

var
  hUser32: HMODULE = 0;
  hDwmApi: HMODULE = 0;
  SetWindowCompositionAttributeFunc: TSetWindowCompositionAttribute = nil;
  DwmSetWindowAttributeFunc: TDwmSetWindowAttribute = nil;

function InitCompositionAPIs: Boolean;
begin
  if hUser32 = 0 then
  begin
    hUser32 := GetModuleHandle('user32.dll');
    if hUser32 <> 0 then
      @SetWindowCompositionAttributeFunc := GetProcAddress(hUser32, 'SetWindowCompositionAttribute');
  end;

  if hDwmApi = 0 then
  begin
    hDwmApi := LoadLibrary('dwmapi.dll');
    if hDwmApi <> 0 then
      @DwmSetWindowAttributeFunc := GetProcAddress(hDwmApi, 'DwmSetWindowAttribute');
  end;

  Result := Assigned(SetWindowCompositionAttributeFunc);
end;

function EnableWindowAcrylicBlur(hWnd: HWND; IsDark: Boolean = True; TintOpacity: Byte = 140): Boolean;
var
  Data: WindowCompositionAttributeData;
  Policy: AccentPolicy;
  Alpha, Red, Green, Blue: Byte;
  TintBGR: Integer;
begin
  Result := False;
  if not InitCompositionAPIs then Exit;

  // On low-spec PC (<4GB RAM or older OS), fallback to standard transparency without heavy GPU acrylic
  if not IsAcrylicSupported then
  begin
    FillChar(Policy, SizeOf(AccentPolicy), 0);
    Policy.AccentState := Ord(ACCENT_ENABLE_BLURBEHIND);
    Policy.AccentFlags := 0;
    Policy.GradientColor := 0;

    Data.Attribute := Ord(WCA_ACCENT_POLICY);
    Data.Data := @Policy;
    Data.SizeOfData := SizeOf(AccentPolicy);

    Result := SetWindowCompositionAttributeFunc(hWnd, Data);
    Exit;
  end;

  Alpha := TintOpacity;
  if IsDark then
  begin
    Red := 24;
    Green := 24;
    Blue := 28;
  end
  else
  begin
    Red := 240;
    Green := 242;
    Blue := 248;
  end;

  // Format: AABBGGRR (little-endian hex: (Alpha shl 24) or (Blue shl 16) or (Green shl 8) or Red)
  TintBGR := (Alpha shl 24) or (Blue shl 16) or (Green shl 8) or Red;

  FillChar(Policy, SizeOf(AccentPolicy), 0);
  Policy.AccentState := Ord(ACCENT_ENABLE_ACRYLICBLURBEHIND);
  Policy.AccentFlags := $20; // Draw borders
  Policy.GradientColor := TintBGR;
  Policy.AnimationId := 0;

  Data.Attribute := Ord(WCA_ACCENT_POLICY);
  Data.Data := @Policy;
  Data.SizeOfData := SizeOf(AccentPolicy);

  Result := SetWindowCompositionAttributeFunc(hWnd, Data);
  if not Result then
  begin
    Policy.AccentState := Ord(ACCENT_ENABLE_BLURBEHIND);
    Policy.AccentFlags := 0;
    Policy.GradientColor := 0;
    Result := SetWindowCompositionAttributeFunc(hWnd, Data);
  end;
end;

function EnableWindowRoundedCorners(hWnd: HWND): Boolean;
var
  CornerPreference: DWORD;
  DarkModeVal: BOOL;
  hr: HRESULT;
begin
  Result := False;
  InitCompositionAPIs;

  if Assigned(DwmSetWindowAttributeFunc) then
  begin
    // Enable Windows 11 Rounded Corners (DWMWCP_ROUND)
    CornerPreference := DWMWCP_ROUND;
    hr := DwmSetWindowAttributeFunc(hWnd, DWMWA_WINDOW_CORNER_PREFERENCE, @CornerPreference, SizeOf(CornerPreference));
    if hr = S_OK then
      Result := True;

    // Match dark mode
    DarkModeVal := DarkModeIsEnabled;
    DwmSetWindowAttributeFunc(hWnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @DarkModeVal, SizeOf(DarkModeVal));
  end;
end;

procedure ApplyPillWindowRegion(hWnd: HWND; Width, Height: Integer);
var
  Rgn: HRGN;
  Radius: Integer;
begin
  if (Width <= 0) or (Height <= 0) then Exit;
  Radius := Height; // Pill shape: radius equals height
  Rgn := CreateRoundRectRgn(0, 0, Width + 1, Height + 1, Radius, Radius);
  if Rgn <> 0 then
    SetWindowRgn(hWnd, Rgn, True);
end;

procedure DrawGlassmorphismBorder(Canvas: TCanvas; R: TRect; IsDark: Boolean = True; GlowIntensity: Single = 0.0);
var
  PillRadius: Integer;
begin
  PillRadius := (R.Bottom - R.Top);

  Canvas.Brush.Style := bsClear;

  // If microphone is active, draw subtle dynamic voice glow
  if GlowIntensity > 0.05 then
  begin
    Canvas.Pen.Width := 2;
    Canvas.Pen.Color := RGB(235, 87, 87); // Coral Red voice active glow
    Canvas.RoundRect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1, PillRadius, PillRadius);
  end
  else
  begin
    Canvas.Pen.Width := 1;
    if IsDark then
      Canvas.Pen.Color := RGB(70, 75, 85) // Subtle specular 1px border in dark mode
    else
      Canvas.Pen.Color := RGB(210, 215, 225); // Subtle specular border in light mode
    Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, PillRadius, PillRadius);
  end;
end;

initialization

finalization
  if hDwmApi <> 0 then
  begin
    FreeLibrary(hDwmApi);
    hDwmApi := 0;
  end;

end.
