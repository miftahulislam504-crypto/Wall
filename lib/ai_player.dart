import 'dart:math';
import 'game_logic.dart';

/// A lightweight heuristic AI:
/// - Mostly moves toward its goal via BFS shortest path.
/// - Occasionally places a wall in front of the opponent's shortest path
///   if that wall would slow the opponent down more than it slows itself.
class AiPlayer {
  final Random _rng = Random();

  /// Decides and applies the AI's move for [state], returning the new state.
  /// Assumes it is currently the AI's turn.
  GameState decideMove(GameState state) {
    final aiId = state.turn;
    final humanId = state.other;

    final aiPos = state.posOf(aiId);
    final humanPos = state.posOf(humanId);
    final aiTarget = state.targetRowOf(aiId);
    final humanTarget = state.targetRowOf(humanId);

    final myPathLen =
        GameEngine.shortestPathLength(state, aiPos, aiTarget, humanPos);
    final oppPathLen =
        GameEngine.shortestPathLength(state, humanPos, humanTarget, aiPos);

    // Decide whether to try a blocking wall this turn.
    final wallsAvailable = true; // unlimited walls
    final shouldConsiderWall =
        wallsAvailable && oppPathLen != -1 && oppPathLen <= myPathLen + 2;

    if (shouldConsiderWall && _rng.nextDouble() < 0.35) {
      final blockingWall = _findGoodBlockingWall(state, aiId, humanId);
      if (blockingWall != null) {
        final result = GameEngine.tryPlaceWall(state, blockingWall);
        if (result != null) return result;
      }
    }

    // Otherwise, move along shortest path toward goal.
    final moves = GameEngine.legalMoves(state);
    if (moves.isEmpty) {
      // Should not normally happen; pass turn safely by returning unchanged.
      return state;
    }

    Pos? bestMove;
    int bestDist = 1 << 30;
    for (final m in moves) {
      final d = GameEngine.shortestPathLength(state, m, aiTarget, humanPos);
      final dist = d == -1 ? (1 << 29) : d;
      if (dist < bestDist) {
        bestDist = dist;
        bestMove = m;
      }
    }

    bestMove ??= moves[_rng.nextInt(moves.length)];
    final result = GameEngine.tryMove(state, bestMove);
    return result ?? state;
  }

  /// Tries a handful of candidate walls near the opponent's path and picks
  /// one that increases the opponent's path length the most while remaining
  /// legal (i.e. doesn't fully block anyone).
  Wall? _findGoodBlockingWall(GameState state, PlayerId aiId, PlayerId humanId) {
    final humanPos = state.posOf(humanId);
    final aiPos = state.posOf(aiId);
    final humanTarget = state.targetRowOf(humanId);
    final currentOppLen =
        GameEngine.shortestPathLength(state, humanPos, humanTarget, aiPos);
    if (currentOppLen == -1) return null;

    Wall? best;
    int bestGain = 0;

    // Only search walls near the opponent's current position to keep this fast.
    final rowStart = max(0, humanPos.row - 2);
    final rowEnd = min(kBoardSize - 2, humanPos.row + 2);
    final colStart = max(0, humanPos.col - 2);
    final colEnd = min(kBoardSize - 2, humanPos.col + 2);

    for (int r = rowStart; r <= rowEnd; r++) {
      for (int c = colStart; c <= colEnd; c++) {
        for (final orientation in WallOrientation.values) {
          final candidate = Wall(r, c, orientation);
          if (!GameEngine.isWallPlacementValid(state, candidate)) continue;

          final trial = state.clone();
          trial.walls.add(candidate);
          final newOppLen = GameEngine.shortestPathLength(
              trial, humanPos, humanTarget, aiPos);
          if (newOppLen == -1) continue;

          final gain = newOppLen - currentOppLen;
          if (gain > bestGain) {
            bestGain = gain;
            best = candidate;
          }
        }
      }
    }

    return bestGain > 0 ? best : null;
  }
}
