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
    Build configuration: Debug (default), Release or RelWithDebInfo.

.PARAMETER OutputDir
    Output directory (default: out/windows).

.PARAMETER QtDir
    Path to Qt installation (auto-detected if omitted).

.PARAMETER Clean
    Remove output directory and Rust build artifacts before building.

.PARAMETER Release
    Shortcut for -Config Release. Debug is the default configuration.

.EXAMPLE
    .\build\windows-build.ps1

.EXAMPLE
    .\build\windows-build.ps1 -Release

.EXAMPLE
    .\build\windows-build.ps1 -Config RelWithDebInfo

.EXAMPLE
    .\build\windows-build.ps1 -Config Debug -Console

.EXAMPLE
    .\build\windows-build.ps1 -Package
#>

param(
    [switch]$Package,
    [ValidateSet("Debug", "Release", "RelWithDebInfo")]
    [string]$Config = "Debug",
    [string]$OutputDir = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "out") "windows"),
    [string]$QtDir = "",
    [switch]$Clean,
    [switch]$Console,
    [switch]$Release,
    [switch]$Help
)

# -Release is a shortcut for -Config Release; -Package always builds a release
# configuration. An explicit -Config wins over both.
if (-not $PSBoundParameters.ContainsKey('Config')) {
    $Config = if ($Release -or $Package) { "Release" } else { "Debug" }
}

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
  -Config <type>     Build config: Debug (default), Release or RelWithDebInfo
  -OutputDir <path>  Output directory (default: out/windows)
  -QtDir <path>      Qt installation dir (auto-detected if omitted)
  -Clean             Remove output dir and Rust artifacts before building
  -Release           Shortcut for -Config Release
  -Console           Keep a console window attached (useful for debugging)
  -Package           Create portable ZIP and InnoSetup installer (release build)
  -Help              Show this help message

Examples:
  .\build\windows-build.ps1
  .\build\windows-build.ps1 -Release
  .\build\windows-build.ps1 -Config Debug -Console
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
Write-Host "Release: $(if ($Config -eq 'Release') { 'Yes' } else { 'No' })" -ForegroundColor Gray

# ---- Auto-detect MSVC compiler ----
# Locates vcvars64.bat across common VS install paths (vswhere + fallbacks).
function Get-VcVarsPath {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        $vswhere = "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
    }
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
    if (-not $vsPath) {
        throw "Visual Studio not found. Install it or run from a Developer Command Prompt."
    }
    $vcvars = Join-Path (Join-Path (Join-Path $vsPath "VC") "Auxiliary") "Build\vcvars64.bat"
    if (-not (Test-Path $vcvars)) {
        throw "vcvars64.bat not found at $vcvars"
    }
    return $vcvars
}

function Import-VisualStudioEnvironment {
    if (Get-Command "cl" -ErrorAction SilentlyContinue) { return }
    Write-Host "Looking for Visual Studio..." -ForegroundColor Yellow
    $vcvars = Get-VcVarsPath
    Write-Host "Loading MSVC environment from $vcvars" -ForegroundColor Gray
    cmd /c "`"$vcvars`" x64 > nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
}
Import-VisualStudioEnvironment

# ---- Check prerequisites ----
function Test-Command([string[]]$Name) {
    foreach ($cmd in $Name) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            throw "'$cmd' not found in PATH. Please install it."
        }
    }
}

Write-Host "Checking prerequisites..." -ForegroundColor Cyan
Test-Command "cmake", "cargo", "rustup"

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
        throw "Qt6 not found at C:\Qt\6.*\msvc*. Set -QtDir or install Qt from the online installer."
    }
}
else {
    Write-Host "Using Qt from: $QtDir" -ForegroundColor Gray
}

# ---- Step 1: Locate vendored mpv-dev ----
$MpvDir = Join-Path (Join-Path (Join-Path $ProjectRoot "build") "vendor") "mpv-dev-x86_64"
$MpvH = Join-Path $MpvDir "include/mpv/client.h"
if (-not (Test-Path $MpvH)) {
    throw "mpv-dev not found at $MpvDir.`nRun .\build\download-vendor.ps1 or download the bundle manually."
}
Write-Host "=== Step 1/7: mpv-dev bundle ===" -ForegroundColor Cyan
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
        if (-not (Test-Path $dllPath)) { throw "libmpv-2.dll not found in bundle" }

        Import-VisualStudioEnvironment

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
        if ($LASTEXITCODE -ne 0) { throw "Failed to generate mpv.lib" }
        Remove-Item -Force $defPath
        Write-Host "Generated mpv.lib ($($exports.Count) exports)" -ForegroundColor Green
    }
}

# ---- Step 2: CMake configure ----
Write-Host "=== Step 2/7: CMake configure ===" -ForegroundColor Cyan

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
    throw "CMake configuration failed"
}

# ---- Step 3: CMake build ----
Write-Host "=== Step 3/7: CMake build ===" -ForegroundColor Cyan
cmake "--build" $OutputDir "--config" $Config

if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed"
}

$ExePath = Join-Path $OutputDir "guinea-mpeg.exe"
if (-not (Test-Path $ExePath)) {
    throw "Build succeeded but guinea-mpeg.exe not found at $ExePath"
}
Write-Host "Build complete: $ExePath" -ForegroundColor Green

# ---- Strip debug info (release builds only) ----
if (($Release -or $Package) -and $Config -ne "Debug") {
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
Write-Host "=== Step 4/7: Deploying Qt DLLs ===" -ForegroundColor Cyan
$Windeployqt = Join-Path (Join-Path $QtDir "bin") "windeployqt.exe"
$DeployType = if ($Config -eq "Debug") { "--debug" } else { "--release" }
if (Test-Path $Windeployqt) {
    & $Windeployqt $ExePath --qmldir (Join-Path $ProjectRoot "qml") $DeployType --no-compiler-runtime
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
Write-Host "=== Step 5/7: Copying mpv DLL ===" -ForegroundColor Cyan
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
Write-Host "=== Step 6/7: Copying Rust DLL ===" -ForegroundColor Cyan
$RustDll = Join-Path $RustDir "target\release\guinea_mpeg_core.dll"
if (Test-Path $RustDll) {
    Copy-Item $RustDll (Join-Path $OutputDir "guinea_mpeg_core.dll") -Force
    Write-Host "guinea_mpeg_core.dll copied." -ForegroundColor Green
}
else {
    Write-Warning "guinea_mpeg_core.dll not found at $RustDll."
}

# ---- Step 7: Bundle ffmpeg ----
Write-Host "=== Step 7/7: Bundling ffmpeg ===" -ForegroundColor Cyan
$FfmpegDir = Join-Path (Join-Path (Join-Path $ProjectRoot "build") "vendor") "ffmpeg"
$FfmpegExe = Join-Path $FfmpegDir "ffmpeg.exe"
$FfprobeExe = Join-Path $FfmpegDir "ffprobe.exe"
if (-not (Test-Path $FfmpegExe)) {
    throw "ffmpeg.exe not found at $FfmpegDir.`nRun .\build\download-vendor.ps1 or download manually."
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
