import 'package:flutter/material.dart';
import '../services/game_controller.dart';
import 'play_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const _buttonWidth = 280.0;
  static const _buttonHeight = 56.0;
  static const _buttonRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Ngăn giao diện chính bị co lại khi hiện bàn phím
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4FC3F7),
              Color(0xFF0288D1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView( // Cho phép nội dung cuộn nếu màn hình quá nhỏ
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildLogo(),
                      const SizedBox(height: 60),
                      _buildMenuButtons(context),
                      const SizedBox(height: 40), // Khoảng đệm dưới
                    ],
                  ),
                ),
              ),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.pets, size: 14, color: Color(0xFFFFD54F)),
                SizedBox(width: 8),
                Text('Vàng miễn phí!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Row(
            children: [
              _topIconButton(Icons.settings),
              const SizedBox(width: 12),
              _topIconButton(Icons.people),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topIconButton(IconData icon) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
      child: IconButton(onPressed: () {}, icon: Icon(icon, color: Colors.white, size: 24), padding: const EdgeInsets.all(8), constraints: const BoxConstraints()),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.pets, size: 80, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text('MA SÓI', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4.0)),
      ],
    );
  }

  Widget _buildMenuButtons(BuildContext context) {
    return Column(
      children: [
        _primaryButton('CHƠI', onPressed: () => _showPlayOptions(context)),
        const SizedBox(height: 16),
        _secondaryButton('TÚI ĐỒ', icon: Icons.inventory_2_outlined),
        const SizedBox(height: 12),
        _secondaryButton('HỒ SƠ', icon: Icons.bar_chart),
      ],
    );
  }

  void _showPlayOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CHỌN CHẾ ĐỘ CHƠI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 32),
            _optionButton(context, 'GHÉP NHANH', Icons.bolt_rounded, 
              color: const Color(0xFFFFD54F),
              textColor: Colors.black,
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayScreen(isQuickMatch: true)));
              }
            ),
            const SizedBox(height: 12),
            _optionButton(context, 'TẠO PHÒNG MỚI', Icons.add_box_rounded, onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayScreen()));
            }),
            const SizedBox(height: 12),
            _optionButton(context, 'VÀO PHÒNG CÓ SẴN', Icons.meeting_room_rounded, onPressed: () {
              Navigator.pop(context);
              _showJoinRoomDialog(context);
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(BuildContext context, String label, IconData icon, {Color? color, Color? textColor, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.white.withOpacity(0.1),
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: color == null ? const BorderSide(color: Colors.white24) : BorderSide.none),
          elevation: 0,
        ),
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('VÀO PHÒNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Nhập mã phòng (VD: WS-XXXXXX)',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                if (GameController.activeRooms.contains(code)) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PlayScreen(roomCode: code)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Phòng $code không tồn tại hoặc đã đóng!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7), foregroundColor: Colors.black),
            child: const Text('VÀO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, {required VoidCallback onPressed}) {
    return Container(
      width: _buttonWidth, height: _buttonHeight + 4,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(_buttonRadius), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0288D1), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius))),
        child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      ),
    );
  }

  Widget _secondaryButton(String label, {IconData? icon}) {
    return SizedBox(
      width: _buttonWidth, height: _buttonHeight,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)), backgroundColor: Colors.white.withOpacity(0.05)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 10)], Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: IconButton(onPressed: () {}, icon: const Icon(Icons.card_giftcard, color: Color(0xFFFFD54F), size: 28))),
          Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline, color: Colors.white, size: 24))),
        ],
      ),
    );
  }
}
