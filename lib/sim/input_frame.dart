/// One frame of player intent. Bots, scripted tests and touch controls all
/// speak this language, which keeps gameplay identical everywhere.
class InputFrame {
  const InputFrame({this.left = false, this.right = false, this.jump = false});

  final bool left;
  final bool right;
  final bool jump;

  static const InputFrame none = InputFrame();

  InputFrame copyWith({bool? left, bool? right, bool? jump}) {
    return InputFrame(
      left: left ?? this.left,
      right: right ?? this.right,
      jump: jump ?? this.jump,
    );
  }

  @override
  String toString() {
    final parts = <String>[
      if (left) 'left',
      if (right) 'right',
      if (jump) 'jump',
    ];
    return parts.isEmpty ? 'idle' : parts.join('+');
  }
}
