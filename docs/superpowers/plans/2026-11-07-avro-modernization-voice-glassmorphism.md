# Avro Keyboard Modernization & Voice Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Goal
Perform a comprehensive architectural audit, bug fix, and modernization of Avro Keyboard (Delphi):
1. Fix core focus-stealing (`WS_EX_NOACTIVATE`), low-level hook timeouts (asynchronous dispatch), and buffer synchronization (`ResetKeyBuffer`).
2. Make SQLite (`uDBase.pas`) thread-safe with `WAL` mode, custom `VoiceCommands` and `VoiceUserLexicon` tables, and critical section protection.
3. Build a non-blocking background audio recording & real-time VAD pipeline (16kHz, 16-bit Mono PCM via `winmm.dll`) with energy-based silence threshold chunking.
4. Implement a Hybrid STT Engine router: Google Speech Recognition API (bn-BD) online primary, with seamless fallback to offline C-ABI DLL wrapper (`whisper.cpp` / `libvosk.dll`) and model lazy-loading.
5. Refactor the floating TopBar window (`uTopBar.pas`) to use modern Glassmorphism / Windows Acrylic blur (`SetWindowCompositionAttribute` / `ACCENT_ENABLE_ACRYLICBLURBEHIND`), `DwmSetWindowAttribute` rounded pill corners, 1px translucent specular border, alpha-blended PNG icons, live voice mic indicator & level glow, and idle auto-collapse.
6. Hardware-aware scaling (`GlobalMemoryStatusEx`) with RAM/OS capability detection and idle unloading.
7. Update build and release workflows for the new version.

---

## File Structure

- **Modified Files**:
  - `Keyboard and Spell checker/Forms/uTopBar.pas` & `uTopBar.dfm`: Glassmorphism rendering, Acrylic blur behind, `WS_EX_NOACTIVATE`, PNG icon support, interactive controls, live mic audio level glow, idle collapse.
  - `Keyboard and Spell checker/Units/KeyboardHook.pas`: Decoupled asynchronous message posting, hook safety.
  - `Keyboard and Spell checker/Units/KeyboardFunctions.pas`: `SendUnicodeString`, `ResetAllKeyBuffers`, hook synchronization.
  - `Keyboard and Spell checker/Units/uDBase.pas`: Thread-safe SQLite database with WAL mode, `TCriticalSection`, `VoiceCommands`, and `VoiceUserLexicon`.
  - `Keyboard and Spell checker/Units/uAvroVoice.pas`: Non-blocking audio capture, real-time VAD silence chunking, Hybrid STT Engine (Google online + offline C-ABI DLL), hardware-aware lifecycle.
  - `Keyboard and Spell checker/Forms/ufrmVoiceDictate.pas`: Modernized dictation overlay, seamless non-focus stealing.
  - `Keyboard and Spell checker/Units/WindowsVersion.pas` / `WindowsDarkMode.pas`: Extended OS detection, hardware capability detection (`GlobalMemoryStatusEx`).
  - `build-release.ps1` & `.github/workflows/build-release.yml`: Release workflow and version bump.

- **New Files**:
  - `Keyboard and Spell checker/Units/uGlassmorphism.pas`: Dedicated Windows Acrylic (`SetWindowCompositionAttribute`), DWM rounded corners, and GDI+ glass drawing utilities.
  - `Keyboard and Spell checker/Units/uOfflineSTTWrapper.pas`: C-ABI loader and interface for `whisper.dll` / `libvosk.dll` with lazy-loading and 120s auto-unloading.
  - `Keyboard and Spell checker/Units/uVoiceLexicon.pas`: Spoken punctuation normalization (`VoiceCommands`) and user corrections.

---

## Tasks

### Task 1: Fix Core Focus Stealing and Hook/Buffer Synchronization
- [x] Implement `WS_EX_NOACTIVATE` and `WM_MOUSEACTIVATE` handling in `uTopBar.pas` and `uWindowHandlers.pas`.
- [x] Decouple `KeyboardHook.pas` from heavy UI calls using `PostMessage`.
- [x] Implement `ResetAllKeyBuffers` in `KeyboardFunctions.pas` and wire before/after voice text injection.

### Task 2: Thread-Safe SQLite & Voice Lexicon Integration
- [x] Upgrade `uDBase.pas` with `TCriticalSection` protecting all SQLite access.
- [x] Configure `PRAGMA journal_mode = WAL;` and `PRAGMA synchronous = NORMAL;`.
- [x] Implement `VoiceCommands` table (mapping spoken punctuation: 'দাঁড়ি' -> '।', 'কমা' -> ',', 'প্রশ্নবোধক' -> '?', etc.) and `VoiceUserLexicon`.

### Task 3: Background Audio Recording, VAD & Hybrid STT Engine
- [x] Implement non-blocking multi-buffer audio capture (16kHz 16-bit Mono PCM via `winmm.dll`).
- [x] Implement RMS-based Voice Activity Detection (VAD) with silence threshold chunking.
- [x] Implement Google bn-BD online STT engine with proper buffer safety (fixing `TBytes` casting).
- [x] Implement `uOfflineSTTWrapper.pas` for offline C-ABI engine fallback.
- [x] Implement hardware detection (`GlobalMemoryStatusEx`) and 120s idle auto-unloading.

### Task 4: Modern Glassmorphism Floating TopBar Window
- [x] Create `uGlassmorphism.pas` with `SetWindowCompositionAttribute` (`ACCENT_ENABLE_ACRYLICBLURBEHIND`) and DWM corner preferences.
- [x] Refactor `uTopBar.pas` to render pill-shaped glass container with 1px translucent border and alpha-blended PNG icons.
- [x] Add mic control, live audio-level glow/pulse, accent selector (bn-BD/bn-IN), and auto-collapse on idle.

### Task 5: Workflow, Release Scripts & Packaging
- [x] Update `build-release.ps1` version from 5.7.0 to 5.8.0.
- [x] Update `.github/workflows/build-release.yml` defaults and artifact packaging.
- [x] Verify clean compilation and syntax integrity across all units.
