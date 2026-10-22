import 'dart:math' as math;

import 'game_sim.dart';
import 'input_frame.dart';
import 'platform.dart';

/// Something that can play the game by looking at the simulation.
///
/// Bots are the backbone of the feedback loop: a deterministic human-like
/// player that exercises features without a phone.
abstract class Bot {
  const Bot();

  String get name;

  InputFrame next(GameSim sim);
}

class IdleBot extends Bot {
  const IdleBot();

  @override
  String get name => 'idle';

  @override
  InputFrame next(GameSim sim) => InputFrame.none;
}

/// Random walk with a bias towards jumping. Good for fuzzing invariants.
class RandomBot extends Bot {
  RandomBot(int seed) : _rng = math.Random(seed);

  final math.Random _rng;
  int _hold = 0;
  bool _left = false;
  bool _right = false;

  @override
  String get name => 'random';

  @override
  InputFrame next(GameSim sim) {
    if (_hold <= 0) {
      _hold = 6 + _rng.nextInt(24);
      final roll = _rng.nextDouble();
      _left = roll < 0.35;
      _right = roll > 0.65;
    }
    _hold--;

    final jump = sim.player.grounded && _rng.nextDouble() < 0.6;
    return InputFrame(left: _left, right: _right, jump: jump);
  }
}

/// Climbs floor by floor. Commits to one platform while airborne, lines up
/// horizontally before jumping and brakes instead of overshooting.
class GreedyBot extends Bot {
  GreedyBot({this.reactionFrames = 0});

  /// Extra frames of "thinking" delay, useful to model sloppy play.
  final int reactionFrames;

  int _cooldown = 0;
  Platform? _target;

  @override
  String get name => 'greedy';

  @override
  InputFrame next(GameSim sim) {
    if (_cooldown > 0) {
      _cooldown--;
      return InputFrame.none;
    }
    _cooldown = reactionFrames;

    final player = sim.player;
    if (player.grounded || _target == null) {
      _target = _chooseTarget(sim);
    }

    final target = _target;
    if (target == null) {
      // Nothing reachable above: hop towards the middle and try again.
      final dx = sim.config.levelWidth / 2 - player.x;
      return InputFrame(
        left: dx < -4,
        right: dx > 4,
        jump: player.grounded,
      );
    }

    final dx = target.centerX - player.x;
    final rise = player.bottom - target.y;

    var jump = false;
    if (player.grounded) {
      final support = _supportUnder(sim);
      final atEdge = support != null &&
          (dx > 0 ? support.right - player.x < 12 : player.x - support.left < 12);
      final reachable = rise > 20 && rise < sim.config.jumpReach;
      jump = reachable && (dx.abs() <= 110 || atEdge);
    }

    return InputFrame(
      left: dx < -10,
      right: dx > 10,
      jump: jump,
    );
  }

  Platform? _chooseTarget(GameSim sim) {
    final player = sim.player;
    Platform? best;
    var bestScore = double.infinity;

    for (final p in sim.platforms) {
      final rise = player.bottom - p.y;
      if (rise < 20 || rise > sim.config.jumpReach) continue;
      final dx = (p.centerX - player.x).abs();
      if (dx > 230) continue;

      // Prefer a clean single-floor step, then closeness.
      final score = dx + (rise - sim.config.floorSpacing).abs() * 0.7;
      if (score < bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return best;
  }

  Platform? _supportUnder(GameSim sim) {
    final b = sim.player.bottom;
    for (final p in sim.platforms) {
      if (p.overlapsX(sim.player.left, sim.player.right) &&
          (b - p.y).abs() < 1.5) {
        return p;
      }
    }
    return null;
  }
}
