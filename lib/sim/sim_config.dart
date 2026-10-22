/// Tunable constants for the game simulation.
///
/// The simulation is engine agnostic and uses "world units". The level is
/// always [levelWidth] units wide; [viewHeight] is how much of the tower is
/// visible and is derived from the screen aspect ratio by the renderer.
class SimConfig {
  const SimConfig({
    this.levelWidth = 480,
    this.viewHeight = 900,
    this.floorSpacing = 120,
    this.gravity = 2300,
    this.jumpSpeed = 850,
    this.maxFallSpeed = 1500,
    this.moveAccel = 3400,
    this.maxMoveSpeed = 300,
    this.groundFriction = 2800,
    this.airFriction = 900,
    this.sprintTopSpeed = 420,
    this.sprintJumpSpeed = 1850,
    this.wallBounceMaxSpeed = 600,
    this.wallBounceBoost = 1.15,
    this.wallBounceLock = 0.12,
    this.spinRate = 12.5,
    this.starInterval = 0.022,
    this.coyoteTime = 0.10,
    this.jumpBufferTime = 0.12,
    this.comboWindow = 3.0,
    this.playerWidth = 26,
    this.playerHeight = 36,
    this.platformHeight = 12,
    this.startY = 0,
    this.cameraAnchor = 0.62,
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

  /// Top horizontal speed the player can reach by holding a direction.
  final double sprintTopSpeed;

  /// Horizontal launch speed for a jump taken at [wallBounceMaxSpeed]. The
  /// launch scales with the player's velocity at take-off, so this is the top
  /// of the jump range (six floors on the default tower).
  final double sprintJumpSpeed;

  /// Speed ceiling after a wall bounce. Above [sprintTopSpeed], the only way
  /// to go faster is to bounce off a side wall.
  final double wallBounceMaxSpeed;

  /// Speed multiplier applied by each wall bounce.
  final double wallBounceBoost;

  /// Seconds the wall bump owns the horizontal velocity before input returns.
  final double wallBounceLock;

  /// How fast the character spins during a sprint jump, in radians/second.
  final double spinRate;

  /// Seconds between gold stars shed by a spinning sprint jump.
  final double starInterval;

  /// Grace period to jump after walking off a platform.
  final double coyoteTime;

  /// How long a jump press is remembered before landing.
  final double jumpBufferTime;

  /// Reach each floor within this many seconds to stay in a combo.
  final double comboWindow;

  final double playerWidth;
  final double playerHeight;
  final double platformHeight;

  /// Player centre Y at spawn.
  final double startY;

  /// Where the player sits on screen (0 = top, 1 = bottom) once climbing.
  final double cameraAnchor;

  /// Max horizontal offset between a floor and the next one, so every floor
  /// is guaranteed to be reachable.
  final double reachLimit;

  /// Every Nth floor is a full-width safe floor (the start floor counts).
  final int safeFloorInterval;

  /// Highest rise (world units) a normal jump can reach, with a margin.
  double get jumpReach => (jumpSpeed * jumpSpeed) / (2 * gravity) - 8;

  /// Highest rise a jump at wall-bounce speed can reach, with the same margin.
  double get sprintJumpReach =>
      (sprintJumpSpeed * sprintJumpSpeed) / (2 * gravity) - 8;

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
      sprintJumpSpeed: sprintJumpSpeed,
      wallBounceMaxSpeed: wallBounceMaxSpeed,
      wallBounceBoost: wallBounceBoost,
      wallBounceLock: wallBounceLock,
      spinRate: spinRate,
      starInterval: starInterval,
      coyoteTime: coyoteTime,
      jumpBufferTime: jumpBufferTime,
      comboWindow: comboWindow,
      playerWidth: playerWidth,
      playerHeight: playerHeight,
      platformHeight: platformHeight,
      startY: startY,
      cameraAnchor: cameraAnchor,
      reachLimit: reachLimit ?? this.reachLimit,
      safeFloorInterval: safeFloorInterval,
    );
  }
}
