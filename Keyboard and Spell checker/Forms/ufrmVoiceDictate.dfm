object frmVoiceDictate: TfrmVoiceDictate
  Left = 0
  Top = 0
  AlphaBlend = True
  AlphaBlendValue = 240
  BorderStyle = bsNone
  Caption = 'Avro Voice Dictation'
  ClientHeight = 54
  ClientWidth = 260
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 17
  object ShapeBackground: TShape
    Left = 0
    Top = 0
    Width = 260
    Height = 54
    Align = alClient
    Brush.Color = 16119285
    Pen.Color = 13816530
    Pen.Width = 1
    Shape = stRoundRect
  end
  object lblMic: TLabel
    Left = 14
    Top = 15
    Width = 24
    Height = 24
    Caption = #127908;
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clRed
    Font.Height = -19
    Font.Name = 'Segoe UI Emoji'
    Font.Style = []
    ParentFont = False
  end
  object lblStatus: TLabel
    Left = 46
    Top = 10
    Width = 140
    Height = 17
    Caption = #2486#2509#2488#2468#2503#2459#2495'... ('#2453#2464#2494' '#2476#2482#2497#2472')'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblHint: TLabel
    Left = 46
    Top = 30
    Width = 132
    Height = 14
    Caption = 'Click to finish | Esc to cancel'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object btnStop: TButton
    Left = 196
    Top = 12
    Width = 52
    Height = 30
    Caption = #2465#2494#2472
    TabOrder = 0
    OnClick = btnStopClick
  end
  object tmrPulse: TTimer
    Interval = 500
    OnTimer = tmrPulseTimer
    Left = 160
    Top = 10
  end
end
