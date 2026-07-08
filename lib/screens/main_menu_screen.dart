import 'package:flutter/material.dart';
import '../services/game_controller.dart';
import '../services/language_service.dart';
import 'play_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const _buttonWidth = 280.0;
  static const _buttonHeight = 56.0;
  static const _buttonRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: langSvc,
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          _buildLogo(),
                          const SizedBox(height: 60),
                          _buildMenuButtons(context),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(context),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.pets, size: 14, color: Color(0xFFFFD54F)),
                const SizedBox(width: 8),
                Text(langSvc.t('free_gold'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Row(
            children: [
              _topIconButton(Icons.settings, onPressed: () => _showLanguageDialog(context)),
              const SizedBox(width: 12),
              _topIconButton(Icons.people),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topIconButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: IconButton(onPressed: onPressed ?? () {}, icon: Icon(icon, color: Colors.white, size: 24), padding: const EdgeInsets.all(8), constraints: const BoxConstraints()),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(langSvc.t('select_lang'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langOption(context, AppLanguage.vi, langSvc.t('lang_vi'), '🇻🇳'),
            const SizedBox(height: 8),
            _langOption(context, AppLanguage.en, langSvc.t('lang_en'), '🇺🇸'),
          ],
        ),
      ),
    );
  }

  Widget _langOption(BuildContext context, AppLanguage lang, String label, String flag) {
    final isSelected = langSvc.currentLanguage == lang;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF4FC3F7) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF4FC3F7)) : null,
      onTap: () {
        langSvc.setLanguage(lang);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.pets, size: 80, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(langSvc.t('game_title'), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4.0)),
      ],
    );
  }

  Widget _buildMenuButtons(BuildContext context) {
    return Column(
      children: [
        _primaryButton(langSvc.t('play'), onPressed: () => _showPlayOptions(context)),
        const SizedBox(height: 16),
        _secondaryButton(langSvc.t('inventory'), icon: Icons.inventory_2_outlined, onPressed: () => _showInDevelopmentMessage(context, langSvc.t('inventory'))),
        const SizedBox(height: 12),
        _secondaryButton(langSvc.t('profile'), icon: Icons.bar_chart, onPressed: () => _showInDevelopmentMessage(context, langSvc.t('profile'))),
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
            Text(langSvc.t('choose_mode'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 32),
            _optionButton(context, langSvc.t('quick_match'), Icons.bolt_rounded, 
              color: const Color(0xFFFFD54F),
              textColor: Colors.black,
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayScreen(isQuickMatch: true)));
              }
            ),
            const SizedBox(height: 12),
            _optionButton(context, langSvc.t('create_room'), Icons.add_box_rounded, onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayScreen()));
            }),
            const SizedBox(height: 12),
            _optionButton(context, langSvc.t('join_room'), Icons.meeting_room_rounded, onPressed: () {
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
          backgroundColor: color ?? Colors.white.withValues(alpha: 0.1),
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
        title: Text(langSvc.t('join_room'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: langSvc.t('room_code_hint'),
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(langSvc.t('cancel'), style: const TextStyle(color: Colors.white60))),
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
                      content: Text(langSvc.t('room_not_found')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7), foregroundColor: Colors.black),
            child: Text(langSvc.t('join'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInDevelopmentMessage(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${langSvc.t('developing')} ($feature)', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _primaryButton(String label, {required VoidCallback onPressed}) {
    return Container(
      width: _buttonWidth, height: _buttonHeight + 4,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(_buttonRadius), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0288D1), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius))),
        child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      ),
    );
  }

  Widget _secondaryButton(String label, {IconData? icon, VoidCallback? onPressed}) {
    return SizedBox(
      width: _buttonWidth, height: _buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed ?? () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white, 
          side: const BorderSide(color: Colors.white, width: 2), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)), 
          backgroundColor: Colors.white.withValues(alpha: 0.05)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 10)], 
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: IconButton(onPressed: () {}, icon: const Icon(Icons.card_giftcard, color: Color(0xFFFFD54F), size: 28))
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: IconButton(
              onPressed: () => _showHelpBottomSheet(context), 
              icon: const Icon(Icons.help_outline, color: Colors.white, size: 24)
            )
          ),
        ],
      ),
    );
  }

  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Text(langSvc.t('help_title'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildHelpSection(langSvc.t('help_intro_title'), langSvc.t('help_intro_content')),
                    const SizedBox(height: 24),
                    Text(langSvc.t('help_roles_title'), style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(color: Colors.white10, height: 20),
                    _buildRoleItem(Icons.person, langSvc.t('role_dan'), langSvc.t('role_dan_desc'), const Color(0xFF4CAF50)),
                    _buildRoleItem(Icons.pets, langSvc.t('role_soi'), langSvc.t('role_soi_desc'), const Color(0xFFEF5350)),
                    _buildRoleItem(Icons.remove_red_eye, langSvc.t('role_tien_tri'), langSvc.t('role_tien_tri_desc'), const Color(0xFF26C6DA)),
                    _buildRoleItem(Icons.shield, langSvc.t('role_bao_ve'), langSvc.t('role_bao_ve_desc'), const Color(0xFF42A5F5)),
                    _buildRoleItem(Icons.science, langSvc.t('role_phu_thuy'), langSvc.t('role_phu_thuy_desc'), const Color(0xFFAB47BC)),
                    _buildRoleItem(Icons.gps_fixed, langSvc.t('role_xa_thu'), langSvc.t('role_xa_thu_desc'), const Color(0xFF29B6F6)),
                    _buildRoleItem(Icons.favorite, langSvc.t('role_cupid'), langSvc.t('role_cupid_desc'), const Color(0xFFEC407A)),
                    _buildRoleItem(Icons.colorize, langSvc.t('role_tho_san'), langSvc.t('role_tho_san_desc'), const Color(0xFFFFA726)),
                    _buildRoleItem(Icons.auto_awesome, langSvc.t('role_soi_nguyen'), langSvc.t('role_soi_nguyen_desc'), const Color(0xFFBA68C8)),
                    _buildRoleItem(Icons.gavel, langSvc.t('role_soi_dau_dan'), langSvc.t('role_soi_dau_dan_desc'), const Color(0xFFFF7043)),
                    _buildRoleItem(Icons.psychology, langSvc.t('role_nerd'), langSvc.t('role_nerd_desc'), const Color(0xFFD4E157)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
      ],
    );
  }

  Widget _buildRoleItem(IconData icon, String name, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
