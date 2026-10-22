import 'dart:math' as math;

import 'input_frame.dart';
import 'platform.dart';
import 'player_state.dart';
import 'sim_config.dart';
import 'trail_star.dart';

enum SimStatus { playing, gameOver }

/// Deterministic, dependency-free game simulation.
///
/// Call [step] with a fixed timestep and an [InputFrame]; everything else
/// (platform generation, camera, scoring) happens here. The Flutter/Flame
/// layer only renders [SimSnapshot]s and feeds input, which means tests can
/// play the exact same game at thousands of steps per second.
class GameSim {
  GameSim({this.config = const SimConfig(), int seed = 7})
    : _rng = math.Random(seed),
      _fxRng = math.Random(seed ^ 0x5f3759df) {
    reset();
  }

  SimConfig config;
  final math.Random _rng;

  /// Separate stream so cosmetic stars never disturb floor generation.
  final math.Random _fxRng;

  PlayerState player = PlayerState(x: 0, y: 0, width: 26, height: 36);
  final List<Platform> platforms = <Platform>[];

  /// Gold stars shed by the current sprint jump. Cosmetic, but simulated so
  /// screenshots and tests see the same trail the phone does.
  final List<TrailStar> stars = <TrailStar>[];

  SimStatus status = SimStatus.playing;

  /// World Y of the top edge of the screen.
  double cameraTop = 0;
  double scoreFloor = 0;
  int jumps = 0;

  /// 0 = walking speed, 1 = full sprint. Builds while running one way.
  double sprintCharge = 0;

  /// Total score: 10 points per floor of height plus completed combo bonuses.
  int points = 0;

  /// Longest completed combo, in floors.
  int bestCombo = 0;

  /// Floors spanned by the combo being built right now.
  int comboFloors = 0;

  /// Jumps that gained at least two floors in the current combo.
  int comboJumps = 0;

  /// Seconds left to reach the next combo floor.
  double comboTimeLeft = 0;

  /// Reward banner state for the HUD ("Great!", "Sweet!", ...).
  String? lastReward;
  int lastRewardPoints = 0;
  double rewardTimeLeft = 0;

  bool _comboActive = false;
  int _comboLastFloor = 0;
  int _lastLandingFloor = 0;
  int _highestFloor = 0;

  /// True while a combo chain is alive.
  bool get comboActive => _comboActive;

  /// Turn off for hand-built test levels.
  bool autoGenerate = true;

  double _coyote = 0;
  double _jumpBuffer = 0;
  double _topRowY = 0;
  double _prevRowCenter = 0;
  double _groundY = 0;
  double _starCooldown = 0;

  /// Row 0 is the start slab; each generated row counts up from there.
  int _rowIndex = 0;

  double get groundY => _groundY;
  double get viewBottom => cameraTop + config.viewHeight;
  bool get sprinting => sprintCharge >= 1;

  void reset() {
    final cfg = config;
    platforms.clear();
    stars.clear();
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
    sprintCharge = 0;
    points = 0;
    bestCombo = 0;
    comboFloors = 0;
    comboJumps = 0;
    comboTimeLeft = 0;
    lastReward = null;
    lastRewardPoints = 0;
    rewardTimeLeft = 0;
    _comboActive = false;
    _comboLastFloor = 0;
    _lastLandingFloor = 0;
    _highestFloor = 0;
    status = SimStatus.playing;
    _coyote = 0;
    _jumpBuffer = 0;
    _starCooldown = 0;
    _rowIndex = 0;
    _topRowY = _groundY;
    _prevRowCenter = cfg.levelWidth / 2;

    // The start floor is a safe floor: full width, so nobody falls off before
    // they have learned the controls.
    platforms.add(
      Platform(
        x: 0,
        y: _groundY,
        width: cfg.levelWidth,
        height: cfg.platformHeight,
        safe: true,
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

    // A jump on this frame uses the sprint the player had when the frame
    // began, so releasing the direction on the same frame as the jump still
    // launches the boost.
    final sprintJump = sprinting;

    // ------------------------------------------------------------------
    // Sprint charge: holding one direction builds speed
    // ------------------------------------------------------------------
    final dir = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    if (dir != 0 && player.vx != 0 && player.vx.sign != dir) {
      // Turning around kills the sprint outright; no free boost for tapping
      // the other way.
      sprintCharge = 0;
    } else if (dir != 0 && player.vx.abs() >= cfg.maxMoveSpeed * 0.5) {
      sprintCharge = math.min(1, sprintCharge + dt / cfg.sprintBuildTime);
    } else {
      sprintCharge = math.max(0, sprintCharge - dt / cfg.sprintReleaseTime);
    }
    final topSpeed =
        cfg.maxMoveSpeed + (cfg.sprintTopSpeed - cfg.maxMoveSpeed) * sprintCharge;

    // ------------------------------------------------------------------
    // Horizontal movement
    // ------------------------------------------------------------------
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
    player.vx = player.vx.clamp(-topSpeed, topSpeed).toDouble();

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
    } else if (player.vy >= 0) {
      // Only floors crossed while falling can support the player; otherwise a
      // rising sprint jump would snap onto the first floor it passes through.
      final support = _supportAt();
      if (support != null) {
        player.setBottom(support.y);
        player.vy = 0;
        player.grounded = true;
        _coyote = cfg.coyoteTime;
      } else {
        player.grounded = false;
      }
    } else {
      player.grounded = false;
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
    // Combos: reaching a higher floor within the combo window chains the
    // chain. Pay out when it ends: bonus = floors squared.
    // ------------------------------------------------------------------
    if (player.grounded && !wasGrounded) {
      _onLanding(_floorAt(player.bottom));
    }
    if (_comboActive) {
      comboTimeLeft -= dt;
      if (comboTimeLeft <= 0) _finishCombo();
    }
    if (rewardTimeLeft > 0) {
      rewardTimeLeft = math.max(0, rewardTimeLeft - dt);
    }

    // ------------------------------------------------------------------
    // Jump
    // ------------------------------------------------------------------
    if (_jumpBuffer > 0 && (player.grounded || _coyote > 0)) {
      final launch = cfg.jumpSpeed * (sprintJump ? cfg.sprintJumpBoost : 1);
      player.vy = -launch;
      player.grounded = false;
      player.spinJump = sprintJump;
      player.spin = 0;
      if (sprintJump) {
        // A little burst on take-off sells the "boost" moment.
        _spawnStar();
        _spawnStar();
        _starCooldown = 0;
      }
      _coyote = 0;
      _jumpBuffer = 0;
      jumps++;
    }

    // ------------------------------------------------------------------
    // Spin and gold star trail
    // ------------------------------------------------------------------
    if (player.spinJump) {
      if (player.grounded) {
        player.spinJump = false;
        player.spin = 0;
      } else {
        player.spin = (player.spin + cfg.spinRate * dt) % (2 * math.pi);
        _starCooldown -= dt;
        if (_starCooldown <= 0) {
          _spawnStar();
          _starCooldown = cfg.starInterval;
        }
      }
    }
    for (final star in stars) {
      star.step(dt);
    }
    stars.removeWhere((star) => star.expired);

    // ------------------------------------------------------------------
    // Camera, world streaming, death
    // ------------------------------------------------------------------
    final target = player.y - cfg.viewHeight * cfg.cameraAnchor;
    if (target < cameraTop) cameraTop = target;

    _streamWorld();

    if (player.top > viewBottom + cfg.gameOverMargin) {
      status = SimStatus.gameOver;
      player.spinJump = false;
      player.spin = 0;
      stars.clear();
    }
  }

  /// Shed one gold star behind the spinning player.
  void _spawnStar() {
    final rng = _fxRng;
    final p = player;
    final back = p.vx == 0 ? 0.0 : p.vx.sign;
    stars.add(
      TrailStar(
        x: p.x - back * (5 + rng.nextDouble() * 6) + (rng.nextDouble() * 2 - 1) * 5,
        y: p.y + (rng.nextDouble() * 2 - 1) * 9,
        vx: -p.vx * 0.22 + (rng.nextDouble() * 2 - 1) * 26,
        vy: -p.vy * 0.10 + (rng.nextDouble() * 2 - 1) * 26 - 18,
        life: 0.32 + rng.nextDouble() * 0.22,
        size: 4.0 + rng.nextDouble() * 2.6,
        phase: rng.nextDouble() * math.pi * 2,
      ),
    );
  }

  /// Floor index for a world bottom coordinate; floor 0 is the start slab.
  int _floorAt(double bottom) =>
      ((config.startY + config.playerHeight / 2 - bottom) / config.floorSpacing)
          .round();

  /// Called on the frame the player touches down. Handles floor points and the
  /// combo chain rules (Icy Tower: 3 s between floors, a one-floor jump ends
  /// the chain).
  void _onLanding(int floor) {
    final gained = floor - _lastLandingFloor;

    if (_comboActive) {
      final advanced = floor - _comboLastFloor;
      if (advanced == 1) {
        // A single-floor hop finishes the combo.
        _finishCombo();
      } else if (advanced >= 2) {
        comboFloors += advanced;
        comboJumps++;
        comboTimeLeft = config.comboWindow;
        _comboLastFloor = floor;
      } else if (advanced < 0) {
        // Falling back down ends the chain.
        _finishCombo();
      }
      // advanced == 0: a straight-up bounce keeps the chain but not the clock.
    } else if (gained >= 2) {
      // Skipping at least one floor starts a new chain.
      _comboActive = true;
      _comboLastFloor = floor;
      comboFloors = gained;
      comboJumps = 1;
      comboTimeLeft = config.comboWindow;
    }

    if (floor > _highestFloor) {
      points += 10 * (floor - _highestFloor);
      _highestFloor = floor;
    }
    _lastLandingFloor = floor;
  }

  void _finishCombo() {
    if (_comboActive && comboFloors >= 4 && comboJumps >= 2) {
      final bonus = comboFloors * comboFloors;
      points += bonus;
      bestCombo = math.max(bestCombo, comboFloors);
      lastReward = comboRewardName(comboFloors);
      lastRewardPoints = bonus;
      rewardTimeLeft = 1.6;
    }
    _comboActive = false;
    comboFloors = 0;
    comboJumps = 0;
    comboTimeLeft = 0;
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
    _rowIndex++;

    // Milestone floors span the whole tower: a guaranteed landing pad that
    // gives the player a breather and a runway for the next sprint.
    if (cfg.safeFloorInterval > 0 && _rowIndex % cfg.safeFloorInterval == 0) {
      platforms.add(
        Platform(
          x: 0,
          y: y,
          width: cfg.levelWidth,
          height: cfg.platformHeight,
          safe: true,
        ),
      );
      _prevRowCenter = cfg.levelWidth / 2;
      return;
    }

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

/// Icy Tower's combo reward names, by combo length in floors.
String comboRewardName(int floors) {
  if (floors >= 200) return 'No way!';
  if (floors >= 140) return 'Splendid!';
  if (floors >= 100) return 'Fantastic!';
  if (floors >= 70) return 'Extreme!';
  if (floors >= 50) return 'Amazing!';
  if (floors >= 35) return 'Wow!';
  if (floors >= 25) return 'Super!';
  if (floors >= 15) return 'Great!';
  if (floors >= 7) return 'Sweet!';
  return 'Good!';
}
