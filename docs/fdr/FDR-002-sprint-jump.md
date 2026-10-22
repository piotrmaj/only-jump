# FDR-002: Sprint Jump

**Status:** Active
**Last reviewed:** 2026-10-22

## Overview

Running in one direction builds momentum. At full sprint the character visibly
moves faster, glows gold, and a jump from that state launches roughly three
floors high while the character spins and sheds a trail of gold stars. It is
the skill reward of the climb: boring floor-by-floor hopping is safe, sprint
jumping is fast and spectacular.

## Behavior

- Holding left or right continuously builds a sprint in about 0.6 seconds. Top
  speed rises from 300 to 420 world units per second.
- The character glows gold as the charge fills; at full sprint the glow is
  unmistakable. There is no separate meter on the HUD.
- Jumping at full sprint clears three floors, never four. A standing jump still
  clears exactly one floor.
- A sprint jump spins the character through a couple of rotations in the air
  and leaves a trail of five-pointed gold stars that lag behind and fade out.
- The spin and stars are cosmetic: no extra air control, no invulnerability, no
  change to landing.
- Charge is kept while airborne, so a sprint jump can be chained into another
  sprint jump if the direction is still held on landing.
- Releasing the direction drains the charge in about 0.35 seconds. Turning
  around drops it immediately; running into a wall stops the run and drains it.
- A jump is boosted if the player was at full sprint when the frame began, so
  releasing the direction on the same frame as the jump still boosts.
- Holding JUMP and a direction together turns the climb into a sprint-jump
  chain (see FDR-001).
- Stars never appear for normal jumps, and the trail is bounded (a few dozen
  stars at most) so long chains stay cheap.

## Design Decisions

### 1. A real speed tier, not a hidden timer

**Decision:** A sprint raises the character's actual top speed by ~40%, in
addition to arming the boosted jump.
**Why:** "It gets more speed" has to be felt in the hands, not inferred from a
meter. Faster ground coverage is also what makes a sprint chain a different
route through the tower rather than just a taller jump.
**Tradeoff:** Effective top speed now depends on a charge the player cannot
read exactly, and every existing tuning number (reach limit, camera anchor,
floor spacing) was chosen around walking speed. Sprint overshoots all of them
on purpose.

### 2. Fixed build and release times

**Decision:** Charge fills in a fixed ~0.6 s and drains in ~0.35 s, regardless
of how fast the character is currently moving.
**Why:** Predictable on touch, deterministic in tests, and easy to explain:
run for half a second, then jump. It makes the sprint a rhythm rather than a
physics accident.
**Tradeoff:** The charge feels binary near the top; 95% and 100% are visually
and mechanically different but hard to tell apart.

### 3. Momentum counts in the air too

**Decision:** Charge builds from continuous one-directional motion whether the
character is grounded or airborne. It only drains when the run is broken.
**Why:** It keeps momentum through a jump, which is what lets the hold-to-jump
control (FDR-001) produce a chain of sprint jumps instead of forcing a
release-and-run rhythm. It also reads as speed carrying you forward.
**Tradeoff:** The character can technically build a sprint while airborne,
which is not physical. It is generous rather than punishing, and the gold halo
makes the state legible.

### 4. Three floors per sprint jump

**Decision:** A sprint jump reaches ~292 world units, about 3.3 floors; a
normal jump reaches ~139, about 1.6 floors.
**Why:** The reward must change route planning to matter, and three floors is
a visible "wow" that still leaves the tower difficult. Four floors would turn
the tower into an elevator.
**Tradeoff:** One input can skip two floors of platforming. Score is derived
from height reached, so skipped floors still count — the cost is skipped
*content* and a much easier climb for players who master the timing, not a
score penalty.

### 5. Cosmetic effects live in the simulation

**Decision:** The spin angle and the gold star trail are simulated state, not
renderer-only animation. Stars are spawned and aged in world units, with a
separate random stream so they never disturb floor generation.
**Why:** The trail is deterministic, testable, and identical in headless
screenshots and on the phone. Bugs in the effect show up in tests instead of
only on a device.
**Tradeoff:** The frame snapshot carries a particle list, and the simulation
pays a small per-frame cost for something that is purely visual.

### 6. Gold halo instead of a charge meter

**Decision:** Readiness is shown on the character as a gold glow, not as a HUD
bar or a number.
**Why:** On a phone the player's eyes belong on the character and the next
floor. A glow also matches the gold star reward, so the visual language is one
idea: gold means speed.
**Tradeoff:** The player can tell "charged" from "not charged", but not how
close they are to full. The halo's opacity ramps with charge, which helps only
coarsely.

## Related

- **ADRs:** none yet.
- **FDRs:** FDR-001 (hold to jump — the two combine into sprint-jump chains),
  FDR-003 (safe floors — the runway where a sprint can be built).

## Open Questions

- Should a full sprint survive a wall jump when that mechanic lands, or should
  the wall reset it like a normal wall bump does today?
- The spin resets to upright on landing. Is a clean landing more readable than
  finishing the rotation naturally, at the cost of a possible snap?
- Should the sprint require the direction to still be held on landing to chain,
  or is keeping the charge through the air enough (current behavior)?
- Sound, screen shake, or a small camera punch on launch would sell the boost
  further once audio exists.
