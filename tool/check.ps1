# Build + test + play headlessly. Use -SkipDevice to keep it fast.
param(
  [int]$Frames = 1800,
  [int]$Seed = 7,
  [int]$MinFloors = 25,
  [switch]$SkipAnalyze
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $SkipAnalyze) {
  Write-Host '== flutter analyze ==' -ForegroundColor Cyan
  flutter analyze
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host '== flutter test ==' -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '== bot playthrough ==' -ForegroundColor Cyan
dart run tool/play.dart --frames $Frames --seed $Seed --min-floors $MinFloors --no-ascii
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'All checks passed.' -ForegroundColor Green
