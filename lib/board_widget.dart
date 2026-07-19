import 'package:flutter/material.dart';
import 'game_logic.dart';

/// Colors matching the reference dark/neon theme (red vs blue).
const Color kP1Color = Color(0xFF3B82F6); // blue
const Color kP2Color = Color(0xFFEF4444); // red
const Color kBoardBg = Color(0xFF141B2E);
const Color kGridLine = Color(0xFF2A3350);
const Color kWallColor = Color(0xFFE0B84A);
const Color kHighlight = Color(0x553B82F6);

/// Interactive board widget. Reports taps on cells and wall-gap slots.
class BoardWidget extends StatelessWidget {
  final GameState state;
  final List<Pos> legalMoveTargets;
  final Wall? hoverWall;
  final void Function(Pos cell) onCellTap;
  final void Function(Wall wall) onWallTap;

  const BoardWidget({
    super.key,
    required this.state,
    required this.legalMoveTargets,
    required this.onCellTap,
    required this.onWallTap,
    this.hoverWall,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return GestureDetector(
            onTapUp: (details) => _handleTap(details.localPosition, size),
            child: CustomPaint(
              size: Size(size, size),
              painter: _BoardPainter(
                state: state,
                legalMoveTargets: legalMoveTargets,
                hoverWall: hoverWall,
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(Offset local, double boardSize) {
    // Layout: 9 cells + 8 gaps, gap width = 18% of a cell for wall-tap targets.
    const n = kBoardSize;
    final cell = boardSize / (n + (n - 1) * 0.18);
    final gap = cell * 0.18;
    final unit = cell + gap;

    double posToCoord(double p) => p / unit;

    final rowCoord = posToCoord(local.dy);
    final colCoord = posToCoord(local.dx);

    final rowFrac = rowCoord - rowCoord.floorToDouble();
    final colFrac = colCoord - colCoord.floorToDouble();
    final cellFrac = cell / unit;

    final isNearRowGap = rowFrac > cellFrac;
    final isNearColGap = colFrac > cellFrac;

    if (isNearRowGap && !isNearColGap) {
      // Tapped in a horizontal gap band -> horizontal wall.
      final r = rowCoord.floor();
      final c = colCoord.floor();
      if (r >= 0 && r <= n - 2 && c >= 0 && c <= n - 2) {
        onWallTap(Wall(r, c, WallOrientation.horizontal));
        return;
      }
    } else if (isNearColGap && !isNearRowGap) {
      final r = rowCoord.floor();
      final c = colCoord.floor();
      if (r >= 0 && r <= n - 2 && c >= 0 && c <= n - 2) {
        onWallTap(Wall(r, c, WallOrientation.vertical));
        return;
      }
    } else if (isNearRowGap && isNearColGap) {
      // Corner/intersection tap: default to whichever orientation has more overlap.
      final r = rowCoord.floor();
      final c = colCoord.floor();
      if (r >= 0 && r <= n - 2 && c >= 0 && c <= n - 2) {
        final orientation = (rowFrac - cellFrac) > (colFrac - cellFrac)
            ? WallOrientation.horizontal
            : WallOrientation.vertical;
        onWallTap(Wall(r, c, orientation));
        return;
      }
    }

    // Otherwise treat as a cell tap.
    final r = rowCoord.floor().clamp(0, n - 1);
    final c = colCoord.floor().clamp(0, n - 1);
    onCellTap(Pos(r, c));
  }
}

class _BoardPainter extends CustomPainter {
  final GameState state;
  final List<Pos> legalMoveTargets;
  final Wall? hoverWall;

  _BoardPainter({
    required this.state,
    required this.legalMoveTargets,
    this.hoverWall,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const n = kBoardSize;
    final boardSize = size.width;
    final cell = boardSize / (n + (n - 1) * 0.18);
    final gap = cell * 0.18;
    final unit = cell + gap;

    final bgPaint = Paint()..color = kBoardBg;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, boardSize, boardSize),
        const Radius.circular(16),
      ),
      bgPaint,
    );

    // Draw cells.
    final cellPaint = Paint()..color = const Color(0xFF1B2440);
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(
          c * unit,
          r * unit,
          cell,
          cell,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(rrect, cellPaint);
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = kGridLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // Highlight legal move targets.
    final highlightPaint = Paint()..color = kHighlight;
    for (final p in legalMoveTargets) {
      final rect = Rect.fromLTWH(p.col * unit, p.row * unit, cell, cell);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        highlightPaint,
      );
    }

    // Highlight target rows (goal edges) subtly.
    _drawGoalEdge(canvas, unit, cell, n, row: 0, color: kP2Color.withOpacity(0.15));
    _drawGoalEdge(canvas, unit, cell, n, row: n - 1, color: kP1Color.withOpacity(0.15));

    // Draw placed walls.
    final wallPaint = Paint()
      ..color = kWallColor
      ..style = PaintingStyle.fill;
    for (final w in state.walls) {
      _drawWall(canvas, w, unit, cell, gap, wallPaint);
    }

    // Draw hover/preview wall (semi-transparent).
    if (hoverWall != null) {
      final previewPaint = Paint()
        ..color = kWallColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      _drawWall(canvas, hoverWall!, unit, cell, gap, previewPaint);
    }

    // Draw pawns.
    _drawPawn(canvas, state.p1Pos, unit, cell, kP1Color);
    _drawPawn(canvas, state.p2Pos, unit, cell, kP2Color);
  }

  void _drawGoalEdge(Canvas canvas, double unit, double cell, int n,
      {required int row, required Color color}) {
    final rect = Rect.fromLTWH(0, row * unit, n * unit - (unit - cell), cell);
    canvas.drawRect(rect, Paint()..color = color);
  }

  void _drawWall(Canvas canvas, Wall w, double unit, double cell, double gap,
      Paint paint) {
    if (w.orientation == WallOrientation.horizontal) {
      final rect = Rect.fromLTWH(
        w.col * unit,
        w.row * unit + cell,
        cell * 2 + gap,
        gap,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    } else {
      final rect = Rect.fromLTWH(
        w.col * unit + cell,
        w.row * unit,
        gap,
        cell * 2 + gap,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }
  }

  void _drawPawn(Canvas canvas, Pos pos, double unit, double cell, Color color) {
    final center = Offset(
      pos.col * unit + cell / 2,
      pos.row * unit + cell / 2,
    );
    final radius = cell * 0.32;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.legalMoveTargets != legalMoveTargets ||
        oldDelegate.hoverWall != hoverWall;
  }
}
