param(
    [string]$Arch = "x86_64",
    [string]$OutputDir = "$PSScriptRoot/.mpv-dev",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$AssetPattern = "mpv-dev-$Arch-*-git-*.7z"

$MpvDir = Join-Path $OutputDir "mpv-dev-$Arch"

if ((Test-Path "$MpvDir/include/mpv/client.h") -and -not $Force) {
    Write-Host "mpv-dev already cached at $MpvDir" -ForegroundColor Green
    return
}

Write-Host "Fetching latest mpv-dev release info..." -ForegroundColor Cyan

$Release = Invoke-RestMethod -Uri "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest" `
    -Headers @{ "Accept" = "application/vnd.github.v3+json" }

$Asset = $Release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
if (-not $Asset) {
    Write-Error "No mpv-dev asset found for architecture '$Arch' in release $($Release.tag_name)"
    exit 1
}

$DownloadUrl = $Asset.browser_download_url
$Filename = $Asset.name
# GitHub API provides sha256 digest on each release asset
$ExpectedHash = $Asset.digest -replace '^sha256:'

Write-Host "Downloading $Filename..." -ForegroundColor Cyan
Write-Host "  URL: $DownloadUrl" -ForegroundColor Gray

$DownloadPath = Join-Path $OutputDir $Filename
$null = New-Item -ItemType Directory -Force -Path $OutputDir

# Download with progress
Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath

# Verify SHA256
if ($ExpectedHash) {
    Write-Host "Verifying SHA256: $ExpectedHash" -ForegroundColor Cyan
    $ActualHash = (Get-FileHash -Path $DownloadPath -Algorithm SHA256).Hash.ToLower()
    if ($ActualHash -ne $ExpectedHash.ToLower()) {
        Write-Error "SHA256 mismatch! Expected: $ExpectedHash, Got: $ActualHash"
        exit 1
    }
    Write-Host "Checksum verified." -ForegroundColor Green
}

Write-Host "Extracting to $MpvDir..." -ForegroundColor Cyan

# Remove old extraction first
if (Test-Path $MpvDir) {
    Remove-Item -Recurse -Force $MpvDir
}

# Create extraction directory and extract
$null = New-Item -ItemType Directory -Force -Path $MpvDir

# Use 7-Zip if available, otherwise try Expand-Archive (which doesn't handle .7z)
$7z = Get-Command "7z" -ErrorAction SilentlyContinue
$7za = Get-Command "7za" -ErrorAction SilentlyContinue

if ($7z) {
    & $7z.Source x "$DownloadPath" -o"$MpvDir" -y | Out-Null
}
elseif ($7za) {
    & $7za.Source x "$DownloadPath" -o"$MpvDir" -y | Out-Null
}
else {
    Write-Host "Neither 7z nor 7za found. Attempting with Expand-Archive..." -ForegroundColor Yellow
    # Expand-Archive doesn't support .7z natively; try if renamed to .zip
    if ($Filename -like "*.7z") {
        Write-Error "Cannot extract .7z archive. Please install 7-Zip (https://7-zip.org) and ensure 7z.exe is in PATH."
        exit 1
    }
    Expand-Archive -Path $DownloadPath -DestinationPath $MpvDir -Force
}

# The mpv-dev archive typically contains include/ and lib/ at the root.
# Verify the expected structure.
if (Test-Path "$MpvDir/include/mpv/client.h") {
    Write-Host "mpv-dev $Arch unpacked successfully at $MpvDir" -ForegroundColor Green
}
else {
    # Maybe there's a subdirectory - look for it
    $SubDir = Get-ChildItem -Directory $MpvDir | Select-Object -First 1
    if ($SubDir -and (Test-Path "$($SubDir.FullName)/include/mpv/client.h")) {
        # Move contents up
        Get-ChildItem -Path $SubDir.FullName | Move-Item -Destination $MpvDir -Force
        Remove-Item -Recurse -Force $SubDir.FullName
        Write-Host "mpv-dev $Arch unpacked successfully at $MpvDir (flattened)" -ForegroundColor Green
    }
    else {
        Write-Error "Extraction completed but include/mpv/client.h not found in $MpvDir"
        exit 1
    }
}

Write-Host "Done. Set MPV_DIR=$MpvDir to use this bundle." -ForegroundColor Cyan
