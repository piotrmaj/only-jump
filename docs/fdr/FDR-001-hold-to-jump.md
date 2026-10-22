# FDR-001: Hold to Jump

**Status:** Active
**Last reviewed:** 2026-10-22

## Overview

Only Jump is played one-thumbed on a phone, so jump is a held control rather
than a sequence of precise taps. While JUMP is down, the character bounces
again every time it touches a floor. The same rule covers tapping once,
buffered presses just before landing, and keyboard play, so there is only one
jump behavior to learn and to test.

## Behavior

- Pressing JUMP jumps once when the character is on a floor or inside the
  coyote window after leaving one.
- Keeping JUMP held keeps hopping: each landing immediately becomes the next
  jump, with no release and re-press.
- Releasing JUMP lets the current hop finish. The next press jumps again.
- Holding JUMP while running off a ledge jumps at the ledge, within the
  coyote window — it is not possible to walk off a ledge while holding JUMP.
- A mid-air press or hold never adds an extra jump. It is remembered for a
  short time and fires on landing (jump buffering).
- Tapping anywhere, or tapping the JUMP button, still means exactly one jump.
- Taps are never swallowed by the physics tick, so tapping works the same on
  60 Hz and 120 Hz screens.
- Keyboard space / W / up behaves exactly like the button: holding the key
  auto-hops, tapping it jumps once.
- Left/right can be held at the same time as JUMP (multi-touch).

## Design Decisions

### 1. Level-triggered jump, not edge-triggered

**Decision:** A held JUMP is a standing "please jump as soon as possible"
request; the jump fires whenever the character is on or near the ground.
**Why:** Releasing and re-pressing between hops adds timing noise that has
nothing to do with the skill being tested (aiming and climbing). Continuous
bouncing matches the Icy Tower lineage and lets a player focus a thumb on
movement.
**Tradeoff:** Less deliberate control. Holding the button while planning a
route causes a hop the player may not have wanted.

### 2. One mechanism for tap, buffer and hold

**Decision:** Holding JUMP keeps the existing jump buffer topped up instead of
introducing a separate auto-repeat timer.
**Why:** Tap, tap-just-before-landing and hold all become the same sentence:
"a jump request, held or recent, fires at the next legal moment." One rule,
one tunable, one set of tests.
**Tradeoff:** The buffer duration now means two things — how forgiving a late
tap is, and how long a released press still counts. Tuning it affects both.

### 3. No minimum time on the ground

**Decision:** A held JUMP may launch on the very step the character lands; no
cooldown or minimum grounded time.
**Why:** Chained hops are the feature. Landing is resolved before the jump in
the same step, so a floor still counts toward the score even though the
character leaves it immediately. The outcome is a continuous rhythm rather
than stuttery taps.
**Tradeoff:** The character can look nearly airborne all the time, which leaves
little room for future landing animations or ground-only interactions.

### 4. Coyote time still applies while holding

**Decision:** A held JUMP fires from the coyote window just like a tap does.
**Why:** "Jump as soon as possible" must hold at ledges too; otherwise holding
JUMP would silently behave differently from tapping at exactly the same
moment.
**Tradeoff:** You cannot run off a ledge while holding JUMP — the character
always jumps first.

### 5. Button reports held state; the board reports taps

**Decision:** The JUMP button streams down/up states, while tapping the board
sends a single-step request. Both paths feed the same simulation input.
**Why:** Held state is reliable under multi-touch and has no gesture-recognition
delay, but tapping the whole screen remains the most discoverable way to start
playing. The simulation consumes intent, not widgets, so both stay testable
headlessly.
**Tradeoff:** Two input paths must be kept behaviorally identical, and both are
covered by tests.

## Related

- **ADRs:** none yet.
- **FDRs:** none yet (this is the first FDR).

## Open Questions

- Variable jump height (release early for a shorter hop) would make holding
  strictly the highest jump, but that changes the feel and is undecided.
- Should a held JUMP restart the run after game over, or is the explicit
  button/Enter the only way back in?
- First-run onboarding could tell players that holding JUMP is a valid (and
  easier) way to play.
