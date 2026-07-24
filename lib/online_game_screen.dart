import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'board_widget.dart';
import 'firebase_service.dart';
import 'game_logic.dart';
import 'game_screen.dart' show ActionMode;

/// Live multiplayer game screen. Both devices watch the same Firestore
/// document; whoever's turn it is writes the next state back.
class OnlineGameScreen extends StatefulWidget {
  final String roomId;
  const OnlineGameScreen({super.key, required this.roomId});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final _service = FirebaseService.instance;

  GameState? _state;
  OnlineRoom? _room;
  PlayerId? _myPlayerId;
  ActionMode _actionMode = ActionMode.move;
  Wall? _pendingWall;
  bool _sending = false;
  String? _error;

  StreamSubscription<GameState>? _stateSub;
  StreamSubscription<OnlineRoom>? _roomSub;

  @override
  void initState() {
    super.initState();
    _service.setPresence(widget.roomId, true);
    _roomSub = _service.watchRoomMeta(widget.roomId).listen((room) {
      if (!mounted) return;
      setState(() {
        _room = room;
        _myPlayerId ??= _service.uid == room.hostUid ? PlayerId.p1 : PlayerId.p2;
      });
    });
    _stateSub = _service.watchGameState(widget.roomId).listen((state) {
      if (!mounted) return;
      setState(() {
        _state = state;
        _pendingWall = null;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _error = 'Connection lost: $e');
    });
  }

  @override
  void dispose() {
    _service.leaveRoom(widget.roomId);
    _stateSub?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }

  bool get _isMyTurn =>
      _state != null && _myPlayerId != null && _state!.turn == _myPlayerId;

  List<Pos> get _legalTargets {
    if (_state == null || !_isMyTurn || _actionMode != ActionMode.move) {
      return [];
    }
    return GameEngine.legalMoves(_state!);
  }

  Future<void> _submit(GameState next) async {
    final prev = _state;
    if (prev == null) return;
    setState(() => _sending = true);
    try {
      await _service.pushMove(widget.roomId, next, prev.moveCount);
    } catch (e) {
      // Stale write — our own listener will re-sync from Firestore's
      // current truth shortly; just surface a gentle message.
      if (mounted) {
        setState(() => _error = 'Move didn\'t sync — try again');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _error = null);
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onCellTap(Pos pos) {
    if (_state == null || !_isMyTurn || _sending) return;
    if (_actionMode != ActionMode.move) return;
    final result = GameEngine.tryMove(_state!, pos);
    if (result != null) {
      setState(() => _actionMode = ActionMode.move);
      _submit(result);
    }
  }

  void _onWallTap(Wall wall) {
    if (_state == null || !_isMyTurn || _sending) return;
    if (_actionMode != ActionMode.wall) return;

    if (!GameEngine.isWallPlacementValid(_state!, wall)) {
      _showSnack('Can\'t place wall here');
      return;
    }

    final result = GameEngine.tryPlaceWall(_state!, wall);
    if (result != null) {
      setState(() {
        _pendingWall = null;
        _actionMode = ActionMode.move;
      });
      _submit(result);
    } else {
      _showSnack('Can\'t place wall here — path blocked or overlapping');
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

  void _leave() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final room = _room;

    if (state == null || room == null || _myPlayerId == null) {
      return Scaffold(
        backgroundColor: kAppBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(kP1Color)),
              const SizedBox(height: 16),
              const Text('Connecting…', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    final myName = _myPlayerId == PlayerId.p1 ? room.hostName : (room.guestName ?? 'Player 2');
    final oppName = _myPlayerId == PlayerId.p1 ? (room.guestName ?? 'Player 2') : room.hostName;
    final winner = state.winner;

    return Scaffold(
      backgroundColor: kAppBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _leave,
        ),
        title: const Text(
          'ONLINE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 4),
                _buildStatusBar(state, myName, oppName),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: BoardWidget(
                        state: state,
                        legalMoveTargets: _legalTargets,
                        hoverWall: _pendingWall,
                        onCellTap: _onCellTap,
                        onWallTap: _onWallTap,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildActionToggle(),
                if (winner != null) ...[
                  const SizedBox(height: 16),
                  _buildWinBanner(winner, myName, oppName),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_error!,
                        style: const TextStyle(color: kP2Color, fontSize: 12),
                        textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(GameState state, String myName, String oppName) {
    final myColor = _myPlayerId == PlayerId.p1 ? kP1Color : kP2Color;
    final oppColor = _myPlayerId == PlayerId.p1 ? kP2Color : kP1Color;

    final turnLabel = state.winner != null
        ? 'Game over'
        : (_isMyTurn ? 'Your turn' : '$oppName\'s turn');
    final turnColor = _isMyTurn ? myColor : oppColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _playerChip(myName, myColor,
              _myPlayerId == PlayerId.p1 ? state.p1WallsPlaced : state.p2WallsPlaced),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: turnColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: turnColor.withOpacity(0.5)),
                ),
                child: Text(turnLabel,
                    style: TextStyle(color: turnColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ),
          _playerChip(oppName, oppColor,
              _myPlayerId == PlayerId.p1 ? state.p2WallsPlaced : state.p1WallsPlaced),
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
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Row(
              children: [
                const Icon(Icons.grid_4x4_rounded, size: 11, color: Colors.white54),
                const SizedBox(width: 2),
                Text('$wallsPlaced', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionToggle() {
    final canAct = _state?.winner == null && _isMyTurn && !_sending;
    final color = _myPlayerId == PlayerId.p1 ? kP1Color : kP2Color;

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
    required Color color,
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
          border: Border.all(color: selected ? color : const Color(0xFF2E3A5C), width: 1.4),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildWinBanner(PlayerId winner, String myName, String oppName) {
    final iWon = winner == _myPlayerId;
    final color = iWon ? kP1Color : kP2Color;
    final label = iWon ? 'You win! 🎉' : '$oppName wins';

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
            boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 24, spreadRadius: 2)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 12)],
                      )),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _leave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('Back to menu', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
