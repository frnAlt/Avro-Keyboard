# Avro Keyboard v5.8.0 — Modern Glassmorphism & Hybrid Voice Engine

A modern evolution of the classic **Avro Keyboard for Windows**, featuring Windows 11/10 Acrylic Glassmorphism, a non-blocking 16kHz Bangla Voice Activity Detection (VAD) pipeline, and a Hybrid Speech-to-Text (STT) Engine router.

---

## 🌟 What's New in v5.8.0

### 1. Modern Glassmorphism TopBar Window
* **Windows Acrylic Blur Behind**: Powered by `SetWindowCompositionAttribute` (`ACCENT_ENABLE_ACRYLICBLURBEHIND`) with dark and light mode adaptive translucency.
* **Rounded Pill-Shaped Design**: Native Windows 11 rounded corner preference (`DWMWA_WINDOW_CORNER_PREFERENCE`, `DWMWCP_ROUND`) and GDI+ anti-aliased pill-shape clipping.
* **1px Specular Border**: Clean, translucent border separating the floating bar crisply from any background window or desktop wallpaper.
* **Multi-DPI Scaling & Crisp Icons**: High-DPI screen repositioning and anti-aliased icon rendering on 100%, 125%, 150%, and 200% displays.
* **Idle Auto-Collapse**: Floating bar automatically collapses to a minimal glass pill icon after 10 seconds of idle time, smoothly expanding back when hovered.
* **True Non-Focus Stealing**: Fully enforced `WS_EX_NOACTIVATE` and `WM_MOUSEACTIVATE` (`MA_NOACTIVATE`) so clicking buttons or microphone never strips focus from your active document or code editor.

---

### 2. Next-Gen Bangla Voice Dictation (Talk-to-Text)
* **Non-Blocking Background Audio & VAD**: 16kHz, 16-bit Mono PCM streaming (`winmm.dll`) with energy-based Voice Activity Detection (VAD). Spoken phrases are automatically chunked in real-time without freezing the UI.
* **Live Visual Audio Level Glow**: TopBar glows with a responsive red/coral ring synchronized to speaking volume.
* **Hybrid STT Engine Router**:
  * **Primary (Online)**: Google Speech Recognition API (`bn-BD` / `bn-IN`) for Gboard-grade accuracy.
  * **Fallback (Offline)**: Automatic instant failover to local C-ABI STT DLLs (`libvosk.dll` / `whisper.dll`) using Bangla models in `/models` when disconnected or on timeout.
* **Spoken Bangla Punctuation (`VoiceCommands`)**:
  * "দাঁড়ি" / "দাড়ি" $\rightarrow$ `।`
  * "কমা" $\rightarrow$ `,`
  * "প্রশ্নবোধক" / "জিজ্ঞাসা চিহ্ন" $\rightarrow$ `?`
  * "বিস্ময়সূচক" / "বিস্ময়বোধক" $\rightarrow$ `!`
  * "কোলন" $\rightarrow$ `:`, "সেমিকোলন" $\rightarrow$ `;`
  * "নতুন লাইন" / "নতুন প্যারা" $\rightarrow$ Line break
* **Zero Backspace Desync**: Synchronized buffer resets before and after Unicode injection guarantee seamless transitions between voice typing and manual phonetic typing.

---

### 3. High-Performance Core Architecture
* **Thread-Safe SQLite (WAL Mode)**:
  * Database queries protected by `TCriticalSection`.
  * `PRAGMA journal_mode = WAL;` and `PRAGMA synchronous = NORMAL;` eliminate `SQLITE_BUSY` locking during concurrent lookups.
* **Decoupled Low-Level Keyboard Hook**:
  * `LowLevelKeyboardProc` in `KeyboardHook.pas` dispatches asynchronous Windows messages (`PostMessage`), eliminating hook lag and Windows `LowLevelHooksTimeout` drops.
* **Hardware-Aware PC Scaling**:
  * Auto-detects physical RAM (`GlobalMemoryStatusEx`). Systems with $<4$GB RAM gracefully use lightweight alpha blending.
  * Offline STT engine memory buffers lazy-load and auto-unload after 120 seconds of inactivity to keep idle RAM usage minimal.

---

## 📦 Release Assets & Catalogs

| Artifact | Architecture | Description |
| :--- | :--- | :--- |
| `Avro-Keyboard-v5.8.0-Setup.exe` | Win32 / x64 | Full installer with all fonts and layouts |
| `Avro-Keyboard-v5.8.0-Portable.zip` | Win32 / x64 | Standalone portable zero-install package |
| `SHA256SUMS.txt` | All | Cryptographic checksums for binary verification |

---

## 🛠️ Verification & Checksums
All build binaries are compiled via automated GitHub Actions pipelines with verifiable SHA-256 checksums.
