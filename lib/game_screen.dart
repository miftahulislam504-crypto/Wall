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

  // In vsAi mode, human is always p1 (bottom-to-top... actually p1 starts row 0).
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
      setState(() => _state = result);
      _maybeTriggerAi();
    }
  }

  void _onWallTap(Wall wall) {
    if (_state.winner != null || _aiThinking) return;
    if (widget.mode == GameMode.vsAi && _state.turn != humanId) return;
    if (_actionMode != ActionMode.wall) return;

    if (_pendingWall == wall) {
      // Second tap on same slot confirms placement.
      final result = GameEngine.tryPlaceWall(_state, wall);
      if (result != null) {
        setState(() {
          _state = result;
          _pendingWall = null;
        });
        _maybeTriggerAi();
      } else {
        _showSnack('এই জায়গায় wall বসানো যাবে না (path ব্লক হয়ে যাবে বা ওভারল্যাপ করছে)');
        setState(() => _pendingWall = null);
      }
    } else {
      if (!GameEngine.isWallPlacementValid(_state, wall)) {
        _showSnack('এই জায়গায় wall বসানো যাবে না');
        return;
      }
      setState(() => _pendingWall = wall);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _maybeTriggerAi() {
    if (widget.mode != GameMode.vsAi) return;
    if (_state.winner != null) return;
    if (_state.turn == humanId) return;

    setState(() => _aiThinking = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
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
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        elevation: 0,
        title: Text(
          widget.mode == GameMode.vsAi ? 'বনাম AI' : '২ জন খেলোয়াড়',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetGame,
            tooltip: 'নতুন গেম',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BoardWidget(
                state: _state,
                legalMoveTargets: _legalTargets,
                hoverWall: _pendingWall,
                onCellTap: _onCellTap,
                onWallTap: _onWallTap,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionToggle(),
            const Spacer(),
            if (winner != null) _buildWinBanner(winner),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final isP1Turn = _state.turn == PlayerId.p1;
    final turnLabel = widget.mode == GameMode.vsAi
        ? (isP1Turn ? 'তোমার পালা' : (_aiThinking ? 'AI ভাবছে...' : 'AI-এর পালা'))
        : (isP1Turn ? 'নীল-এর পালা' : 'লাল-এর পালা');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _playerChip('নীল', kP1Color, _state.p1WallsPlaced),
          Column(
            children: [
              Text(
                turnLabel,
                style: TextStyle(
                  color: isP1Turn ? kP1Color : kP2Color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          _playerChip('লাল', kP2Color, _state.p2WallsPlaced),
        ],
      ),
    );
  }

  Widget _playerChip(String label, Color color, int wallsPlaced) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text('$wallsPlaced wall',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionToggle() {
    final canAct = _state.winner == null &&
        !_aiThinking &&
        (widget.mode != GameMode.vsAi || _state.turn == humanId);

    return AnimatedOpacity(
      opacity: canAct ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !canAct,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _modeButton(
                  label: 'বল সরাও',
                  icon: Icons.arrow_forward,
                  selected: _actionMode == ActionMode.move,
                  onTap: () => setState(() {
                    _actionMode = ActionMode.move;
                    _pendingWall = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _modeButton(
                  label: 'Wall বসাও',
                  icon: Icons.grid_4x4,
                  selected: _actionMode == ActionMode.wall,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? kWallColor.withOpacity(0.9) : const Color(0xFF1B2440),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kWallColor : kGridLine,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w600,
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
        ? (isP1 ? 'তুমি জিতেছো! 🎉' : 'AI জিতেছে 🤖')
        : (isP1 ? 'নীল জিতেছে! 🎉' : 'লাল জিতেছে! 🎉');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _resetGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: const Text('আবার খেলো'),
          ),
        ],
      ),
    );
  }
}
