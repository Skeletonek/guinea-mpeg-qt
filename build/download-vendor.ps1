<#
.SYNOPSIS
    Downloads vendored build dependencies for GuineaMPEG Windows builds.
.DESCRIPTION
    Fetches mpv-dev-x86_64 (libmpv SDK) and ffmpeg/ffprobe
    into build/vendor/ so the build script doesn't need network access.
.EXAMPLE
    .\build\download-vendor.ps1
.PARAMETER OnlyMpv
    Only download the mpv-dev-x86_64 bundle, skipping ffmpeg/ffprobe.
.PARAMETER OnlyFfmpeg
    Only download ffmpeg/ffprobe, skipping the mpv-dev-x86_64 bundle.
.PARAMETER Force
    Re-download dependencies even if they are already present.
#>

param(
    [switch]$OnlyMpv,
    [switch]$OnlyFfmpeg,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$VendorDir = Join-Path (Join-Path $ProjectRoot "build") "vendor"
New-Item -ItemType Directory -Force -Path $VendorDir | Out-Null

# ---- Download configuration ----
# Change these URLs to point at a different mirror or build variant.
$MpvReleaseApiUrl = "https://api.github.com/repos/zhongfly/mpv-winbuild/releases/latest"
$MpvAssetPattern  = '^mpv-dev-x86_64-\d{8}'
$MpvExcludedPattern = '-v3-'
$FfmpegReleaseUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.1-latest-win64-gpl-shared-8.1.zip"
$FfmpegChecksumsUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/checksums.sha256"
$UserAgent = "guinea-mpeg-vendor/1.0"

function Invoke-UrlRequest {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$OutputFile
    )

    if (-not (Get-Command "curl" -ErrorAction SilentlyContinue) -and -not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
        throw "curl not found. Install curl or use a system with curl available (Windows 10 1803+ bundles it)."
    }
    if ($OutputFile) {
        Write-Host "Downloading $([System.IO.Path]::GetFileName($OutputFile)) ..." -ForegroundColor Yellow
        & curl.exe --location --fail --silent --show-error --user-agent $script:UserAgent --output $OutputFile --url $Url
        if ($LASTEXITCODE -ne 0) { throw "download of $Url failed (curl exit $LASTEXITCODE)" }
    } else {
        return (& curl.exe --location --fail --silent --show-error --user-agent $script:UserAgent --url $Url)
    }
}

function Expand-Archive7z {
    param(
        [Parameter(Mandatory)][string]$ArchivePath,
        [Parameter(Mandatory)][string]$Destination
    )

    Write-Host "Extracting..." -ForegroundColor Yellow
    if (-not (Get-Command "7z" -ErrorAction SilentlyContinue)) {
        throw "7-Zip (7z) not found in PATH. Install 7-Zip."
    }
    $null = 7z x $ArchivePath -o"$Destination" -y
    if ($LASTEXITCODE -ne 0) { throw "extraction of $ArchivePath failed" }
    Remove-Item -Force $ArchivePath
}

function Install-Mpv {
    param(
        [string]$VendorDir,
        [string]$MpvDir
    )

    Write-Host "=== mpv-dev-x86_64 ===" -ForegroundColor Cyan

    $release = Invoke-UrlRequest -Url $script:MpvReleaseApiUrl | ConvertFrom-Json
    $asset = $release.assets | Where-Object { $_.name -match $script:MpvAssetPattern -and $_.name -notmatch $script:MpvExcludedPattern } | Select-Object -First 1
    if (-not $asset) {
        throw "No mpv-dev-x86_64 asset found in latest $($script:MpvReleaseApiUrl) release"
    }

    $archive = Join-Path $VendorDir $asset.name
    Invoke-UrlRequest -Url $asset.browser_download_url -OutputFile $archive

    Expand-Archive7z -ArchivePath $archive -Destination $VendorDir

    # Restructure: files extract into vendor root, move into mpv-dev-x86_64/
    if (Test-Path (Join-Path $VendorDir "include/mpv")) {
        New-Item -ItemType Directory -Force -Path $MpvDir | Out-Null
        Move-Item (Join-Path $VendorDir "include") "$MpvDir/include" -Force
        Move-Item (Join-Path $VendorDir "libmpv-2.dll") "$MpvDir/libmpv-2.dll" -Force
        Remove-Item (Join-Path $VendorDir "libmpv.dll.a") -Force -ErrorAction SilentlyContinue
    }
    Write-Host "mpv-dev-x86_64 ready at $MpvDir" -ForegroundColor Green
}

function Install-Ffmpeg {
    param(
        [string]$VendorDir,
        [string]$FfmpegDir
    )

    Write-Host "=== ffmpeg ===" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $FfmpegDir | Out-Null

    $assetName = [System.IO.Path]::GetFileName($script:FfmpegReleaseUrl)
    $archive = Join-Path $FfmpegDir $assetName
    Invoke-UrlRequest -Url $script:FfmpegReleaseUrl -OutputFile $archive

    # Verify the download against BtbN's published checksums
    $checksumsFile = Join-Path $FfmpegDir "checksums.sha256"
    Invoke-UrlRequest -Url $script:FfmpegChecksumsUrl -OutputFile $checksumsFile
    $expectedHash = Get-Content $checksumsFile | Where-Object { $_ -like "*$assetName*" } | Select-Object -First 1
    $expectedHash = if ($expectedHash) { ($expectedHash -split '\s+')[0] } else { $null }
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path $archive).Hash.ToLowerInvariant()
    if (-not $expectedHash -or $expectedHash -ne $actualHash) {
        throw "ffmpeg checksum mismatch (expected $expectedHash, got $actualHash)"
    }
    Write-Host "ffmpeg checksum OK." -ForegroundColor Green
    Remove-Item -Force $checksumsFile

    Expand-Archive7z -ArchivePath $archive -Destination $FfmpegDir
    $Extracted = Get-ChildItem $FfmpegDir -Filter "ffmpeg-*" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $Extracted) {
        throw "Extraction of $archive did not produce an 'ffmpeg-*' directory"
    }
    $BinDir = Join-Path $Extracted.FullName "bin"
    Move-Item (Join-Path $BinDir "ffmpeg.exe") (Join-Path $FfmpegDir "ffmpeg.exe") -Force
    Move-Item (Join-Path $BinDir "ffprobe.exe") (Join-Path $FfmpegDir "ffprobe.exe") -Force
    # The gpl-shared build needs its libav DLLs next to the executables
    Get-ChildItem $BinDir -Filter "*.dll" | Copy-Item -Destination $FfmpegDir -Force
    Remove-Item -Recurse -Force $Extracted.FullName
    Write-Host "ffmpeg ready at $FfmpegDir" -ForegroundColor Green
}

if ($OnlyMpv -and $OnlyFfmpeg) {
    throw "OnlyMpv and OnlyFfmpeg are mutually exclusive"
}
$WantMpv = $OnlyMpv -or -not $OnlyFfmpeg
$WantFfmpeg = $OnlyFfmpeg -or -not $OnlyMpv

$MpvDir = Join-Path $VendorDir "mpv-dev-x86_64"
$MpvH = Join-Path $MpvDir "include/mpv/client.h"
if ($WantMpv) {
    if ($Force -or -not (Test-Path $MpvH)) {
        Install-Mpv -VendorDir $VendorDir -MpvDir $MpvDir
    } else {
        Write-Host "mpv-dev-x86_64 already present" -ForegroundColor Green
    }
}

$FfmpegDir = Join-Path $VendorDir "ffmpeg"
$FfmpegExe = Join-Path $FfmpegDir "ffmpeg.exe"
$FfmpegDlls = Get-ChildItem $FfmpegDir -Filter "*.dll" -ErrorAction SilentlyContinue
if ($WantFfmpeg) {
    if ($Force -or -not (Test-Path $FfmpegExe) -or -not $FfmpegDlls) {
        Install-Ffmpeg -VendorDir $VendorDir -FfmpegDir $FfmpegDir
    } else {
        Write-Host "ffmpeg already present" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Vendor download complete! ===" -ForegroundColor Green
Write-Host "Run .\build\windows-build.ps1 to build." -ForegroundColor Cyan
