import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/only_jump_game.dart';
import '../sim/game_sim.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final OnlyJumpGame _game = OnlyJumpGame(
    seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _restart() {
    _game.restart();
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final down = event is KeyDownEvent;
    final up = event is KeyUpEvent;
    if (!down && !up) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _game.setLeft(down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      _game.setRight(down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      _game.setJumpHeld(down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR && down) {
      _restart();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyG && down) {
      _game.showDebug.value = !_game.showDebug.value;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && down && _game.status.value == SimStatus.gameOver) {
      _restart();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF050B16),
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: _game),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _game.queueJump(),
            ),
            _Hud(game: _game),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 92),
                  child: IgnorePointer(child: _ComboHud(game: _game)),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _Controls(game: _game),
              ),
            ),
            _GameOverOverlay(game: _game, onRestart: _restart),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game});

  final OnlyJumpGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: game.floors,
                builder: (context, floors, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$floors',
                        style: const TextStyle(
                          fontSize: 52,
                          height: 0.95,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Color(0xFF66C7FF), blurRadius: 18),
                          ],
                        ),
                      ),
                      const Text(
                        'FLOORS',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8FD3F4),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (context, score, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDDF4FF),
                        ),
                      ),
                      const Text(
                        'SCORE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8FD3F4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<int>(
                        valueListenable: game.bestScore,
                        builder: (context, best, _) => Text(
                          'BEST $best',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6FB8DE),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboHud extends StatelessWidget {
  const _ComboHud({required this.game});

  final OnlyJumpGame game;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC63D);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: game.combo,
          builder: (context, combo, _) {
            if (combo < 2) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gold.withValues(alpha: 0.75),
                  width: 1.5,
                ),
              ),
              child: Text(
                'COMBO  $combo',
                style: const TextStyle(
                  fontSize: 15,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE7A8),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<String?>(
          valueListenable: game.reward,
          builder: (context, reward, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: reward == null
                  ? const SizedBox.shrink()
                  : Text(
                      reward,
                      key: ValueKey<String>(reward),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD166),
                        shadows: [
                          Shadow(color: Color(0x99FFB300), blurRadius: 12),
                        ],
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.game});

  final OnlyJumpGame game;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _HoldButton(
          size: 68,
          icon: Icons.chevron_left_rounded,
          onChanged: game.setLeft,
        ),
        const SizedBox(width: 10),
        _HoldButton(
          size: 68,
          icon: Icons.chevron_right_rounded,
          onChanged: game.setRight,
        ),
        const Spacer(),
        _HoldButton(
          size: 84,
          label: 'JUMP',
          onChanged: game.setJumpHeld,
        ),
      ],
    );
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.size,
    required this.onChanged,
    this.icon,
    this.label,
  });

  final double size;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final String? label;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  final Set<int> _pointers = <int>{};
  bool _pressed = false;

  void _apply(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
    widget.onChanged(pressed);
  }

  void _down(PointerDownEvent event) {
    _pointers.add(event.pointer);
    _apply(true);
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _apply(false);
  }

  @override
  Widget build(BuildContext context) {
    const ice = Color(0xFF7FD4FF);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ice.withValues(alpha: _pressed ? 0.5 : 0.14),
          border: Border.all(
            color: ice.withValues(alpha: _pressed ? 0.95 : 0.35),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: ice.withValues(alpha: _pressed ? 0.35 : 0.12),
              blurRadius: _pressed ? 18 : 8,
            ),
          ],
        ),
        child: widget.icon != null
            ? Icon(widget.icon, size: widget.size * 0.6, color: const Color(0xFFDDF4FF))
            : Text(
                widget.label!,
                style: TextStyle(
                  fontSize: widget.size * 0.2,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFDDF4FF),
                ),
              ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game, required this.onRestart});

  final OnlyJumpGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SimStatus>(
      valueListenable: game.status,
      builder: (context, status, _) {
        if (status != SimStatus.gameOver) return const SizedBox.shrink();
        return Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You fell',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: game.floors,
                builder: (context, floors, _) => Text(
                  '$floors floors',
                  style: const TextStyle(fontSize: 18, color: Color(0xFFB7E4FF)),
                ),
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (context, score, _) => Text(
                  '$score points',
                  style: const TextStyle(fontSize: 18, color: Color(0xFFB7E4FF)),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: game.bestCombo,
                builder: (context, combo, _) => Text(
                  'best combo $combo',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8FD3F4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRestart,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7FD4FF),
                  foregroundColor: const Color(0xFF06233A),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                child: const Text('CLIMB AGAIN'),
              ),
            ],
          ),
        );
      },
    );
  }
}
