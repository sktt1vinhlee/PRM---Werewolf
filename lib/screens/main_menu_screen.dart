import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import '../services/firestore_service.dart';
import 'play_screen.dart';
import 'role_library_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const _buttonRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final buttonWidth = isSmallScreen ? size.width * 0.8 : 280.0;
    final buttonHeight = isSmallScreen ? 50.0 : 56.0;

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
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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
                          SizedBox(height: isSmallScreen ? 20 : 40),
                          _buildLogo(isSmallScreen),
                          SizedBox(height: isSmallScreen ? 30 : 60),
                          _buildMenuButtons(context, buttonWidth, buttonHeight),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12)
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nights_stay, size: 14, color: Color(0xFFFFD54F)),
                const SizedBox(width: 8),
                Text(
                  langSvc.t('free_gold'), 
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          _topIconButton(Icons.settings, onPressed: () => _showLanguageDialog(context)),
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

  Widget _buildLogo(bool isSmallScreen) {
    final logoSize = isSmallScreen ? 100.0 : 120.0;
    final iconSize = isSmallScreen ? 60.0 : 70.0;
    return Column(
      children: [
        Container(
          width: logoSize, height: logoSize,
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
                blurRadius: isSmallScreen ? 30 : 40,
                spreadRadius: 5,
              )
            ],
          ),
          child: Center(
            child: Icon(Icons.nights_stay, size: iconSize, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        FittedBox(
          child: Text(
            langSvc.t('game_title'), 
            style: TextStyle(
              color: Colors.white, 
              fontSize: isSmallScreen ? 28 : 32, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 2.0
            )
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButtons(BuildContext context, double width, double height) {
    return Column(
      children: [
        _primaryButton(langSvc.t('play'), width, height, onPressed: () => _showPlayOptions(context)),
        const SizedBox(height: 16),
        _secondaryButton(langSvc.t('role_library'), width, height, icon: Icons.library_books, onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const RoleLibraryScreen()));
        }),
        const SizedBox(height: 12),
        _secondaryButton(langSvc.t('achievements'), width, height, icon: Icons.emoji_events_outlined, onPressed: () => _showInDevelopmentMessage(context, langSvc.t('achievements'))),
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
                _showQuickMatchOptions(context);
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

  void _showQuickMatchOptions(BuildContext context) {
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
            Text(langSvc.t('quick_match'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 32),
            _optionButton(context, langSvc.currentLanguage == AppLanguage.vi ? 'Ghép trận Online' : 'Online Matchmaking', Icons.public, 
              color: const Color(0xFF4FC3F7),
              textColor: Colors.black,
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayScreen(
                  isQuickMatch: true, 
                  isOnlineQuickMatch: true,
                )));
              }
            ),
            const SizedBox(height: 12),
            _optionButton(context, langSvc.currentLanguage == AppLanguage.vi ? 'Chơi với Máy (Offline)' : 'Play with Bot (Offline)', Icons.computer, 
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayScreen(isQuickMatch: true, isOnlineQuickMatch: false)));
              }
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(langSvc.t('join_room').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            FutureBuilder<String>(
              future: SharedPreferences.getInstance().then((p) => p.getString('player_name') ?? ''),
              builder: (context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(langSvc.t('your_name').toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(snapshot.data ?? '...', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(height: 1, width: double.infinity, color: Colors.white12),
                  ],
                );
              }
            ),
            const SizedBox(height: 24),
            Text(langSvc.t('room_code_label').toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            TextField(
              controller: codeController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: langSvc.t('room_code_hint'),
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FC3F7))),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text(langSvc.t('cancel').toUpperCase(), style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold))
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final name = prefs.getString('player_name') ?? '';
                    final code = codeController.text.trim().toUpperCase();
                    if (name.isNotEmpty && code.isNotEmpty) {
                      final exists = await firestoreSvc.checkRoomExists(code);
                      if (exists) {
                        await firestoreSvc.joinRoom(code, name);
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PlayScreen(roomCode: code, userName: name)));
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(langSvc.t('room_not_found')),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FC3F7), 
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(langSvc.t('join').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
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

  Widget _primaryButton(String label, double width, double height, {required VoidCallback onPressed}) {
    return Container(
      width: width, height: height + 4,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(_buttonRadius), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F172A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius))),
        child: FittedBox(child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0))),
      ),
    );
  }

  Widget _secondaryButton(String label, double width, double height, {IconData? icon, VoidCallback? onPressed}) {
    return SizedBox(
      width: width, height: height,
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
            Flexible(child: FittedBox(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
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
                    _buildHelpSection(langSvc.t('help_mechanic_title'), langSvc.t('help_mechanic_content')),
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
