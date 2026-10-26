# Avro Keyboard Modernization & Upstream PR Specification

**Date:** 2026-10-26  
**Status:** Draft / Review  
**Target Repository:** `mugli/Avro-Keyboard` (via `frnAlt/Avro-Keyboard`)  
**License:** Mozilla Public License 2.0 (MPL 2.0)

---

## 1. Intent & Purpose

Avro Keyboard is the preeminent open-source Unicode Bengali typing software for Microsoft Windows, created by Dr. Mehdi Hasan Khan (OmicronLab). 

This design specifies a non-breaking, modern upgrade that brings Avro Keyboard into modern desktop parity while keeping 100% fidelity with the upstream repository (`mugli/Avro-Keyboard`). The upgrades include:
1. A modern, translucent macOS-inspired frosted glass UI skin (`macOS Glass.avroskin`) with crisp high-resolution iconography.
2. Voice-to-Text (কণ্ঠস্বর / Speech-to-Text) dictation in Bengali (`bn-BD` / `bn-IN`) streaming text directly into active windows.
3. Google Spell Checker / Online Suggestion engine integrated into the Avro Spell Checker as a hybrid provider alongside the offline dictionary.
4. Modern productivity touches: Bangla punctuation/symbol picker (Dari ৷, Taka ৳, Hasanta, ZWJ/ZWNJ) and quick emoji access.
5. Production CI/CD automation via GitHub Actions to compile Delphi 12 projects headlessly with MSBuild, package portable and installer assets, and publish GitHub Releases.
6. Clean Contributor attribution conforming strictly to MPL 2.0 guidelines.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- **Zero Regressions:** 100% preservation of core typing logic: keyboard hook (`KeyboardHook.pas`), phonetic translation rules (`clsEnglishToBangla.pas`, `clsAvroPhonetic.pas`), and fixed layouts (`Probhat`, `National/Jatiya`, `Bornona`, `Avro Easy`).
- **Seamless Upstream Merging:** Modular, clean code commits that can be split into individual, reviewable pull requests for upstream maintainers.
- **Modern Look & Feel:** A floating macOS-style translucent frosted-glass TopBar that feels lightweight, beautiful, and native on Windows 10/11.
- **Offline Reliability:** Avro must remain fully functional offline. Any cloud/online features (Google Speech, Google Spell Check) must gracefully degrade without throwing errors or interrupting typing.
- **Headless Build Automation:** A fully automated `.github/workflows/build-release.yml` that builds all projects in `WholeProject.groupproj` on GitHub Actions and publishes GitHub Releases.

### Non-Goals
- Complete codebase rewrite to another language (e.g. Electron, Flutter, C#/.NET) - the project remains native Embarcadero Delphi 12 VCL to maintain ultra-low latency, low memory footprint, and complete Windows IME compatibility.
- Modifying or removing any legacy layouts, skins, or user configuration registries.

### Anti-Goals
- **No Keystroke Lag:** Under no circumstances should cloud/network calls occur synchronously in the typing hook or keyboard message loop.
- **No Monolithic Bloat:** No massive external binaries or multi-gigabyte runtimes; integrations rely on lightweight Windows APIs and modular Delphi units.

---

## 3. Architecture & Modular Breakdown

### 3.1. Modern macOS Glass Skin (`macOS Glass.avroskin`)
Avro Keyboard has a built-in XML-based skin layout engine (`clsSkinLayoutConverter.pas` / `uTopBar.pas`).

**Skin Architecture:**
- **Container:** `assets/skins/macOS Glass.avroskin`
- **Visuals:**
  - Background: Translucent frosted glass gradient with subtle drop-shadow and rounded capsule/pill contours (8px border radius).
  - High-contrast, clean icons for:
    - Avro Logo (Globe / 'অ')
    - Keyboard Mode toggle (Bangla / English pill with glowing accent indicator)
    - Layout selector dropdown
    - Layout Viewer
    - Avro Mouse
    - Tools menu
    - Voice-to-Text mic trigger
    - Help / About
    - Minimize / Close
  - Each button provides high-resolution 32-bit alpha-channel bitmaps for `Normal`, `Over` (hover), and `Down` (active) states.
- **Compatibility:** Backward compatible with all existing skins (`Avro Classic`, `Aero7 dark`, `Avro Flat`, `iAvro`).

---

### 3.2. Voice-to-Text (কণ্ঠস্বর - Speech to Text)

**Mechanism:**
- Triggered either via:
  1. The microphone icon on the topbar.
  2. Global hotkey (configurable, default `Ctrl+Shift+V` or `Win+Alt+B`).
- **Speech Capture & Transcription:**
  - Modular background worker (`uAvroVoice.pas`).
  - Records audio via standard Windows MMDevice / waveIn API in 16kHz mono PCM.
  - Asynchronously dispatches audio frames to Google Speech-to-Text REST API (`languageCode=bn-BD` / `bn-IN`) or Windows Speech Synthesis/Recognition.
  - On transcription receipt, injects the decoded Bangla text directly into the focused window using Avro's existing `KeyboardFunctions.SendKey_Char(UnicodeString)`.
- **UI:** A subtle, non-intrusive floating audio waveform / pulsing indicator pill showing listening status, with an instant cancel button (`Esc`).

---

### 3.3. Google Spell Checker / Online Suggestions

**Mechanism:**
- Integrated into `AvroSpell.dll` and `Avro_Spell_Checker.exe`.
- **Hybrid Provider (`uSpellGoogleSearch.pas`):**
  - Offline lookup: Queries local SQLite dictionary (`Database.db3`) and `autodict.dct` first.
  - Online lookup: If the word is unrecognized and "Enable Online Suggestions" is active, queries the Google Bengali suggestion API asynchronously.
  - Deduplicates and sorts suggestions by phonetic distance (`uSimilarSort_Spell.pas`).
- **Failure Handling:** If the network request times out (>1.5s) or fails, the spell checker seamlessly displays local suggestions with zero UI stutter.

---

### 3.4. Bangla Symbols & Emoji Quick Picker

- Accessible from the Tools menu and via hotkey (`Ctrl+Alt+S`).
- Displays a clean popup grid with:
  - Common Bangla punctuation: Dari (`।`), Double Dari (`॥`), Taka (`৳`), Ishwar sign (`৺`), Hasanta (`্`), ZWNJ (`‌`), ZWJ (`‍`).
  - Commonly used emojis categorized into smileys, gestures, and symbols.
- Clicking any character immediately dispatches it via `SendKey_Char` into the active application.

---

### 3.5. Automated GitHub Actions CI/CD (`build-release.yml`)

**Workflow Specifications:**
- **Trigger:** On push to `master`, pull request, and version tags (`v*`).
- **Runner:** `windows-latest`.
- **Steps:**
  1. Checkout repository with full history.
  2. Install / setup Embarcadero Delphi command-line tools / MSBuild environment.
  3. Compile all projects:
     - `Keyboard and Spell checker\Avro_Keyboard.dproj`
     - `Keyboard and Spell checker\SpellChecker\AvroSpell.dproj`
     - `Keyboard and Spell checker\SpellChecker\Avro_Spell_Checker.dproj`
     - `Layout Editor\LayoutEditor.dproj`
     - `Skin Designer\SkinDesigner.dproj`
     - `Unicode to ascii converter\Unicode_to_Bijoy.dproj`
  4. Collect output binaries into `build/` directory with proper release names (`Avro Keyboard.exe`, `Avro Spell Checker.exe`, `AvroSpell.dll`, etc.).
  5. Package standalone zip (`Avro-Keyboard-vX.Y.Z-Portable.zip`) and installer assets.
  6. On tag push: create automated GitHub Release with SHA256 checksums and release notes.

---

### 3.6. Author Attribution & MPL 2.0 Compliance

- All files retain original copyright:
  `Copyright (C) OmicronLab (https://www.omicronlab.com). All Rights Reserved.`
- Contributor section updated:
  `Contributor(s): frnAlt, Antigravity AI, and community contributors.`
- `ufrmAbout.pas` updated with clean contributor tab and version notes without modifying original credits.
- `Readme.md` updated with compilation instructions, feature guide, and workflow status badge.

---

### 3.7. Community Issue Fixes (Aligned with Upstream Logic)

Addressing key open issues from `mugli/Avro-Keyboard/issues`:
1. **Issue #98 (Automated Portable & Release Build):** Add headless automated PowerShell and batch compilation scripts (`build-portable.bat`, `build-release.ps1`) that discover MSBuild / Delphi installations and build without IDE interaction.
2. **Issue #114 (Dynamic Cursor Caret Tracking):** Refine caret tracking in `uWindowHandlers.pas` so the phonetic suggestion window dynamically follows the text cursor across modern multi-DPI and Chromium/Electron apps.
3. **Issue #109 (Multi-Monitor & DPI Scaling):** Enhance TopBar and popup scaling when dragged between screens with differing DPI ratios (100% vs 125% vs 150%).
4. **Issue #93 (System Tray Minimize Hint):** Provide clean, non-intrusive balloon notification on Windows 10/11 when Avro is minimized to tray.
5. **Issue #97 (User Dictionary Preservation):** Ensure user-defined words (`autodict.dct` and custom dictionary) are never overwritten during new releases or portable runs.

---

## 4. Upstream PR Strategy

To ensure seamless merging into `mugli/Avro-Keyboard`:
1. **Branch 1: `ci/github-actions-build`** - Adds `.github/workflows/build-release.yml` and headless build scripts (Issue #98).
2. **Branch 2: `fix/cursor-tracking-and-dpi`** - Caret tracking and DPI scaling fixes (Issues #114, #109, #93).
3. **Branch 3: `feat/macos-glass-skin`** - Adds `assets/skins/macOS Glass.avroskin` and high-DPI assets.
4. **Branch 4: `feat/google-spell-checker`** - Adds `uSpellGoogleSearch.pas` and hybrid options.
5. **Branch 5: `feat/voice-to-text`** - Adds `uAvroVoice.pas` and topbar/menu integration.
6. **Branch 6: `feat/symbols-emoji-picker`** - Adds Bangla symbols and emoji quick picker.
Each branch is strictly isolated, cleanly formatted with `Formatter_Profile.config`, and tested for zero regressions before creating PRs.
