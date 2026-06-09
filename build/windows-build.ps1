<#
.SYNOPSIS
    Build GuineaMPEG for Windows.

.DESCRIPTION
    Builds GuineaMPEG from source with vendored dependencies.
    Requires `build/vendor/mpv-dev-x86_64/` and `build/vendor/ffmpeg/`. 
    Run `build\download-vendor.ps1` to fetch these if missing.

.PARAMETER Package
    Create portable ZIP and InnoSetup installer after building.

.PARAMETER Config
    Build configuration: Release (default) or RelWithDebInfo.

.PARAMETER OutputDir
    Output directory (default: out/windows).

.PARAMETER QtDir
    Path to Qt installation (auto-detected if omitted).

.PARAMETER Clean
    Remove output directory and Rust build artifacts before building.

.PARAMETER Release
    Strip debug info from the final binary for a release build (smaller size).

.EXAMPLE
    .\build\windows-build.ps1

.EXAMPLE
    .\build\windows-build.ps1 -Config RelWithDebInfo

.EXAMPLE
    .\build\windows-build.ps1 -Package
#>

param(
    [switch]$Package,
    [ValidateSet("Release", "RelWithDebInfo")]
    [string]$Config = "Release",
    [string]$OutputDir = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "out") "windows"),
    [string]$QtDir = "",
    [switch]$Clean,
    [switch]$Console,
    [switch]$Release,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
GuineaMPEG Windows Build Script
===============================

Builds GuineaMPEG from source. Handles the full pipeline:
  - Configures with CMake (MSVC + Ninja)
  - Builds Rust library (cargo) and C++ app
  - Deploys Qt DLLs (windeployqt)
  - Copies mpv and Rust DLLs
  - Bundles ffmpeg for transcoding

Usage:
  .\build\windows-build.ps1 [options]

Options:
  -Config <type>     Build config: Release (default) or RelWithDebInfo
  -OutputDir <path>  Output directory (default: out/windows)
  -QtDir <path>      Qt installation dir (auto-detected if omitted)
  -Clean             Remove output dir and Rust artifacts before building
  -Release           Strip debug info from the binary
  -Console           Keep a console window attached (useful for debugging)
  -Package           Create portable ZIP and InnoSetup installer
  -Help              Show this help message

Examples:
  .\build\windows-build.ps1
  .\build\windows-build.ps1 -Config RelWithDebInfo -Console
  .\build\windows-build.ps1 -Package -Clean
"@
    exit 0
}

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RustDir = Join-Path $ProjectRoot "rust"

Write-Host "=== GuineaMPEG Windows Build ===" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Configuration: $Config" -ForegroundColor Gray
Write-Host "Output dir: $OutputDir" -ForegroundColor Gray
Write-Host "Release: $(if ($Release) { 'Yes' } else { 'No' })" -ForegroundColor Gray

# ---- Check prerequisites ----
function Test-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error "'$Name' not found in PATH. Please install it."
        exit 1
    }
}

Write-Host "Checking prerequisites..." -ForegroundColor Cyan
Test-Command "cmake"
Test-Command "cargo"
Test-Command "rustup"

# Verify MSVC Rust target
$Targets = rustup target list --installed
if ($Targets -notcontains "x86_64-pc-windows-msvc") {
    Write-Host "Adding Rust target: x86_64-pc-windows-msvc..." -ForegroundColor Yellow
    rustup target add x86_64-pc-windows-msvc
}

# ---- Auto-detect Qt ----
if (-not $QtDir) {
    $QtDirs = Get-ChildItem "C:\Qt\6.*\msvc*\" -Directory -ErrorAction SilentlyContinue `
        | Sort-Object Name -Descending
    if ($QtDirs) {
        $QtDir = $QtDirs[0].FullName
        Write-Host "Auto-detected Qt at: $QtDir" -ForegroundColor Green
    }
    else {
        Write-Error "Qt6 not found at C:\Qt\6.*\msvc*. Set -QtDir or install Qt from the online installer."
        exit 1
    }
}
else {
    Write-Host "Using Qt from: $QtDir" -ForegroundColor Gray
}

# ---- Step 1: Locate vendored mpv-dev ----
$MpvDir = Join-Path (Join-Path (Join-Path $ProjectRoot "build") "vendor") "mpv-dev-x86_64"
$MpvH = Join-Path $MpvDir "include/mpv/client.h"
if (-not (Test-Path $MpvH)) {
    Write-Error "mpv-dev not found at $MpvDir.`nRun .\build\download-vendor.ps1 or download the bundle manually."
    exit 1
}
Write-Host "=== Step 1/6: mpv-dev bundle ===" -ForegroundColor Cyan
Write-Host "Using vendored mpv-dev at $MpvDir" -ForegroundColor Green

# Ensure lib/ subdirectory
$libDir = Join-Path $MpvDir "lib"
$null = New-Item -ItemType Directory -Force -Path $libDir

# Ensure we have mpv.lib (MSVC COFF import library)
$mpvLibPath = Join-Path $libDir "mpv.lib"
if (-not (Test-Path $mpvLibPath)) {
    $existingLib = Get-ChildItem -LiteralPath $MpvDir -Filter "*.lib" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingLib) {
        Copy-Item $existingLib.FullName $mpvLibPath -Force
        Write-Host "Found existing MSVC import library." -ForegroundColor Green
    } else {
        Write-Host "Generating MSVC import library from libmpv-2.dll..." -ForegroundColor Yellow
        $dllPath = Join-Path $MpvDir "libmpv-2.dll"
        if (-not (Test-Path $dllPath)) { Write-Error "libmpv-2.dll not found in bundle"; exit 1 }

        if (-not (Get-Command "dumpbin" -ErrorAction SilentlyContinue)) {
            $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
            if (-not (Test-Path $vswhere)) { $vswhere = "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe" }
            $vsPath = if (Test-Path $vswhere) { & $vswhere -latest -property installationPath } else { $null }
            if (-not $vsPath) {
                $vsPath = @(
                    "C:\Program Files\Microsoft Visual Studio\2022\Community",
                    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community",
                    "C:\Program Files\Microsoft Visual Studio\2022\Professional",
                    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional",
                    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise",
                    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise",
                    "C:\Program Files\Microsoft Visual Studio\2022\BuildTools",
                    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
                ) | Where-Object { Test-Path "$_\VC\Auxiliary\Build\vcvars64.bat" } | Select-Object -First 1
            }
            if (-not $vsPath) { Write-Error "Visual Studio not found. Cannot generate mpv.lib."; exit 1 }
            $vcvars = Join-Path (Join-Path (Join-Path $vsPath "VC") "Auxiliary") "Build\vcvars64.bat"
            cmd /c "`"$vcvars`" x64 > nul 2>&1 && set" | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
            }
        }

        $defPath = Join-Path $libDir "mpv.def"
        $output = & dumpbin /exports $dllPath
        $inExports = $false; $exports = @()
        foreach ($line in $output) {
            if ($line -match '^\s+ordinal\s+hint\s+RVA\s+name') { $inExports = $true; continue }
            if ($inExports -and $line -match '^\s+(\d+)\s+([0-9A-F]+)\s+([0-9A-F]+)\s+(\S+)') {
                $name = $matches[4]
                if ($name -like 'mpv_*') { $exports += $name }
            }
        }
        Set-Content -Path $defPath -Value "LIBRARY libmpv-2.dll`r`nEXPORTS`r`n$($exports -join "`r`n")" -Encoding ASCII
        & lib /def:$defPath /out:$mpvLibPath /machine:x64
        if ($LASTEXITCODE -ne 0) { Write-Error "Failed to generate mpv.lib"; exit 1 }
        Remove-Item -Force $defPath
        Write-Host "Generated mpv.lib ($($exports.Count) exports)" -ForegroundColor Green
    }
}

# ---- Auto-detect MSVC compiler ----
function Import-VisualStudioEnvironment {
    if (Get-Command "cl" -ErrorAction SilentlyContinue) { return }
    Write-Host "Looking for Visual Studio..." -ForegroundColor Yellow
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        $vswhere = "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
    }
    if (-not (Test-Path $vswhere)) {
        Write-Error "Visual Studio not found. Install it or run from a Developer Command Prompt."
        exit 1
    }
    $vsPath = & $vswhere -latest -property installationPath
    if (-not $vsPath) {
        $candidates = @(
            "C:\Program Files\Microsoft Visual Studio\2022\Community",
            "C:\Program Files\Microsoft Visual Studio\2022\Professional",
            "C:\Program Files\Microsoft Visual Studio\2022\Enterprise",
            "C:\Program Files\Microsoft Visual Studio\2022\BuildTools",
            "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community",
            "C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional",
            "C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise",
            "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools",
            "C:\Program Files\Microsoft Visual Studio\2019\Community",
            "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community"
        )
        $vsPath = $candidates | Where-Object { Test-Path "$_\VC\Auxiliary\Build\vcvars64.bat" } | Select-Object -First 1
    }
    if (-not $vsPath) {
        Write-Error "Could not find Visual Studio installation."
        exit 1
    }
    $vcvars = Join-Path (Join-Path (Join-Path $vsPath "VC") "Auxiliary") "Build\vcvars64.bat"
    if (-not (Test-Path $vcvars)) {
        Write-Error "vcvars64.bat not found at $vcvars"
        exit 1
    }
    Write-Host "Loading MSVC environment from $vcvars" -ForegroundColor Gray
    cmd /c "`"$vcvars`" x64 > nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
}
Import-VisualStudioEnvironment

# ---- Step 2: CMake configure ----
Write-Host "=== Step 2/6: CMake configure ===" -ForegroundColor Cyan

if ($Clean) {
    Write-Host "=== Cleaning build artifacts ===" -ForegroundColor Cyan
    if (Test-Path $OutputDir) {
        Remove-Item -Recurse -Force $OutputDir
    }
    $RustTarget = Join-Path $RustDir "target"
    if (Test-Path $RustTarget) {
        Remove-Item -Recurse -Force $RustTarget
    }
}
$null = New-Item -ItemType Directory -Force -Path $OutputDir

$env:MPV_DIR = $MpvDir
$env:MPV_LIB_DIR = Join-Path $MpvDir "lib"
cmake -S $ProjectRoot -B $OutputDir `
    "-G" "Ninja" `
    "-DCMAKE_BUILD_TYPE=$Config" `
    "-DCMAKE_PREFIX_PATH=$QtDir" `
    "-DCMAKE_C_COMPILER=cl" `
    "-DCMAKE_CXX_COMPILER=cl" `
    "-DPACKAGE_TARGET=windows" `
    $(if ($Console) { "-DCONSOLE_MODE=ON" } else { "-DCONSOLE_MODE=OFF" })

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configuration failed"
    exit 1
}

# ---- Step 3: CMake build ----
Write-Host "=== Step 3/6: CMake build ===" -ForegroundColor Cyan
cmake "--build" $OutputDir "--config" $Config

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake build failed"
    exit 1
}

$ExePath = Join-Path $OutputDir "guinea-mpeg.exe"
if (-not (Test-Path $ExePath)) {
    Write-Error "Build succeeded but guine-mpeg.exe not found at $ExePath"
    exit 1
}
Write-Host "Build complete: $ExePath" -ForegroundColor Green

# ---- Strip debug info (Release mode) ----
if ($Release -or $Package) {
    Write-Host "=== Stripping debug info ===" -ForegroundColor Cyan
    $stripTool = if (Get-Command "strip" -ErrorAction SilentlyContinue) { "strip" }
        elseif (Get-Command "llvm-strip" -ErrorAction SilentlyContinue) { "llvm-strip" }
        else { $null }
    if ($stripTool) {
        & $stripTool "--strip-debug" $ExePath
        $RustDllStrip = Join-Path $OutputDir "guinea_mpeg_core.dll"
        if (Test-Path $RustDllStrip) {
            & $stripTool "--strip-debug" $RustDllStrip
        }
        Write-Host "Stripped with $stripTool." -ForegroundColor Green
    } else {
        Write-Warning "strip/llvm-strip not found. Binary may contain debug symbols."
    }
}

# ---- Step 4: Deploy Qt DLLs ----
Write-Host "=== Step 4/6: Deploying Qt DLLs ===" -ForegroundColor Cyan
$Windeployqt = Join-Path (Join-Path $QtDir "bin") "windeployqt.exe"
if (Test-Path $Windeployqt) {
    & $Windeployqt $ExePath --qmldir (Join-Path $ProjectRoot "qml") --release --no-compiler-runtime
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "windeployqt returned exit code $LASTEXITCODE"
    }
    else {
        Write-Host "Qt DLLs deployed." -ForegroundColor Green
    }
}
else {
    Write-Warning "windeployqt not found at $Windeployqt. Skipping Qt DLL deployment."
}

# ---- Step 5: Copy mpv DLL ----
Write-Host "=== Step 5/6: Copying mpv DLL ===" -ForegroundColor Cyan
$MpvDll = Join-Path $MpvDir "libmpv-2.dll"
if (Test-Path $MpvDll) {
    Copy-Item $MpvDll (Join-Path $OutputDir "libmpv-2.dll") -Force
    # The import library references libmpv-2.dll (via LIBRARY directive in .def),
    # but also provide mpv.dll as a fallback for compatibility.
    Copy-Item $MpvDll (Join-Path $OutputDir "mpv.dll") -Force
    Write-Host "libmpv-2.dll and mpv.dll copied." -ForegroundColor Green
}
else {
    Write-Warning "libmpv-2.dll not found at $MpvDll. Copy manually."
}

# ---- Step 6: Copy Rust DLL ----
Write-Host "=== Step 6/6: Copying Rust DLL ===" -ForegroundColor Cyan
$RustDll = Join-Path $RustDir "target\release\guinea_mpeg_core.dll"
if (Test-Path $RustDll) {
    Copy-Item $RustDll (Join-Path $OutputDir "guinea_mpeg_core.dll") -Force
    Write-Host "guinea_mpeg_core.dll copied." -ForegroundColor Green
}
else {
    Write-Warning "guinea_mpeg_core.dll not found at $RustDll."
}

# ---- Step 7: Bundle ffmpeg ----
Write-Host "=== Bundling ffmpeg ===" -ForegroundColor Cyan
$FfmpegDir = Join-Path (Join-Path (Join-Path $ProjectRoot "build") "vendor") "ffmpeg"
$FfmpegExe = Join-Path $FfmpegDir "ffmpeg.exe"
$FfprobeExe = Join-Path $FfmpegDir "ffprobe.exe"
if (-not (Test-Path $FfmpegExe)) {
    Write-Error "ffmpeg.exe not found at $FfmpegDir.`nRun .\build\download-vendor.ps1 or download manually."
    exit 1
}
Copy-Item $FfmpegExe (Join-Path $OutputDir "ffmpeg.exe") -Force
Copy-Item $FfprobeExe (Join-Path $OutputDir "ffprobe.exe") -Force
Write-Host "ffmpeg.exe + ffprobe.exe bundled." -ForegroundColor Green

Write-Host ""
Write-Host "=== Build complete! ===" -ForegroundColor Green
Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan
Write-Host "Executable: $ExePath" -ForegroundColor Cyan

# ---- Packaging ----
if ($Package) {
    Write-Host ""
    Write-Host "=== Packaging ===" -ForegroundColor Cyan

    Write-Host "Cleaning build artifacts from output..." -ForegroundColor Gray
    @("CMakeCache.txt", "cmake_install.cmake", "build.ninja", ".ninja_log", ".ninja_deps") | ForEach-Object {
        Remove-Item -Force (Join-Path $OutputDir $_) -ErrorAction SilentlyContinue
    }
    @("CMakeFiles", ".qt", "CMakeScripts") | ForEach-Object {
        Remove-Item -Recurse -Force (Join-Path $OutputDir $_) -ErrorAction SilentlyContinue
    }
    Get-ChildItem $OutputDir -Filter "*.dir" -Directory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $CargoToml = Join-Path (Join-Path $ProjectRoot "rust") "Cargo.toml"
    $Version = Select-String -Path $CargoToml '^version = "(.+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
    $ArchiveName = "guinea-mpeg-$Version-x86_64"

    # Portable ZIP
    $ZipPath = Join-Path (Split-Path $OutputDir -Parent) "$ArchiveName.zip"
    Write-Host "Creating portable ZIP: $ZipPath" -ForegroundColor Cyan
    Get-ChildItem $OutputDir | Compress-Archive -DestinationPath $ZipPath -Force
    Write-Host "ZIP created: $ZipPath" -ForegroundColor Green

    # InnoSetup installer
    $ISCC = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if (-not $ISCC) {
        $ISCC = Get-Command "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" -ErrorAction SilentlyContinue
        if (-not $ISCC) {
            $ISCC = Get-Command "C:\Program Files\Inno Setup 6\ISCC.exe" -ErrorAction SilentlyContinue
        }
    }

    if ($ISCC) {
        $IssPath = Join-Path (Join-Path $PSScriptRoot "windows") "installer.iss"
        $InstallerPath = Join-Path (Split-Path $OutputDir -Parent) "$ArchiveName.exe"

        Write-Host "Creating InnoSetup installer..." -ForegroundColor Cyan
        & $ISCC.Source `
            "/DAppVersion=$Version" `
            "/DSourceDir=$OutputDir" `
            "/DOutputDir=$(Split-Path $OutputDir -Parent)" `
            "/DOutputFilename=$ArchiveName" `
            $IssPath

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installer created." -ForegroundColor Green
        }
        else {
            Write-Warning "InnoSetup failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Warning "ISCC.exe (InnoSetup) not found. Skipping installer creation."
        Write-Warning "Install InnoSetup 6 from https://jrsoftware.org/isdl.php"
    }
}

Write-Host ""
Write-Host "=== All done! ===" -ForegroundColor Green
