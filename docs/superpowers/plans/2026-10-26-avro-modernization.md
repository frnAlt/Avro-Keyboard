# Avro Keyboard Modernization & Upstream PR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a production-grade, regression-free modernization of Avro Keyboard featuring a macOS frosted-glass UI skin, Google Spell Checker integration, Voice-to-Text dictation, symbols/emoji quick picker, upstream issue fixes (cursor tracking, DPI scaling), automated headless CI/CD compilation, and clean MPL 2.0 attribution ready for merging into `mugli/Avro-Keyboard`.

**Architecture:** Maintain strict adherence to Embarcadero Delphi 12 VCL architecture. Keep all core keyboard hook and IMM32 message processing untouched. Guarantee full 100% offline capability across all tools:
- Core typing, layouts, and phonetic engine run 100% locally.
- Modern macOS Glass UI and Symbols/Emoji picker are 100% offline.
- Spell Checker uses the local SQLite database (`Database.db3`) and `autodict.dct` as its primary engine, querying Google Online suggestions only when internet is connected and instantly falling back to local results when offline.
- Voice-to-Text provides dual-mode architecture: Windows SAPI/Desktop Speech engine for offline dictation and Google Cloud Speech for online dictation.
All network operations run in non-blocking background worker threads with hard timeouts (1500ms max) so typing latency and responsiveness are never impacted.

**Tech Stack:** Embarcadero Delphi 12 Community Edition / MSBuild, Object Pascal, Win32 API (Hooks, MMDevice audio, SendInput), Windows VCL Styles, GitHub Actions (windows-latest), MPL 2.0.

**Spec:** [`docs/superpowers/specs/2026-10-26-avro-modernization-design.md`](file:///home/ffjisan804/Avro-Keyboard/docs/superpowers/specs/2026-10-26-avro-modernization-design.md)

## Global Constraints

- Never break or modify core phonetic rules in `clsEnglishToBangla.pas` or keyboard hooking in `KeyboardHook.pas`.
- Never execute synchronous network calls on the main UI/typing thread.
- Preserve 100% backward compatibility with existing keyboard layouts (`.avrolayout`) and skins (`.avroskin`).
- Preserve original OmicronLab copyright headers across all files; record all additions under `Contributor(s):` per MPL 2.0.
- All code must conform to Delphi 12 syntax and formatting defined in `Formatter_Profile.config`.

## Review Focus

1. **Network timeout / offline typing:** If internet drops or Google API fails, the spell checker and voice dictation must fall back immediately without hanging the UI or causing typing lag.
2. **Multi-monitor DPI boundary crossings:** Moving the TopBar or caret window between 100% and 150% DPI displays must preserve correct scale and icon sharpness without clipping.
3. **Audio buffer overflow / resource release:** Audio recording in `uAvroVoice.pas` must free MMDevice wave handles in `finally` blocks to prevent memory/handle leaks.
4. **User dictionary preservation:** Upgrades and portable builds must never overwrite `autodict.dct` or custom user dictionaries.
5. **Headless MSBuild compliance:** CI/CD build scripts must resolve project dependencies and output paths correctly without requiring RAD Studio IDE GUI interaction.

---

### Task 1: Headless Build Automation & GitHub Actions CI/CD Workflow (Issue #98)

**Files:**
- Create: `.github/workflows/build-release.yml`
- Create: `build-portable.bat`
- Create: `build-release.ps1`
- Modify: `Readme.md`

**Interfaces:**
- Consumes: `WholeProject.groupproj`, `build/`
- Produces: `build/Avro Keyboard.exe`, `build/Avro Spell Checker.exe`, `build/AvroSpell.dll`, `build/Layout Editor.exe`, `build/Skin Designer.exe`, `build/Unicode to Bijoy.exe`, `Avro-Keyboard-Portable.zip`

- [ ] **Step 1: Create PowerShell headless build script `build-release.ps1`**
  Implement automatic detection of Embarcadero RAD Studio / Delphi MSBuild tools from Windows Registry (`HKLM:\SOFTWARE\Embarcadero\BDS\*` or standard installation directories), invoke MSBuild with `/p:Config=Release /target:Build WholeProject.groupproj`, and populate `build/` with proper binary names.

- [ ] **Step 2: Create batch build script `build-portable.bat`**
  Provide a lightweight batch wrapper calling MSBuild and archiving the resulting binaries, layouts (`assets/keyboard-layouts`), skins (`assets/skins`), and fonts into a portable distribution ZIP.

- [ ] **Step 3: Create GitHub Actions workflow `.github/workflows/build-release.yml`**
  Configure a Windows runner workflow that triggers on `push`, `pull_request`, and `tags: v*`. Steps: checkout, locate/configure MSBuild, build `WholeProject.groupproj`, generate portable zip with SHA256 checksums, and publish release artifacts via `softprops/action-gh-release`.

- [ ] **Step 4: Update `Readme.md`**
  Document the automated build commands (`build-portable.bat`, `build-release.ps1`), CI workflow status, and how community contributors can build headlessly.

- [ ] **Step 5: Verify build script syntax and configuration**
  Run verification commands to confirm XML/YAML validity of the workflow and batch scripts.

- [ ] **Step 6: Commit Task 1**
  ```bash
  git add .github/workflows/build-release.yml build-portable.bat build-release.ps1 Readme.md
  git commit -m "ci: add automated headless build scripts and GitHub Actions release workflow (#98)"
  ```

---

### Task 2: Fix Cursor Caret Tracking & DPI Issues (Issues #114, #109, #93, #97)

**Files:**
- Modify: `Keyboard and Spell checker/Units/uWindowHandlers.pas`
- Modify: `Keyboard and Spell checker/Units/KeyboardHook.pas`
- Modify: `Keyboard and Spell checker/Forms/uForm1.pas`
- Modify: `Keyboard and Spell checker/Units/uFileFolderHandling.pas`

**Interfaces:**
- Consumes: Win32 `GetGUIThreadInfo`, `ClientToScreen`, Windows DPI awareness APIs
- Produces: `GetCaretPosition(var Pt: TPoint): Boolean` with dynamic multi-monitor coordinate correction

- [ ] **Step 1: Refine caret position tracking in `uWindowHandlers.pas`**
  Implement dynamic caret tracking using `GetGUIThreadInfo` with fallback to `GetCaretPos` and screen offset calculation so the phonetic suggestion popup tracks the text cursor in modern Chromium, Electron, and Office applications without lagging or freezing.

- [ ] **Step 2: Update phonetic suggestion window positioning in `KeyboardHook.pas`**
  Ensure suggestion popup clamps to the current monitor's work area and avoids multi-monitor clipping when typing near screen edges.

- [ ] **Step 3: Add Windows 10/11 system tray notification on minimize in `uForm1.pas` (Issue #93)**
  Display a non-intrusive notification toast/balloon hint when Avro is minimized to the notification area explaining how to restore the topbar.

- [ ] **Step 4: Protect user dictionary during updates in `uFileFolderHandling.pas` (Issue #97)**
  Add safe merge logic so existing user-added vocabulary in `autodict.dct` is preserved when updating versions.

- [ ] **Step 5: Verify Pascal unit syntax and compile readiness**
  Verify units format cleanly with `Formatter_Profile.config` and contain no syntax regressions.

- [ ] **Step 6: Commit Task 2**
  ```bash
  git add "Keyboard and Spell checker/Units/uWindowHandlers.pas" "Keyboard and Spell checker/Units/KeyboardHook.pas" "Keyboard and Spell checker/Forms/uForm1.pas" "Keyboard and Spell checker/Units/uFileFolderHandling.pas"
  git commit -m "fix: improve caret tracking, multi-monitor DPI scaling, and dictionary preservation (#114, #109, #93, #97)"
  ```

---

### Task 3: macOS Frosted Glass Modern Skin (`macOS Glass.avroskin`)

**Files:**
- Create: `assets/skins/macOS Glass.avroskin`
- Create: `assets/skins/macOS Glass Dark.avroskin`
- Modify: `Keyboard and Spell checker/Classes/clsSkinLayoutConverter.pas`
- Modify: `Keyboard and Spell checker/Forms/uTopBar.pas`

**Interfaces:**
- Consumes: Avro XML skin format (`<Layout><SkinName>macOS Glass</SkinName>...`)
- Produces: High-DPI transparent floating TopBar with frosted glass aesthetic and modern button states

- [ ] **Step 1: Construct modern button graphics and layout specifications**
  Generate crisp, modern anti-aliased iconography for:
  - Globe / Avro logo ('অ')
  - Mode toggle capsule (English / Bangla status indicator)
  - Layout selector dropdown icon
  - Layout viewer icon
  - Avro mouse icon
  - Tools menu icon
  - Voice dictation microphone icon
  - Punctuation & symbols picker icon
  - Close and minimize icons
  Each button is generated in 32-bit BMP/PNG with alpha transparency for `Normal`, `Over`, and `Down` states.

- [ ] **Step 2: Generate `assets/skins/macOS Glass.avroskin` (Light Glass)**
  Encode the translucent background, capsule border, and high-DPI icons into valid Avro XML format matching `clsSkinLayoutConverter.pas` standards.

- [ ] **Step 3: Generate `assets/skins/macOS Glass Dark.avroskin` (Dark Glass)**
  Encode dark frosted glass aesthetic with subtle luminous accents for dark mode users.

- [ ] **Step 4: Update skin parser and default skin list**
  Ensure `clsSkinLayoutConverter.pas` and `uTopBar.pas` load the modern skin smoothly with accurate button hit-testing and anti-aliased transparency.

- [ ] **Step 5: Verify skin XML syntax and asset integrity**
  Validate XML structure and base64 payloads to ensure flawless loading.

- [ ] **Step 6: Commit Task 3**
  ```bash
  git add "assets/skins/macOS Glass.avroskin" "assets/skins/macOS Glass Dark.avroskin" "Keyboard and Spell checker/Classes/clsSkinLayoutConverter.pas" "Keyboard and Spell checker/Forms/uTopBar.pas"
  git commit -m "feat: add modern macOS frosted glass skins and high-DPI iconography"
  ```

---

### Task 4: Google Hybrid Spell Checker Engine

**Files:**
- Create: `Keyboard and Spell checker/SpellChecker/uSpellGoogleSearch.pas`
- Modify: `Keyboard and Spell checker/SpellChecker/AvroSpell.dpr`
- Modify: `Keyboard and Spell checker/SpellChecker/clsSpellPhoneticSuggestionBuilder.pas`
- Modify: `Keyboard and Spell checker/SpellChecker/ufrmSpellOptions.pas` & `.dfm`

**Interfaces:**
- Consumes: Google Input Tools Bengali API endpoint (`https://inputtools.google.com/request?text=...&itc=bn-t-i0-und&num=5`)
- Produces: `function GoogleSuggestBangla(const QueryWord: string; var Suggestions: TStringList; TimeoutMs: Integer = 1500): Boolean`

- [ ] **Step 1: Implement `uSpellGoogleSearch.pas`**
  Build a dedicated, asynchronous HTTP REST client using standard Win32 `WinINet` / `WinHTTP` APIs (no external DLL dependencies). Query Google's Bengali phonetic suggestion API with JSON response parsing and a hard 1500ms timeout.

- [ ] **Step 2: Implement hybrid suggestion merge in `clsSpellPhoneticSuggestionBuilder.pas`**
  Query local SQLite database (`uDBase.pas`) and hash table first. If online suggestions are enabled in options, invoke `GoogleSuggestBangla` asynchronously. Deduplicate and rank suggestions using Levenshtein distance (`uSpellEditDistanceSearch.pas`).

- [ ] **Step 3: Update `ufrmSpellOptions.pas` and `.dfm`**
  Add a checkbox: "Enable Google Online Suggestions (Requires Internet)" with an optional API Key input field for enterprise quota.

- [ ] **Step 4: Update `AvroSpell.dpr` project file**
  Include `uSpellGoogleSearch.pas` in the library uses clause and verify export compatibility with `AvroSpell.dll`.

- [ ] **Step 5: Verify error resilience and timeout handling**
  Verify that when offline or when connection times out, the function returns `False` immediately and local dictionary suggestions display with zero interruption.

- [ ] **Step 6: Commit Task 4**
  ```bash
  git add "Keyboard and Spell checker/SpellChecker/uSpellGoogleSearch.pas" "Keyboard and Spell checker/SpellChecker/AvroSpell.dpr" "Keyboard and Spell checker/SpellChecker/clsSpellPhoneticSuggestionBuilder.pas" "Keyboard and Spell checker/SpellChecker/ufrmSpellOptions.pas" "Keyboard and Spell checker/SpellChecker/ufrmSpellOptions.dfm"
  git commit -m "feat: implement hybrid Google online spell check engine with offline fallback"
  ```

---

### Task 5: Voice-to-Text (কণ্ঠস্বর / Speech to Text) Engine

**Files:**
- Create: `Keyboard and Spell checker/Units/uAvroVoice.pas`
- Create: `Keyboard and Spell checker/Forms/ufrmVoiceDictate.pas` & `ufrmVoiceDictate.dfm`
- Modify: `Keyboard and Spell checker/Forms/uForm1.pas`
- Modify: `Keyboard and Spell checker/Forms/uTopBar.pas`
- Modify: `Keyboard and Spell checker/Avro_Keyboard.dproj`

**Interfaces:**
- Consumes: Windows `waveInOpen`/`waveInStart` API (16kHz, 16-bit mono), Google Speech Recognition API (`languageCode=bn-BD`)
- Produces: `TAvroVoiceEngine` class dispatching recognized text to `KeyboardFunctions.SendKey_Char`

- [ ] **Step 1: Implement audio recording and HTTP client in `uAvroVoice.pas`**
  Create `TAvroVoiceEngine` using standard Win32 `mmsystem.pas` (`waveInOpen`, `waveInAddBuffer`, `waveInStart`, `waveInStop`). Record microphone audio in standard 16kHz 16-bit linear PCM and stream via HTTPS POST to Google Cloud Speech recognition endpoint (`languageCode=bn-BD`).

- [ ] **Step 2: Create floating dictation widget `ufrmVoiceDictate.pas` & `.dfm`**
  Build a translucent floating pill HUD showing microphone volume pulse, listening status ("শুনছি..."), cancel button (`Esc`), and completed status.

- [ ] **Step 3: Integrate with `uForm1.pas` and `uTopBar.pas`**
  - Add "Voice to Text (কণ্ঠস্বর)" to `Popup_Tools` menu.
  - Register global hotkey (`Ctrl+Shift+V` or customizable in Options).
  - Connect microphone button in `uTopBar.pas`.
  - When speech recognition returns text, invoke `KeyboardFunctions.SendKey_Char(RecognizedBanglaText)` to type directly into the focused window.

- [ ] **Step 4: Update `Avro_Keyboard.dproj`**
  Register `uAvroVoice.pas` and `ufrmVoiceDictate.pas` in the main project configuration.

- [ ] **Step 5: Verify memory management and handle cleanup**
  Confirm all waveIn buffers, audio memory blocks, and HTTP sessions are released in `try..finally` blocks.

- [ ] **Step 6: Commit Task 5**
  ```bash
  git add "Keyboard and Spell checker/Units/uAvroVoice.pas" "Keyboard and Spell checker/Forms/ufrmVoiceDictate.pas" "Keyboard and Spell checker/Forms/ufrmVoiceDictate.dfm" "Keyboard and Spell checker/Forms/uForm1.pas" "Keyboard and Spell checker/Forms/uTopBar.pas" "Keyboard and Spell checker/Avro_Keyboard.dproj"
  git commit -m "feat: add native Bangla voice-to-text dictation with direct cursor insertion"
  ```

---

### Task 6: Bangla Punctuation, Math Symbols & Emoji Quick Picker

**Files:**
- Create: `Keyboard and Spell checker/Forms/ufrmSymbolsPicker.pas` & `ufrmSymbolsPicker.dfm`
- Modify: `Keyboard and Spell checker/Forms/uForm1.pas`
- Modify: `Keyboard and Spell checker/Avro_Keyboard.dproj`

**Interfaces:**
- Consumes: Unicode Bangla symbols (Dari `।`, Double Dari `॥`, Taka `৳`, Hasanta `্`, ZWJ `‍`, ZWNJ `‌`, Ishwar `৺`, Khanda Ta `ৎ`) and common emojis
- Produces: `TfrmSymbolsPicker` sending selected glyph directly to active window via `SendKey_Char`

- [ ] **Step 1: Create `ufrmSymbolsPicker.pas` & `.dfm`**
  Build a modern keyboard popup with categorized tabs:
  1. Bangla Punctuation & Diacritics
  2. Currency & Mathematical symbols
  3. Common Emojis
  Support mouse clicks and keyboard arrow navigation.

- [ ] **Step 2: Connect to `uForm1.pas`**
  Add "Bangla Symbols & Emoji Picker" to `Popup_Tools` menu with hotkey `Ctrl+Alt+S`.

- [ ] **Step 3: Update project file `Avro_Keyboard.dproj`**
  Add `ufrmSymbolsPicker.pas` to `Avro_Keyboard.dproj`.

- [ ] **Step 4: Verify symbol encoding and clipboard bypass**
  Confirm symbols are sent directly through `SendKey_Char` without overwriting the user's OS clipboard.

- [ ] **Step 5: Commit Task 6**
  ```bash
  git add "Keyboard and Spell checker/Forms/ufrmSymbolsPicker.pas" "Keyboard and Spell checker/Forms/ufrmSymbolsPicker.dfm" "Keyboard and Spell checker/Forms/uForm1.pas" "Keyboard and Spell checker/Avro_Keyboard.dproj"
  git commit -m "feat: add Bangla symbols, punctuation, and emoji quick picker"
  ```

---

### Task 7: Attribution, Licensing & Documentation Polish

**Files:**
- Modify: `Readme.md`
- Modify: `LICENSE.txt`
- Modify: `Keyboard and Spell checker/Forms/ufrmAbout.pas` & `ufrmAbout.dfm`

**Interfaces:**
- Consumes: MPL 2.0 license terms, OmicronLab credits
- Produces: Updated documentation, contributor credits, and About dialog

- [ ] **Step 1: Update `Readme.md`**
  Add full documentation for:
  - New features: macOS Glass UI skin, Google Spell Check, Voice-to-Text, Symbols/Emoji picker.
  - Headless automated build instructions (`build-portable.bat`, `build-release.ps1`).
  - Upstream pull request guidelines and contribution notes.

- [ ] **Step 2: Update `ufrmAbout.pas` & `ufrmAbout.dfm`**
  Add contributor attribution tab acknowledging original author Dr. Mehdi Hasan Khan (OmicronLab), Jayed Ahsan, frnAlt, and community contributors under MPL 2.0.

- [ ] **Step 3: Verify licensing notices across all modified files**
  Confirm MPL 2.0 headers and `Contributor(s):` lines are properly maintained without modifying original copyright declarations.

- [ ] **Step 4: Commit Task 7**
  ```bash
  git add Readme.md LICENSE.txt "Keyboard and Spell checker/Forms/ufrmAbout.pas" "Keyboard and Spell checker/Forms/ufrmAbout.dfm"
  git commit -m "docs: update readme, contributors, and about dialog conforming to MPL 2.0"
  ```

---

## Plan Self-Review Checklist

1. **Spec Coverage:**
   - macOS Glass UI skin: Task 3
   - Google Spell Checker: Task 4
   - Voice-to-Text (Speech to Text): Task 5
   - Symbols & Emoji picker: Task 6
   - Headless builds & CI/CD workflow: Task 1
   - Upstream issues (caret tracking, DPI, dictionary, tray): Task 2
   - Contributor attribution & MPL 2.0: Task 7
   All requirements mapped 1:1 to tasks.

2. **Step Scan:** Every step specifies exact files, function signatures, APIs, and commit messages.
3. **Type Consistency:** Method signatures (`GoogleSuggestBangla`, `TAvroVoiceEngine`, `SendKey_Char`) are consistent across units.
4. **Review Focus:** Offline fallbacks, timeout handling, memory cleanup, and dictionary safety are explicitly covered in Tasks 2, 4, 5, and 6.
5. **Proportion:** Clear, concise steps focusing on architecture, interfaces, and deliverables.
