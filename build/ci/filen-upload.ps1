<#
.SYNOPSIS
    Uploads one or more Windows artifacts (matched by a glob) to a Filen.io
    directory via the classic filen-cli v0.0.36 (win-x64 standalone binary).
.PARAMETER LocalGlob
    Glob of local files to upload, e.g. "out\guinea-mpeg-*-x86_64.zip".
.PARAMETER CloudDir
    Destination Filen.io directory, e.g. "/Shared/apps/guinea-mpeg".
.EXAMPLE
    .\build\ci\filen-upload.ps1 -LocalGlob "out\guinea-mpeg-*-x86_64.zip" -CloudDir "/Shared/apps/guinea-mpeg"
#>

param(
    [Parameter(Mandatory)][string]$LocalGlob,
    [Parameter(Mandatory)][string]$CloudDir
)

$ErrorActionPreference = "Stop"

$FilenVersion = "0.0.36"
$FilenBin = Join-Path $env:TEMP "filen-cli-v$FilenVersion-win-x64.exe"
if (-not (Test-Path $FilenBin)) {
    $Url = "https://github.com/FilenCloudDienste/filen-cli/releases/download/v$FilenVersion/filen-cli-v$FilenVersion-win-x64.exe"
    Write-Host "Downloading filen-cli ..." -ForegroundColor Yellow
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $FilenBin
}

if (-not $env:FILEN_AUTH_CONFIG_B64) {
    throw "FILEN_AUTH_CONFIG_B64 secret is not set"
}
[System.IO.File]::WriteAllBytes(
    (Join-Path $PWD ".filen-cli-auth-config"),
    [Convert]::FromBase64String($env:FILEN_AUTH_CONFIG_B64)
)

$files = Get-ChildItem $LocalGlob
if (-not $files) {
    throw "No files match $LocalGlob"
}

# mkdir is idempotent and harmless when the folder already exists.
& $FilenBin --quiet --no-autocomplete mkdir $CloudDir 2>$null | Out-Null

foreach ($f in $files) {
    & $FilenBin --quiet --no-autocomplete upload $f.FullName $CloudDir
    if ($LASTEXITCODE -ne 0) {
        throw "upload of $($f.Name) failed (exit $LASTEXITCODE)"
    }
    Write-Host "Uploaded $($f.Name) -> $CloudDir" -ForegroundColor Green
}