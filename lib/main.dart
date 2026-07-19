import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const WallDashApp());
}

class WallDashApp extends StatelessWidget {
  const WallDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wall Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060911),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F9DFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
