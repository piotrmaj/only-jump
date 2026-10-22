# Only Jump — plan

A phone-first vertical platform climber in the spirit of Icy Tower: run left
and right, bounce up an endless tower of ice platforms, chase floor count.
Built with Flutter + Flame, shipped to Android.

## v0.1 — the very basic version (this repo)

Goal: a playable loop that already feels like the genre, and that can be
verified without a phone.

Scope:

- One fixed-width tower (480 world units), endless upward.
- Player with acceleration, friction, gravity, jump, coyote time, jump buffer.
- Procedurally generated ice floors, each reachable from the one below.
- Camera that only moves up; score = highest floor climbed; best score in
  memory; falling below the screen ends the run and offers a restart.
- Controls: on-screen left / right / jump (multi-touch), hold jump to chain
  hops, tap to jump, keyboard for desktop testing.
- Android build, portrait, immersive fullscreen.

Explicitly not in v0.1: art, audio, combo scoring, power-ups, crumbling
platforms, persistence, menus, monetisation.

Acceptance criteria (enforced by tests):

- `flutter test` is green.
- A single jump clears one floor but never two.
- No double jump; coyote time and jump buffering work, and holding jump hops
  one floor at a time.
- Generated floors are inside the level and reachable.
- A greedy bot climbs ≥ 60 floors in 60 simulated seconds on the default
  tuning, and reaches ≥ 15 floors in 20 s runs across seeds 1–8.
- 10 random-input runs keep physics finite and inside bounds.
- The painter produces screenshots in `test/artifacts/`.

## Architecture

```
lib/
  sim/            pure Dart, no Flutter imports, deterministic
    game_sim.dart       fixed-step physics, platform streaming, camera, score
    sim_config.dart     every tunable in one place
    bots.dart           idle / greedy / random players
    input_script.dart   "40 right / 1 right+jump" recording format
    harness.dart        drive the sim, trace, ASCII dump, failure context
    ascii_view.dart     debug view of a frame
  render/
    sim_painter.dart    single source of truth for visuals (game + goldens)
  game/
    only_jump_game.dart Flame shell: fixed-step accumulator, input, HUD state
  ui/
    game_screen.dart    HUD, touch controls, game over overlay, keyboard
```

Why the split: gameplay must be testable in milliseconds, on CI, with no
emulator. Flame only renders snapshots and feeds input, so the phone and the
test harness run the same physics.

## Feedback loop (how the agent plays and validates features)

Fast loop, in order of cost:

1. `dart run tool/play.dart --frames 1200 --min-floors 15`
   Headless bot run, prints a summary, an ASCII board and a climb sparkline.
   Seconds, no widgets.
2. `flutter test`
   Physics, bot, fuzz, parser and screenshot tests. Tens of seconds.
3. `flutter test test/render_artifacts_test.dart --update-goldens`
   Then read `test/artifacts/frame_*.png` to check visuals (I can open PNGs).
4. `powershell -File tool/install-device.ps1 -Screenshot artifacts/device.png`
   Real Samsung device: build, install, launch, screenshot, optional logcat.
5. `flutter run` for interactive tuning.

Rules that keep this honest:

- Every new mechanic gets a sim-level test and, where visible, an artifact
  screenshot.
- Every bug fix starts with a failing scenario in `test/` (script or bot).
- Tunables live in `SimConfig`; no magic numbers in the renderer or UI.
- Scripts are text files, so a regression is reproducible and reviewable.

## Roadmap

### v0.2 — the Icy Tower feel
- Sprint jump: holding one direction builds speed, then a jump spins the
  character three floors high with a gold star trail (FDR-002).
- Milestone safe floors: the start floor and every 50th floor span the whole
  tower (FDR-003).
- Wall-jump off the level edges (the signature move).
- Combo scoring: chained jumps before landing on a lower floor, 3-second
  window, floors squared payout and reward names (FDR-004).
- Floor markers every 10 floors + new floor palette.
- Tests: sprint jump clears three floors but never four; normal jump still
  clears one; wall-jump apex; combo counter rules.

### v0.3 — content and progression
- High score persistence (`shared_preferences`).
- Simple menu: play, best, sound toggle.
- One alternate character skin and 3 tower themes.
- Tests: persistence round-trip, theme selection.

### v0.4 — hazards
- Crumbling platforms, springs, moving platforms.
- Difficulty ramp by height.
- Tests: each hazard type in isolation + a seeded 2-minute survival run.

### v0.5 — ship
- Icon, splash, store screenshots from `test/artifacts/` + device shots.
- Signed release APK, versioning, changelog.
- Device smoke test on the Samsung after every release build.

## Tuning notes

- `floorSpacing` 88 vs jump apex ~132 → comfortable single-floor steps.
- `reachLimit` 150 keeps every next floor reachable and matches the greedy
  bot's horizontal reach.
- `cameraAnchor` 0.62 gives room to see the next floors and the drop below.
