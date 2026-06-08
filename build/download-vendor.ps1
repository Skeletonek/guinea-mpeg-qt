<#
.SYNOPSIS
    Downloads vendored build dependencies for GuineaMPEG Windows builds.
.DESCRIPTION
    Fetches mpv-dev-x86_64 (libmpv SDK) and ffmpeg/ffprobe
    into build/vendor/ so the build script doesn't need network access.
.EXAMPLE
    .\build\download-vendor.ps1
#>

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$VendorDir = Join-Path (Join-Path $ProjectRoot "build") "vendor"

# ---- mpv-dev-x86_64 ----
$MpvDir = Join-Path $VendorDir "mpv-dev-x86_64"
$MpvH = Join-Path $MpvDir "include/mpv/client.h"
if (-not (Test-Path $MpvH)) {
    Write-Host "=== mpv-dev-x86_64 ===" -ForegroundColor Cyan

    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "guinea-mpeg-vendor/1.0")
    $json = $wc.DownloadString("https://api.github.com/repos/zhongfly/mpv-winbuild/releases/latest")
    $release = $json | ConvertFrom-Json

    $asset = $release.assets | Where-Object { $_.name -match '^mpv-dev-x86_64-\d{8}' -and $_.name -notmatch '-v3-' } | Select-Object -First 1
    if (-not $asset) {
        Write-Error "No mpv-dev-x86_64 asset found in latest zhongfly/mpv-winbuild release"
        exit 1
    }

    $archiveName = $asset.name
    $downloadUrl = $asset.browser_download_url
    Write-Host "Downloading $archiveName ..." -ForegroundColor Yellow

    $archive = Join-Path $VendorDir $archiveName
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archive -UseBasicParsing

    Write-Host "Extracting..." -ForegroundColor Yellow
    if (-not (Get-Command "7z" -ErrorAction SilentlyContinue)) {
        Write-Error "7-Zip (7z) not found in PATH. Install 7-Zip."
        exit 1
    }
    $null = 7z x $archive -o"$VendorDir" -y
    if ($LASTEXITCODE -ne 0) { Write-Error "7z extraction failed"; exit 1 }
    Remove-Item -Force $archive

    # Restructure: files extract into vendor root, move into mpv-dev-x86_64/
    if (Test-Path (Join-Path $VendorDir "include/mpv")) {
        New-Item -ItemType Directory -Force -Path $MpvDir | Out-Null
        Move-Item (Join-Path $VendorDir "include") "$MpvDir/include" -Force
        Move-Item (Join-Path $VendorDir "libmpv-2.dll") "$MpvDir/libmpv-2.dll" -Force
        Remove-Item (Join-Path $VendorDir "libmpv.dll.a") -Force -ErrorAction SilentlyContinue
    }
    Write-Host "mpv-dev-x86_64 ready at $MpvDir" -ForegroundColor Green
} else {
    Write-Host "mpv-dev-x86_64 already present" -ForegroundColor Green
}

# ---- ffmpeg ----
$FfmpegDir = Join-Path $VendorDir "ffmpeg"
$FfmpegExe = Join-Path $FfmpegDir "ffmpeg.exe"
if (-not (Test-Path $FfmpegExe)) {
    Write-Host "=== ffmpeg ===" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $FfmpegDir | Out-Null

    $zip = Join-Path $FfmpegDir "ffmpeg.zip"
    Write-Host "Downloading ffmpeg-release-essentials.zip ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile $zip -UseBasicParsing

    Write-Host "Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $zip -DestinationPath $FfmpegDir -Force
    $Extracted = Get-ChildItem $FfmpegDir -Filter "ffmpeg-*" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($Extracted) {
        Move-Item (Join-Path $Extracted.FullName "bin/ffmpeg.exe") $FfmpegExe -Force
        Move-Item (Join-Path $Extracted.FullName "bin/ffprobe.exe") "$FfmpegDir/ffprobe.exe" -Force
        Remove-Item -Recurse -Force $Extracted.FullName
    }
    Remove-Item -Force $zip
    Write-Host "ffmpeg ready at $FfmpegDir" -ForegroundColor Green
} else {
    Write-Host "ffmpeg already present" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Vendor download complete! ===" -ForegroundColor Green
Write-Host "Run .\build\windows-build.ps1 to build." -ForegroundColor Cyan
