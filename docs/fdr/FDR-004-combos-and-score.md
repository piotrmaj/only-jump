# FDR-004: Combos and Score

**Status:** Active
**Last reviewed:** 2026-10-22

## Overview

Climbing used to produce a single number: floors. Now every floor is worth
points, and linking jumps without touching a lower floor builds a **combo** that
pays out a bonus when it ends. The rules are ported from Icy Tower — the game
behind the 1337-floor-combo world record run — so chaining three-floor sprint
jumps is the high-skill line, and a safe one-floor hop cashes the chain in.

## Behavior

- Every new highest floor is worth **10 points**. Points never go down, even if
  the player falls.
- A combo begins when a jump gains **at least two floors**.
- Each later landing that gains two or more floors adds those floors to the
  chain. Three-floor sprint jumps add three.
- A landing on the **same floor** (a straight-up bounce) neither adds nor ends
  the chain, but it does not reset the timer either.
- A landing exactly **one floor** higher ends the combo; that is the deliberate
  "cash out" move.
- Falling back to a **lower floor** also ends the combo.
- If **3 seconds** pass without reaching a higher floor, the combo ends.
- A finished combo pays **floors × floors** points, but only if it spanned at
  least **4 floors in at least 2 jumps**. Shorter chains pay nothing.
- The HUD shows a gold **COMBO n** pill while a chain is alive and a short
  reward banner when it pays: `Good!` (4), `Sweet!` (7), `Great!` (15),
  `Super!` (25), `Wow!` (35), `Amazing!` (50), `Extreme!` (70), `Fantastic!`
  (100), `Splendid!` (140), `No way!` (200).
- `BEST` in the HUD tracks the best score of the session, and the game-over
  overlay shows floors, points and the longest combo reached.

## Design Decisions

### 1. Port the documented Icy Tower rules, not a new multiplier

**Decision:** Use the original combo shape: a 3-second window between floors, a
chain of skipped floors, a one-floor jump or a fall ends it, and the bonus is
the square of the floors spanned.
**Why:** The feature is explicitly modeled on the 1337-floor-combo record run.
A generic "x2, x3" multiplier would look similar in a screenshot but would
change the risk: in Icy Tower, the skill is sustaining the chain, and the
reward grows super-linearly with it.
**Tradeoff:** The rules are subtle enough to need a HUD explanation eventually.
"One floor ends it, two floors extend it" is not guessable from play alone.

### 2. Combos count floors gained, not jumps

**Decision:** A three-floor sprint jump adds three to the combo, so two boosted
jumps make a six-floor chain.
**Why:** The scoreboard unit in Icy Tower is the floor combo, and it makes the
payout reward height gained rather than the number of inputs. It also gives
sprint jumps a scoring identity: normal hops can start or end a chain, but only
boosted jumps build one quickly.
**Tradeoff:** A player can chain long, slow jump arcs that gain three floors
each and look less flashy than the same combo built with wall bounces.

### 3. Require two jumps and four floors

**Decision:** A combo pays only at 4+ floors and 2+ jumps.
**Why:** Without it, every single sprint jump would immediately bank 9 points
and the combo counter would be noise. The threshold makes the first reward
("Good!") mean "you linked two boosted jumps", which is the intended lesson.
**Tradeoff:** A 3-floor sprint jump and a 1-floor hop pay only the 10 points per
floor; beginners may feel the first combo attempt gave nothing.

### 4. The 3-second clock only resets on new floors

**Decision:** Bouncing on the spot does not refresh the combo timer.
**Why:** Otherwise hold-to-jump (FDR-001) would let a player keep a combo alive
forever on one safe floor by mashing. In Icy Tower the clock is measured from
the last floor *reached*, and that is the rule that makes long combos a climb.
**Tradeoff:** Landing on the same floor is now a wasted input during a combo;
the player has to keep moving up.

### 5. High-water floor points instead of revoking on descent

**Decision:** Floor points are awarded once per new highest floor and are kept.
**Why:** Icy Tower revokes the 10-per-floor bonus when the player descends from
a floor. Our camera ends the run as soon as the player falls out of view, so
the revoke rule would only matter for brief drops, and it would make the score
counter jump backwards on a phone screen. Keeping points monotonic makes the
HUD readable and still rewards height.
**Tradeoff:** Briefly dropping down is only punished through the lost combo,
not through the score, so it is less costly than in the original.

### 6. Presentation stays in the HUD, not the world painter

**Decision:** The combo pill and reward banner are Flutter widgets fed by value
notifiers from the sim; the painter is unchanged.
**Why:** The painter is the single source of truth for world visuals and is
used by both the game and the screenshot artifacts. Score text is UI, and
keeping it out of the painter avoids duplicating HUD styling in the golden
pipeline.
**Tradeoff:** Combo state does not appear in painter-only artifact screenshots;
it is verified through sim tests and on-device play.

## Implementation Notes

- Landing is detected by the sim as the `grounded` transition on a fixed step,
  before the jump block, so a landing that immediately launches again still
  scores.
- While building this, sprint jumps were found to stop on the first floor they
  passed: the support check treated any platform within one unit of the
  player's feet as ground, regardless of velocity. Support now only applies
  while falling (`vy >= 0`). This is what let the 3-floor sprint jump (FDR-002)
  actually clear three floors.
- `SimConfig.comboWindow` is the only tuning knob (default 3.0 s).

## Related

- **ADRs:** none yet.
- **FDRs:** FDR-001 (hold to jump — chains are built by landing and jumping
  again), FDR-002 (sprint jump — the three-floor jump that feeds combos),
  FDR-003 (safe floors — the runway where a combo can be started safely).

## Open Questions

- Wall bouncing is the missing piece of the record run: the original rewards
  reversing at the wall with preserved speed. Should that be the next mechanic?
- Should floor points be revoked on descent, for closer fidelity to Icy Tower?
- Should the best score and best combo persist between runs (v0.3)?
- Is 3 seconds the right window for a phone-sized screen, or does the shorter
  view make combos harder than in the original?
- Should the combo pill show the remaining window (a shrinking ring or bar) so
  players can see the 3-second clock?
