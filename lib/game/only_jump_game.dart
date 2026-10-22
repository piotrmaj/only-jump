import 'dart:math' as math;
import 'dart:ui' show Canvas;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Size;

import '../render/sim_painter.dart';
import '../sim/game_sim.dart';
import '../sim/input_frame.dart';
import '../sim/sim_config.dart';
import '../sim/sim_snapshot.dart';

/// Thin Flame shell: fixed-step simulation + input, plus a single board
/// component that paints snapshots. All gameplay lives in [GameSim].
class OnlyJumpGame extends FlameGame {
  OnlyJumpGame({SimConfig config = const SimConfig(), int seed = 7})
    : sim = GameSim(config: config, seed: seed);

  static const double fixedStep = 1 / 60;

  final GameSim sim;

  final ValueNotifier<int> floors = ValueNotifier<int>(0);
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> bestScore = ValueNotifier<int>(0);
  final ValueNotifier<int> combo = ValueNotifier<int>(0);
  final ValueNotifier<int> bestCombo = ValueNotifier<int>(0);
  final ValueNotifier<String?> reward = ValueNotifier<String?>(null);
  final ValueNotifier<SimStatus> status = ValueNotifier<SimStatus>(
    SimStatus.playing,
  );
  final ValueNotifier<bool> showDebug = ValueNotifier<bool>(false);

  double _accumulator = 0;
  bool _left = false;
  bool _right = false;
  bool _jumpHeld = false;
  bool _jumpQueued = false;

  @override
  Color backgroundColor() => const Color(0xFF050B16);

  @override
  Future<void> onLoad() async {
    await add(_BoardComponent(this));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x > 0 && size.y > 0) {
      sim.setViewHeight(sim.config.levelWidth * size.y / size.x);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (sim.status == SimStatus.playing) {
      _accumulator += math.min(dt, 0.25);
      while (_accumulator >= fixedStep) {
        sim.step(
          fixedStep,
          InputFrame(
            left: _left,
            right: _right,
            jump: _jumpHeld || _jumpQueued,
          ),
        );
        _jumpQueued = false;
        _accumulator -= fixedStep;
      }
    } else {
      _accumulator = 0;
      _jumpQueued = false;
    }

    floors.value = sim.scoreFloor.floor();
    score.value = sim.points;
    if (score.value > bestScore.value) bestScore.value = score.value;
    combo.value = sim.comboActive ? sim.comboFloors : 0;
    bestCombo.value = sim.bestCombo;
    reward.value = sim.rewardTimeLeft > 0
        ? '${sim.lastReward}  +${sim.lastRewardPoints}'
        : null;
    if (status.value != sim.status) status.value = sim.status;
  }

  void setLeft(bool down) {
    _left = down;
  }

  void setRight(bool down) {
    _right = down;
  }

  void setJumpHeld(bool down) {
    _jumpHeld = down;
    if (down) _jumpQueued = true;
  }

  /// A tap that may be shorter than one simulation step.
  void queueJump() {
    _jumpQueued = true;
  }

  void restart() {
    sim.reset();
    _accumulator = 0;
    _left = false;
    _right = false;
    _jumpHeld = false;
    _jumpQueued = false;
    floors.value = 0;
    score.value = 0;
    combo.value = 0;
    reward.value = null;
    status.value = SimStatus.playing;
  }
}

class _BoardComponent extends Component {
  _BoardComponent(this.game);

  final OnlyJumpGame game;

  @override
  void render(Canvas canvas) {
    SimPainter(
      SimSnapshot.of(game.sim),
      showDebug: game.showDebug.value,
      time: game.sim.scoreFloor * 0.05,
    ).paint(canvas, Size(game.size.x, game.size.y));
  }
}
