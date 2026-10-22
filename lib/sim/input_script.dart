import 'input_frame.dart';

/// Declarative input recording, e.g.
///
/// ```text
/// # frames input
/// 40 right
/// 1  right+jump
/// 24 idle
/// ```
class InputScript {
  const InputScript(this.segments);

  final List<InputSegment> segments;

  factory InputScript.parse(String source) {
    final segments = <InputSegment>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i].split('#').first.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) {
        throw FormatException('line $lineNo: expected "<frames> <input>"');
      }
      final frames = int.tryParse(parts[0]);
      if (frames == null || frames < 0) {
        throw FormatException('line $lineNo: bad frame count "${parts[0]}"');
      }

      var left = false;
      var right = false;
      var jump = false;
      for (final atom in parts.skip(1)) {
        for (final token in atom.split('+')) {
          switch (token) {
            case 'idle' || 'none':
              break;
            case 'left':
              left = true;
            case 'right':
              right = true;
            case 'jump':
              jump = true;
            default:
              throw FormatException('line $lineNo: unknown input "$token"');
          }
        }
      }
      segments.add(
        InputSegment(
          frames,
          InputFrame(left: left, right: right, jump: jump),
        ),
      );
    }
    return InputScript(segments);
  }

  int get totalFrames =>
      segments.fold(0, (sum, segment) => sum + segment.frames);

  @override
  String toString() => segments.map((s) => '${s.frames} ${s.input}').join('\n');
}

class InputSegment {
  const InputSegment(this.frames, this.input);

  final int frames;
  final InputFrame input;
}
