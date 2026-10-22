import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sim/sim_snapshot.dart';

/// Draws a [SimSnapshot]. Shared by the game and by screenshot tests, so what
/// I validate headlessly is what ships.
class SimPainter extends CustomPainter {
  SimPainter(this.snapshot, {this.showDebug = false, this.time = 0});

  final SimSnapshot snapshot;
  final bool showDebug;
  final double time;

  static const Color _deep = Color(0xFF050B16);
  static const Color _mid = Color(0xFF0B1B33);
  static const Color _low = Color(0xFF14436B);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final scale = size.width / snapshot.levelWidth;
    _paintBackground(canvas, size);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    canvas.translate(0, -snapshot.cameraTop);
    _paintPlatforms(canvas);
    _paintStars(canvas);
    _paintPlayer(canvas);
    if (showDebug) _paintDebug(canvas);
    canvas.restore();
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_deep, _mid, _low],
      stops: [0.0, 0.55, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Parallax stars: deterministic, cheap, and they sell the height.
    final starPaint = Paint()..color = const Color(0xFFB7DDF7).withValues(alpha: 0.35);
    for (var i = 0; i < 46; i++) {
      final fx = (i * 0.6180339887) % 1.0;
      final base = (i * 0.317) % 1.0;
      final y = ((base * size.height) - snapshot.cameraTop * 0.12) % size.height;
      canvas.drawCircle(
        Offset(fx * size.width, y.abs()),
        i % 5 == 0 ? 1.6 : 1.0,
        starPaint,
      );
    }

    // Drifting snow.
    final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (var i = 0; i < 34; i++) {
      final fx = (i * 0.7548776662) % 1.0;
      final y = ((i * 0.213 * size.height) + time * (18 + i % 7 * 4)) % size.height;
      canvas.drawCircle(
        Offset(fx * size.width + math.sin(time * 0.7 + i) * 6, y),
        1.2 + (i % 3) * 0.5,
        snowPaint,
      );
    }
  }

  void _paintPlatforms(Canvas canvas) {
    final body = Paint()..color = const Color(0xFF8FD3F4);
    final top = Paint()..color = const Color(0xFFEAF9FF);
    final shade = Paint()..color = const Color(0xFF3E7FA8);

    final safeBody = Paint()..color = const Color(0xFFA6E2FA);
    final safeTop = Paint()..color = const Color(0xFFFFE7A8);
    final safeGlow = Paint()
      ..color = const Color(0xFFFFC94D).withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    for (final p in snapshot.platforms) {
      if (p.bottom < snapshot.cameraTop - 8 || p.y > snapshot.viewBottom + 8) {
        continue;
      }
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(p.x, p.y, p.width, p.height),
        const Radius.circular(4),
      );
      if (p.safe) {
        canvas.drawRRect(rrect.inflate(1.5), safeGlow);
      }
      canvas.drawRRect(rrect, p.safe ? safeBody : body);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x, p.y, p.width, 3.5),
          const Radius.circular(2),
        ),
        p.safe ? safeTop : top,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x + 2, p.y + p.height - 3, p.width - 4, 3),
          const Radius.circular(2),
        ),
        shade,
      );
    }
  }

  /// Gold stars trailing a spinning sprint jump.
  void _paintStars(Canvas canvas) {
    const gold = Color(0xFFFFC63D);
    const spark = Color(0xFFFFF6C2);

    for (final star in snapshot.stars) {
      if (star.y < snapshot.cameraTop - 20 ||
          star.y > snapshot.viewBottom + 20) {
        continue;
      }
      final fade = 1 - star.t;
      final twinkle = 0.85 + 0.15 * math.sin(star.phase + star.age * 34);
      final radius = star.size * (0.55 + 0.45 * fade) * twinkle;
      final center = Offset(star.x, star.y);

      canvas.drawCircle(
        center,
        radius * 2.1,
        Paint()
          ..color = gold.withValues(alpha: 0.18 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        _starPath(center, radius, radius * 0.44, star.phase + star.age * 5),
        Paint()..color = Color.lerp(spark, gold, star.t)!.withValues(alpha: fade),
      );
    }
  }

  static Path _starPath(
    Offset center,
    double outer,
    double inner,
    double rotation, {
    int points = 5,
  }) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = rotation - math.pi / 2 + i * math.pi / points;
      final offset = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    return path..close();
  }

  void _paintPlayer(Canvas canvas) {
    final p = snapshot.player;
    final left = p.left;
    final bodyRect = Rect.fromLTWH(left, p.top, p.width, p.height);

    // Full sprint arms the character: a gold halo reads "jump now" without a
    // separate charge meter on the HUD.
    if (snapshot.sprintCharge > 0.05) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.width * (0.75 + 0.25 * snapshot.sprintCharge),
        Paint()
          ..color = const Color(0xFFFFC63D)
              .withValues(alpha: 0.10 + 0.20 * snapshot.sprintCharge)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // Soft shadow so the jump arc reads better. Stays flat while the body
    // spins.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.x, p.bottom + 3),
        width: p.width * 0.9,
        height: 6,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    canvas.save();
    if (p.spinJump) {
      canvas.translate(p.x, p.y);
      canvas.rotate(p.spin);
      canvas.translate(-p.x, -p.y);
    }

    final body = RRect.fromRectAndRadius(bodyRect, const Radius.circular(9));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFA8E0FF)],
        ).createShader(bodyRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF2C6E96),
    );

    // Scarf.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left - 1.5, p.top + p.height - 14, p.width + 3, 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFFFF8A3D),
    );

    // Eyes, shifted towards the facing direction.
    final eyeX = p.x + (p.facingLeft ? -3.5 : 3.5);
    final eyeY = p.top + p.height * 0.42;
    final eyePaint = Paint()..color = const Color(0xFF0B2033);
    canvas.drawCircle(Offset(eyeX, eyeY), 2.4, eyePaint);
    canvas.drawCircle(Offset(eyeX + (p.facingLeft ? 5 : -5), eyeY), 2.4, eyePaint);

    // Feet.
    final feetY = p.bottom - 2.5;
    final feetPaint = Paint()..color = const Color(0xFF2C6E96);
    canvas.drawOval(Rect.fromCenter(center: Offset(p.x - 6, feetY), width: 9, height: 4), feetPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(p.x + 6, feetY), width: 9, height: 4), feetPaint);

    canvas.restore();
  }

  void _paintDebug(Canvas canvas) {
    final hitbox = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFF4D6D);
    canvas.drawRect(
      Rect.fromLTWH(
        snapshot.player.left,
        snapshot.player.top,
        snapshot.player.width,
        snapshot.player.height,
      ),
      hitbox,
    );

    final platformEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF6CFF9E).withValues(alpha: 0.8);
    for (final p in snapshot.platforms) {
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.width, p.height), platformEdge);
    }

    final bounds = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFD166);
    canvas.drawRect(
      Rect.fromLTWH(0, snapshot.cameraTop, snapshot.levelWidth, snapshot.viewHeight),
      bounds,
    );
  }

  @override
  bool shouldRepaint(covariant SimPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.showDebug != showDebug ||
      oldDelegate.time != time;
}
