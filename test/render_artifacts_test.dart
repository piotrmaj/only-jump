import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:only_jump/render/sim_painter.dart';
import 'package:only_jump/sim/bots.dart';
import 'package:only_jump/sim/game_sim.dart';
import 'package:only_jump/sim/harness.dart';
import 'package:only_jump/sim/sim_config.dart';
import 'package:only_jump/sim/sim_snapshot.dart';

/// Renders the real painter into PNGs. Read these files to visually verify a
/// change without a phone: they are the "eyes" of the feedback loop.
Future<void> renderPng(
  SimSnapshot snapshot,
  String path, {
  Size size = const Size(480, 900),
  bool debug = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  SimPainter(snapshot, showDebug: debug).paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('writes gameplay screenshots to test/artifacts', (tester) async {
    await tester.runAsync(() async {
      final harness = SimHarness(
        config: const SimConfig(viewHeight: 900),
        seed: 11,
      );
      final bot = GreedyBot();

      for (final stop in [0, 60, 120, 240, 360]) {
        while (harness.frame < stop) {
          harness.runFrames(1, bot);
        }
        final name = stop.toString().padLeft(3, '0');
        await renderPng(harness.snapshot, 'test/artifacts/frame_$name.png');
      }
    });

    final first = File('test/artifacts/frame_000.png');
    expect(first.existsSync(), isTrue);
    expect(first.lengthSync(), greaterThan(2000));
  });

  testWidgets('writes a game over screenshot', (tester) async {
    await tester.runAsync(() async {
      final harness = SimHarness(
        config: const SimConfig(viewHeight: 900),
        seed: 4,
      );
      // Idle on the starting slab, then walk off the edge and fall.
      harness.runSeconds(2);
      harness.runSeconds(8, RandomBot(3));
      expect(harness.sim.status, SimStatus.gameOver);
      await renderPng(
        harness.snapshot,
        'test/artifacts/game_over_${harness.sim.status.name}.png',
      );
    });
  });

  testWidgets('writes a debug overlay screenshot', (tester) async {
    await tester.runAsync(() async {
      final harness = SimHarness(
        config: const SimConfig(viewHeight: 900),
        seed: 11,
      );
      harness.runSeconds(4, GreedyBot());
      await renderPng(
        harness.snapshot,
        'test/artifacts/debug_overlay.png',
        debug: true,
      );
    });
  });
}
