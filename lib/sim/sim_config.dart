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
    this.coyoteTime = 0.10,
    this.jumpBufferTime = 0.12,
    this.playerWidth = 26,
    this.playerHeight = 36,
    this.platformHeight = 12,
    this.startY = 0,
    this.cameraAnchor = 0.62,
    this.gameOverMargin = 60,
    this.reachLimit = 140,
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

  /// Highest rise (world units) a jump can reach, with a safety margin.
  double get jumpReach => (jumpSpeed * jumpSpeed) / (2 * gravity) - 8;

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
      coyoteTime: coyoteTime,
      jumpBufferTime: jumpBufferTime,
      playerWidth: playerWidth,
      playerHeight: playerHeight,
      platformHeight: platformHeight,
      startY: startY,
      cameraAnchor: cameraAnchor,
      gameOverMargin: gameOverMargin,
      reachLimit: reachLimit ?? this.reachLimit,
    );
  }
}
