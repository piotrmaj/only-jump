# FDR-002: Sprint Jump and Wall Bounce

**Status:** Active
**Last reviewed:** 2026-10-22

## Overview

Speed is the jump mechanic. Run to build horizontal velocity, then jump: a
standing hop reaches one floor, a full run reaches three, and a wall bump can
push the character past the normal running top speed for a six-floor launch.
The edges of the tower are part of the movement rather than a wall to stop at:
the character visibly bumps off them, and a well timed bounce builds the speed
needed for the biggest jumps. A boosted jump spins the character and sheds a
trail of gold stars.

This replaces the earlier "charge for 0.6 s, then boost" model. The charge
timer is gone; the only thing that matters is velocity at take-off.

## Behavior

- Holding a direction accelerates the character up to 420 world units per
  second. There is no sprint meter and no build-up timer.
- Jump launch speed is a function of horizontal speed when the frame begins. A
  standing jump is unchanged; releasing the direction on the jump frame still
  uses the run's speed.
- The speed-to-height curve is quadratic: about 1 floor from a standstill, 3
  from a full run, and 6 from a wall-bounced top speed.
- Hitting the left or right edge reverses horizontal velocity and multiplies
  it by 1.15, capped at 600. The character bounces visibly instead of sticking.
- The bump takes over horizontal control for 0.12 s, so a held direction does
  not instantly cancel the rebound and the player has time to steer away.
- Holding the direction of travel after a bump keeps the extra speed. Steering
  back into the wall loses it, so chaining bumps is a skill.
- The character glows gold when moving faster than a walk. A jump that reaches
  three or more floors sets `spinJump`: the character spins and sheds gold
  stars until it lands.
- A jump span is capped at six floors; no tuning can produce seven.
- Floors are spaced 120 world units apart (was 88), so fewer floors are on
  screen and the difference between a hop and a super jump is more visible.
- Holding JUMP and a direction together turns the climb into a chained
  super-jump run (FDR-001).
- Stars never appear for normal jumps, and the trail is bounded so long chains
  stay cheap.

## Design Decisions

### 1. Velocity is the mechanic, not a stored charge

**Decision:** Remove `sprintCharge` and the build/release timers. Compute the
jump launch directly from `vx` at take-off.
**Why:** In the reference game the character's speed on the floor is what
determines jump height; a timer that fills on one platform is invisible and
does not reward wall movement. Direct velocity means the player can read the
mechanic from the character's movement and from the gold glow.
**Tradeoff:** Speed is now sensitive to input: releasing a direction for one
frame before jumping costs height (the frame-start velocity is used, so there
is a one-frame grace, but no more). It also makes any future speed modifiers
(ice, springs, downhill) affect jumps automatically.

### 2. A quadratic speed-to-height curve

**Decision:** `launch = jump + (max - jump) * (speed / wallBounceMax)^2`.
**Why:** A linear curve made a normal run clear four or five floors, which
turned the tower into an elevator. Squaring keeps walking jumps small, gives a
full run the familiar three-floor reward, and reserves the six-floor launch for
the wall-bounce speed range that most players will not reach by accident.
**Tradeoff:** The top end is steep: between 480 and 600 speed the jump grows
from four to six floors. Carrying wall-bounce speed becomes disproportionately
valuable, which is intended but hard to balance against future speed sources.

### 3. Walls bump automatically, but only carry speed if you steer

**Decision:** Every wall contact reverses `vx` and multiplies it by 1.15,
capped at 600. A 0.12 s lock ignores horizontal input after the bump.
**Why:** On a phone, requiring a frame-perfect reversal at the wall would make
the mechanic inaccessible. An automatic bump is readable, keeps the character
moving, and still rewards the Icy Tower technique: hold away from the wall as
you hit it, then hold the new direction to carry the extra speed. The lock
prevents holding into the wall from producing jitter.
**Tradeoff:** Simply running into a wall now speeds the character up, so speed
is easy to gain and the six-floor ceiling is reachable without precise timing.
The skill shifts from "bounce correctly" to "aim the resulting jump".

### 4. Six floors is the hard ceiling

**Decision:** Jump span is capped at six floors by capping jump launch, not by
clamping the landing.
**Why:** "Up to six platforms at once" needs a clear, testable maximum. Capping
the launch means every part of the jump (apex, spin, star trail, time in the
air) agrees with the limit, and a seventh floor is physically impossible.
**Tradeoff:** At wall-bounce speed the character spends a long time airborne
(about 1.7 s), which is a large commitment on a screen that only shows eight
floors.

### 5. Larger floor spacing

**Decision:** Increase `floorSpacing` from 88 to 120.
**Why:** With the old spacing, the character was almost two floors tall and the
tower read as cramped; a normal jump cleared 1.6 floors, so the difference
between a hop and a super jump was mostly hidden by the platform density. At
120, a standing jump clears one floor with margin and a full run clears three.
**Tradeoff:** Fewer floors are visible (about eight on a tall phone), so the
next landing can be off-screen after a six-floor jump and the camera has less
room to recover.

### 6. Cosmetic effects live in the simulation

**Decision:** The spin angle, the gold star trail and the gold speed glow are
simulated/deterministic state, not renderer-only animation. The glow level is
derived from velocity.
**Why:** The trail is deterministic, testable, and identical in headless
screenshots and on the phone. Bugs in the effect show up in tests instead of
only on a device.
**Tradeoff:** The frame snapshot carries a particle list and a speed ratio, and
the simulation pays a small per-frame cost for something that is purely visual.

### 7. Gold halo instead of a meter

**Decision:** Readiness is shown on the character as a gold glow that ramps with
speed.
**Why:** On a phone the player's eyes belong on the character and the next
floor. The glow matches the gold star reward, so the visual language is one
idea: gold means speed.
**Tradeoff:** The halo shows the sprint tier, but not the wall-bounce surplus
above 420; the biggest jumps are found by feel.

## Related

- **ADRs:** none yet.
- **FDRs:** FDR-001 (hold to jump — the two combine into chained jumps),
  FDR-003 (safe floors — the runway where speed can be built),
  FDR-004 (combos — each jump can add one to six floors to a chain).

## Open Questions

- Should a wall bump reset the combo timer or count as reaching a floor? It
  currently does neither; only landings matter.
- The 0.12 s bump lock is enough to feel, but is it enough to stop accidental
  double bumps when the player holds into the wall?
- Should wall bounces work mid-air at full strength, or only when grounded? The
  current model is uniform, which lets players steer a jump off a wall.
- The six-floor launch is close to the full screen height. Is eight visible
  floors enough, or should the camera zoom out or the anchor move up?
- Sound, screen shake, or a small camera punch on launch would sell the boost
  further once audio exists.
