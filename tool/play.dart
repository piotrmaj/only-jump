import 'dart:io';

import 'package:only_jump/sim/ascii_view.dart';
import 'package:only_jump/sim/bots.dart';
import 'package:only_jump/sim/game_sim.dart';
import 'package:only_jump/sim/harness.dart';
import 'package:only_jump/sim/input_script.dart';
import 'package:only_jump/sim/sim_config.dart';

/// Headless player. Prints what happened and exits non-zero when the run
/// misses the requested bar, so it doubles as a smoke test.
///
/// Usage:
///   dart run tool/play.dart
///   dart run tool/play.dart --frames 3600 --bot greedy --min-floors 30
///   dart run tool/play.dart --script test/scripts/climb.txt --min-floors 5
///   dart run tool/play.dart --bot random --seed 12 --no-ascii
void main(List<String> args) {
  var frames = 1800;
  var seed = 7;
  var botName = 'greedy';
  var minFloors = 1;
  var scriptPath = '';
  var ascii = true;
  var cols = 56;
  var rows = 24;
  var viewHeight = 900.0;

  Never fail(String message, [List<String> hints = const []]) {
    stderr.writeln('error: $message');
    for (final hint in hints) {
      stderr.writeln('       $hint');
    }
    stderr.writeln('run with --help for usage');
    exit(2);
  }

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String value() {
      if (i + 1 >= args.length) fail('missing value for $arg');
      return args[++i];
    }

    if (arg == '--frames') {
      frames = int.tryParse(value()) ?? fail('--frames needs a number');
    } else if (arg == '--seed') {
      seed = int.tryParse(value()) ?? fail('--seed needs a number');
    } else if (arg == '--bot') {
      botName = value();
    } else if (arg == '--min-floors') {
      minFloors = int.tryParse(value()) ?? fail('--min-floors needs a number');
    } else if (arg == '--script') {
      scriptPath = value();
    } else if (arg == '--view-height') {
      viewHeight = double.tryParse(value()) ?? fail('--view-height needs a number');
    } else if (arg == '--cols') {
      cols = int.tryParse(value()) ?? fail('--cols needs a number');
    } else if (arg == '--rows') {
      rows = int.tryParse(value()) ?? fail('--rows needs a number');
    } else if (arg == '--no-ascii') {
      ascii = false;
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln(_usage);
      return;
    } else {
      fail('unknown argument "$arg"');
    }
  }

  final Bot bot;
  switch (botName) {
    case 'idle':
      bot = const IdleBot();
      break;
    case 'random':
      bot = RandomBot(seed);
      break;
    case 'greedy':
      bot = GreedyBot();
      break;
    default:
      fail('unknown bot "$botName"', ['available bots: idle, greedy, random']);
  }

  final harness = SimHarness(
    config: SimConfig(viewHeight: viewHeight),
    seed: seed,
  );
  final heights = <double>[];
  final stopwatch = Stopwatch()..start();

  if (scriptPath.isNotEmpty) {
    final file = File(scriptPath);
    if (!file.existsSync()) fail('script not found: $scriptPath');
    final script = InputScript.parse(file.readAsStringSync());
    if (frames < script.totalFrames) frames = script.totalFrames;
    harness.play(script);
  }

  while (harness.frame < frames) {
    harness.runFrames(1, bot);
    if (harness.frame % 30 == 0) heights.add(harness.sim.scoreFloor);
    if (harness.sim.status == SimStatus.gameOver) break;
  }
  heights.add(harness.sim.scoreFloor);
  stopwatch.stop();

  final floors = harness.sim.scoreFloor.floor();
  final perSecond = stopwatch.elapsedMilliseconds == 0
      ? harness.frame
      : (harness.frame * 1000 / stopwatch.elapsedMilliseconds).round();

  if (ascii) {
    stdout.writeln(
      harness.dump(
        cols: cols,
        rows: rows,
        note: scriptPath.isEmpty ? 'bot: $botName seed: $seed' : 'script: $scriptPath',
      ),
    );
    stdout.writeln();
  }

  stdout.writeln('frames      ${harness.frame} (${stopwatch.elapsedMilliseconds} ms, $perSecond steps/s)');
  stdout.writeln('bot         $botName');
  stdout.writeln('seed        $seed');
  stdout.writeln('floors      ${harness.sim.scoreFloor.toStringAsFixed(1)}');
  stdout.writeln('jumps       ${harness.sim.jumps}');
  stdout.writeln('points      ${harness.sim.points}');
  stdout.writeln('best combo  ${harness.sim.bestCombo}');
  stdout.writeln('status      ${harness.sim.status.name}');
  if (heights.length > 1) {
    stdout.writeln('climb       ${AsciiView.sparkline(heights)}');
  }

  if (harness.sim.status == SimStatus.gameOver) {
    stdout.writeln('note        the run ended below the camera');
  }

  if (floors < minFloors) {
    stderr.writeln(
      'FAIL: climbed $floors floors, needed $minFloors\n${harness.describe()}',
    );
    exit(1);
  }
  stdout.writeln('OK');
}

const String _usage = '''
Headless Only Jump runner.

  --frames <n>        simulation frames to run (default 1800 = 30 s)
  --bot <name>        idle | greedy | random (default greedy)
  --seed <n>          platform/random seed (default 7)
  --min-floors <n>    exit 1 if the run climbs less than this (default 1)
  --script <file>     play a recorded input script instead of a bot
  --view-height <px>  logical view height fed to the simulation (default 900)
  --cols/--rows <n>   ASCII board size
  --no-ascii          only print the summary
  -h, --help          this text
''';
