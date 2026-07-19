import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_service.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 8));
    await FirebaseService.instance.ensureSignedIn().timeout(const Duration(seconds: 8));
  } catch (e) {
    // Don't let Firebase/network problems block the app from opening.
    // Local (offline) game modes still work without Firebase; online
    // features will simply show an error when actually used.
    debugPrint('Firebase init/sign-in failed or timed out: $e');
  }

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
