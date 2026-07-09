import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import 'main_menu_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadLastName();
  }

  Future<void> _loadLastName() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedName = prefs.getString('player_name');
    if (savedName != null && savedName.isNotEmpty) {
      _nameController.text = savedName;
      setState(() => _isValid = savedName.trim().length >= 2);
    }
  }

  Future<void> _saveNameAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_name', name);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainMenuScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isShortScreen = size.height < 600;

    return ListenableBuilder(
      listenable: langSvc,
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: isShortScreen ? 30 : 60),
                      Container(
                        width: isSmallScreen ? 120 : 150, 
                        height: isSmallScreen ? 120 : 150,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFEF5350).withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.2, 1.0],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF5350).withValues(alpha: 0.6),
                              blurRadius: isSmallScreen ? 40 : 60,
                              spreadRadius: 10,
                            )
                          ],
                        ),
                        child: Center(
                          child: Icon(Icons.nights_stay, size: isSmallScreen ? 60 : 80, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 40),
                      FittedBox(
                        child: Text(
                          langSvc.t('game_title'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 32 : 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        langSvc.currentLanguage == AppLanguage.vi 
                          ? 'Chào mừng bạn đến với\nMa Sói Online'
                          : 'Welcome to\nWerewolf Online',
                        style: TextStyle(color: Colors.white60, fontSize: isSmallScreen ? 13 : 15, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isShortScreen ? 30 : 48),
                      TextField(
                        controller: _nameController,
                        maxLength: 16,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        onChanged: (v) => setState(() => _isValid = v.trim().length >= 2),
                        decoration: InputDecoration(
                          hintText: langSvc.t('your_name'),
                          hintStyle: const TextStyle(color: Colors.white24),
                          counterStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(Icons.person, color: Color(0xFF4FC3F7)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: isSmallScreen ? 56 : 64,
                        child: ElevatedButton(
                          onPressed: _isValid ? _saveNameAndContinue : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4FC3F7),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white10,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: FittedBox(
                            child: Text(
                              langSvc.currentLanguage == AppLanguage.vi ? 'BẮT ĐẦU' : 'START',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
