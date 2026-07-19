import 'dart:collection';

/// Board size: 9x9 classic Quoridor grid.
const int kBoardSize = 9;

enum PlayerId { p1, p2 }

/// A cell position on the 9x9 grid.
class Pos {
  final int row;
  final int col;
  const Pos(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Pos && other.row == row && other.col == col;

  @override
  int get hashCode => row * 100 + col;

  @override
  String toString() => '($row,$col)';
}

/// Orientation of a wall segment.
enum WallOrientation { horizontal, vertical }

/// A wall occupies a 2-cell-long slot, anchored at its top-left intersection.
/// Intersections range from (0,0) to (7,7) on a 9x9 board (8x8 grid of gaps).
///
/// Coordinate convention (must match rendering in board_widget.dart exactly):
/// A horizontal wall at (row, col) sits on the grid line BELOW cell-row `row`
/// (i.e. blocks movement between row `row` and row `row+1`), spanning column
/// `col` and `col+1`.
/// A vertical wall at (row, col) sits on the grid line to the RIGHT of
/// cell-col `col` (i.e. blocks movement between col `col` and col `col+1`),
/// spanning row `row` and `row+1`.
class Wall {
  final int row;
  final int col;
  final WallOrientation orientation;
  final PlayerId? owner;
  const Wall(this.row, this.col, this.orientation, [this.owner]);

  @override
  bool operator ==(Object other) =>
      other is Wall &&
      other.row == row &&
      other.col == col &&
      other.orientation == orientation;

  @override
  int get hashCode => row * 1000 + col * 10 + orientation.index;
}

class GameState {
  Pos p1Pos;
  Pos p2Pos;
  final List<Wall> walls;
  PlayerId turn;
  PlayerId? winner;
  int p1WallsPlaced;
  int p2WallsPlaced;

  GameState({
    Pos? p1Pos,
    Pos? p2Pos,
    List<Wall>? walls,
    this.turn = PlayerId.p1,
    this.winner,
    this.p1WallsPlaced = 0,
    this.p2WallsPlaced = 0,
  })  : p1Pos = p1Pos ?? const Pos(0, 4),
        p2Pos = p2Pos ?? const Pos(kBoardSize - 1, 4),
        walls = walls ?? [];

  Pos posOf(PlayerId id) => id == PlayerId.p1 ? p1Pos : p2Pos;
  int targetRowOf(PlayerId id) => id == PlayerId.p1 ? kBoardSize - 1 : 0;
  PlayerId get other => turn == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;

  GameState clone() => GameState(
        p1Pos: p1Pos,
        p2Pos: p2Pos,
        walls: List.of(walls),
        turn: turn,
        winner: winner,
        p1WallsPlaced: p1WallsPlaced,
        p2WallsPlaced: p2WallsPlaced,
      );
}

/// Handles all rules: legal moves, wall placement validity, pathfinding, win check.
class GameEngine {
  /// Returns true if a wall blocks movement directly between two ORTHOGONALLY
  /// adjacent cells `a` and `b` (must differ by exactly 1 in one axis).
  static bool isBlockedBetween(List<Wall> walls, Pos a, Pos b) {
    if (a.row == b.row) {
      // Horizontal neighbors -> check vertical walls between them.
      final int col = a.col < b.col ? a.col : b.col; // left col
      final int row = a.row;
      // A vertical wall at (wr, wc) sits on the line right of column wc,
      // blocking the gap between column wc and wc+1, for rows wr and wr+1.
      // So it blocks between `col` and `col+1` exactly when w.col == col,
      // for either w.row == row or w.row == row - 1 (wall spans 2 rows).
      for (final w in walls) {
        if (w.orientation != WallOrientation.vertical) continue;
        if (w.col == col && (w.row == row || w.row == row - 1)) {
          return true;
        }
      }
      return false;
    } else if (a.col == b.col) {
      final int row = a.row < b.row ? a.row : b.row; // top row
      final int col = a.col;
      // A horizontal wall at (wr, wc) sits on the line below row wr,
      // blocking the gap between row wr and wr+1, for columns wc and wc+1.
      for (final w in walls) {
        if (w.orientation != WallOrientation.horizontal) continue;
        if (w.row == row && (w.col == col || w.col == col - 1)) {
          return true;
        }
      }
      return false;
    }
    return true; // not adjacent at all
  }

  /// All orthogonal neighbor cells reachable from `pos`, respecting walls
  /// and the "jump over opponent" Quoridor rule.
  static List<Pos> reachableNeighbors(GameState state, Pos pos, Pos opponentPos) {
    final List<Pos> results = [];
    const deltas = [Pos(-1, 0), Pos(1, 0), Pos(0, -1), Pos(0, 1)];

    for (final d in deltas) {
      final next = Pos(pos.row + d.row, pos.col + d.col);
      if (!_inBounds(next)) continue;
      if (isBlockedBetween(state.walls, pos, next)) continue;

      if (next == opponentPos) {
        // Try straight jump over opponent.
        final jump = Pos(next.row + d.row, next.col + d.col);
        final straightBlocked = isBlockedBetween(state.walls, next, jump);
        if (_inBounds(jump) && !straightBlocked) {
          results.add(jump);
        } else {
          // Diagonal jumps (simplified Quoridor side-step rule).
          final sideDeltas = d.row == 0
              ? [const Pos(-1, 0), const Pos(1, 0)]
              : [const Pos(0, -1), const Pos(0, 1)];
          for (final sd in sideDeltas) {
            final diag = Pos(next.row + sd.row, next.col + sd.col);
            if (_inBounds(diag) &&
                !isBlockedBetween(state.walls, next, diag)) {
              results.add(diag);
            }
          }
        }
      } else {
        results.add(next);
      }
    }
    return results;
  }

  static bool _inBounds(Pos p) =>
      p.row >= 0 && p.row < kBoardSize && p.col >= 0 && p.col < kBoardSize;

  /// Legal single-step moves (including jumps) for the current player.
  static List<Pos> legalMoves(GameState state) {
    final me = state.posOf(state.turn);
    final opp = state.posOf(state.other);
    return reachableNeighbors(state, me, opp);
  }

  /// BFS shortest path length from `start` to any cell in target row.
  /// Returns -1 if unreachable.
  static int shortestPathLength(GameState state, Pos start, int targetRow, Pos opponentPos) {
    final visited = <Pos>{start};
    final queue = Queue<_PathNode>();
    queue.add(_PathNode(start, 0));

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (node.pos.row == targetRow) return node.dist;

      for (final next in reachableNeighbors(state, node.pos, opponentPos)) {
        if (visited.contains(next)) continue;
        visited.add(next);
        queue.add(_PathNode(next, node.dist + 1));
      }
    }
    return -1;
  }

  /// Checks whether both players still have at least one path to their goal.
  static bool bothPlayersHavePath(GameState state) {
    final p1Len = shortestPathLength(state, state.p1Pos, kBoardSize - 1, state.p2Pos);
    final p2Len = shortestPathLength(state, state.p2Pos, 0, state.p1Pos);
    return p1Len != -1 && p2Len != -1;
  }

  /// Checks whether a wall placement is structurally valid (in bounds,
  /// no overlap/crossing with existing walls).
  static bool isWallPlacementStructurallyValid(GameState state, Wall wall) {
    if (wall.row < 0 || wall.row > kBoardSize - 2) return false;
    if (wall.col < 0 || wall.col > kBoardSize - 2) return false;

    for (final w in state.walls) {
      if (w == wall) return false;

      if (w.orientation == wall.orientation) {
        // Same orientation: overlap if they share a cell-pair.
        if (wall.orientation == WallOrientation.horizontal) {
          if (w.row == wall.row && (w.col - wall.col).abs() <= 1) return false;
        } else {
          if (w.col == wall.col && (w.row - wall.row).abs() <= 1) return false;
        }
      } else {
        // Perpendicular: they cross if they share the same center intersection.
        if (w.row == wall.row && w.col == wall.col) return false;
      }
    }
    return true;
  }

  /// Full validity check: structural + doesn't fully block either player's path.
  static bool isWallPlacementValid(GameState state, Wall wall) {
    if (!isWallPlacementStructurallyValid(state, wall)) return false;

    final trial = state.clone();
    trial.walls.add(wall);
    return bothPlayersHavePath(trial);
  }

  /// Attempts to move the current player's pawn to `dest`. Returns updated
  /// state if legal, otherwise null.
  static GameState? tryMove(GameState state, Pos dest) {
    if (state.winner != null) return null;
    final legal = legalMoves(state);
    if (!legal.contains(dest)) return null;

    final next = state.clone();
    if (next.turn == PlayerId.p1) {
      next.p1Pos = dest;
    } else {
      next.p2Pos = dest;
    }

    if (dest.row == next.targetRowOf(next.turn)) {
      next.winner = next.turn;
    } else {
      next.turn = next.other;
    }
    return next;
  }

  /// Attempts to place a wall for the current player. Returns updated state
  /// if legal, otherwise null.
  static GameState? tryPlaceWall(GameState state, Wall wall) {
    if (state.winner != null) return null;
    if (!isWallPlacementValid(state, wall)) return null;

    final owned = Wall(wall.row, wall.col, wall.orientation, state.turn);
    final next = state.clone();
    next.walls.add(owned);
    if (next.turn == PlayerId.p1) {
      next.p1WallsPlaced += 1;
    } else {
      next.p2WallsPlaced += 1;
    }
    next.turn = next.other;
    return next;
  }
}

class _PathNode {
  final Pos pos;
  final int dist;
  _PathNode(this.pos, this.dist);
}
