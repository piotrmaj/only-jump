import 'package:flutter_test/flutter_test.dart';
import 'package:only_jump/sim/bots.dart';
import 'package:only_jump/sim/game_sim.dart';
import 'package:only_jump/sim/harness.dart';
import 'package:only_jump/sim/input_frame.dart';
import 'package:only_jump/sim/input_script.dart';

void main() {
  test('greedy bot climbs the tower', () {
    final h = SimHarness(seed: 3);
    h.runSeconds(60, GreedyBot());

    final floors = h.sim.scoreFloor.floor();
    expect(
      floors,
      greaterThanOrEqualTo(60),
      reason: 'bot only reached $floors floors\n${h.describe()}',
    );
    expect(h.sim.status, SimStatus.playing, reason: h.describe());
  });

  test('greedy bot survives every seed we ship', () {
    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final h = SimHarness(seed: seed);
      h.runSeconds(20, GreedyBot());
      expect(
        h.sim.scoreFloor.floor(),
        greaterThanOrEqualTo(15),
        reason: 'seed $seed stalled\n${h.describe()}',
      );
    }
  });

  test('random play keeps the simulation inside its invariants', () {
    for (var seed = 1; seed <= 10; seed++) {
      final h = SimHarness(seed: seed);
      h.runSeconds(20, RandomBot(seed));

      final p = h.sim.player;
      expect(p.x.isFinite && p.y.isFinite, isTrue, reason: 'seed $seed');
      expect(p.vx.isFinite && p.vy.isFinite, isTrue, reason: 'seed $seed');
      expect(p.left, greaterThanOrEqualTo(-0.01), reason: 'seed $seed');
      expect(
        p.right,
        lessThanOrEqualTo(h.sim.config.levelWidth + 0.01),
        reason: 'seed $seed',
      );
      expect(h.sim.platforms.length, lessThan(200), reason: 'seed $seed');
      expect(h.sim.scoreFloor, greaterThanOrEqualTo(0));

      for (final platform in h.sim.platforms) {
        expect(
          platform.y,
          lessThanOrEqualTo(h.sim.viewBottom + 240.01),
          reason: 'seed $seed: platform below the cull line',
        );
      }
    }
  });

  test('scripted fall ends the run and stops the simulation', () {
    final h = SimHarness(autoGenerate: false);
    h.useLevel(
      const [],
      playerBottom: 200,
    );
    final before = h.sim.player.y;
    h.play(InputScript.parse('300 idle'));
    expect(h.sim.status, SimStatus.gameOver);
    expect(h.sim.player.y, greaterThan(before));

    final frozenY = h.sim.player.y;
    h.step(const InputFrame(left: true, jump: true));
    expect(h.sim.player.y, frozenY, reason: 'simulation ran after game over');
  });

  test('score is the high-water mark of landed floors', () {
    final h = SimHarness(seed: 9);
    h.runSeconds(30, GreedyBot());
    expect(h.sim.scoreFloor, greaterThan(20));
    expect(h.snapshot.floors, h.sim.scoreFloor.floor());
  });
}
