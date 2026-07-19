import 'dart:ui';
import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'board_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      body: Stack(
        children: [
          _buildAmbientBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMiniBoardGlyph(),
                    const SizedBox(height: 28),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [kP1Color, Colors.white, kP2Color],
                        stops: [0.0, 0.5, 1.0],
                      ).createShader(bounds),
                      child: const Text(
                        'WALL DASH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: _rule(kP2Color)),
                        const SizedBox(width: 10),
                        const Text(
                          'RACE • BLOCK • WIN',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _rule(kP1Color)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Race your pawn to the other side —\neach turn, move or place a wall',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 44),
                    _menuButton(
                      context,
                      label: '2 Players',
                      sub: 'Pass and play, same phone',
                      icon: Icons.people_alt_rounded,
                      accent: kP1Color,
                      onTap: () => _startGame(context, GameMode.twoPlayer),
                    ),
                    const SizedBox(height: 16),
                    _menuButton(
                      context,
                      label: 'Play vs AI',
                      sub: 'Test yourself against the engine',
                      icon: Icons.smart_toy_rounded,
                      accent: kP2Color,
                      onTap: () => _startGame(context, GameMode.vsAi),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rule(Color color) {
    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0), color.withOpacity(0.8)]),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
      ),
    );
  }

  /// Ambient glow orbs — same atmospheric treatment as the game screen so
  /// the whole app feels like one continuous world.
  Widget _buildAmbientBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _glowOrb(kP2Color.withOpacity(0.16), 260),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _glowOrb(kP1Color.withOpacity(0.16), 280),
          ),
        ],
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

  /// Small decorative glyph: two glossy pawns facing off across a wall,
  /// giving the title a concrete visual anchor before any text loads.
  Widget _buildMiniBoardGlyph() {
    return SizedBox(
      width: 96,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: _glyphPawn(kP1Color),
          ),
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: kWallColor,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(color: kWallColor.withOpacity(0.7), blurRadius: 10)],
            ),
          ),
          Positioned(
            right: 0,
            child: _glyphPawn(kP2Color),
          ),
        ],
      ),
    );
  }

  Widget _glyphPawn(Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.55)!, color],
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.6), blurRadius: 16, spreadRadius: 1),
        ],
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, __) => GameScreen(mode: mode),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required String label,
    required String sub,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: accent.withOpacity(0.15),
              highlightColor: accent.withOpacity(0.08),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF171F36).withOpacity(0.9),
                      const Color(0xFF11172A).withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withOpacity(0.45), width: 1.3),
                  boxShadow: [
                    BoxShadow(color: accent.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [accent.withOpacity(0.35), accent.withOpacity(0.08)],
                        ),
                        border: Border.all(color: accent.withOpacity(0.6)),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: accent.withOpacity(0.8), size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
