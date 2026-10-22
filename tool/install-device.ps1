<#
.SYNOPSIS
  Build Only Jump and install it on an Android phone (USB or wireless debugging).

.DESCRIPTION
  Mirrors android/send-apk.sh from the assistant repo, adapted for Windows and
  Flutter. Builds the APK, finds the phone (USB, configured wireless endpoint,
  or mDNS discovery of a known serial), installs, launches, and can grab a
  screenshot for visual verification.

  Phone hints are read from android/local.properties (gitignored):
    phoneAdbSerial=R5CY12Q1KFX     stable serial, discovered over mDNS
    phoneAdb=192.168.0.23:37123    cached wireless endpoint

  Env overrides: ANDROID_PHONE_SERIAL, ANDROID_PHONE_ADB.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool/install-device.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool/install-device.ps1 -Pair 192.168.0.23:37123 -Code 123456

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool/install-device.ps1 -Screenshot artifacts/device.png -Logs
#>
[CmdletBinding()]
param(
  [string]$Serial = $env:ANDROID_PHONE_SERIAL,
  [string]$Endpoint = $env:ANDROID_PHONE_ADB,
  [string]$Pair = '',
  [string]$Code = '',
  [switch]$Release,
  [switch]$NoBuild,
  [string]$Screenshot = '',
  [switch]$Logs,
  [switch]$ListDevices,
  [int]$LaunchWaitSeconds = 3
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$appId = 'com.onlyjump.only_jump'
$activity = "$appId/.MainActivity"

function Write-Step([string]$Message) { Write-Host "[..] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[ok] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[!!] $Message" -ForegroundColor Yellow }
function Stop-WithError([string]$Message, [string[]]$Hints = @()) {
  Write-Host "[xx] $Message" -ForegroundColor Red
  foreach ($hint in $Hints) { Write-Host "     $hint" -ForegroundColor DarkGray }
  exit 1
}

# ---------------------------------------------------------------------------
# adb
# ---------------------------------------------------------------------------
function Find-Adb {
  $candidates = @()
  foreach ($envName in @('ANDROID_HOME', 'ANDROID_SDK_ROOT')) {
    $value = [Environment]::GetEnvironmentVariable($envName)
    if ($value) { $candidates += (Join-Path $value 'platform-tools\adb.exe').Replace('\', [IO.Path]::DirectorySeparatorChar) }
  }
  if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe') }
  $candidates += 'C:\Android\platform-tools\adb.exe'

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) { return $candidate }
  }
  $command = Get-Command adb -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  return $null
}

$adb = Find-Adb
if (-not $adb) {
  Stop-WithError 'adb not found.' @(
    'Install Android platform-tools, or set ANDROID_HOME to your SDK folder.',
    'Expected at: %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe'
  )
}

& $adb start-server | Out-Null

function Get-ConnectedDevices {
  $devices = @()
  foreach ($line in (& $adb devices 2>$null)) {
    if ($line -match '^(\S+)\s+device\s*$') { $devices += $matches[1] }
  }
  return , $devices
}

if ($ListDevices) {
  $devices = Get-ConnectedDevices
  if ($devices.Count -eq 0) {
    Write-Host 'No devices connected.'
  } else {
    foreach ($device in $devices) {
      $model = (& $adb -s $device shell getprop ro.product.model | Out-String).Trim()
      Write-Host "$device`t$model"
    }
  }
  exit 0
}

# ---------------------------------------------------------------------------
# Phone hints from android/local.properties
# ---------------------------------------------------------------------------
$configPath = Join-Path $root 'android/local.properties'
if (Test-Path $configPath) {
  foreach ($line in (Get-Content $configPath)) {
    if ($line -match '^\s*phoneAdbSerial\s*=\s*(.+?)\s*$' -and -not $Serial) {
      $Serial = $matches[1]
    }
    if ($line -match '^\s*phoneAdb\s*=\s*(.+?)\s*$' -and -not $Endpoint) {
      $Endpoint = $matches[1]
    }
  }
}

# ---------------------------------------------------------------------------
# Pairing (one-off per Wi-Fi network)
# ---------------------------------------------------------------------------
if ($Pair) {
  if (-not $Code) {
    Stop-WithError 'Pairing needs the 6-digit code from the phone.' @(
      'On the phone: Developer options > Wireless debugging > Pair device with pairing code.',
      'Then run: tool/install-device.ps1 -Pair <ip:pairPort> -Code <code>'
    )
  }
  Write-Step "Pairing with $Pair ..."
  $pairOutput = (& $adb pair $Pair $Code 2>&1 | Out-String)
  Write-Host $pairOutput.Trim()
  if ($pairOutput -notmatch 'Successfully paired') {
    $hints = @(
      'Check the IP:port and code on the "Pair device with pairing code" screen.',
      'The pairing port changes every time that screen opens; reopen it for a fresh port.',
      'The phone and this PC must be on the same Wi-Fi network.'
    )
    if ($pairOutput -match 'protocol fault') {
      $hints = @(
        'The pairing dialog was probably closed or the port expired.',
        'Reopen "Pair device with pairing code" and use the new port + code.'
      ) + $hints
    }
    Stop-WithError 'adb pair failed.' $hints
  }
  Write-Ok 'Paired.'
}

# ---------------------------------------------------------------------------
# Find the target device
# ---------------------------------------------------------------------------
$target = ''
$devices = Get-ConnectedDevices

if ($Serial) {
  foreach ($device in $devices) {
    if ($device -like "*$Serial*") { $target = $device; break }
  }
}

if (-not $target -and $Serial) {
  Write-Step "Looking for $Serial over mDNS (wireless debugging)..."
  $mdns = (& $adb mdns services 2>$null | Out-String)
  if ($mdns -match 'unknown command|error') {
    Write-Warn "adb mdns is not available here: $($mdns.Trim())"
  }
  $pattern = '(?im)^[^\r\n]*' + [regex]::Escape($Serial) + '[^\r\n]*?((?:\d{1,3}\.){3}\d{1,3}:\d{2,5})'
  foreach ($match in [regex]::Matches($mdns, $pattern)) {
    $candidate = $match.Groups[1].Value
    Write-Step "Trying $candidate ..."
    $connectOutput = (& $adb connect $candidate 2>&1 | Out-String)
    if ($connectOutput -match 'connected to|already connected to') {
      $target = $candidate
      break
    }
  }
}

if (-not $target -and $Endpoint) {
  Write-Step "Connecting to $Endpoint ..."
  $connectOutput = (& $adb connect $Endpoint 2>&1 | Out-String)
  if ($connectOutput -match 'connected to|already connected to') {
    $target = $Endpoint
  } else {
    Write-Warn $connectOutput.Trim()
  }
}

if (-not $target) {
  $devices = Get-ConnectedDevices
  if ($devices.Count -eq 1) {
    $target = $devices[0]
    Write-Step "Using the only connected device: $target"
  }
}

if (-not $target) {
  $rawDevices = (& $adb devices | Out-String)
  if ($rawDevices -match '(?m)^\S+\s+unauthorized') {
    Stop-WithError 'Phone connected but not authorized.' @(
      'Unlock the phone and tap "Allow" on the USB debugging prompt.',
      'Then run this script again.'
    )
  }
  Stop-WithError 'No Android phone found.' @(
    'USB: enable Developer options > USB debugging, plug the phone in, allow the prompt.',
    'Wireless: Developer options > Wireless debugging > Pair device with pairing code,',
    'then run: tool/install-device.ps1 -Pair <ip:pairPort> -Code <code>',
    'Both devices must be on the same Wi-Fi network.'
  )
}

# Remember a wireless endpoint for the next run.
if ($target -match ':\d+$' -and (Test-Path $configPath)) {
  $lines = @(Get-Content $configPath)
  if ($lines -match '^\s*phoneAdb\s*=') {
    $lines = $lines -replace '^\s*phoneAdb\s*=.*$', "phoneAdb=$target"
  } else {
    $lines += "phoneAdb=$target"
  }
  Set-Content -Path $configPath -Value $lines
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
$mode = if ($Release) { 'release' } else { 'debug' }
if (-not $NoBuild) {
  Write-Step "Building $mode APK (first build can take a few minutes)..."
  & flutter build apk "--$mode"
  if ($LASTEXITCODE -ne 0) {
    Stop-WithError "flutter build apk --$mode failed." @(
      'Run "flutter doctor" for toolchain problems.',
      'Free the phone: close the app if the build fails on a locked file (rare on Windows).'
    )
  }
}

$apk = Join-Path $root "build/app/outputs/flutter-apk/app-$mode.apk"
if (-not (Test-Path $apk)) {
  Stop-WithError "APK not found at $apk" @('Re-run without -NoBuild.')
}

# ---------------------------------------------------------------------------
# Install + launch + verify
# ---------------------------------------------------------------------------
Write-Step "Installing on $target ..."
$installOutput = (& $adb -s $target install -r $apk 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $installOutput -notmatch 'Success') {
  Write-Host $installOutput.Trim()
  Stop-WithError 'Install failed.' @(
    'If this is INSTALL_FAILED_UPDATE_INCOMPATIBLE (different signing key), run:',
    "  adb -s $target uninstall $appId",
    'and then run this script again.'
  )
}
Write-Ok 'APK installed.'

& $adb -s $target shell am force-stop $appId | Out-Null
$startOutput = (& $adb -s $target shell am start -W -n $activity 2>&1 | Out-String)
if ($startOutput -notmatch 'Status: ok' -and $startOutput -notmatch 'LaunchState') {
  Write-Warn "The launch command was not confirmed: $($startOutput.Trim())"
}
Start-Sleep -Seconds ([Math]::Max(1, $LaunchWaitSeconds))

$model = (& $adb -s $target shell getprop ro.product.model | Out-String).Trim()
$androidVersion = (& $adb -s $target shell getprop ro.build.version.release | Out-String).Trim()

$windowState = (& $adb -s $target shell dumpsys window windows 2>$null | Out-String)
$activityState = (& $adb -s $target shell dumpsys activity activities 2>$null | Out-String)
if ($windowState -match "only_jump" -or $activityState -match "only_jump") {
  Write-Ok "Only Jump is running on $model (Android $androidVersion) at $target."
} else {
  Write-Warn "Installed on $model (Android $androidVersion), but the foreground window was not confirmed. Check the phone."
}

if ($Screenshot) {
  $shotPath = $Screenshot
  if (-not [IO.Path]::IsPathRooted($shotPath)) { $shotPath = Join-Path $root $shotPath }
  $shotDir = Split-Path -Parent $shotPath
  if ($shotDir) { New-Item -ItemType Directory -Force -Path $shotDir | Out-Null }

  $remote = '/sdcard/only_jump_screen.png'
  & $adb -s $target shell screencap -p $remote 2>&1 | Out-Null
  & $adb -s $target pull $remote $shotPath 2>&1 | Out-Null
  & $adb -s $target shell rm -f $remote 2>&1 | Out-Null

  if (Test-Path $shotPath) {
    Write-Ok "Screenshot saved: $shotPath"
  } else {
    Write-Warn 'Screenshot failed.'
  }
}

if ($Logs) {
  Write-Host ''
  Write-Host '--- flutter logs (last 120 lines) ---'
  & $adb -s $target logcat -d -t 400 -s flutter 2>$null | Select-Object -Last 120 | ForEach-Object { Write-Host $_ }
}

exit 0
