import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:werewolf/core/constants/app_colors.dart';
import 'package:werewolf/screens/main_menu_screen.dart';
import 'package:werewolf/features/auth/screens/login_screen.dart';
import 'package:werewolf/features/waiting_room/screens/waiting_room_screen.dart';

void main() {
  // Chuẩn bị sẵn sàng cho việc gọi API hoặc Socket sau này
  WidgetsFlutterBinding.ensureInitialized(); 
  runApp(const WerewolfApp());
}

class WerewolfApp extends StatelessWidget {
  const WerewolfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Ma Sói',
      debugShowCheckedModeBanner: false,
      
      // 1. ÁP DỤNG THEME TỐI CỦA BẠN CHO TOÀN BỘ APP
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        brightness: Brightness.dark, 
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        useMaterial3: true,
      ),

      // 2. CẤU HÌNH ĐIỀU HƯỚNG MÀN HÌNH (ROUTING)
      initialRoute: '/main-menu', // Mở app lên là vào Màn Hình Chính của Vinh
      
      getPages: [
        GetPage(
          name: '/main-menu',
          page: () => const MainMenuScreen(),
          transition: Transition.fadeIn, 
        ),
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
          transition: Transition.rightToLeft, // Hiệu ứng trượt từ phải sang
        ),
        GetPage(
          name: '/waiting-room',
          page: () => const WaitingRoomScreen(),
          transition: Transition.rightToLeft,
        ),
      ],
    );
  }
}