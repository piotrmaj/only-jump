import 'game_sim.dart';
import 'platform.dart';
import 'player_state.dart';

/// Immutable frame data handed to the renderer and to screenshot tests.
class SimSnapshot {
  SimSnapshot({
    required this.levelWidth,
    required this.viewHeight,
    required this.cameraTop,
    required this.player,
    required this.platforms,
    required this.scoreFloor,
    required this.status,
    required this.jumps,
  });

  factory SimSnapshot.of(GameSim sim) {
    return SimSnapshot(
      levelWidth: sim.config.levelWidth,
      viewHeight: sim.config.viewHeight,
      cameraTop: sim.cameraTop,
      player: sim.player.copy(),
      platforms: List<Platform>.of(sim.platforms),
      scoreFloor: sim.scoreFloor,
      status: sim.status,
      jumps: sim.jumps,
    );
  }

  final double levelWidth;
  final double viewHeight;
  final double cameraTop;
  final PlayerState player;
  final List<Platform> platforms;
  final double scoreFloor;
  final SimStatus status;
  final int jumps;

  double get viewBottom => cameraTop + viewHeight;
  int get floors => scoreFloor.floor();
}
