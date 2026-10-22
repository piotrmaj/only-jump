/// Tunable constants for the game simulation.
///
/// The simulation is engine agnostic and uses "world units". The level is
/// always [levelWidth] units wide; [viewHeight] is how much of the tower is
/// visible and is derived from the screen aspect ratio by the renderer.
class SimConfig {
  const SimConfig({
    this.levelWidth = 480,
    this.viewHeight = 900,
    this.floorSpacing = 88,
    this.gravity = 2300,
    this.jumpSpeed = 800,
    this.maxFallSpeed = 1500,
    this.moveAccel = 3400,
    this.maxMoveSpeed = 300,
    this.groundFriction = 2800,
    this.airFriction = 900,
    this.sprintTopSpeed = 420,
    this.sprintBuildTime = 0.6,
    this.sprintReleaseTime = 0.35,
    this.sprintJumpBoost = 1.45,
    this.spinRate = 12.5,
    this.starInterval = 0.022,
    this.coyoteTime = 0.10,
    this.jumpBufferTime = 0.12,
    this.playerWidth = 26,
    this.playerHeight = 36,
    this.platformHeight = 12,
    this.startY = 0,
    this.cameraAnchor = 0.62,
    this.gameOverMargin = 60,
    this.reachLimit = 140,
    this.safeFloorInterval = 50,
  });

  /// Width of a level in world units.
  final double levelWidth;

  /// Visible height of the tower in world units.
  final double viewHeight;

  /// Vertical distance between generated floors.
  final double floorSpacing;

  final double gravity;
  final double jumpSpeed;
  final double maxFallSpeed;

  final double moveAccel;
  final double maxMoveSpeed;
  final double groundFriction;
  final double airFriction;

  /// Top horizontal speed once a one-directional run is fully charged.
  final double sprintTopSpeed;

  /// Seconds of continuous running needed to reach a full sprint.
  final double sprintBuildTime;

  /// Seconds to bleed off a full sprint when the run is broken.
  final double sprintReleaseTime;

  /// Vertical launch multiplier for a jump taken at full sprint.
  final double sprintJumpBoost;

  /// How fast the character spins during a sprint jump, in radians/second.
  final double spinRate;

  /// Seconds between gold stars shed by a spinning sprint jump.
  final double starInterval;

  /// Grace period to jump after walking off a platform.
  final double coyoteTime;

  /// How long a jump press is remembered before landing.
  final double jumpBufferTime;

  final double playerWidth;
  final double playerHeight;
  final double platformHeight;

  /// Player centre Y at spawn.
  final double startY;

  /// Where the player sits on screen (0 = top, 1 = bottom) once climbing.
  final double cameraAnchor;

  /// Falling this far below the view ends the run.
  final double gameOverMargin;

  /// Max horizontal offset between a floor and the next one, so every floor
  /// is guaranteed to be reachable.
  final double reachLimit;

  /// Every Nth floor is a full-width safe floor (the start floor counts).
  final int safeFloorInterval;

  /// Highest rise (world units) a jump can reach, with a safety margin.
  double get jumpReach => (jumpSpeed * jumpSpeed) / (2 * gravity) - 8;

  /// Highest rise a sprint jump can reach, with the same margin.
  double get sprintJumpReach =>
      (jumpSpeed * sprintJumpBoost) * (jumpSpeed * sprintJumpBoost) /
          (2 * gravity) -
      8;

  SimConfig copyWith({
    double? viewHeight,
    double? floorSpacing,
    double? gravity,
    double? jumpSpeed,
    double? maxMoveSpeed,
    double? reachLimit,
  }) {
    return SimConfig(
      levelWidth: levelWidth,
      viewHeight: viewHeight ?? this.viewHeight,
      floorSpacing: floorSpacing ?? this.floorSpacing,
      gravity: gravity ?? this.gravity,
      jumpSpeed: jumpSpeed ?? this.jumpSpeed,
      maxFallSpeed: maxFallSpeed,
      moveAccel: moveAccel,
      maxMoveSpeed: maxMoveSpeed ?? this.maxMoveSpeed,
      groundFriction: groundFriction,
      airFriction: airFriction,
      sprintTopSpeed: sprintTopSpeed,
      sprintBuildTime: sprintBuildTime,
      sprintReleaseTime: sprintReleaseTime,
      sprintJumpBoost: sprintJumpBoost,
      spinRate: spinRate,
      starInterval: starInterval,
      coyoteTime: coyoteTime,
      jumpBufferTime: jumpBufferTime,
      playerWidth: playerWidth,
      playerHeight: playerHeight,
      platformHeight: platformHeight,
      startY: startY,
      cameraAnchor: cameraAnchor,
      gameOverMargin: gameOverMargin,
      reachLimit: reachLimit ?? this.reachLimit,
      safeFloorInterval: safeFloorInterval,
    );
  }
}
