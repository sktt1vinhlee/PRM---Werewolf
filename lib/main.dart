import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/intro_screen.dart';
import 'services/language_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WerewolfApp());
}

class WerewolfApp extends StatefulWidget {
  const WerewolfApp({super.key});

  @override
  State<WerewolfApp> createState() => _WerewolfAppState();
}

class _WerewolfAppState extends State<WerewolfApp> {
  bool _initialized = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 1. Khởi tạo Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Đăng nhập ẩn danh để có quyền truy cập Firestore (fix lỗi ko đăng nhập được)
      await FirebaseAuth.instance.signInAnonymously();
      
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: langSvc,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ma Sói Online',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4FC3F7)),
            useMaterial3: true,
          ),
          home: !_initialized 
            ? _buildSplashScreen() 
            : const IntroScreen(),
        );
      }
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 120, height: 120,
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
                        color: const Color(0xFFEF5350).withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.nights_stay, size: 70, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Color(0xFF4FC3F7),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                langSvc.currentLanguage == AppLanguage.vi ? 'ĐANG KHỞI TẠO...' : 'INITIALIZING...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
