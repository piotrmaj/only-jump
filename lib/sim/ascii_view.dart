import 'dart:math' as math;

import 'game_sim.dart';

/// Renders a coarse ASCII top-down-of-the-tower view. Cheap enough to print
/// from a CLI and good enough for an LLM (or a human) to sanity check a frame
/// without any graphics stack.
class AsciiView {
  const AsciiView._();

  static String render(
    GameSim sim, {
    int cols = 56,
    int rows = 26,
    String? note,
  }) {
    final cfg = sim.config;
    final grid = List.generate(rows, (_) => List<String>.filled(cols, ' '));

    double colOf(double x) =>
        (x / cfg.levelWidth * (cols - 1)).clamp(0, cols - 1).toDouble();
    int rowOf(double y) =>
        ((y - sim.cameraTop) / cfg.viewHeight * (rows - 1))
            .round()
            .clamp(0, rows - 1);

    for (final p in sim.platforms) {
      if (p.y < sim.cameraTop || p.y > sim.viewBottom) continue;
      final row = rowOf(p.y);
      final start = colOf(p.left).round();
      final end = colOf(p.right).round();
      for (var c = start; c <= end && c < cols; c++) {
        if (c >= 0 && grid[row][c] == ' ') grid[row][c] = '=';
      }
    }

    final playerRow = rowOf(sim.player.y);
    final playerCol = colOf(sim.player.x).round();
    if (sim.player.y >= sim.cameraTop && sim.player.y <= sim.viewBottom) {
      grid[playerRow][playerCol] = '@';
    }

    final border = '+${'-' * (cols - 2)}+';
    final buffer = StringBuffer();

    buffer.writeln(
      'floors ${sim.scoreFloor.toStringAsFixed(1)}  '
      'pos (${sim.player.x.toStringAsFixed(0)}, ${sim.player.y.toStringAsFixed(0)})  '
      'vel (${sim.player.vx.toStringAsFixed(0)}, ${sim.player.vy.toStringAsFixed(0)})  '
      '${sim.player.grounded ? 'grounded' : 'airborne'}  '
      '${sim.status.name}',
    );
    if (note != null) buffer.writeln(note);
    buffer.writeln(border);
    for (final row in grid) {
      buffer
        ..write('|')
        ..write(row.join())
        ..writeln('|');
    }
    buffer.writeln(border);
    buffer.writeln(
      'camera ${sim.cameraTop.toStringAsFixed(0)}  '
      'view ${cfg.viewHeight.toStringAsFixed(0)}  '
      'platforms ${sim.platforms.length}  '
      'jumps ${sim.jumps}',
    );
    buffer.write('legend  @ player   = ice platform   ^ up the tower');
    return buffer.toString();
  }

  /// Small sparkline of the climb for logs.
  static String sparkline(List<double> heights) {
    if (heights.isEmpty) return '';
    const levels = '▁▂▃▄▅▆▇█';
    final min = heights.reduce(math.min);
    final max = heights.reduce(math.max);
    final span = math.max(max - min, 1);
    return heights
        .map(
          (h) => levels[((h - min) / span * (levels.length - 1)).round()],
        )
        .join();
  }
}
