import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const _backgroundColor = Color(0xFF81D4FA);
  static const _buttonWidth = 280.0;
  static const _buttonHeight = 52.0;
  static const _buttonRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: Center(child: _buildMenuButtons())),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD54F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets,
                  size: 16,
                  color: Color(0xFF8D6E00),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Vàng miễn phí!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings, color: Colors.white, size: 28),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.people, color: Colors.white, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _filledButton(
          'CHƠI',
          onPressed: () {
            Get.toNamed('/login'); // Gọi Màn 1 của bạn
          },
        ),
        const SizedBox(height: 12),
        _outlinedButton('TÚI ĐỒ', onPressed: () {}),
        const SizedBox(height: 12),
        _outlinedButton('RƯƠNG QUÀ', onPressed: () {}),
        const SizedBox(height: 12),
        _outlinedButton('HỒ SƠ SỰ NGHIỆP', onPressed: () {}),
        const SizedBox(height: 20),
        const Text(
          'VAI TRÒ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'CHÀO MỪNG ĐẾN BETA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _filledButton(String label, {required VoidCallback onPressed}) {
    return SizedBox(
      width: _buttonWidth,
      height: _buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _outlinedButton(String label, {required VoidCallback onPressed}) {
    return SizedBox(
      width: _buttonWidth,
      height: _buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.card_giftcard,
              color: Color(0xFFFFD54F),
              size: 32,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.question_mark,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
