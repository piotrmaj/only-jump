---
name: install-samsung
description: Use when the user asks to install, deploy, run, or put Only Jump on their Samsung/Android phone. Builds the APK, connects over USB or wireless debugging, installs, launches, verifies the foreground app, and can capture a screenshot.
---

# Install Only Jump on the phone

Everything runs through `tool/install-device.ps1` (PowerShell, Windows). It
builds the APK, finds the phone, installs, launches and verifies it.

## Quick path

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File tool/install-device.ps1 -Screenshot artifacts/device.png
```

Then read `artifacts/device.png` to confirm the game actually rendered.

## If no phone is found

Ask the user for exactly one of these — never guess the address:

1. **USB**: enable Developer options → USB debugging, plug the phone in,
   unlock it and accept the debugging prompt.
2. **Wireless debugging** (same Wi-Fi): Developer options → Wireless
   debugging → "Pair device with pairing code". Ask for the `IP:port` shown
   *and* the 6-digit code, then run:

```powershell
powershell -ExecutionPolicy Bypass -File tool/install-device.ps1 -Pair 192.168.0.23:37123 -Code 123456
```

Pairing is needed once per network. If `adb devices` already lists the phone,
skip pairing entirely. When pairing, the port changes every time the dialog
opens — always use the port currently displayed, and pair quickly before the
dialog closes. Later runs only need the quick path; the script caches the
wireless endpoint in `android/local.properties` (`phoneAdb=host:port`) and the
serial can be set with `phoneAdbSerial=<serial>`.

Run without `-Pair` after pairing. `-ListDevices` shows what adb sees.

## Useful flags

| Flag | Purpose |
| --- | --- |
| `-Screenshot <path>` | pull a PNG from the phone (for visual checks) |
| `-Logs` | print the last `flutter` logcat lines |
| `-Release` | build/install the release APK |
| `-NoBuild` | install the existing APK without rebuilding |
| `-Serial <serial>` | pick a device by serial |
| `-Endpoint host:port` | connect to a known wireless endpoint |
| `-ListDevices` | list connected devices and models |

Equivalent of `flutter run`: this is a debug build, but it does not attach a
debugger or hot-reload. After installing, changes need another run.

## Troubleshooting

- **unauthorized** → unlock the phone, tap "Allow" on the prompt, rerun.
- **INSTALL_FAILED_UPDATE_INCOMPATIBLE** → the APK signing key changed; run
  `adb -s <device> uninstall com.onlyjump.only_jump`, then rerun the script.
- **No device found over wireless** → phone and PC must be on the same
  network and Wireless debugging must stay enabled; re-pair if it was toggled.
- **Build fails** → run `flutter doctor -v`, fix the Android toolchain
  (this machine uses `%LOCALAPPDATA%\Android\Sdk`).

## After installing

1. Confirm the printed line says the app is running.
2. If `-Screenshot` was used, open the PNG and describe what is on screen.
3. For a crash, rerun with `-Logs` and read the Flutter exception.
