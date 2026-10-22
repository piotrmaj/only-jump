import 'dart:math' as math;

import 'input_frame.dart';
import 'platform.dart';
import 'player_state.dart';
import 'sim_config.dart';

enum SimStatus { playing, gameOver }

/// Deterministic, dependency-free game simulation.
///
/// Call [step] with a fixed timestep and an [InputFrame]; everything else
/// (platform generation, camera, scoring) happens here. The Flutter/Flame
/// layer only renders [SimSnapshot]s and feeds input, which means tests can
/// play the exact same game at thousands of steps per second.
class GameSim {
  GameSim({this.config = const SimConfig(), int seed = 7})
    : _rng = math.Random(seed) {
    reset();
  }

  SimConfig config;
  final math.Random _rng;

  PlayerState player = PlayerState(x: 0, y: 0, width: 26, height: 36);
  final List<Platform> platforms = <Platform>[];
  SimStatus status = SimStatus.playing;

  /// World Y of the top edge of the screen.
  double cameraTop = 0;
  double scoreFloor = 0;
  int jumps = 0;

  /// Turn off for hand-built test levels.
  bool autoGenerate = true;

  double _coyote = 0;
  double _jumpBuffer = 0;
  double _topRowY = 0;
  double _prevRowCenter = 0;
  double _groundY = 0;

  double get groundY => _groundY;
  double get viewBottom => cameraTop + config.viewHeight;

  void reset() {
    final cfg = config;
    platforms.clear();
    player = PlayerState(
      x: cfg.levelWidth / 2,
      y: cfg.startY,
      width: cfg.playerWidth,
      height: cfg.playerHeight,
    );
    _groundY = cfg.startY + cfg.playerHeight / 2;
    cameraTop = cfg.startY - cfg.viewHeight * cfg.cameraAnchor;
    scoreFloor = 0;
    jumps = 0;
    status = SimStatus.playing;
    _coyote = 0;
    _jumpBuffer = 0;
    _topRowY = _groundY;
    _prevRowCenter = cfg.levelWidth / 2;

    platforms.add(
      Platform(
        x: cfg.levelWidth / 2 - 110,
        y: _groundY,
        width: 220,
        height: cfg.platformHeight,
      ),
    );
    player.grounded = true;

    if (autoGenerate) {
      _streamWorld();
    }
  }

  /// Called by the renderer when the screen aspect ratio changes.
  void setViewHeight(double height) {
    if (height <= 0 || (height - config.viewHeight).abs() < 0.5) return;
    config = config.copyWith(viewHeight: height);
    if (player.top < cameraTop) {
      cameraTop = player.y - height * config.cameraAnchor;
    }
  }

  void step(double dt, InputFrame input) {
    if (status != SimStatus.playing) return;
    final cfg = config;

    // ------------------------------------------------------------------
    // Horizontal movement
    // ------------------------------------------------------------------
    final dir = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    if (dir != 0) {
      player.vx += dir * cfg.moveAccel * dt;
      player.facingLeft = dir < 0;
    } else {
      final friction = (player.grounded ? cfg.groundFriction : cfg.airFriction) * dt;
      if (player.vx.abs() <= friction) {
        player.vx = 0;
      } else {
        player.vx -= player.vx.sign * friction;
      }
    }
    player.vx = player.vx.clamp(-cfg.maxMoveSpeed, cfg.maxMoveSpeed).toDouble();

    // ------------------------------------------------------------------
    // Jump buffering / coyote time
    // ------------------------------------------------------------------
    // Level-triggered, not edge-triggered: holding jump keeps the request
    // alive, so the player hops again the moment they touch a floor. A tap
    // still means one jump, and airborne presses never stack (see below).
    if (input.jump) {
      _jumpBuffer = cfg.jumpBufferTime;
    } else {
      _jumpBuffer = math.max(0, _jumpBuffer - dt);
    }
    _coyote = math.max(0, _coyote - dt);

    // ------------------------------------------------------------------
    // Integrate
    // ------------------------------------------------------------------
    player.vy = math.min(player.vy + cfg.gravity * dt, cfg.maxFallSpeed);

    final oldBottom = player.bottom;
    player.x += player.vx * dt;
    if (player.left < 0) {
      player.x = player.width / 2;
      player.vx = 0;
    } else if (player.right > cfg.levelWidth) {
      player.x = cfg.levelWidth - player.width / 2;
      player.vx = 0;
    }

    player.y += player.vy * dt;

    Platform? landedOn;
    if (player.vy >= 0) {
      for (final p in platforms) {
        if (p.overlapsX(player.left, player.right) &&
            oldBottom <= p.y + 0.01 &&
            player.bottom >= p.y) {
          if (landedOn == null || p.y < landedOn.y) landedOn = p;
        }
      }
    }

    final wasGrounded = player.grounded;
    if (landedOn != null) {
      player.setBottom(landedOn.y);
      player.vy = 0;
      player.grounded = true;
      _coyote = cfg.coyoteTime;
    } else {
      final support = _supportAt();
      if (support != null) {
        player.setBottom(support.y);
        player.vy = 0;
        player.grounded = true;
        _coyote = cfg.coyoteTime;
      } else {
        player.grounded = false;
      }
    }
    // Keep coyote time from the last grounded frame, including walking off.
    if (!player.grounded && wasGrounded) {
      _coyote = math.max(_coyote, cfg.coyoteTime);
    }

    // ------------------------------------------------------------------
    // Score: only advances while standing on a floor, before a buffered jump
    // can launch the player again. A jump must not tick the counter mid-air.
    // ------------------------------------------------------------------
    if (player.grounded) {
      final startBottom = cfg.startY + cfg.playerHeight / 2;
      scoreFloor = math.max(
        scoreFloor,
        (startBottom - player.bottom) / cfg.floorSpacing,
      );
    }

    // ------------------------------------------------------------------
    // Jump
    // ------------------------------------------------------------------
    if (_jumpBuffer > 0 && (player.grounded || _coyote > 0)) {
      player.vy = -cfg.jumpSpeed;
      player.grounded = false;
      _coyote = 0;
      _jumpBuffer = 0;
      jumps++;
    }

    // ------------------------------------------------------------------
    // Camera, world streaming, death
    // ------------------------------------------------------------------
    final target = player.y - cfg.viewHeight * cfg.cameraAnchor;
    if (target < cameraTop) cameraTop = target;

    _streamWorld();

    if (player.top > viewBottom + cfg.gameOverMargin) {
      status = SimStatus.gameOver;
    }
  }

  Platform? _supportAt() {
    final b = player.bottom;
    for (final p in platforms) {
      if (p.overlapsX(player.left, player.right) &&
          b >= p.y - 1 &&
          b <= p.y + 1) {
        return p;
      }
    }
    return null;
  }

  void _streamWorld() {
    if (!autoGenerate) return;
    final untilY = cameraTop - config.viewHeight;
    while (_topRowY > untilY) {
      _topRowY -= config.floorSpacing;
      _addRow(_topRowY);
    }
    platforms.removeWhere((p) => p.y > viewBottom + 240);
  }

  void _addRow(double y) {
    final cfg = config;
    final rng = _rng;

    // One platform per floor, always within horizontal reach of the previous
    // floor. Extra platforms per row need real reachability planning; until
    // then they could strand the player with no way up.
    final width = 90 + rng.nextDouble() * 80;
    final maxX = cfg.levelWidth - width - 10;
    final jitter = (rng.nextDouble() * 2 - 1) * cfg.reachLimit;
    final x = (_prevRowCenter + jitter - width / 2)
        .clamp(10.0, math.max(10.0, maxX))
        .toDouble();

    final platform = Platform(
      x: x,
      y: y,
      width: width,
      height: cfg.platformHeight,
    );
    platforms.add(platform);
    _prevRowCenter = platform.centerX;
  }
}
