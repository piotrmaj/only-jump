# Only Jump

A small, phone-first vertical platform climber inspired by Icy Tower: run,
jump, and climb an endless tower of ice floors. Flutter + Flame.

## Play

```powershell
flutter run              # attached device or emulator
flutter run -d chrome    # quick desktop-ish check
```

Controls: on-screen `◀` `▶` and `JUMP` (hold it to keep hopping), tap
anywhere to jump. Keyboard: arrows / A-D, space / W / up (hold to keep
hopping), `R` restart, `G` debug overlay.

Hold one direction to run: speed sets jump height. A standing jump clears one
floor, a full run clears three, and bumping off the side walls keeps and builds
speed for a launch of up to six floors. Boosted jumps spin the character and
leave a gold star trail. The start floor and every 50th floor are full-width
safe floors.

Every new floor is worth 10 points. Link two or more boosted jumps without
landing lower to build a combo: a 3-second clock, floors squared as the bonus,
and Icy Tower reward names from `Good!` to `No way!`. A one-floor hop or a fall
ends the chain and cashes it in.

## Install on a Samsung / Android phone

USB or wireless debugging, one command:

```powershell
powershell -ExecutionPolicy Bypass -File tool/install-device.ps1 -Screenshot artifacts/device.png
```

First time on Wi-Fi (Developer options → Wireless debugging → Pair device with
pairing code):

```powershell
powershell -ExecutionPolicy Bypass -File tool/install-device.ps1 -Pair 192.168.0.23:37123 -Code 123456
```

The script finds the phone (USB, cached endpoint, or mDNS), builds, installs,
launches, verifies the foreground app and can pull a screenshot and logcat.
See `.opencode/skills/install-samsung/SKILL.md` for the full flag list.

## Test without a phone

The game logic is a deterministic, Flutter-free simulation, so it can be
played by bots and scripts:

```powershell
dart run tool/play.dart --frames 1800 --bot greedy --min-floors 25
dart run tool/play.dart --script test/scripts/demo.txt
flutter test                       # physics, bots, fuzz, smoke, screenshots
flutter test test/render_artifacts_test.dart   # regenerate PNGs
```

`tool/play.dart` prints floors, jumps, points, best combo, status, an ASCII
board and a climb sparkline. Screenshots land in `test/artifacts/`.

## Layout

- `lib/sim/` — deterministic game sim, bots, scripted input, harness.
- `lib/render/sim_painter.dart` — the only renderer (game + screenshots).
- `lib/game/` — Flame shell and fixed-step loop.
- `lib/ui/` — HUD, touch controls, game over.
- `test/` — physics, climb, fuzz, parser, smoke, screenshot artifacts.
- `docs/fdr/` — feature decision records: what each mechanic does and why.
- `PLAN.md` — scope, feedback loop, roadmap.

## Status

v0.2 in progress: sprint spin jump, safe floors, combos and scoring. See
`PLAN.md` for the roadmap.
