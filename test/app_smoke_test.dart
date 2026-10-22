import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:only_jump/game/only_jump_game.dart';
import 'package:only_jump/main.dart';

void main() {
  test('a tap is not lost between fixed steps', () {
    final game = OnlyJumpGame();
    game.onGameResize(Vector2(480, 900));

    // Two third-of-a-step frames: no simulation step happens yet.
    game.update(1 / 240);
    game.queueJump();
    game.update(1 / 240);
    expect(game.sim.jumps, 0, reason: 'nothing should step this early');

    game.update(1 / 120);
    expect(
      game.sim.jumps,
      1,
      reason: 'the queued tap was dropped before reaching a fixed step',
    );
  });

  testWidgets('app boots and shows the climb HUD', (tester) async {
    await tester.pumpWidget(const OnlyJumpApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(GameWidget<OnlyJumpGame>), findsOneWidget);
    expect(find.text('FLOORS'), findsOneWidget);
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });
}
