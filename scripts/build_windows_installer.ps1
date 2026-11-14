# Builds a Windows installer (Setup.exe) for Counseling IS.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\build_windows_installer.ps1
#
# Requirements:
#   - Flutter SDK on PATH
#   - Inno Setup 6:  winget install --id JRSoftware.InnoSetup -e

$ErrorActionPreference = 'Stop'

function Fail([string]$message) {
    Write-Host "error: $message" -ForegroundColor Red
    exit 1
}

Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Fail 'flutter not found on PATH'
}

Write-Host ''
Write-Host '==> Building release app'
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Fail "flutter build windows failed (exit $LASTEXITCODE)" }

$releaseDir = 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $releaseDir 'counseling_is.exe'))) {
    Fail "expected counseling_is.exe not found in $releaseDir"
}

$flutterAssets = Join-Path $releaseDir 'data\flutter_assets'
$requiredAssets = @(
    'assets\forms\branding\carranglan_school_seal.png',
    'assets\forms\branding\deped_seal.png',
    'assets\forms\branding\deped_matatag_banner.jpg',
    'assets\fonts\roboto-regular.ttf',
    'assets\fonts\roboto-bold.ttf'
)
foreach ($asset in $requiredAssets) {
    if (-not (Test-Path (Join-Path $flutterAssets $asset))) {
        Fail "required PDF asset missing from Windows release: $asset"
    }
}

$line = Get-Content 'pubspec.yaml' | Where-Object { $_ -match '^\s*version:\s*\S' } | Select-Object -First 1
if ($line -match '^\s*version:\s*(\d+\.\d+\.\d+)') {
    $version = $Matches[1]
} else {
    Fail 'could not read version from pubspec.yaml'
}

$iscc = $null
$candidates = @(
    "$(${env:ProgramFiles(x86)})\Inno Setup 6\ISCC.exe",
    "$($env:ProgramFiles)\Inno Setup 6\ISCC.exe",
    "$($env:LOCALAPPDATA)\Programs\Inno Setup 6\ISCC.exe"
)
foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) { $iscc = $candidate; break }
}
if (-not $iscc) {
    $command = Get-Command 'iscc.exe' -ErrorAction SilentlyContinue
    if ($command) { $iscc = $command.Source }
}
if (-not $iscc) {
    Fail 'Inno Setup 6 not found. Install it with: winget install --id JRSoftware.InnoSetup -e'
}

Write-Host ''
Write-Host "==> Compiling installer (version $version)"
& $iscc "/DMyAppVersion=$version" (Join-Path $PSScriptRoot 'windows_installer.iss')
if ($LASTEXITCODE -ne 0) { Fail "ISCC failed (exit $LASTEXITCODE)" }

$setup = "build\windows\installer\CounselingIS-Setup-$version.exe"
if (-not (Test-Path $setup)) { Fail "expected installer not found at $setup" }

$hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()
Write-Host ''
Write-Host '==> Done'
Write-Host "Installer: $setup"
Write-Host "SHA-256:  $hash"
