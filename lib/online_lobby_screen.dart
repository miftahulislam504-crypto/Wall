import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board_widget.dart';
import 'firebase_service.dart';
import 'online_game_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

enum _LobbyMode { menu, quickMatching, creatingRoom, joiningRoom }

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _service = FirebaseService.instance;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  _LobbyMode _mode = _LobbyMode.menu;
  StreamSubscription<String>? _quickMatchSub;
  String? _hostedRoomId;
  String? _hostedRoomCode;
  StreamSubscription<OnlineRoom>? _hostRoomSub;
  String? _error;
  bool _busy = false;

  String get _displayName {
    final t = _nameController.text.trim();
    return t.isEmpty ? 'Player' : t;
  }

  @override
  void dispose() {
    _quickMatchSub?.cancel();
    _hostRoomSub?.cancel();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _goToGame(String roomId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OnlineGameScreen(roomId: roomId)),
    );
  }

  Future<void> _startQuickMatch() async {
    setState(() {
      _mode = _LobbyMode.quickMatching;
      _error = null;
    });
    _quickMatchSub = _service.quickMatch(_displayName).listen(
      (roomId) {
        if (!mounted) return;
        _goToGame(roomId);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _mode = _LobbyMode.menu;
          _error = 'Matchmaking failed: $e';
        });
      },
    );
  }

  Future<void> _cancelQuickMatch() async {
    await _quickMatchSub?.cancel();
    await _service.cancelQuickMatch();
    if (!mounted) return;
    setState(() => _mode = _LobbyMode.menu);
  }

  Future<void> _createRoom() async {
    setState(() {
      _mode = _LobbyMode.creatingRoom;
      _error = null;
      _busy = true;
    });
    try {
      final roomId = await _service.createRoom(_displayName);
      _hostedRoomId = roomId;
      _hostRoomSub = _service.watchRoomMeta(roomId).listen((room) {
        if (!mounted) return;
        setState(() => _hostedRoomCode = room.code);
        if (room.status == 'active') {
          _hostRoomSub?.cancel();
          _goToGame(roomId);
        }
      });
    } catch (e) {
      setState(() {
        _mode = _LobbyMode.menu;
        _error = 'Could not create room: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelHostedRoom() async {
    await _hostRoomSub?.cancel();
    final id = _hostedRoomId;
    if (id != null) {
      try {
        await _service.deleteRoom(id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _mode = _LobbyMode.menu;
      _hostedRoomId = null;
      _hostedRoomCode = null;
    });
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the full room code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roomId = await _service.joinRoomByCode(code, _displayName);
      if (!mounted) return;
      _goToGame(roomId);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PLAY ONLINE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _nameField(),
              const SizedBox(height: 24),
              if (_error != null) ...[
                _errorBanner(_error!),
                const SizedBox(height: 16),
              ],
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameField() {
    return TextField(
      controller: _nameController,
      maxLength: 16,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Your display name (optional)',
        labelStyle: const TextStyle(color: Colors.white54),
        counterStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF111928),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF232C48)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kP1Color),
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kP2Color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kP2Color.withOpacity(0.4)),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _LobbyMode.menu:
        return _buildMenu();
      case _LobbyMode.quickMatching:
        return _buildQuickMatching();
      case _LobbyMode.creatingRoom:
        return _buildHostingRoom();
      case _LobbyMode.joiningRoom:
        return _buildJoinRoom();
    }
  }

  Widget _buildMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _actionCard(
          icon: Icons.bolt_rounded,
          title: 'Quick Match',
          subtitle: 'Get paired with a random opponent',
          color: kP1Color,
          onTap: _startQuickMatch,
        ),
        const SizedBox(height: 14),
        _actionCard(
          icon: Icons.group_add_rounded,
          title: 'Create Room',
          subtitle: 'Get a code to invite a friend',
          color: kP2Color,
          onTap: _createRoom,
        ),
        const SizedBox(height: 14),
        _actionCard(
          icon: Icons.login_rounded,
          title: 'Join with Code',
          subtitle: 'Enter a friend\'s room code',
          color: kWallColor,
          onTap: () => setState(() => _mode = _LobbyMode.joiningRoom),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF121A2C), Color(0xFF0D1220)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.4), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [color.withOpacity(0.3), color.withOpacity(0.06)],
                      ),
                      border: Border.all(color: color.withOpacity(0.55)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.8), size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMatching() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(kP1Color),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Looking for an opponent…',
              style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: _cancelQuickMatch,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Color(0xFF2E3A5C)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildHostingRoom() {
    if (_busy || _hostedRoomCode == null) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(kP2Color)),
      );
    }
    final code = _hostedRoomCode!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Share this code with your friend',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF111928),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kP2Color.withOpacity(0.5), width: 1.5),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Tap the code to copy', style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kP2Color),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Waiting for opponent…',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: _cancelHostedRoom,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Color(0xFF2E3A5C)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoom() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text('Enter room code', style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 5,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 8),
          decoration: InputDecoration(
            counterStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF111928),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF232C48)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kWallColor),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _joinByCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: kWallColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Join Room', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _mode = _LobbyMode.menu;
            _error = null;
          }),
          child: const Text('Back', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
