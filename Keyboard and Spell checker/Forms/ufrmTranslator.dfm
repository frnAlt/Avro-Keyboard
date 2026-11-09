object frmTranslator: TfrmTranslator
  Left = 0
  Top = 0
  AlphaBlend = True
  AlphaBlendValue = 248
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSizeToolWin
  Caption = 'Avro Multilingual Translator'
  ClientHeight = 360
  ClientWidth = 440
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 15
  object lblHeader: TLabel
    Left = 14
    Top = 10
    Width = 230
    Height = 18
    Caption = 'Avro Open Translator (Google API)'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -14
    Font.Name = 'Segoe UI Semibold'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblStatus: TLabel
    Left = 14
    Top = 336
    Width = 32
    Height = 14
    Caption = 'Ready.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object comboSourceLang: TComboBox
    Left = 14
    Top = 36
    Width = 175
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 0
    Text = 'Auto-Detect'
    Items.Strings = (
      'Auto-Detect'
      'Bengali'
      'English'
      'Arabic'
      'Hindi'
      'Spanish'
      'French'
      'German'
      'Chinese'
      'Japanese'
      'Urdu'
    )
  end
  object btnSwap: TButton
    Left = 196
    Top = 35
    Width = 46
    Height = 25
    Caption = '<->'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 1
    OnClick = btnSwapClick
  end
  object comboTargetLang: TComboBox
    Left = 249
    Top = 36
    Width = 175
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 2
    Text = 'Bengali'
    Items.Strings = (
      'Bengali'
      'English'
      'Arabic'
      'Hindi'
      'Spanish'
      'French'
      'German'
      'Chinese'
      'Japanese'
      'Urdu'
    )
  end
  object memoSource: TMemo
    Left = 14
    Top = 68
    Width = 410
    Height = 110
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object memoTarget: TMemo
    Left = 14
    Top = 186
    Width = 410
    Height = 110
    Color = clWindow
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 4
  end
  object btnTranslate: TButton
    Left = 14
    Top = 304
    Width = 90
    Height = 26
    Caption = 'Translate'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 5
    OnClick = btnTranslateClick
  end
  object btnCopy: TButton
    Left = 110
    Top = 304
    Width = 70
    Height = 26
    Caption = 'Copy'
    TabOrder = 6
    OnClick = btnCopyClick
  end
  object btnInsert: TButton
    Left = 186
    Top = 304
    Width = 100
    Height = 26
    Caption = 'Insert at Cursor'
    TabOrder = 7
    OnClick = btnInsertClick
  end
  object btnSpeak: TButton
    Left = 292
    Top = 304
    Width = 64
    Height = 26
    Caption = 'Voice'
    TabOrder = 8
    OnClick = btnSpeakClick
  end
  object btnClear: TButton
    Left = 362
    Top = 304
    Width = 62
    Height = 26
    Caption = 'Clear'
    TabOrder = 9
    OnClick = btnClearClick
  end
end
