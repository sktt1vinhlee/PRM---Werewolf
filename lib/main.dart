import 'package:flutter/material.dart';
import 'package:werewolf/screens/main_menu_screen.dart';

void main() {
  runApp(const WerewolfApp());
}

class WerewolfApp extends StatelessWidget {
  const WerewolfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Sói',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF81D4FA)),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}