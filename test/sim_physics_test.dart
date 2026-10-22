import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:only_jump/sim/game_sim.dart';
import 'package:only_jump/sim/harness.dart';
import 'package:only_jump/sim/input_frame.dart';
import 'package:only_jump/sim/input_script.dart';
import 'package:only_jump/sim/platform.dart';
import 'package:only_jump/sim/sim_config.dart';

void hold(SimHarness h, int frames, InputFrame input) {
  for (var i = 0; i < frames; i++) {
    h.step(input);
  }
}

void main() {
  group('horizontal movement', () {
    test('accelerates to max speed and stops with friction', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 300, width: 480)],
        playerBottom: 300,
      );
      h.runFrames(2);

      hold(h, 30, const InputFrame(right: true));
      expect(
        h.sim.player.vx,
        greaterThanOrEqualTo(h.sim.config.maxMoveSpeed),
        reason: h.describe(),
      );
      expect(
        h.sim.player.vx,
        lessThanOrEqualTo(h.sim.config.sprintTopSpeed),
        reason: h.describe(),
      );

      hold(h, 60, InputFrame.none);
      expect(h.sim.player.vx, 0);
    });

    test('walls clamp the player inside the level', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 300, width: 480)],
        playerBottom: 300,
      );
      h.runFrames(2);

      hold(h, 240, const InputFrame(right: true));
      expect(
        h.sim.player.right,
        closeTo(h.sim.config.levelWidth, 0.5),
        reason: h.describe(),
      );

      hold(h, 480, const InputFrame(left: true));
      expect(h.sim.player.left, closeTo(0, 0.5), reason: h.describe());
    });
  });

  group('jumping', () {
    test('single jump clears one floor but not two', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 400, width: 480)],
        playerBottom: 400,
      );
      h.runFrames(2);
      final groundY = h.sim.player.y;

      h.step(const InputFrame(jump: true));
      var apex = groundY;
      for (var i = 0; i < 90; i++) {
        h.step(InputFrame.none);
        apex = math.min(apex, h.sim.player.y);
      }

      final rise = groundY - apex;
      expect(
        rise,
        greaterThan(h.sim.config.floorSpacing * 1.15),
        reason: 'jump must clear one floor (rise=$rise)',
      );
      expect(
        rise,
        lessThan(h.sim.config.floorSpacing * 2),
        reason: 'jump must not skip two floors (rise=$rise)',
      );
    });

    test('no double jump while airborne', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 400, width: 480)],
        playerBottom: 400,
      );
      h.runFrames(2);

      h.step(const InputFrame(jump: true));
      h.step(InputFrame.none);
      expect(h.sim.jumps, 1);

      h.step(const InputFrame(jump: true));
      h.step(const InputFrame(jump: false));
      expect(h.sim.jumps, 1, reason: 'double jump appeared out of nowhere');
    });

    test('coyote time allows a jump just after leaving a ledge', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 300, width: 240)],
        playerBottom: 300,
        playerX: 220,
      );
      h.runFrames(2);
      expect(h.sim.player.grounded, isTrue);

      var guard = 0;
      while (h.sim.player.grounded && guard++ < 120) {
        h.step(const InputFrame(right: true));
      }
      expect(h.sim.player.grounded, isFalse);

      h.step(const InputFrame(jump: true));
      expect(h.sim.jumps, 1, reason: h.describe());
    });

    test('jump pressed just before landing is buffered', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 300, width: 480)],
        playerBottom: 280,
      );
      h.step(const InputFrame(jump: true));
      for (var i = 0; i < 20; i++) {
        h.step(InputFrame.none);
      }
      expect(h.sim.jumps, 1, reason: 'buffered jump did not fire\n${h.describe()}');
    });

    test('holding jump hops again as soon as the player lands', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 400, width: 480)],
        playerBottom: 400,
      );
      h.runFrames(2);

      h.step(const InputFrame(jump: true));
      expect(h.sim.jumps, 1);

      var lowestBottom = h.sim.player.bottom;
      var frames = 0;
      while (h.sim.jumps == 1 && frames++ < 120) {
        h.step(const InputFrame(jump: true));
        lowestBottom = math.max(lowestBottom, h.sim.player.bottom);
      }

      expect(
        h.sim.jumps,
        2,
        reason: 'holding jump did not hop again after landing\n${h.describe()}',
      );
      expect(
        lowestBottom,
        closeTo(400, 0.5),
        reason: 'second hop fired before touching the floor\n${h.describe()}',
      );
    });

    test('holding jump keeps hopping, but only on the floor', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 400, width: 480)],
        playerBottom: 400,
      );
      h.runFrames(2);

      var hops = 0;
      for (var i = 0; i < 300; i++) {
        final jumpsBefore = h.sim.jumps;
        h.step(const InputFrame(jump: true));
        if (h.sim.jumps > jumpsBefore) {
          hops++;
          // A hop from the floor always starts at platform height.
          expect(
            h.sim.player.bottom,
            closeTo(400, 1),
            reason: 'hop $hops started mid-air\n${h.describe()}',
          );
        }
      }

      expect(
        hops,
        greaterThanOrEqualTo(4),
        reason: 'holding jump should chain hops (hops=$hops)\n${h.describe()}',
      );
    });
  });

  group('sprint jump', () {
    /// Charges a sprint on a full-width slab and returns the harness.
    SimHarness chargeSprint({double playerX = 60}) {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 400, width: 480)],
        playerBottom: 400,
        playerX: playerX,
      );
      h.runFrames(2);
      hold(h, 45, const InputFrame(right: true));
      return h;
    }

    test('holding a direction builds speed above a walk', () {
      final h = chargeSprint();
      expect(h.sim.sprintCharge, 1, reason: h.describe());
      expect(h.sim.sprinting, isTrue);
      expect(
        h.sim.player.vx,
        closeTo(h.sim.config.sprintTopSpeed, 1),
        reason: h.describe(),
      );

      // Letting go bleeds the charge off.
      hold(h, 30, InputFrame.none);
      expect(h.sim.sprintCharge, 0, reason: h.describe());
    });

    test('turning around drops the sprint', () {
      final h = chargeSprint();
      expect(h.sim.sprinting, isTrue);

      hold(h, 3, const InputFrame(left: true));
      expect(h.sim.sprintCharge, 0, reason: h.describe());
    });

    test('a sprint jump clears three floors but never four', () {
      final h = chargeSprint();
      final groundY = h.sim.player.y;

      h.step(const InputFrame(right: true, jump: true));
      var apex = groundY;
      for (var i = 0; i < 90; i++) {
        h.step(const InputFrame(right: true));
        apex = math.min(apex, h.sim.player.y);
      }

      final rise = groundY - apex;
      final spacing = h.sim.config.floorSpacing;
      expect(
        rise,
        greaterThan(spacing * 3),
        reason: 'sprint jump must clear three floors (rise=$rise)\n${h.describe()}',
      );
      expect(
        rise,
        lessThan(spacing * 4),
        reason: 'sprint jump must not clear four floors (rise=$rise)\n${h.describe()}',
      );
    });

    test('a standing jump stays a normal jump', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 400, width: 480)],
        playerBottom: 400,
      );
      h.runFrames(2);

      h.step(const InputFrame(jump: true));
      expect(h.sim.player.spinJump, isFalse);
      expect(h.sim.stars, isEmpty);
    });

    test('sprint jump spins, sheds gold stars, and stops on landing', () {
      final h = chargeSprint();

      h.step(const InputFrame(jump: true));
      expect(h.sim.player.spinJump, isTrue);
      expect(h.sim.player.spin, greaterThan(0));

      hold(h, 6, InputFrame.none);
      expect(h.sim.player.spin, greaterThan(0));
      expect(h.sim.stars, isNotEmpty, reason: 'no gold stars while spinning');
      expect(h.sim.stars.length, lessThan(40));

      var guard = 0;
      while (!h.sim.player.grounded && guard++ < 180) {
        h.step(InputFrame.none);
      }
      expect(h.sim.player.grounded, isTrue, reason: h.describe());
      expect(h.sim.player.spinJump, isFalse);
      expect(h.sim.player.spin, 0);

      hold(h, 60, InputFrame.none);
      expect(h.sim.stars, isEmpty, reason: 'stars outlived their trail');
    });
  });

  group('safe floors', () {
    test('the start floor spans the whole level', () {
      final h = SimHarness(seed: 1);
      final start = h.sim.platforms.firstWhere((p) => p.y == h.sim.groundY);
      expect(start.safe, isTrue);
      expect(start.x, 0);
      expect(start.width, h.sim.config.levelWidth);
    });

    test('every Nth row is full width and safe', () {
      final h = SimHarness(
        seed: 1,
        config: const SimConfig(safeFloorInterval: 2),
      );
      final safe = h.sim.platforms.where((p) => p.safe).toList();
      expect(safe.length, greaterThan(3));

      for (final p in safe) {
        expect(p.x, 0);
        expect(p.width, h.sim.config.levelWidth);
        final rows = ((h.sim.groundY - p.y) / h.sim.config.floorSpacing).round();
        expect(rows.isEven, isTrue, reason: 'safe floor off the cadence: $p');
      }

      final normal = h.sim.platforms.where((p) => !p.safe);
      expect(normal, isNotEmpty);
      expect(
        normal.any((p) => p.width < h.sim.config.levelWidth),
        isTrue,
        reason: 'normal floors must stay partial-width',
      );
    });

    test('the first screen keeps the default cadence', () {
      final h = SimHarness(seed: 1);
      // Only the start slab is safe until floor 50.
      expect(h.sim.platforms.where((p) => p.safe).length, 1);
    });
  });

  group('tower', () {
    test('floors only count once the player lands', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 0, y: 400, width: 480)],
        playerBottom: 400,
      );
      h.runFrames(2);
      expect(h.sim.scoreFloor, 0);

      h.step(const InputFrame(jump: true));
      var apex = h.sim.player.y;
      for (var i = 0; i < 20; i++) {
        h.step(InputFrame.none);
        apex = math.min(apex, h.sim.player.y);
      }
      expect(h.sim.scoreFloor, 0, reason: 'score moved while airborne');
      expect(h.sim.player.y, lessThan(apex + 20));
    });

    test('camera never moves down', () {
      final h = SimHarness(seed: 5);
      var previous = h.sim.cameraTop;
      for (var i = 0; i < 600; i++) {
        h.runFrames(1);
        expect(h.sim.cameraTop, lessThanOrEqualTo(previous + 0.001));
        previous = h.sim.cameraTop;
      }
    });

    test('falling out of view ends the run', () {
      final h = SimHarness(autoGenerate: false);
      h.useLevel(
        [const Platform(x: 100, y: 300, width: 120)],
        playerBottom: 300,
      );
      h.runFrames(2);
      hold(h, 240, const InputFrame(right: true));

      expect(h.sim.status, SimStatus.gameOver, reason: h.describe());
      expect(h.sim.scoreFloor, greaterThanOrEqualTo(0));
    });

    test('generated floors stay inside the level and are reachable', () {
      final h = SimHarness(seed: 2);
      h.runFrames(1);
      final rows = <double, List<Platform>>{};
      for (final p in h.sim.platforms) {
        expect(p.x, greaterThanOrEqualTo(0));
        expect(p.right, lessThanOrEqualTo(h.sim.config.levelWidth));
        rows.putIfAbsent(p.y, () => []).add(p);
      }

      final sortedRows = rows.keys.toList()..sort((a, b) => b.compareTo(a));
      for (var i = 1; i < sortedRows.length; i++) {
        final lower = rows[sortedRows[i - 1]]!;
        final upper = rows[sortedRows[i]]!;
        final gap = sortedRows[i - 1] - sortedRows[i];
        expect(gap, closeTo(h.sim.config.floorSpacing, 0.01));

        final linked = upper.any(
          (u) => lower.any((l) {
            // Horizontal distance between the two slabs; a full-width safe
            // floor overlaps every floor below it.
            final gap = math.max(
              0.0,
              math.max(u.left - l.right, l.left - u.right),
            );
            return gap <= h.sim.config.reachLimit + 0.01;
          }),
        );
        expect(linked, isTrue, reason: 'unreachable floor at y=${sortedRows[i]}');
      }
    });
  });

  group('combos and score', () {
    /// A full-width ladder from the start floor upward, so landings are
    /// unambiguous and horizontal aiming is never the reason a test fails.
    /// The tower is wider than the screen so a sprint jump has room to fly
    /// without clipping a wall (which would drain the sprint mid-air).
    SimHarness ladder() {
      const config = SimConfig(levelWidth: 1000);
      final start = SimHarness(autoGenerate: false, config: config);
      final ground = start.sim.groundY;
      final platforms = <Platform>[
        for (var i = 0; i < 12; i++)
          Platform(x: 0, y: ground - i * config.floorSpacing, width: 1000),
      ];
      start.useLevel(platforms, playerBottom: ground, playerX: 60);
      start.runFrames(2);
      hold(start, 45, const InputFrame(right: true));
      return start;
    }

    /// Steps until the player is back on a floor.
    bool land(SimHarness h, InputFrame input, {int maxFrames = 240}) {
      for (var i = 0; i < maxFrames; i++) {
        h.step(input);
        if (h.sim.player.grounded) return true;
      }
      return false;
    }

    /// Two chained sprint jumps: a six-floor combo in two jumps.
    SimHarness sixFloorCombo() {
      final h = ladder();
      h.step(const InputFrame(right: true, jump: true));
      expect(land(h, const InputFrame(right: true)), isTrue, reason: h.describe());
      h.step(const InputFrame(right: true, jump: true));
      expect(land(h, const InputFrame(right: true)), isTrue, reason: h.describe());
      return h;
    }

    test('floors are worth ten points each', () {
      final h = ladder();
      expect(h.sim.points, 0);

      h.step(const InputFrame(right: true, jump: true));
      expect(land(h, const InputFrame(right: true)), isTrue, reason: h.describe());
      expect(h.sim.comboFloors, 3);
      expect(h.sim.comboJumps, 1);
      expect(h.sim.points, 30, reason: h.describe());
    });

    test('a six-floor chain in two jumps pays floors squared', () {
      final h = sixFloorCombo();
      expect(h.sim.comboActive, isTrue);
      expect(h.sim.comboFloors, 6);
      expect(h.sim.comboJumps, 2);
      expect(h.sim.points, 60, reason: h.describe());

      // Drop the sprint, then a single-floor hop ends the combo.
      hold(h, 25, InputFrame.none);
      expect(h.sim.sprinting, isFalse, reason: h.describe());
      h.step(const InputFrame(jump: true));
      expect(land(h, InputFrame.none), isTrue, reason: h.describe());

      expect(h.sim.comboActive, isFalse);
      expect(h.sim.bestCombo, 6);
      expect(h.sim.lastReward, 'Good!');
      expect(h.sim.lastRewardPoints, 36);
      expect(h.sim.points, 60 + 10 + 36, reason: h.describe());
    });

    test('a combo times out after three seconds', () {
      final h = sixFloorCombo();
      hold(h, 200, InputFrame.none);

      expect(h.sim.comboActive, isFalse);
      expect(h.sim.bestCombo, 6);
      expect(h.sim.lastRewardPoints, 36);
      expect(h.sim.points, 96, reason: h.describe());
    });

    test('one skipped floor is not a combo', () {
      final h = ladder();
      h.step(const InputFrame(right: true, jump: true));
      expect(land(h, const InputFrame(right: true)), isTrue, reason: h.describe());

      hold(h, 25, InputFrame.none);
      h.step(const InputFrame(jump: true));
      expect(land(h, InputFrame.none), isTrue, reason: h.describe());

      expect(h.sim.comboActive, isFalse);
      expect(h.sim.bestCombo, 0);
      expect(h.sim.lastReward, isNull);
      expect(h.sim.points, 40, reason: h.describe());
    });

    test('reward names follow the Icy Tower thresholds', () {
      expect(comboRewardName(4), 'Good!');
      expect(comboRewardName(7), 'Sweet!');
      expect(comboRewardName(15), 'Great!');
      expect(comboRewardName(25), 'Super!');
      expect(comboRewardName(35), 'Wow!');
      expect(comboRewardName(50), 'Amazing!');
      expect(comboRewardName(70), 'Extreme!');
      expect(comboRewardName(100), 'Fantastic!');
      expect(comboRewardName(140), 'Splendid!');
      expect(comboRewardName(200), 'No way!');
    });
  });

  group('input script', () {
    test('parses segments, comments and combined tokens', () {
      final script = InputScript.parse('''
# climb
20 right
1 right+jump
10 idle
5 left
''');
      expect(script.segments.length, 4);
      expect(script.totalFrames, 36);
      expect(script.segments[1].input.right, isTrue);
      expect(script.segments[1].input.jump, isTrue);
      expect(script.segments[3].input.left, isTrue);
    });

    test('rejects unknown tokens', () {
      expect(() => InputScript.parse('10 fly'), throwsFormatException);
      expect(() => InputScript.parse('10'), throwsFormatException);
    });

    test('scripted run is deterministic', () {
      SimConfig config() => const SimConfig();
      final a = SimHarness(config: config(), seed: 42);
      final b = SimHarness(config: config(), seed: 42);
      const script = InputScript([
        InputSegment(30, InputFrame(right: true)),
        InputSegment(1, InputFrame(jump: true)),
        InputSegment(40, InputFrame.none),
        InputSegment(20, InputFrame(left: true, jump: true)),
      ]);
      a.play(script);
      b.play(script);
      expect(a.sim.player.x, b.sim.player.x);
      expect(a.sim.player.y, b.sim.player.y);
      expect(a.sim.scoreFloor, b.sim.scoreFloor);
    });
  });
}
