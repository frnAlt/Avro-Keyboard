# 🚀 Avro Keyboard — Download, Installation & Build Guide

> **Important**: If you ran an existing `Avro Keyboard.exe` and did **not** see the new features (Acrylic Glassmorphism floating TopBar, Google-style phonetic candidate bar, Voice-to-Text dictation, or Google Translator), read **Section 1** below first. Avro Keyboard is a compiled native Windows binary; modifying source code requires either downloading the pre-built release package from GitHub or compiling with Delphi.

---

## 📑 Table of Contents
1. [Why "Avro Keyboard.exe" Did Not Show Changes](#1-why-avro-keyboardexe-did-not-show-changes)
2. [Option 1: Download Pre-Built Release (Easiest — No Setup Needed)](#2-option-1-download-pre-built-release-easiest--no-setup-needed)
3. [Option 2: Trigger GitHub Actions to Build & Download Latest Binary](#3-option-2-trigger-github-actions-to-build--download-latest-binary)
4. [Option 3: Compile Locally from Source Code (Delphi RAD Studio)](#4-option-3-compile-locally-from-source-code-delphi-rad-studio)
5. [Feature Verification Checklist](#5-feature-verification-checklist)
6. [Troubleshooting & FAQs](#6-troubleshooting--faqs)

---

## 1. Why "Avro Keyboard.exe" Did Not Show Changes

Avro Keyboard is written in **Embarcadero Delphi (Object Pascal)** and compiles directly into native Windows x86 machine code (`Avro Keyboard.exe`).

* **Source Files vs. Compiled Executables**: Modifying source files (`.pas`, `.dfm`) does **not** change any `.exe` file sitting in your folders until the project is recompiled by Delphi's compiler (`dcc32.exe` / MSBuild).
* **Running Old OmicronLab Binary**: If you double-clicked an older installed `Avro Keyboard.exe` (such as legacy version 5.6.0 from 2019) or ran `build-release.ps1` without Delphi installed, Windows executed the old 2019 base binary.
* **Background Process Lock**: If an old instance of Avro Keyboard was already running in your Windows System Tray (near the clock), launching another instance would either display the dialog *"Avro Keyboard is already running on this system"* or silently bring the old instance to the foreground.

```
                    ┌───────────────────────────────┐
                    │  Source Code Changes (.pas)   │
                    │   - Acrylic Glassmorphism     │
                    │   - Candidate Selection Bar   │
                    │   - Voice Dictation & STT     │
                    │   - Realtime Google Translate │
                    └──────────────┬────────────────┘
                                   │
                    Must be COMPILED via Delphi
                                   │
               ┌───────────────────┴───────────────────┐
               ▼                                       ▼
  GitHub Actions Cloud Build             Local Delphi RAD Studio
 (Automated CI/CD Windows Runner)      (Shift+F9 or build-release.ps1)
               │                                       │
               └───────────────────┬───────────────────┘
                                   ▼
                   ┌───────────────────────────────┐
                   │ Fresh "Avro Keyboard.exe"     │
                   │ (Contains ALL modern features)│
                   └───────────────────────────────┘
```

---

## 2. Option 1: Download Pre-Built Release (Easiest — No Setup Needed)

You do **not** need to install Delphi or compile code to use the modern features. You can download the pre-compiled portable zip directly from GitHub.

### Step-by-Step Instructions:
1. Open the repository on GitHub: **[Avro Keyboard Repository](https://github.com/mugli/Avro-Keyboard)**.
2. In the right-hand sidebar, click on **Releases** (or navigate to `https://github.com/mugli/Avro-Keyboard/releases`).
3. Under the latest release (e.g. `v5.8.0` or latest tag), download:
   * **`Avro-Keyboard-v5.8.0-Portable.zip`** (Zero installation, extract and run)
4. Extract the `.zip` archive into a folder of your choice (e.g., `C:\AvroKeyboard\` or your Desktop).
5. **Close any old running Avro Keyboard**:
   * Right-click the Avro icon in the Windows Taskbar System Tray (near the clock) and select **Exit**, **OR**
   * Open Command Prompt / PowerShell and run:
     ```cmd
     taskkill /F /IM "Avro Keyboard.exe"
     ```
6. Open the extracted folder and double-click **`Avro Keyboard.exe`**.
7. Enjoy the modern Glassmorphism TopBar, Voice Dictation, Candidate Bar, and Google Translator!

---

## 3. Option 2: Trigger GitHub Actions to Build & Download Latest Binary

If you want the absolute latest code directly from the `modernize-avro` branch, you can trigger the automated GitHub Actions workflow to compile it in the cloud.

### Step-by-Step Instructions:
1. Navigate to your repository on GitHub.
2. Click on the **Actions** tab at the top.
3. In the left workflow list, select **"Build & Release Avro Keyboard"**.
4. Click the **"Run workflow"** button on the right side.
5. Configure the run parameters:
   * **Use workflow from**: Branch `modernize-avro`
   * **Version Bump Strategy**: `auto` (or `patch`)
   * **Build Configuration**: `Release`
   * **Build Platform**: `Win32`
   * **Publish as GitHub Release**: `true`
6. Click the green **"Run workflow"** button.
7. The GitHub runner will spin up a fresh Windows virtual machine, compile all projects, run asset bundling, tag the repository, and publish the release.
8. Once completed (about 2–3 minutes):
   * Download the generated **`Avro-Keyboard-Binaries-v...`** artifact from the workflow run, or
   * Go to the **Releases** page to download the newly published `Avro-Keyboard-v5.8.0-Portable.zip`.

---

## 4. Option 3: Compile Locally from Source Code (Delphi RAD Studio)

If you are a developer and wish to compile the binaries locally on your own Windows computer:

### Prerequisites:
* **Operating System**: Windows 10 or Windows 11 (64-bit or 32-bit).
* **Delphi IDE**: Embarcadero Delphi Community Edition (12 Athens, 11 Alexandria, or 10.4 Sydney).
  * [Download Delphi Community Edition for Free](https://www.embarcadero.com/products/delphi/starter/free-download)
* **Git for Windows**: To clone the repository.

---

### Method A: Build via Delphi IDE (Visual GUI)

1. **Clone the repository**:
   ```bash
   git clone -b modernize-avro https://github.com/mugli/Avro-Keyboard.git
   cd Avro-Keyboard
   ```
2. **Open the project**:
   * Launch **Embarcadero Delphi**.
   * Go to `File > Open Project...`.
   * Navigate to the project root and select **`WholeProject.groupproj`** (or select `Keyboard and Spell checker\Avro_Keyboard.dproj`).
3. **Configure the target**:
   * In the Delphi **Project Manager** window (top-right):
   * Expand **`Avro_Keyboard.exe`**.
   * Set **Target Platforms** to `32-bit Windows (Win32)`.
   * Set **Build Configurations** to `Release`.
4. **Compile & Build**:
   * From the top menu, select `Project > Build All Projects` (or press `Shift + F9`).
   * The compiler will generate the updated binary in `build\Avro Keyboard.exe`.
5. Run the new `build\Avro Keyboard.exe`.

---

### Method B: Headless Command-Line Build (PowerShell Script)

You can run our automated headless build script without opening the Delphi graphical editor:

1. Open PowerShell in the project root directory.
2. Run:
   ```powershell
   .\build-release.ps1 -Configuration Release -Platform Win32
   ```
3. The script will:
   * Auto-detect your Embarcadero Delphi installation (`rsvars.bat`).
   * Compile `WholeProject.groupproj` using `msbuild.exe`.
   * Normalize binary names to `Avro Keyboard.exe`, `Avro Spell Checker.exe`, `Layout Editor.exe`, etc.
   * Bundle all skins (including `macOS Glass.avroskin` and `macOS Glass Dark.avroskin`), keyboards, and phonetic candidate dictionaries.
   * Create `build\Avro-Keyboard-Portable.zip`.
4. Run `build\Avro Keyboard.exe`.

---

## 5. Feature Verification Checklist

Once you run the compiled `Avro Keyboard.exe`, verify all modern upgrades:

| Feature | How to Test & Verify | Expected Result |
| :--- | :--- | :--- |
| **Windows 11 Acrylic Glassmorphism** | Launch Avro Keyboard. Check the floating TopBar. | Translucent frosted glass effect (`ACCENT_ENABLE_ACRYLICBLURBEHIND`) with rounded corners and modern SVG vector icons. |
| **Skin Switcher (Light / Dark)** | Click the Palette / Skin icon on the floating TopBar $\rightarrow$ Select `macOS Glass` or `macOS Glass Dark`. | TopBar dynamically changes between translucent frosted light and dark glass. |
| **Phonetic Candidate Bar** | Switch Avro to Bangla mode (`F12`). Type casual English like `kemon`, `valo`, `bhalo`, `acho`, `dhonnobad`. | A horizontal frosted glass candidate strip pops up with numbered suggestions (`[1] কেমন`, `[2] ...`). |
| **Number Key Selection** | While candidate bar is visible, press `1`, `2`, or `3` (or click candidate chip). | The chosen candidate is instantly committed into your document. |
| **Bangla Voice Dictation** | Click the **Microphone icon** on the floating TopBar or press `Ctrl + Shift + V`. | TopBar shows live audio input glow. Speak Bangla phrases; text is typed into the cursor position in real time. |
| **Realtime Google Translator** | Click the **Translate icon** or press `Ctrl + Shift + T`. | Dual-pane translator window opens. Type English to get Bangla or vice-versa with instant copy/insert. |
| **Single-Instance Safety** | Launch `Avro Keyboard.exe` a second time while it is already open. | Instead of crashing or showing an error dialog, the existing floating TopBar smoothly animates to the foreground. |

---

## 6. Troubleshooting & FAQs

### Q1: I get the error: *"Avro Keyboard is already running on this system"*
* **Cause**: An old instance of Avro Keyboard is still running in the background.
* **Fix**:
  1. Check your Windows System Tray (bottom-right near the clock, click the little `^` arrow).
  2. Right-click the **Avro Keyboard** icon and click **Exit**.
  3. Alternatively, open Command Prompt as Administrator and run:
     ```cmd
     taskkill /F /IM "Avro Keyboard.exe"
     ```
  4. Now start the new `Avro Keyboard.exe`.

---

### Q2: Why did `build-release.ps1` say *"Embarcadero BDS not detected"*?
* **Cause**: Delphi (RAD Studio) is not installed on your local computer.
* **Fix**:
  * You do not need to install Delphi! Simply follow **[Section 2: Download Pre-Built Release](#2-option-1-download-pre-built-release-easiest--no-setup-needed)** to download the ready-to-run package built by GitHub Actions.
  * If you wish to build locally, download the free [Delphi Community Edition](https://www.embarcadero.com/products/delphi/starter/free-download).

---

### Q3: Windows SmartScreen shows *"Windows protected your PC"*
* **Cause**: The freshly compiled binary is newly generated and does not have an expensive commercial code-signing certificate.
* **Fix**: Click **"More info"** $\rightarrow$ Click **"Run anyway"**.

---

### Q4: Bangla characters look broken or show boxes (tofu)
* **Cause**: Your Windows system is missing high-quality Bangla OpenType fonts.
* **Fix**:
  1. Open the `assets/` folder in the project or portable package.
  2. Double-click `Kalpurush.ttf` or `Siyamrupali.ttf`.
  3. Click **Install** (or right-click $\rightarrow$ **Install for all users**).
