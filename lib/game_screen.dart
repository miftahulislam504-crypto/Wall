import 'dart:ui';
import 'package:flutter/material.dart';
import 'game_logic.dart';
import 'board_widget.dart';
import 'ai_player.dart';

enum GameMode { twoPlayer, vsAi }
enum ActionMode { move, wall }

class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameState _state = GameState();
  ActionMode _actionMode = ActionMode.move;
  Wall? _pendingWall;
  final AiPlayer _ai = AiPlayer();
  bool _aiThinking = false;

  static const PlayerId humanId = PlayerId.p1;

  List<Pos> get _legalTargets {
    if (_actionMode != ActionMode.move || _state.winner != null) return [];
    return GameEngine.legalMoves(_state);
  }

  void _onCellTap(Pos pos) {
    if (_state.winner != null || _aiThinking) return;
    if (widget.mode == GameMode.vsAi && _state.turn != humanId) return;
    if (_actionMode != ActionMode.move) return;

    final result = GameEngine.tryMove(_state, pos);
    if (result != null) {
      setState(() {
        _state = result;
        _actionMode = ActionMode.move;
      });
      _maybeTriggerAi();
    }
  }

  // Fingers rarely land on the exact same pixel twice, and the wall slots
  // are narrow. If the second tap lands one row/col away from the pending
  // wall (same orientation), treat it as "confirm" instead of silently
  // switching the preview — this is what a human tapping twice near the
  // same spot actually means.
  bool _isSameOrAdjacentWall(Wall a, Wall b) {
    if (a.orientation != b.orientation) return false;
    return (a.row - b.row).abs() <= 1 && (a.col - b.col).abs() <= 1;
  }

  void _onWallTap(Wall wall) {
    if (_state.winner != null || _aiThinking) return;
    if (widget.mode == GameMode.vsAi && _state.turn != humanId) return;
    if (_actionMode != ActionMode.wall) return;

    final pending = _pendingWall;
    if (pending != null && _isSameOrAdjacentWall(pending, wall)) {
      final result = GameEngine.tryPlaceWall(_state, pending);
      if (result != null) {
        setState(() {
          _state = result;
          _pendingWall = null;
          _actionMode = ActionMode.move;
        });
        _maybeTriggerAi();
      } else {
        _showSnack('Can\'t place wall here — path blocked or overlapping');
        setState(() => _pendingWall = null);
      }
    } else {
      if (!GameEngine.isWallPlacementValid(_state, wall)) {
        _showSnack('Can\'t place wall here');
        return;
      }
      setState(() => _pendingWall = wall);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1B2440),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2E3A5C)),
        ),
      ),
    );
  }

  void _maybeTriggerAi() {
    if (widget.mode != GameMode.vsAi) return;
    if (_state.winner != null) return;
    if (_state.turn == humanId) return;

    setState(() => _aiThinking = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_state.winner != null || _state.turn == humanId) {
        setState(() => _aiThinking = false);
        return;
      }
      final next = _ai.decideMove(_state);
      setState(() {
        _state = next;
        _aiThinking = false;
      });
    });
  }

  void _resetGame() {
    setState(() {
      _state = GameState();
      _actionMode = ActionMode.move;
      _pendingWall = null;
      _aiThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final winner = _state.winner;

    return Scaffold(
      backgroundColor: kAppBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.mode == GameMode.vsAi ? Icons.smart_toy_rounded : Icons.people_alt_rounded,
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              widget.mode == GameMode.vsAi ? 'VS AI' : '2 PLAYERS',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _resetGame,
            tooltip: 'New game',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildAmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildStatusBar(),
                const SizedBox(height: 14),
                if (widget.mode == GameMode.twoPlayer) ...[
                  _buildTeamBanner(PlayerId.p2, flip: true),
                  const SizedBox(height: 10),
                  Transform.rotate(
                    angle: 3.14159,
                    child: _buildActionToggleFor(PlayerId.p2),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  _buildTeamBanner(PlayerId.p2, flip: false),
                  const SizedBox(height: 14),
                ],
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: BoardWidget(
                        state: _state,
                        legalMoveTargets: _legalTargets,
                        hoverWall: _pendingWall,
                        onCellTap: _onCellTap,
                        onWallTap: _onWallTap,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildTeamBanner(PlayerId.p1, flip: false),
                const SizedBox(height: 10),
                _buildActionToggleFor(PlayerId.p1),
                if (winner != null) ...[
                  const SizedBox(height: 16),
                  _buildWinBanner(winner),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Soft ambient glow orbs behind the whole screen for depth, echoing the
  /// atmospheric dark background of the reference.
  Widget _buildAmbientBackground() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: kAppBg),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: _glowOrb(kP2Color.withOpacity(0.18), 220),
            ),
            Positioned(
              bottom: -100,
              right: -60,
              child: _glowOrb(kP1Color.withOpacity(0.18), 260),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }

  /// "ROT" / "BLAU" style banner: triangle marker + letterspaced team name
  /// flanked by glowing rule-lines, matching the reference exactly.
  Widget _buildTeamBanner(PlayerId player, {required bool flip}) {
    final color = player == PlayerId.p1 ? kP1Color : kP2Color;
    final label = player == PlayerId.p1 ? 'BLAU' : 'ROT';
    final icon = flip ? Icons.expand_less_rounded : Icons.expand_more_rounded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: _glowRule(color)),
        const SizedBox(width: 12),
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _glowRule(color)),
      ],
    );
  }

  Widget _glowRule(Color color) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0), color.withOpacity(0.9)],
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.6), blurRadius: 4),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final isP1Turn = _state.turn == PlayerId.p1;
    final Widget turnWidget = widget.mode == GameMode.vsAi
        ? (isP1Turn
            ? _turnPill('Your turn', kP1Color)
            : _turnPill(
                'AI\'s turn',
                kP2Color,
                loading: _aiThinking,
                icon: Icons.smart_toy_rounded,
              ))
        : _turnPill(
            isP1Turn ? 'Blue\'s turn' : 'Red\'s turn',
            isP1Turn ? kP1Color : kP2Color,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _playerChip('Blue', kP1Color, _state.p1WallsPlaced),
          turnWidget,
          _playerChip('Red', kP2Color, _state.p2WallsPlaced),
        ],
      ),
    );
  }

  Widget _turnPill(String label, Color color, {bool loading = false, IconData? icon}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerChip(String label, Color color, int wallsPlaced) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Row(
              children: [
                const Icon(Icons.grid_4x4_rounded, size: 11, color: Colors.white54),
                const SizedBox(width: 2),
                Text('$wallsPlaced',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionToggleFor(PlayerId player) {
    final isMyTurn = _state.turn == player;
    final canAct = _state.winner == null && !_aiThinking && isMyTurn;
    final color = player == PlayerId.p1 ? kP1Color : kP2Color;

    return AnimatedOpacity(
      opacity: canAct ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !canAct,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _modeButton(
                  label: 'Move',
                  icon: Icons.open_with_rounded,
                  selected: _actionMode == ActionMode.move,
                  color: color,
                  onTap: () => setState(() {
                    _actionMode = ActionMode.move;
                    _pendingWall = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _modeButton(
                  label: 'Wall',
                  icon: Icons.grid_4x4_rounded,
                  selected: _actionMode == ActionMode.wall,
                  color: color,
                  onTap: () => setState(() => _actionMode = ActionMode.wall),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    Color color = kWallColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!])
              : const LinearGradient(colors: [Color(0xFF171F36), Color(0xFF141B30)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFF2E3A5C),
            width: 1.4,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinBanner(PlayerId winner) {
    final isP1 = winner == PlayerId.p1;
    final color = isP1 ? kP1Color : kP2Color;
    final label = widget.mode == GameMode.vsAi
        ? (isP1 ? 'You win!' : 'AI wins')
        : (isP1 ? 'Blue wins!' : 'Red wins!');
    final icon = widget.mode == GameMode.vsAi && !isP1
        ? Icons.smart_toy_rounded
        : Icons.emoji_events_rounded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.22), color.withOpacity(0.08)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.7), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.35), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 12)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _resetGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Play again', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
