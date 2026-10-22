/// One gold star left behind by a spinning sprint jump.
///
/// Stars live in the simulation, not the renderer, so the trail is
/// deterministic, testable and identical in headless runs and on the phone.
class TrailStar {
  TrailStar({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.phase,
  });

  double x;
  double y;
  double vx;
  double vy;

  /// Seconds until the star disappears.
  final double life;

  /// Base radius in world units.
  final double size;

  /// Where the star sits in its twinkle cycle.
  final double phase;

  double age = 0;

  /// 0 at birth, 1 at death.
  double get t => (age / life).clamp(0.0, 1.0);
  bool get expired => age >= life;

  void step(double dt) {
    age += dt;
    x += vx * dt;
    y += vy * dt;
    // Drag plus a gentle sink, so stars lag behind the jump instead of
    // racing it.
    final drag = (1 - 2.2 * dt).clamp(0.0, 1.0);
    vx *= drag;
    vy = vy * drag - 90 * dt;
  }

  TrailStar copy() => TrailStar(
    x: x,
    y: y,
    vx: vx,
    vy: vy,
    life: life,
    size: size,
    phase: phase,
  )..age = age;
}
