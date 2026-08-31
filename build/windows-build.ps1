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

.PARAMETER Arch
    Target architecture: x86_64 (default) or arm64 (Windows on ARM).
    arm64 builds require the ARM64 MSVC build tools and the Qt
    "win64_msvc2022_arm64" package. The produced binaries only run on
    Windows-on-ARM devices.

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
    [ValidateSet("x86_64", "arm64")]
    [string]$Arch = "x86_64",
    [string]$OutputDir = (Join-Path (Join-Path $PSScriptRoot "..") "out\windows"),
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
  -Arch <arch>       Target architecture: x86_64 (default) or arm64
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
  .\build\windows-build.ps1 -Arch arm64 -Package
"@
    exit 0
}

$ErrorActionPreference = "Stop"

# ---- Project layout ----
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RustDir = Join-Path $ProjectRoot "rust"
$BuildDir = Join-Path (Split-Path $OutputDir -Parent) ".build-windows"
$VendorDir = Join-Path (Join-Path $ProjectRoot "build") "vendor"
$ExePath = Join-Path $BuildDir "guinea-mpeg.exe"

# ---- Per-architecture selection ----
# Vendor dirs mirror download-vendor.ps1 (mpv uses "aarch64", ffmpeg keeps the
# legacy "ffmpeg" dir for x86_64).
switch ($Arch) {
    "arm64" {
        $MpvAssetArch = "aarch64"
        $RustTarget = "aarch64-pc-windows-msvc"
        # vcvarsall's first arg is the HOST arch: "arm64" on a WoA host,
        # "x64_arm64" (x64 host -> arm64 target) when cross-building on x86_64.
        $VcArch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64_arm64" }
        $Machine = "arm64"
        $ArchSuffix = "arm64"
    }
    default {
        $MpvAssetArch = "x86_64"
        $RustTarget = "x86_64-pc-windows-msvc"
        $VcArch = "x64"
        $Machine = "x64"
        $ArchSuffix = "x86_64"
    }
}
$MpvDir = Join-Path $VendorDir "mpv-dev-$MpvAssetArch"
$FfmpegDir = if ($Arch -eq "arm64") { Join-Path $VendorDir "ffmpeg-arm64" } else { Join-Path $VendorDir "ffmpeg" }

# ---- Helpers ----

function Write-Step {
    param([int]$Index, [string]$Name)
    Write-Host "=== Step $Index/7: $Name ===" -ForegroundColor Cyan
}

function Assert-LastExitCode {
    param([string]$Action)
    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed (exit code $LASTEXITCODE)"
    }
}

# Copies a file into the staging dir. Warns (or throws with -Required) if the
# source is missing.
function Copy-ToStage {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$Required
    )
    if (-not (Test-Path $Source)) {
        if ($Required) {
            throw "$(Split-Path $Source -Leaf) not found at $Source.`nRun .\build\download-vendor.ps1 or download manually."
        }
        Write-Warning "$(Split-Path $Source -Leaf) not found at $Source."
        return
    }
    Copy-Item $Source $Destination -Force
    Write-Host "$(Split-Path $Destination -Leaf) staged." -ForegroundColor Green
}

# ---- Environment ----

# Locates vcvarsall.bat across common VS install paths (vswhere + fallbacks).
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
        ) | Where-Object { Test-Path "$_\VC\Auxiliary\Build\vcvarsall.bat" } | Select-Object -First 1
    }
    if (-not $vsPath) {
        throw "Visual Studio not found. Install it or run from a Developer Command Prompt."
    }
    $vcvars = Join-Path (Join-Path (Join-Path $vsPath "VC") "Auxiliary") "Build\vcvarsall.bat"
    if (-not (Test-Path $vcvars)) {
        throw "vcvarsall.bat not found at $vcvars"
    }
    return $vcvars
}

function Import-VisualStudioEnvironment {
    if (Get-Command "cl" -ErrorAction SilentlyContinue) { return }
    Write-Host "Looking for Visual Studio..." -ForegroundColor Yellow
    $vcvars = Get-VcVarsPath
    Write-Host "Loading MSVC $VcArch environment from $vcvars" -ForegroundColor Gray
    cmd /c "`"$vcvars`" $VcArch > nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
}

function Test-Command([string[]]$Name) {
    foreach ($cmd in $Name) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            throw "'$cmd' not found in PATH. Please install it."
        }
    }
}

# ---- Prerequisites ----

function Assert-Preconditions {
    Write-Host "Checking prerequisites..." -ForegroundColor Cyan
    Test-Command "cmake", "cargo", "rustup"

    $Targets = rustup target list --installed
    if ($Targets -notcontains $RustTarget) {
        Write-Host "Adding Rust target: $RustTarget..." -ForegroundColor Yellow
        rustup target add $RustTarget
    }

    if (-not $script:QtDir) {
        $QtDirs = Get-ChildItem "C:\Qt\6.*" -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue } |
            Where-Object {
                if ($Arch -eq "arm64") { $_.Name -like "msvc*arm64" }
                else { $_.Name -like "msvc*" -and $_.Name -notlike "*arm64" }
            } |
            Sort-Object Name -Descending
        if ($QtDirs) {
            $script:QtDir = $QtDirs[0].FullName
            Write-Host "Auto-detected Qt at: $script:QtDir" -ForegroundColor Green
        }
        else {
            throw "Qt6 not found under C:\Qt. Install the $(if ($Arch -eq 'arm64') { 'win64_msvc2022_arm64' } else { 'msvc2022' }) Qt kit."
        }
    }
    else {
        Write-Host "Using Qt from: $script:QtDir" -ForegroundColor Gray
    }

    $MpvHeader = Join-Path $MpvDir "include/mpv/client.h"
    if (-not (Test-Path $MpvHeader)) {
        throw "mpv-dev not found at $MpvDir.`nRun .\build\download-vendor.ps1 or download the bundle manually."
    }
    Write-Host "Using vendored mpv-dev at $MpvDir" -ForegroundColor Green
}

# ---- Build steps ----

function Ensure-MpvImportLibrary {
    Write-Step 1 "mpv-dev bundle"

    $libDir = Join-Path $MpvDir "lib"
    $null = New-Item -ItemType Directory -Force -Path $libDir
    $mpvLibPath = Join-Path $libDir "mpv.lib"
    if (Test-Path $mpvLibPath) { return }

    $existingLib = Get-ChildItem -LiteralPath $MpvDir -Filter "*.lib" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingLib) {
        Copy-Item $existingLib.FullName $mpvLibPath -Force
        Write-Host "Found existing MSVC import library." -ForegroundColor Green
        return
    }

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
    & lib /def:$defPath /out:$mpvLibPath /machine:$Machine
    Assert-LastExitCode "mpv.lib generation"
    Remove-Item -Force $defPath
    Write-Host "Generated mpv.lib ($($exports.Count) exports)" -ForegroundColor Green
}

function Invoke-Clean {
    if (-not $Clean) { return }
    Write-Host "=== Cleaning build artifacts ===" -ForegroundColor Cyan
    foreach ($dir in @($OutputDir, $BuildDir, (Join-Path $RustDir "target"))) {
        if (Test-Path $dir) {
            Remove-Item -Recurse -Force $dir
        }
    }
}

function Invoke-CMakeConfigure {
    Write-Step 2 "CMake configure"
    $null = New-Item -ItemType Directory -Force -Path $OutputDir

    $env:MPV_DIR = $MpvDir
    $env:MPV_LIB_DIR = Join-Path $MpvDir "lib"
    $consoleFlag = if ($Console) { "-DCONSOLE_MODE=ON" } else { "-DCONSOLE_MODE=OFF" }
    cmake -S $ProjectRoot -B $BuildDir `
        "-G" "Ninja" `
        "-DCMAKE_BUILD_TYPE=$Config" `
        "-DCMAKE_PREFIX_PATH=$QtDir" `
        "-DCMAKE_C_COMPILER=cl" `
        "-DCMAKE_CXX_COMPILER=cl" `
        "-DPACKAGE_TARGET=windows" `
        "-DRUST_TARGET=$RustTarget" `
        "-DBUILD_TESTING=OFF" `
        $consoleFlag
    Assert-LastExitCode "CMake configuration"
}

function Invoke-CMakeBuild {
    Write-Step 3 "CMake build"
    cmake "--build" $BuildDir "--config" $Config
    Assert-LastExitCode "CMake build"

    if (-not (Test-Path $ExePath)) {
        throw "Build succeeded but guinea-mpeg.exe not found at $ExePath"
    }
    Write-Host "Build complete: $ExePath" -ForegroundColor Green
}

function Invoke-Strip {
    if (($Release -or $Package) -and $Config -ne "Debug") {
        Write-Host "=== Stripping debug info ===" -ForegroundColor Cyan
        $stripTool = if (Get-Command "strip" -ErrorAction SilentlyContinue) { "strip" }
            elseif (Get-Command "llvm-strip" -ErrorAction SilentlyContinue) { "llvm-strip" }
            else { $null }
        if ($stripTool) {
            & $stripTool "--strip-debug" $ExePath
            $RustDllStrip = Join-Path $BuildDir "guinea_mpeg_core.dll"
            if (Test-Path $RustDllStrip) {
                & $stripTool "--strip-debug" $RustDllStrip
            }
            Write-Host "Stripped with $stripTool." -ForegroundColor Green
        }
        else {
            Write-Warning "strip/llvm-strip not found. Binary may contain debug symbols."
        }
    }
}

# ---- Staging ----

function Deploy-Qt {
    Write-Step 4 "Deploy Qt DLLs"
    $Windeployqt = Join-Path (Join-Path $QtDir "bin") "windeployqt.exe"
    if (-not (Test-Path $Windeployqt)) {
        Write-Warning "windeployqt not found at $Windeployqt. Skipping Qt DLL deployment."
        return
    }
    # Deploy Qt into the staging dir (--dir), keeping the build dir free of
    # deployed Qt files.
    $DeployType = if ($Config -eq "Debug") { "--debug" } else { "--release" }
    & $Windeployqt $ExePath --qmldir (Join-Path $ProjectRoot "qml") $DeployType --no-compiler-runtime --dir $OutputDir
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "windeployqt returned exit code $LASTEXITCODE"
    }
    else {
        Write-Host "Qt DLLs deployed." -ForegroundColor Green
    }
}

function Stage-MpvDll {
    Write-Step 5 "Copy mpv DLL"
    # The import library references libmpv-2.dll (via LIBRARY directive in .def);
    # the exe imports libmpv-2.dll, so a separate mpv.dll is redundant.
    Copy-ToStage -Source (Join-Path $MpvDir "libmpv-2.dll") -Destination (Join-Path $OutputDir "libmpv-2.dll")
}

function Stage-AppFiles {
    Write-Step 6 "Stage app files"
    Copy-ToStage -Source $ExePath -Destination (Join-Path $OutputDir "guinea-mpeg.exe")
    # cargo mirrors the CMake build type: only Release produces a release crate.
    $RustProfile = if ($Config -eq "Release") { "release" } else { "debug" }
    Copy-ToStage -Source (Join-Path $RustDir "target\$RustTarget\$RustProfile\guinea_mpeg_core.dll") -Destination (Join-Path $OutputDir "guinea_mpeg_core.dll")
    # CMake POST_BUILD copies default_profiles.toml next to the exe in the build
    # dir; stage it alongside the app as well.
    Copy-ToStage -Source (Join-Path $BuildDir "default_profiles.toml") -Destination (Join-Path $OutputDir "default_profiles.toml")
}

function Stage-Ffmpeg {
    Write-Step 7 "Bundle ffmpeg"
    Copy-ToStage -Source (Join-Path $FfmpegDir "ffmpeg.exe") -Destination (Join-Path $OutputDir "ffmpeg.exe") -Required
    Copy-ToStage -Source (Join-Path $FfmpegDir "ffprobe.exe") -Destination (Join-Path $OutputDir "ffprobe.exe") -Required
    # ffmpeg is dynamically linked against the libav DLLs (BtbN gpl-shared) -
    # they must sit next to the executables.
    $FfmpegDlls = @(Get-ChildItem $FfmpegDir -Filter "*.dll" -ErrorAction SilentlyContinue)
    if ($FfmpegDlls.Count -eq 0) {
        Write-Warning "No libav DLLs found in $FfmpegDir. The shared ffmpeg build will not run. Re-run .\build\download-vendor.ps1 -Force."
    } else {
        $FfmpegDlls | Copy-Item -Destination $OutputDir -Force
        Write-Host "$($FfmpegDlls.Count) ffmpeg DLLs staged." -ForegroundColor Green
    }
}

function Trim-Staging {
    Write-Host "=== Trimming staging dir ===" -ForegroundColor Cyan
    # D3D12 shader compiler: not needed since the app forces the OpenGL backend.
    @("dxcompiler.dll", "dxil.dll") | ForEach-Object {
        Remove-Item -Force (Join-Path $OutputDir $_) -ErrorAction SilentlyContinue
    }
    # Keep only Qt translations for the locales the app ships; windeployqt
    # copies all of them otherwise.
    $AppLocales = @("cs", "de", "es", "fr", "it", "pl", "ru", "szl")
    $TranslationsDir = Join-Path $OutputDir "translations"
    if (Test-Path $TranslationsDir) {
        $KeepFiles = @($AppLocales | ForEach-Object { "qt_$_.qm" })
        Get-ChildItem $TranslationsDir -Filter "qt_*.qm" |
            Where-Object { $_.Name -notin $KeepFiles } |
            Remove-Item -Force
        Write-Host "Qt translations trimmed to: $($AppLocales -join ', ')" -ForegroundColor Gray
    }
    Write-Host "Staging dir trimmed." -ForegroundColor Green
}

# ---- Packaging ----

function New-Package {
    if (-not $Package) { return }
    Write-Host ""
    Write-Host "=== Packaging ===" -ForegroundColor Cyan

    $CargoToml = Join-Path (Join-Path $ProjectRoot "rust") "Cargo.toml"
    $Version = Select-String -Path $CargoToml '^version = "(.+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
    $ArchiveName = "guinea-mpeg-$Version-$ArchSuffix"

    $ZipPath = Join-Path (Split-Path $OutputDir -Parent) "$ArchiveName.zip"
    Write-Host "Creating portable ZIP: $ZipPath" -ForegroundColor Cyan
    Get-ChildItem $OutputDir | Compress-Archive -DestinationPath $ZipPath -Force
    Write-Host "ZIP created: $ZipPath" -ForegroundColor Green

    $ISCC = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if (-not $ISCC) {
        $ISCC = Get-Command "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" -ErrorAction SilentlyContinue
        if (-not $ISCC) {
            $ISCC = Get-Command "C:\Program Files\Inno Setup 6\ISCC.exe" -ErrorAction SilentlyContinue
        }
    }
    if (-not $ISCC) {
        Write-Warning "ISCC.exe (InnoSetup) not found. Skipping installer creation."
        Write-Warning "Install InnoSetup 6 from https://jrsoftware.org/isdl.php"
        return
    }

    $IssPath = Join-Path (Join-Path $PSScriptRoot "windows") "installer.iss"
    Write-Host "Creating InnoSetup installer..." -ForegroundColor Cyan
    & $ISCC.Source `
        "/DAppVersion=$Version" `
        "/DAppArchitecture=$ArchSuffix" `
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

# ---- Main ----

Write-Host "=== GuineaMPEG Windows Build ===" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Configuration: $Config" -ForegroundColor Gray
Write-Host "Architecture: $Arch" -ForegroundColor Gray
Write-Host "Rust target: $RustTarget" -ForegroundColor Gray
Write-Host "Build dir: $BuildDir" -ForegroundColor Gray
Write-Host "Output dir: $OutputDir" -ForegroundColor Gray
Write-Host "Release: $(if ($Config -eq 'Release') { 'Yes' } else { 'No' })" -ForegroundColor Gray

if ($Arch -eq "arm64") {
    Write-Warning "arm64 binaries only run on Windows-on-ARM (WoA) devices. x86_64 hosts can build them but cannot execute them."
}

# Without -Clean, stale artifacts from previous builds (e.g. Debug Qt DLLs
# from an earlier Debug run into the same output dir) may remain and get
# bundled into the package.
if (-not $Clean) {
    Write-Warning "Running without -Clean: the output dir may contain stale artifacts from previous builds (e.g. Debug Qt DLLs). Use -Clean for a reproducible package."
}

Import-VisualStudioEnvironment
Assert-Preconditions
Ensure-MpvImportLibrary
Invoke-Clean
Invoke-CMakeConfigure
Invoke-CMakeBuild
Invoke-Strip
Deploy-Qt
Stage-MpvDll
Stage-AppFiles
Stage-Ffmpeg
Trim-Staging

Write-Host ""
Write-Host "=== Build complete! ===" -ForegroundColor Green
Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan
Write-Host "Executable: $ExePath" -ForegroundColor Cyan

New-Package

Write-Host ""
Write-Host "=== All done! ===" -ForegroundColor Green
