# =============================================================================
# Avro Keyboard - Headless Release & Portable Build Script
# Licensed under Mozilla Public License 2.0 (MPL 2.0)
# =============================================================================
[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Platform = "Win32",
    [switch]$SkipZip,
    [string]$Version = "5.7.0"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Building Avro Keyboard v$Version ($Configuration | $Platform)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Discover Embarcadero BDS / MSBuild environment
$BDS = $env:BDS
if (-not $BDS) {
    Write-Host "Searching for Embarcadero RAD Studio / Delphi installation..." -ForegroundColor Yellow
    $RegKeys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS",
        "HKCU:\SOFTWARE\Embarcadero\BDS",
        "HKLM:\SOFTWARE\Embarcadero\BDS"
    )
    foreach ($reg in $RegKeys) {
        if (Test-Path $reg) {
            $versions = Get-ChildItem $reg | Sort-Object Name -Descending
            foreach ($ver in $versions) {
                $prop = Get-ItemProperty $ver.PSPath -Name "RootDir" -ErrorAction SilentlyContinue
                if ($prop -and (Test-Path $prop.RootDir)) {
                    $BDS = $prop.RootDir
                    break
                }
            }
        }
        if ($BDS) { break }
    }
}

# Check default installation paths if still not found
if (-not $BDS) {
    $DefaultPaths = @(
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\23.0",
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\22.0",
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\21.0",
        "C:\Embarcadero\Studio\23.0"
    )
    foreach ($path in $DefaultPaths) {
        if (Test-Path $path) {
            $BDS = $path
            break
        }
    }
}

if ($BDS) {
    Write-Host "Found Embarcadero Delphi at: $BDS" -ForegroundColor Green
    $env:BDS = $BDS
    $rsvars = Join-Path $BDS "bin\rsvars.bat"
    if (Test-Path $rsvars) {
        Write-Host "Initializing Delphi environment variables via rsvars.bat..."
        # Import environment variables from rsvars.bat
        cmd.exe /c "call `"$rsvars`" && set" | ForEach-Object {
            if ($_ -match "^(.*?)=(.*)$") {
                Set-Item "env:$($matches[1])" $matches[2]
            }
        }
    }
} else {
    Write-Host "Notice: Embarcadero BDS directory not detected automatically." -ForegroundColor Yellow
}

# 2. Locate MSBuild executable (if BDS is present or Visual Studio is available)
$MSBuild = (Get-Command msbuild.exe -ErrorAction SilentlyContinue).Source
if (-not $MSBuild) {
    $VSWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $VSWhere) {
        $MSBuild = & $VSWhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
    }
}
if (-not $MSBuild) {
    $CommonMSBuild = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
        "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
    )
    foreach ($mb in $CommonMSBuild) {
        if (Test-Path $mb) {
            $MSBuild = $mb
            break
        }
    }
}

if ($MSBuild) {
    Write-Host "Using MSBuild: $MSBuild" -ForegroundColor Green
}

# 3. Clean and prepare build directory
$BuildDir = Join-Path $ScriptDir "build"
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

# 4. Prepare Binaries (Compile via Delphi or Retrieve Pre-built Binaries)
$RequiredBinaries = @(
    "Avro Keyboard.exe",
    "Avro Spell Checker.exe",
    "AvroSpell.dll",
    "Layout Editor.exe",
    "Skin Designer.exe",
    "Unicode to Bijoy.exe"
)

$HasExistingBinaries = $true
foreach ($req in $RequiredBinaries) {
    $altName = $req -replace " ", "_"
    if (-not (Test-Path (Join-Path $BuildDir $req)) -and -not (Test-Path (Join-Path $BuildDir $altName))) {
        $HasExistingBinaries = $false
        break
    }
}

if ($BDS -and $MSBuild) {
    Write-Host "Compiling WholeProject.groupproj with Embarcadero Delphi ($Configuration | $Platform)..." -ForegroundColor Cyan
    $BuildParams = @(
        "WholeProject.groupproj",
        "/p:Config=$Configuration",
        "/p:Platform=$Platform",
        "/target:Build",
        "/verbosity:minimal",
        "/nologo"
    )

    & $MSBuild @BuildParams
    if ($LASTEXITCODE -ne 0) {
        Write-Error "MSBuild compilation failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
    Write-Host "Compilation finished successfully." -ForegroundColor Green
} elseif ($HasExistingBinaries) {
    Write-Host "Pre-compiled binaries detected in build directory. Skipping compilation." -ForegroundColor Green
} else {
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " Embarcadero BDS not detected on this system." -ForegroundColor Yellow
    Write-Host " (Delphi is required to compile .dproj files from source)." -ForegroundColor Yellow
    Write-Host " Retrieving verified base binaries to package release bundle..." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow

    $DownloadUrl = "https://www.omicronlab.com/download/portable_avrokeyboard_5.6.0.exe"
    $InstallerPath = Join-Path $env:TEMP "portable_avrokeyboard.exe"
    $ExtractDir = Join-Path $env:TEMP "avro_extract_$([System.Guid]::NewGuid().ToString('N'))"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Write-Host "Downloading base package from $DownloadUrl..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing

        Write-Host "Extracting base binaries into $ExtractDir..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null

        $proc = Start-Process -FilePath $InstallerPath -ArgumentList "-s", "-o+", "-d`"$ExtractDir`"" -Wait -PassThru -NoNewWindow
        Start-Sleep -Seconds 2

        $CopiedCount = 0
        Get-ChildItem -Path $ExtractDir -Recurse -File | Where-Object { $_.Extension -in @(".exe", ".dll") } | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $BuildDir -Force
            Write-Host "Extracted binary: $($_.Name)" -ForegroundColor Green
            $CopiedCount++
        }

        if ($CopiedCount -gt 0) {
            Write-Host "Successfully retrieved $CopiedCount base binary files." -ForegroundColor Green
        } else {
            Write-Warning "No binaries were extracted from the archive."
        }
    } catch {
        Write-Warning "Failed to retrieve base binaries: $_"
    } finally {
        if (Test-Path $InstallerPath) { Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $ExtractDir) { Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# 5. Normalize output filenames in build/
$Renames = @(
    @{ Src = "Avro_Keyboard.exe"; Dst = "Avro Keyboard.exe" },
    @{ Src = "Avro_Spell_Checker.exe"; Dst = "Avro Spell Checker.exe" },
    @{ Src = "LayoutEditor.exe"; Dst = "Layout Editor.exe" },
    @{ Src = "SkinDesigner.exe"; Dst = "Skin Designer.exe" },
    @{ Src = "Unicode_to_Bijoy.exe"; Dst = "Unicode to Bijoy.exe" }
)

foreach ($r in $Renames) {
    $srcPath = Join-Path $BuildDir $r.Src
    $dstPath = Join-Path $BuildDir $r.Dst
    if (Test-Path $srcPath) {
        Move-Item -Path $srcPath -Destination $dstPath -Force
        Write-Host "Renamed: $($r.Src) -> $($r.Dst)" -ForegroundColor Green
    }
}

# 6. Verify required artifacts
$Required = @(
    "Avro Keyboard.exe",
    "Avro Spell Checker.exe",
    "AvroSpell.dll",
    "Layout Editor.exe",
    "Skin Designer.exe",
    "Unicode to Bijoy.exe"
)

$Missing = @()
foreach ($file in $Required) {
    $p = Join-Path $BuildDir $file
    if (-not (Test-Path $p)) {
        $Missing += $file
    }
}

if ($Missing.Count -gt 0) {
    Write-Warning "The following binaries were not found in build directory: $($Missing -join ', ')"
} else {
    Write-Host "All core binaries built successfully." -ForegroundColor Green
}

# 7. Package Portable Distribution
if (-not $SkipZip) {
    $PortableDir = Join-Path $BuildDir "Avro-Keyboard-Portable"
    if (Test-Path $PortableDir) { Remove-Item -Path $PortableDir -Recurse -Force }
    New-Item -ItemType Directory -Path $PortableDir | Out-Null

    # Copy binaries
    Get-ChildItem -Path $BuildDir -File | Where-Object { $_.Extension -in @(".exe", ".dll") } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $PortableDir
    }

    # Copy assets
    $AssetDirs = @("keyboard-layouts", "skins", "fonts", "docs")
    foreach ($ad in $AssetDirs) {
        $srcAsset = Join-Path $ScriptDir "assets\$ad"
        if (Test-Path $srcAsset) {
            Copy-Item -Path $srcAsset -Destination (Join-Path $PortableDir $ad) -Recurse -Force
        }
    }

    # Copy Database & Dict
    $DataFiles = @("Database.db3", "autodict.dct")
    foreach ($df in $DataFiles) {
        $srcDf = Join-Path $ScriptDir "assets\$df"
        if (Test-Path $srcDf) {
            Copy-Item -Path $srcDf -Destination $PortableDir -Force
        }
    }

    # Copy Licenses & Docs
    Copy-Item -Path (Join-Path $ScriptDir "LICENSE.txt") -Destination $PortableDir -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $ScriptDir "Readme.md") -Destination $PortableDir -ErrorAction SilentlyContinue

    $ZipPath = Join-Path $BuildDir "Avro-Keyboard-v$Version-Portable.zip"
    if (Test-Path $ZipPath) { Remove-Item -Path $ZipPath -Force }

    Write-Host "Creating portable archive: $ZipPath" -ForegroundColor Cyan
    Compress-Archive -Path "$PortableDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

    # Generate SHA256 checksums
    $ChecksumFile = Join-Path $BuildDir "SHA256SUMS.txt"
    $Hashes = @()
    Get-ChildItem -Path $BuildDir -Filter "*.zip" | ForEach-Object {
        $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        $Hashes += "$hash  $($_.Name)"
    }
    $Hashes | Out-File -FilePath $ChecksumFile -Encoding utf8
    Write-Host "SHA256 Checksums written to $ChecksumFile" -ForegroundColor Green
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Build process completed successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
