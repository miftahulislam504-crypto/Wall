import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'board_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: kP1Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Wall Dash',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: kP2Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'নিজের বল অপর পাশে নিয়ে যাও —\nপ্রতি চালে সরাও অথবা wall বসাও',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 48),
                _menuButton(
                  context,
                  label: '২ জন খেলোয়াড় (একই ফোনে)',
                  icon: Icons.people,
                  onTap: () => _startGame(context, GameMode.twoPlayer),
                ),
                const SizedBox(height: 16),
                _menuButton(
                  context,
                  label: 'AI-এর বিপক্ষে খেলো',
                  icon: Icons.smart_toy,
                  onTap: () => _startGame(context, GameMode.vsAi),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(mode: mode)),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B2440),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: kGridLine),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
