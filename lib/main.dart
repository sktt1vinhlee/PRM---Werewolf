import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:werewolf/screens/main_menu_screen.dart';

void main() async {
  // Bắt buộc phải có để khởi tạo Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }

  runApp(const WerewolfApp());
}

class WerewolfApp extends StatelessWidget {
  const WerewolfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Sói Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4FC3F7)),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
