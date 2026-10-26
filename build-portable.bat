@echo off
rem =============================================================================
rem Avro Keyboard - Portable One-Click Build Script
rem Licensed under Mozilla Public License 2.0 (MPL 2.0)
rem =============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0"
echo ==========================================================
echo Starting Avro Keyboard Automated Build...
echo ==========================================================

rem Check for PowerShell
where powershell >nul 2>nul
if %errorlevel% equ 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-release.ps1" %*
    exit /b %errorlevel%
)

echo PowerShell not found. Attempting direct MSBuild compilation...
if not defined BDS (
    if exist "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" (
        call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
    ) else if exist "C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat" (
        call "C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat"
    )
)

msbuild WholeProject.groupproj /p:Config=Release /target:Build /nologo
if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %errorlevel%
)

echo [SUCCESS] Build completed. Check build\ directory.
exit /b 0
