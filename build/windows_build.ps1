<#
.SYNOPSIS
    Build GuineaMPEG for Windows.

.DESCRIPTION
    Orchestrates the full Windows build pipeline:
    1. Download mpv-dev bundle (if missing)
    2. Configure with CMake (MSVC, Ninja)
    3. Build (CMake invokes cargo for Rust + MSVC for C++)
    4. Deploy Qt DLLs with windeployqt
    5. Copy mpv DLL into output
    Then package into InnoSetup installer and/or ZIP

.PARAMETER SkipPackage
    Skip installer/archive creation.

.PARAMETER SkipMpv
    Skip mpv-dev download step (use existing).

.PARAMETER Config
    Build configuration: Release (default) or RelWithDebInfo.

.PARAMETER OutputDir
    Output directory (default: out/windows).

.PARAMETER QtDir
    Path to Qt installation (auto-detected if omitted).

.PARAMETER NoClean
    Do not clean the build directory before building.

.EXAMPLE
    .\build\windows_build.ps1

.EXAMPLE
    .\build\windows_build.ps1 -Config RelWithDebInfo -SkipPackage
#>

param(
    [switch]$SkipPackage,
    [switch]$SkipMpv,
    [ValidateSet("Release", "RelWithDebInfo")]
    [string]$Config = "Release",
    [string]$OutputDir = (Join-Path $PSScriptRoot ".." "out" "windows"),
    [string]$QtDir = "",
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RustDir = Join-Path $ProjectRoot "rust"

Write-Host "=== GuineaMPEG Windows Build ===" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Configuration: $Config" -ForegroundColor Gray
Write-Host "Output dir: $OutputDir" -ForegroundColor Gray

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

# ---- Step 1: Download mpv-dev ----
$MpvDir = Join-Path $ProjectRoot "build" "windows" ".mpv-dev" "mpv-dev-x86_64"
if (-not $SkipMpv) {
    Write-Host "=== Step 1/5: Acquiring mpv-dev bundle ===" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "windows" "mpv-dev.ps1") -Arch x86_64 -OutputDir (Join-Path $ProjectRoot "build" "windows" ".mpv-dev")
}
else {
    Write-Host "=== Step 1/5: Skipping mpv-dev download (--SkipMpv) ===" -ForegroundColor Yellow
}

# Verify mpv-dev was acquired
if (-not (Test-Path "$MpvDir/include/mpv/client.h")) {
    Write-Error "mpv-dev not found at $MpvDir. Run without -SkipMpv or set MPV_DIR manually."
    exit 1
}

# ---- Step 2: CMake configure ----
Write-Host "=== Step 2/5: CMake configure ===" -ForegroundColor Cyan

if (-not $NoClean) {
    if (Test-Path $OutputDir) {
        Remove-Item -Recurse -Force $OutputDir
    }
}
$null = New-Item -ItemType Directory -Force -Path $OutputDir

cmake -S $ProjectRoot -B $OutputDir `
    -G Ninja `
    -DCMAKE_BUILD_TYPE=$Config `
    -DCMAKE_PREFIX_PATH="$QtDir" `
    -DMPV_DIR="$MpvDir" `
    -DCMAKE_C_COMPILER=cl `
    -DCMAKE_CXX_COMPILER=cl `
    -DPACKAGE_TARGET=windows

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configuration failed"
    exit 1
}

# ---- Step 3: CMake build ----
Write-Host "=== Step 3/5: CMake build ===" -ForegroundColor Cyan
cmake --build $OutputDir --config $Config

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

# ---- Step 4: Deploy Qt DLLs ----
Write-Host "=== Step 4/5: Deploying Qt DLLs ===" -ForegroundColor Cyan
$Windeployqt = Join-Path $QtDir "bin" "windeployqt.exe"
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
Write-Host "=== Step 5/5: Copying mpv DLL ===" -ForegroundColor Cyan
$MpvDll = Join-Path $MpvDir "bin" "mpv-2.dll"
if (Test-Path $MpvDll) {
    Copy-Item $MpvDll (Join-Path $OutputDir "mpv-2.dll") -Force
    Write-Host "mpv-2.dll copied." -ForegroundColor Green
}
else {
    Write-Warning "mpv-2.dll not found at $MpvDll. Copy manually."
}

Write-Host ""
Write-Host "=== Build complete! ===" -ForegroundColor Green
Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan
Write-Host "Executable: $ExePath" -ForegroundColor Cyan

# ---- Packaging ----
if (-not $SkipPackage) {
    Write-Host ""
    Write-Host "=== Packaging ===" -ForegroundColor Cyan

    $CargoToml = Join-Path $ProjectRoot "rust" "Cargo.toml"
    $Version = Select-String -Path $CargoToml '^version = "(.+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
    $ArchiveName = "GuineaMPEG-$Version-win64"

    # Portable ZIP
    $ZipPath = Join-Path (Split-Path $OutputDir -Parent) "$ArchiveName.zip"
    Write-Host "Creating portable ZIP: $ZipPath" -ForegroundColor Cyan
    Compress-Archive -Path "$OutputDir\*" -DestinationPath $ZipPath -Force
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
        $IssPath = Join-Path $PSScriptRoot "windows" "installer.iss"
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
