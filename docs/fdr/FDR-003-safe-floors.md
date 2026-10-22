# FDR-003: Safe Floors

**Status:** Active
**Last reviewed:** 2026-10-22

## Overview

The start floor and every 50th floor after it span the full width of the
tower. They are gold-trimmed landing pads: impossible to miss, comfortable to
land on, and wide enough to build a sprint before the next stretch of the
climb. They turn the endless tower into a series of readable milestones.

## Behavior

- The start floor is full width, spanning the whole screen. A new player cannot
  walk off it by accident.
- Every 50th floor (50, 100, 150, …) is a full-width safe floor with a warm
  gold top trim and a soft glow.
- Safe floors are ordinary floors otherwise: they count toward the score and
  climbing continues normally above them.
- Because they touch both walls, they can always be landed on, and there is
  room to charge a full sprint before leaving.
- The first normal floor above a safe floor is generated from the centre of the
  tower, so the pattern restarts predictably after each milestone.
- Safe floors are not checkpoints. Falling back out of view below the tower
  still ends the run.

## Design Decisions

### 1. Cadence tied to floor number

**Decision:** Safe floors appear every 50 floors as counted by the HUD, not
every N world units and not after a time interval.
**Why:** The score is the player's mental model of progress. "Next safe floor
at 50" is legible, shareable and does not depend on how fast someone climbs.
**Tradeoff:** If floor spacing is retuned, the world-space distance between
safe floors changes, and the climb between them gets longer or shorter without
the rule changing.

### 2. Full width, flush against both walls

**Decision:** A safe floor is one slab spanning the entire level width, with no
gaps and no decorative notches.
**Why:** A "safe" floor that can be missed is not safe. Full width also means
no special collision or generation rule: the existing one-platform-per-floor
invariant and the reach limit are trivially satisfied.
**Tradeoff:** Milestone floors carry no risk at all. When hazards arrive
(crumbling floors, springs), they will need an explicit "never on a safe floor"
rule.

### 3. The start floor is a safe floor

**Decision:** Row 0 uses the same full-width, gold-trimmed treatment as every
milestone.
**Why:** The first ten seconds should teach running and jumping, not punish a
stray tap with a fall. It is also the natural runway for the first sprint jump
(FDR-002).
**Tradeoff:** The fall loses its position as an early lesson, and the first
game over now requires an actual jump, so it arrives a little later.

### 4. Every 50 floors, not every 10

**Decision:** The interval is 50 floors, which is ~4,400 world units at the
current spacing.
**Why:** 50 is a real milestone (the HUD number rolls over) and frequent enough
to give a goal inside a normal run, without turning the tower into a highway of
free landings. A 10-floor cadence would remove most of the risk from early play.
**Tradeoff:** A beginner who dies before floor 50 never sees the mechanic apart
from the start floor, so it is invisible until a run gets somewhere.

### 5. Generation resets to the centre after a safe floor

**Decision:** The row above a safe floor is generated around the tower centre,
not relative to where the player landed.
**Why:** Safe floors span the width, so "which part did the player use" is
ambiguous. Resetting to the centre makes the reachability rule obviously true
on the next row and prevents the tower from hugging a wall for the next 49
floors.
**Tradeoff:** The tower becomes slightly predictable right after each
milestone; skilled players learn the opening move of each 50-floor block.

### 6. Gold trim rather than new UI

**Decision:** Safe floors are marked with a warm gold top edge and a soft glow,
using the same gold as the sprint effects.
**Why:** The milestone should be readable at a glance while falling towards it,
without adding HUD elements or numbers. Sharing the sprint's gold keeps one
visual language: gold means opportunity.
**Tradeoff:** The cue is art-dependent. Any future art pass has to preserve a
distinct, non-ice look for safe floors or the mechanic becomes invisible.

## Related

- **ADRs:** none yet.
- **FDRs:** FDR-002 (sprint jump — safe floors are the runway for a sprint).

## Open Questions

- Should reaching a safe floor be celebrated (flash, floor number, short
  banner) or is the visual trim enough?
- Should the game instead restart a run at the last safe floor (checkpoint)
  rather than ending it? That changes the risk model of the whole game.
- Should the interval grow with height (50, then 100, then 150) to keep the
  late tower tense?
- Once hazards exist, do safe floors need a hard guarantee that nothing
  dangerous spawns on or immediately above them?
