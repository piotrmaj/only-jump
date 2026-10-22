/// Mutable player state owned by [GameSim].
class PlayerState {
  PlayerState({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Centre position in world units.
  double x;
  double y;
  double vx = 0;
  double vy = 0;

  final double width;
  final double height;

  bool grounded = false;
  bool facingLeft = false;

  /// True while a sprint jump is spinning. Cleared on landing.
  bool spinJump = false;

  /// Rotation in radians, only meaningful while [spinJump] is true.
  double spin = 0;

  double get left => x - width / 2;
  double get right => x + width / 2;
  double get top => y - height / 2;
  double get bottom => y + height / 2;

  void setBottom(double value) => y = value - height / 2;

  PlayerState copy() => PlayerState(x: x, y: y, width: width, height: height)
    ..vx = vx
    ..vy = vy
    ..grounded = grounded
    ..facingLeft = facingLeft
    ..spinJump = spinJump
    ..spin = spin;
}
