import 'ascii_view.dart';
import 'bots.dart';
import 'game_sim.dart';
import 'input_frame.dart';
import 'input_script.dart';
import 'platform.dart';
import 'sim_config.dart';
import 'sim_snapshot.dart';

/// A scriptable driver around [GameSim].
///
/// Tests, bots and the CLI all use this, so a scenario validated headlessly is
/// exactly the scenario that runs on a phone.
class SimHarness {
  SimHarness({
    SimConfig config = const SimConfig(),
    int seed = 7,
    this.dt = 1 / 60,
    bool autoGenerate = true,
  }) : sim = GameSim(config: config, seed: seed) {
    sim.autoGenerate = autoGenerate;
  }

  final GameSim sim;
  final double dt;

  int frame = 0;

  /// When true every step is stored in [trace] (slower, but great for
  /// debugging a failed scenario).
  bool recordTrace = false;
  final List<TraceFrame> trace = <TraceFrame>[];

  SimSnapshot get snapshot => SimSnapshot.of(sim);

  /// Build a hand-made level. Used by physics tests for full control.
  void useLevel(
    List<Platform> platforms, {
    required double playerBottom,
    double playerX = 240,
  }) {
    sim.autoGenerate = false;
    sim.platforms
      ..clear()
      ..addAll(platforms);
    sim.player
      ..x = playerX
      ..vx = 0
      ..vy = 0
      ..grounded = false
      ..setBottom(playerBottom);
    sim.cameraTop = playerBottom - sim.config.viewHeight * sim.config.cameraAnchor;
    sim.scoreFloor = 0;
    sim.status = SimStatus.playing;
  }

  void runFrames(int frames, [Bot? bot]) {
    for (var i = 0; i < frames; i++) {
      if (sim.status != SimStatus.playing) break;
      step(bot?.next(sim) ?? InputFrame.none);
    }
  }

  void runSeconds(double seconds, [Bot? bot]) =>
      runFrames((seconds / dt).round(), bot);

  void play(InputScript script) {
    for (final segment in script.segments) {
      for (var i = 0; i < segment.frames; i++) {
        if (sim.status != SimStatus.playing) return;
        step(segment.input);
      }
    }
  }

  void step(InputFrame input) {
    sim.step(dt, input);
    if (recordTrace) {
      trace.add(
        TraceFrame(
          frame: frame,
          x: sim.player.x,
          y: sim.player.y,
          vx: sim.player.vx,
          vy: sim.player.vy,
          grounded: sim.player.grounded,
          cameraTop: sim.cameraTop,
          floors: sim.scoreFloor,
          status: sim.status,
        ),
      );
    }
    frame++;
  }

  String dump({int cols = 56, int rows = 24, String? note}) {
    final label = note != null ? 'frame $frame  $note' : 'frame $frame';
    return AsciiView.render(sim, cols: cols, rows: rows, note: label);
  }

  /// Human readable failure context for `expect(..., reason: ...)`.
  String describe() {
    return 'frame=$frame floors=${sim.scoreFloor.toStringAsFixed(1)} '
        'pos=(${sim.player.x.toStringAsFixed(1)}, ${sim.player.y.toStringAsFixed(1)}) '
        'vel=(${sim.player.vx.toStringAsFixed(1)}, ${sim.player.vy.toStringAsFixed(1)}) '
        'grounded=${sim.player.grounded} status=${sim.status.name}\n'
        '${dump(rows: 16)}';
  }
}

class TraceFrame {
  const TraceFrame({
    required this.frame,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.grounded,
    required this.cameraTop,
    required this.floors,
    required this.status,
  });

  final int frame;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final bool grounded;
  final double cameraTop;
  final double floors;
  final SimStatus status;
}
