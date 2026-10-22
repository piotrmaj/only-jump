import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:only_jump/game/only_jump_game.dart';
import 'package:only_jump/main.dart';

void main() {
  testWidgets('app boots and shows the climb HUD', (tester) async {
    await tester.pumpWidget(const OnlyJumpApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(GameWidget<OnlyJumpGame>), findsOneWidget);
    expect(find.text('FLOORS'), findsOneWidget);
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });
}
