import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_logic.dart';

/// ---------------------------------------------------------------------
/// Palette — deep-space navy board with glowing neon team colors.
/// ---------------------------------------------------------------------
const Color kP1Color = Color(0xFF4F9DFF); // blue "BLAU"
const Color kP1ColorDeep = Color(0xFF2563EB);
const Color kP2Color = Color(0xFFFF4D6A); // red "ROT"
const Color kP2ColorDeep = Color(0xFFDC2233);

const Color kAppBg = Color(0xFF05070D);
const Color kBoardFrame = Color(0xFF0A0E18);
const Color kBoardBg = Color(0xFF0C111F);
const Color kCellBg = Color(0xFF111928);
const Color kCellBgAlt = Color(0xFF0E1523);
const Color kGridLine = Color(0x2A6B7A9C);
const Color kWallColor = Color(0xFFE6A85C);
const Color kWallColorDeep = Color(0xFFC77E22);
const Color kHighlight = Color(0xFF2FB58F);

Color wallColorFor(PlayerId? owner) {
  if (owner == PlayerId.p1) return kP1Color;
  if (owner == PlayerId.p2) return kP2Color;
  return kWallColor;
}

Color wallColorDeepFor(PlayerId? owner) {
  if (owner == PlayerId.p1) return kP1ColorDeep;
  if (owner == PlayerId.p2) return kP2ColorDeep;
  return kWallColorDeep;
}

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
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF141A30), Color(0xFF07090F)],
              ),
              border: Border.all(color: const Color(0xFF232C48), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.02),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                const _CornerDiamond(alignment: Alignment.centerLeft),
                const _CornerDiamond(alignment: Alignment.centerRight),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: GestureDetector(
                    onTapUp: (details) => _handleTap(details.localPosition, size - 20),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => CustomPaint(
                        size: Size(size - 20, size - 20),
                        painter: _BoardPainter(
                          state: state,
                          legalMoveTargets: legalMoveTargets,
                          hoverWall: hoverWall,
                          entrance: t,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleTap(Offset local, double boardSize) {
    const n = kBoardSize;
    final cell = boardSize / (n + (n - 1) * 0.18);
    final gap = cell * 0.18;
    final unit = cell + gap;

    // The visual gap between cells is intentionally thin (18% of a cell) so
    // the board looks clean. Hitting that thin strip with a finger is hard,
    // so for touch detection we treat a wider "reach" band around each gap
    // (extending into the neighboring cells) as valid wall-tap territory,
    // while the drawn wall stays in the same visual spot.
    const double edgeReach = 0.30; // fraction of a cell, on each side of the gap

    double posToCoord(double p) => p / unit;

    final rowCoord = posToCoord(local.dy);
    final colCoord = posToCoord(local.dx);

    final rowFrac = rowCoord - rowCoord.floorToDouble();
    final colFrac = colCoord - colCoord.floorToDouble();
    final cellFrac = cell / unit;

    // How far (in cell-fractions) the tap is past the "reach" threshold for
    // each axis. Positive means it counts as a gap-tap on that axis.
    final rowGapDist = rowFrac - (cellFrac - edgeReach);
    final colGapDist = colFrac - (cellFrac - edgeReach);

    final isNearRowGap = rowGapDist > 0;
    final isNearColGap = colGapDist > 0;

    if (isNearRowGap && !isNearColGap) {
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
      final r = rowCoord.floor();
      final c = colCoord.floor();
      if (r >= 0 && r <= n - 2 && c >= 0 && c <= n - 2) {
        // Both axes are within reach of a gap — pick whichever is closer to
        // an actual gap so a corner-ish tap still resolves sensibly.
        final orientation = rowGapDist > colGapDist
            ? WallOrientation.horizontal
            : WallOrientation.vertical;
        onWallTap(Wall(r, c, orientation));
        return;
      }
    }

    final r = rowCoord.floor().clamp(0, n - 1);
    final c = colCoord.floor().clamp(0, n - 1);
    onCellTap(Pos(r, c));
  }
}

class _CornerDiamond extends StatelessWidget {
  final Alignment alignment;
  const _CornerDiamond({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF3A4568),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        transform: Matrix4.rotationZ(math.pi / 4),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final GameState state;
  final List<Pos> legalMoveTargets;
  final Wall? hoverWall;
  final double entrance;

  _BoardPainter({
    required this.state,
    required this.legalMoveTargets,
    required this.entrance,
    this.hoverWall,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const n = kBoardSize;
    final boardSize = size.width;
    final cell = boardSize / (n + (n - 1) * 0.18);
    final gap = cell * 0.18;
    final unit = cell + gap;

    final bgRect = Rect.fromLTWH(0, 0, boardSize, boardSize);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A0F1C), kBoardBg, Color(0xFF0D1322)],
      ).createShader(bgRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(16)),
      bgPaint,
    );

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(c * unit, r * unit, cell, cell);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
        final isAlt = (r + c) % 2 == 0;
        canvas.drawRRect(
          rrect,
          Paint()..color = isAlt ? kCellBg : kCellBgAlt,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = kGridLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    _drawGlowingGoalEdge(canvas, unit, cell, n, row: 0, color: kP2Color);
    _drawGlowingGoalEdge(canvas, unit, cell, n, row: n - 1, color: kP1Color);

    for (final w in state.walls) {
      _drawWall(canvas, w, unit, cell, gap, wallColorFor(w.owner),
          wallColorDeepFor(w.owner), 1.0);
    }

    if (hoverWall != null) {
      _drawWall(canvas, hoverWall!, unit, cell, gap, wallColorFor(state.turn),
          wallColorDeepFor(state.turn), 0.55);
    }

    _drawPawn(canvas, state.p1Pos, unit, cell, kP1Color, kP1ColorDeep, entrance);
    _drawPawn(canvas, state.p2Pos, unit, cell, kP2Color, kP2ColorDeep, entrance);
  }

  void _drawGlowingGoalEdge(Canvas canvas, double unit, double cell, int n,
      {required int row, required Color color}) {
    final width = n * unit - (unit - cell);
    final rect = Rect.fromLTWH(0, row * unit, width, cell);

    canvas.drawRect(rect, Paint()..color = color.withOpacity(0.055));

    final lineY = row == 0 ? row * unit + 2 : row * unit + cell - 2;
    final glowPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(Offset(4, lineY), Offset(width - 4, lineY), glowPaint);
    canvas.drawLine(
      Offset(4, lineY),
      Offset(width - 4, lineY),
      Paint()
        ..color = color.withOpacity(0.75)
        ..strokeWidth = 1.2,
    );
  }

  void _drawWall(Canvas canvas, Wall w, double unit, double cell, double gap,
      Color color, Color deep, double opacity) {
    final Rect rect;
    if (w.orientation == WallOrientation.horizontal) {
      rect = Rect.fromLTWH(
        w.col * unit,
        w.row * unit + cell,
        cell * 2 + gap,
        gap,
      );
    } else {
      rect = Rect.fromLTWH(
        w.col * unit + cell,
        w.row * unit,
        gap,
        cell * 2 + gap,
      );
    }
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withOpacity(0.35 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final gradient = w.orientation == WallOrientation.horizontal
        ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [color.withOpacity(opacity), deep.withOpacity(opacity)])
        : LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [color.withOpacity(opacity), deep.withOpacity(opacity)]);
    canvas.drawRRect(
      rrect,
      Paint()..shader = gradient.createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withOpacity(0.22 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawPawn(Canvas canvas, Pos pos, double unit, double cell, Color color,
      Color deep, double entrance) {
    final center = Offset(
      pos.col * unit + cell / 2,
      pos.row * unit + cell / 2,
    );
    final radius = cell * 0.34 * Curves.easeOutBack.transform(entrance);

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.55),
        width: radius * 1.7,
        height: radius * 0.55,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(
      center,
      radius * 1.5,
      Paint()
        ..color = color.withOpacity(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            Color.lerp(color, Colors.white, 0.55)!,
            color,
            deep,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(sphereRect),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawCircle(
      center.translate(-radius * 0.32, -radius * 0.35),
      radius * 0.28,
      Paint()..color = Colors.white.withOpacity(0.75),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.legalMoveTargets != legalMoveTargets ||
        oldDelegate.hoverWall != hoverWall ||
        oldDelegate.entrance != entrance;
  }
}
