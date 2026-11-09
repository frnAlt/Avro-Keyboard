object frmSymbolsPicker: TfrmSymbolsPicker
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Bangla Symbols & Emoji Picker'
  ClientHeight = 240
  ClientWidth = 320
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
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 320
    Height = 240
    ActivePage = TabBangla
    Align = alClient
    TabOrder = 0
    object TabBangla: TTabSheet
      Caption = 'Bangla Punctuation'
      object GridBangla: TDrawGrid
        Left = 0
        Top = 0
        Width = 312
        Height = 209
        Align = alClient
        ColCount = 6
        DefaultColWidth = 50
        DefaultRowHeight = 40
        FixedCols = 0
        FixedRows = 0
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -19
        Font.Name = 'Kalpurush'
        Font.Style = []
        ParentFont = False
        RowCount = 4
        ScrollBars = ssVertical
        TabOrder = 0
        OnDrawCell = GridBanglaDrawCell
        OnSelectCell = GridBanglaSelectCell
      end
    end
    object TabSymbols: TTabSheet
      Caption = 'Math & Currency'
      ImageIndex = 1
      object GridSymbols: TDrawGrid
        Left = 0
        Top = 0
        Width = 312
        Height = 209
        Align = alClient
        ColCount = 6
        DefaultColWidth = 50
        DefaultRowHeight = 40
        FixedCols = 0
        FixedRows = 0
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -19
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        RowCount = 4
        ScrollBars = ssVertical
        TabOrder = 0
        OnDrawCell = GridSymbolsDrawCell
        OnSelectCell = GridSymbolsSelectCell
      end
    end
    object TabEmoji: TTabSheet
      Caption = 'Emojis'
      ImageIndex = 2
      object GridEmoji: TDrawGrid
        Left = 0
        Top = 0
        Width = 312
        Height = 209
        Align = alClient
        ColCount = 6
        DefaultColWidth = 50
        DefaultRowHeight = 40
        FixedCols = 0
        FixedRows = 0
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -19
        Font.Name = 'Segoe UI Emoji'
        Font.Style = []
        ParentFont = False
        RowCount = 4
        ScrollBars = ssVertical
        TabOrder = 0
        OnDrawCell = GridEmojiDrawCell
        OnSelectCell = GridEmojiSelectCell
      end
    end
  end
end
