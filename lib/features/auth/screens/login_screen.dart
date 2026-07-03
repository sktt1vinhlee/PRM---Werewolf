import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:werewolf/core/constants/app_colors.dart'; // Đảm bảo file này đã đổi sang tông tối
import 'package:werewolf/features/auth/state/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController authController = Get.put(
    AuthController(),
    permanent: true,
  );

  // Đổi tên controller cho phù hợp ngữ cảnh game
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController roomCodeController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nicknameController.dispose();
    roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Màu nền tối
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Game (Nên thay bằng Image.asset chứa logo Ma Sói thật sau này)
                    const Icon(
                      Icons.pets, 
                      color: AppColors.primary, // Đỏ máu
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'WEREWOLF VILLAGE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      'Tìm phòng và tham gia vào trò chơi sinh tử',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 48),

                    // Ô nhập Tên người chơi (Nickname)
                    TextFormField(
                      controller: nicknameController,
                      style: const TextStyle(color: Colors.white), // Chữ nhập vào màu trắng
                      decoration: InputDecoration(
                        labelText: 'Tên hiển thị (Nickname)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppColors.surface, // Đổi màu nền ô nhập liệu tối hơn background 1 chút
                        errorStyle: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên để mọi người nhận diện!';
                        }
                        if (value.length > 15) {
                          return 'Tên quá dài (Tối đa 15 ký tự)!';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ô nhập Mã phòng (Room Code)
                    TextFormField(
                      controller: roomCodeController,
                      obscureText: false, // Bỏ ẩn mật khẩu vì đây là mã phòng
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Mã Phòng (Room Code)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.meeting_room,
                          color: AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        errorStyle: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập mã phòng để tham gia!';
                        }
                        if (value.length < 4) {
                          return 'Mã phòng thường có ít nhất 4 ký tự!';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Nút Tham gia / Vào Làng
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          FocusScope.of(context).unfocus();

                          bool success = await authController.joinRoom(
                            nickname: nicknameController.text.trim(),
                            roomCode: roomCodeController.text.trim(),
                          );

                          if (success) {
                            // Chuyển hướng sang Màn 4 (Phòng Chờ)
                            Get.offAllNamed('/waiting-room');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Obx(
                        () => authController.isLoading.value
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'VÀO LÀNG',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
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