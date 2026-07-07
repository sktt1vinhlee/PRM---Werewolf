import 'dart:async';
import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../models/role_definition.dart';
import '../models/online_player.dart';
import '../models/chat_message.dart';
import '../services/game_controller.dart';

class PlayScreen extends StatefulWidget {
  final String? roomCode;
  final bool isQuickMatch;
  const PlayScreen({super.key, this.roomCode, this.isQuickMatch = false});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final GameController _controller;
  final TextEditingController _chatController = TextEditingController();
  bool _showChatTab = true;
  bool _isGameOverDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _controller = GameController(initialRoomCode: widget.roomCode);
    _controller.addListener(_onControllerUpdate);
    
    // Nếu là ghép nhanh, khởi chạy game ngay lập tức
    if (widget.isQuickMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.initializeOnlineGame();
      });
    }
  }

  void _onControllerUpdate() {
    final gameOverMsg = _controller.checkGameOver();
    if (gameOverMsg.isNotEmpty && mounted && !_isGameOverDialogShowing) {
      _isGameOverDialogShowing = true;
      _showGameOverDialog(_controller.isMyWin(gameOverMsg), gameOverMsg);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _showGameOverDialog(bool isWin, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(children: [
          Icon(isWin ? Icons.emoji_events : Icons.sentiment_very_dissatisfied, color: isWin ? const Color(0xFFFFD54F) : const Color(0xFFEF5350), size: 28),
          const SizedBox(width: 10),
          Text(isWin ? 'CHIẾN THẮNG!' : 'THẤT BẠI!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () { setState(() => _isGameOverDialogShowing = false); Navigator.of(context).pop(); _controller.resetGame(); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
            child: const Text('QUAY VỀ PHÒNG CHỜ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_controller.currentState == PlayState.lobby) return true;
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Thoát game?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Tiến trình sẽ bị hủy. Bạn muốn rời phòng?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('HỦY', style: TextStyle(color: Colors.white60))),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)), child: const Text('RỜI PHÒNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isNight = _controller.currentPhase == GamePhase.night;
    final isLobby = _controller.currentState == PlayState.lobby;
    final isReveal = _controller.currentState == PlayState.roleReveal;
    
    Widget content;
    if (isLobby) {
      content = SafeArea(child: _buildLobbyView());
    } else if (isReveal) {
      content = _buildRoleRevealView();
    } else {
      content = SafeArea(child: _buildOnlinePlayingView());
    }
    
    if (isLobby || isReveal) {
      content = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
          ),
        ),
        child: content,
      );
    }

    // Màu nền cho trạng thái đang chơi (Ban ngày: Sky 300, Ban đêm: Slate 900)
    final bgColor = isNight ? const Color(0xFF0F172A) : const Color(0xFF9CDCFD);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: (isLobby || isReveal) ? Colors.transparent : bgColor,
        body: content,
      ),
    );
  }

  // --- LOBBY VIEW ---
  Widget _buildLobbyView() {
    return Column(children: [
      _buildTopBar('PHÒNG CHỜ ONLINE', showInfo: true),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildRoomCodeCard(), const SizedBox(height: 16),
        _buildUserProfileCard(), const SizedBox(height: 16),
        _buildLobbyPlayerCountCard(), const SizedBox(height: 24),
        const Text('DANH SÁCH NGƯỜI CHƠI:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        _buildConnectedPlayersSimulator(), const SizedBox(height: 16),
        _buildChatLogTabs(),
      ]))),
      _buildLobbyBottomBar(),
    ]);
  }

  Widget _buildRoomCodeCard() {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MÃ PHÒNG:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_controller.roomCode, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
      ])),
      const SizedBox(width: 12),
      ElevatedButton.icon(onPressed: _controller.generateRoomCode, icon: const Icon(Icons.refresh, size: 16), label: const Text('ĐỔI MÃ'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0288D1), padding: const EdgeInsets.symmetric(horizontal: 12))),
    ]));
  }

  Widget _buildUserProfileCard() {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TÊN CỦA BẠN:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      TextField(maxLength: 16, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: InputDecoration(counterText: '', filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.person, color: Colors.white70)), controller: TextEditingController(text: _controller.userName)..selection = TextSelection.collapsed(offset: _controller.userName.length), onChanged: _controller.updateUserName),
    ]));
  }

  Widget _buildLobbyPlayerCountCard() {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Số lượng người chơi:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text('${_controller.playerCount} Người', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
      Slider(value: _controller.playerCount.toDouble(), min: 6, max: 18, divisions: 12, activeColor: Colors.white, inactiveColor: Colors.white30, onChanged: (v) => _controller.updatePlayerCount(v.toInt())),
    ]));
  }

  Widget _buildConnectedPlayersSimulator() {
    final players = _controller.lobbyPlayerNames;
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)), child: Column(children: [
      Row(children: [
        if (players.length < _controller.playerCount) ...[
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(
          players.length < _controller.playerCount 
            ? 'Đang chờ người chơi khác... (${players.length} / ${_controller.playerCount})'
            : 'Phòng đã đầy! (${players.length} / ${_controller.playerCount})', 
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
        )),
      ]),
      const Divider(color: Colors.white24, height: 20),
      ListView.builder(
        shrinkWrap: true, 
        physics: const NeverScrollableScrollPhysics(), 
        itemCount: players.length, 
        itemBuilder: (c, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 10, 
                  backgroundColor: i == 0 ? const Color(0xFFFFD54F) : Colors.white24, 
                  child: Text('${i + 1}', style: TextStyle(fontSize: 9, color: i == 0 ? Colors.black : Colors.white))
                ), 
                const SizedBox(width: 10), 
                Text(
                  players[i], 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 13, 
                    fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal
                  )
                ),
                if (i == 0) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star, color: Color(0xFFFFD54F), size: 12),
                ]
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), 
                  borderRadius: BorderRadius.circular(6), 
                  border: Border.all(color: Colors.white54, width: 0.5)
                ), 
                child: const Text('SẴN SÀNG', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))
              ),
            ]
          )
        )
      ),
    ]));
  }

  Widget _buildLobbyBottomBar() {
    return Container(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _controller.isLobbyLoading ? null : _controller.startLobbyTransition, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0288D1)), child: _controller.isLobbyLoading ? const CircularProgressIndicator(color: Color(0xFF0288D1)) : const Text('VÀO PHÒNG & BẮT ĐẦU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))));
  }

  // --- ROLE REVEAL VIEW ---
  Widget _buildRoleRevealView() {
    final role = _controller.myPlayer?.role;
    if (role == null) return const SizedBox.shrink();

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'VAI TRÒ CỦA BẠN LÀ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 240,
              height: 340,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(role.icon, size: 100, color: role.primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    role.name.toUpperCase(),
                    style: TextStyle(
                      color: role.primaryColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      role.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'CHUẨN BỊ VÀO ĐÊM...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PLAYING VIEW ---
  Widget _buildOnlinePlayingView() {
    return Column(children: [
      _buildOnlinePlayTopBar(),
      _buildOnlinePhaseHeader(),
      Expanded(child: GridView.builder(padding: const EdgeInsets.all(12), itemCount: _controller.playerCount, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8), itemBuilder: (c, i) => _buildPlayerOnlineCard(_controller.players[i]))),
      _buildChatLogTabs(),
      _buildBottomOnlineController(),
    ]);
  }

  Widget _buildOnlinePlayTopBar() {
    final isNight = _controller.currentPhase == GamePhase.night;
    final textColor = isNight ? Colors.white70 : const Color(0xFF0F172A);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(onPressed: () async { if (await _onWillPop()) _controller.resetGame(); }, icon: Icon(Icons.arrow_back_ios_new, color: isNight ? Colors.white : const Color(0xFF0F172A))),
      Column(children: [Text('PHÒNG: ${_controller.roomCode}', style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)), if (_controller.phaseTimerSeconds > 0) Text('Còn lại: ${_controller.phaseTimerSeconds}s', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 10, fontWeight: FontWeight.bold))]),
      IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.help_outline, color: Color(0xFFFFD54F))),
    ]));
  }

  Widget _buildOnlinePhaseHeader() {
    final phase = _controller.currentPhase;
    final isNight = phase == GamePhase.night; final isVoting = phase == GamePhase.voting;
    String txt = isNight ? 'BAN ĐÊM - ĐÊM ${_controller.dayNumber}' : (isVoting ? 'BỎ PHIẾU - NGÀY ${_controller.dayNumber}' : 'THẢO LUẬN - NGÀY ${_controller.dayNumber}');
    Color clr = isNight ? const Color(0xFF311B92) : (isVoting ? const Color(0xFFC62828) : const Color(0xFFF57F17));
    return Container(width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), decoration: BoxDecoration(color: clr.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: clr.withOpacity(0.5), width: 1.5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [Icon(isNight ? Icons.nights_stay : Icons.wb_sunny, color: isNight ? const Color(0xFFB39DDB) : const Color(0xFFFFD54F), size: 20), const SizedBox(width: 8), Text(txt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))]),
      Text('SỐNG: ${_controller.players.where((p) => p.isAlive).length}/${_controller.playerCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    ]));
  }

  Widget _buildPlayerOnlineCard(OnlinePlayer player) {
    final isNight = _controller.currentPhase == GamePhase.night;
    final isSelected = _controller.selectedPlayer?.id == player.id;
    final reveal = _controller.shouldRevealRole(player);
    final border = isSelected ? const Color(0xFFFFD54F) : _controller.getPlayerBorderColor(player);
    final cardColor = player.isAlive 
        ? (isNight ? const Color(0xFF1E293B) : Colors.white) 
        : (isNight ? const Color(0xFF0F172A).withOpacity(0.6) : Colors.grey[300]);
    final textColor = player.isAlive 
        ? (isNight ? Colors.white : const Color(0xFF0F172A)) 
        : (isNight ? Colors.white30 : Colors.black45);

    return GestureDetector(
      onTap: () { if (_controller.currentPhase == GamePhase.voting && player.isAlive && player.id != _controller.myPlayer?.id) _controller.executeVote(player); else _controller.selectPlayer(isSelected ? null : player); },
      child: Container(decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: isSelected ? 2.5 : 1)), child: Stack(alignment: Alignment.center, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('P${player.id} - ${player.name}', textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 6),
          Icon(reveal ? player.role.icon : Icons.help_outline, color: player.isAlive && reveal ? player.role.secondaryColor : (isNight ? Colors.white24 : Colors.black12), size: 24),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(_controller.getPlayerRoleNameDisplay(player), textAlign: TextAlign.center, style: TextStyle(color: player.isAlive && reveal ? player.role.secondaryColor : (isNight ? Colors.white24 : Colors.black12), fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        if (!player.isAlive) Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16)), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.close, color: Color(0xFFEF5350)), Text('TỬ NẠN', style: TextStyle(color: Color(0xFFEF5350), fontSize: 10, fontWeight: FontWeight.bold))])))),
        
        _buildSkillIndicators(player),

        if (player.id == _controller.myPlayer?.id) Positioned(top: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: player.role.primaryColor, borderRadius: BorderRadius.circular(4)), child: const Text('BẠN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
        if (player.isHost) Positioned(top: 6, left: player.id == _controller.myPlayer?.id ? 30 : 6, child: const Icon(Icons.star, color: Colors.amber, size: 10)),
      ])),
    );
  }

  Widget _buildSkillIndicators(OnlinePlayer player) {
    if (!player.isAlive) return const SizedBox.shrink();
    final my = _controller.myPlayer; if (my == null) return const SizedBox.shrink();
    List<Widget> icons = [];

    if (player.hasBeenScannedBySeer && player.id != my.id) icons.add(_miniIcon(Icons.remove_red_eye, Colors.cyan));
    
    bool isSelectedByCupid = my.role.id == 'cupid' && _controller.cupidSelections.any((p) => p.id == player.id);
    if (_controller.shouldShowLoverHeart(player) || isSelectedByCupid) icons.add(_miniIcon(Icons.favorite, Colors.pink));

    if (my.role.id == 'bao_ve' && player.wasProtectedByBodyguard) icons.add(_miniIcon(Icons.shield, Colors.blueAccent));
    if (my.role.id == 'phu_thuy' && player.wasHealedByWitch) icons.add(_miniIcon(Icons.health_and_safety, Colors.greenAccent));
    if (my.role.id == 'phu_thuy' && player.isPoisoned) icons.add(_miniIcon(Icons.science, Colors.purpleAccent));
    if (my.role.team == RoleTeam.werewolf && _controller.werewolfTarget?.id == player.id) icons.add(_miniIcon(Icons.pets, Colors.redAccent));

    if (icons.isEmpty && player.voteCount == 0) return const SizedBox.shrink();

    return Positioned(
      top: 6,
      right: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (icons.isNotEmpty) Wrap(spacing: 2, children: icons),
          if (player.voteCount > 0) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(6)), child: Text('${player.voteCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _miniIcon(IconData icon, Color clr) => Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: clr, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2, spreadRadius: 1)]), child: Icon(icon, color: Colors.white, size: 12));

  Widget _buildChatLogTabs() {
    final isWolf = _controller.myPlayer?.role.team == RoleTeam.werewolf;
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    // Ô chat ở Lobby dùng phong cách glassmorphism, Ban đêm dùng màu tối
    final isDark = isLobby || isNight;
    
    return Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isLobby ? Colors.white.withOpacity(0.2) : (isDark ? const Color(0xFF0F172A) : Colors.white), borderRadius: BorderRadius.circular(16), border: Border.all(color: isLobby ? Colors.white30 : const Color(0xFF334155), width: 0.5), boxShadow: [if (!isDark && !isLobby) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)]), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [_buildTabButton('TRÒ CHUYỆN 💬', isActive: _showChatTab, onTap: () => setState(() => _showChatTab = true)), _buildTabButton('NHẬT KÝ 📜', isActive: !_showChatTab, onTap: () => setState(() => _showChatTab = false))]),
      const Divider(color: Color(0xFF334155), height: 1),
      Container(height: 120, padding: const EdgeInsets.all(8), child: _showChatTab ? ListView.builder(itemCount: _controller.chatMessages.length, itemBuilder: (c, i) {
        final msg = _controller.chatMessages[i]; if (msg.isWerewolfOnly && !isWolf) return const SizedBox.shrink(); if (msg.isGhost && _controller.myPlayer?.isAlive == true) return const SizedBox.shrink();
        return _buildChatMessageTile(msg);
      }) : ListView.builder(itemCount: _controller.actionLogs.length, itemBuilder: (c, i) => _buildActionLogTile(_controller.actionLogs[i]))),
      if (_showChatTab) Padding(padding: const EdgeInsets.all(6), child: Row(children: [
        Expanded(child: SizedBox(height: 38, child: TextField(controller: _chatController, enabled: !_controller.isChatDisabled(), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12), decoration: InputDecoration(hintText: _controller.getChatHintText(), hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black45), filled: true, fillColor: isLobby ? Colors.white.withOpacity(0.1) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)), onSubmitted: (v) { _controller.sendUserMessage(v); _chatController.clear(); }))),
        const SizedBox(width: 6),
        CircleAvatar(radius: 18, backgroundColor: _controller.isChatDisabled() ? Colors.grey : (isLobby ? Colors.white : const Color(0xFFFFD54F)), child: IconButton(icon: Icon(Icons.send, size: 14, color: isLobby ? const Color(0xFF0288D1) : Colors.black), onPressed: _controller.isChatDisabled() ? null : () { _controller.sendUserMessage(_chatController.text); _chatController.clear(); })),
      ])),
    ]));
  }

  Widget _buildChatMessageTile(ChatMessage msg) {
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    final isDark = isLobby || isNight;
    
    Color clr = msg.isSystem ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309)) : (msg.isWerewolfOnly ? Colors.red : (msg.isGhost ? Colors.grey : (msg.senderName.contains('(Bạn)') ? (isDark ? Colors.green : const Color(0xFF15803D)) : (isDark ? Colors.white70 : const Color(0xFF0F172A)))));
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: RichText(text: TextSpan(children: [
      if (msg.isWerewolfOnly) const TextSpan(text: '[SÓI] ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
      if (msg.isGhost) const TextSpan(text: '[MA 👻] ', style: TextStyle(color: Colors.grey, fontSize: 11)),
      TextSpan(text: '${msg.senderName}: ', style: TextStyle(color: clr, fontWeight: FontWeight.bold, fontSize: 11.5)),
      TextSpan(text: msg.content, style: TextStyle(color: msg.isGhost ? Colors.grey : (isDark ? Colors.white70 : const Color(0xFF334155)), fontSize: 11.5)),
    ])));
  }

  Widget _buildActionLogTile(String log) {
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    final isDark = isLobby || isNight;
    
    Color clr = log.startsWith('Hệ thống:') ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309)) : (log.startsWith('Tiên Tri:') ? (isDark ? Colors.cyan : const Color(0xFF0369A1)) : (log.startsWith('Bảo Vệ:') ? (isDark ? Colors.blue : const Color(0xFF1D4ED8)) : (log.startsWith('Phù Thủy:') ? (isDark ? Colors.purple : const Color(0xFF7E22CE)) : (log.startsWith('Ma Sói:') ? Colors.red : (isDark ? Colors.white70 : const Color(0xFF334155))))));
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(log, style: TextStyle(color: clr, fontSize: 11.5)));
  }

  Widget _buildTabButton(String label, {required bool isActive, required VoidCallback onTap}) {
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    final isDark = isLobby || isNight;
    
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, decoration: BoxDecoration(color: isActive ? Colors.transparent : (isDark ? Colors.black26 : Colors.black.withOpacity(0.05))), child: Text(label, style: TextStyle(color: isActive ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFF0369A1)) : (isDark ? Colors.white60 : Colors.black54), fontSize: 11, fontWeight: FontWeight.bold)))));
  }

  Widget _buildTopBar(String title, {bool showInfo = false}) {
    return Padding(padding: const EdgeInsets.all(8), child: Row(children: [IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)), Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)), showInfo ? IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.info_outline, color: Color(0xFFFFD54F))) : const SizedBox(width: 48)]));
  }

  void _showOnlineRulesDialog() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), builder: (c) => Container(padding: const EdgeInsets.all(20), child: ListView.separated(itemCount: _controller.roleDefinitions.length, separatorBuilder: (c, i) => const Divider(color: Colors.white10), itemBuilder: (c, i) => _buildRoleRuleTile(_controller.roleDefinitions[i]))));
  }

  Widget _buildRoleRuleTile(RoleDefinition role) {
    return Row(children: [Icon(role.icon, color: role.secondaryColor), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(role.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(role.description, style: const TextStyle(color: Colors.white70, fontSize: 12))]))]);
  }

  Widget _buildBottomOnlineController() {
    if (_controller.myPlayer == null) return const SizedBox.shrink();
    final isNight = _controller.currentPhase == GamePhase.night; final isDead = !_controller.myPlayer!.isAlive;
    // Ban ngày thanh dưới dùng màu xanh (Sky 700)
    final barColor = isNight ? const Color(0xFF1E293B) : const Color(0xFF0369A1);
    
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [_buildMyRoleSummaryTile(), const SizedBox(width: 8), Expanded(child: Text(isDead ? 'Bạn đã tử nạn.' : _controller.getActionInstructionText(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center))]),
      const SizedBox(height: 10),
      Row(children: [
        if (isDead) Expanded(child: ElevatedButton(onPressed: _controller.resetGame, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('RỜI PHÒNG', style: TextStyle(color: Colors.white)))),
        if (isDead) const SizedBox(width: 8),
        if (!isDead && _controller.selectedPlayer != null) Expanded(child: _buildSkillActionButton()),
        if (!isDead && _controller.selectedPlayer != null) const SizedBox(width: 8),
        Expanded(child: ElevatedButton(onPressed: _controller.hunterSkillTriggered ? null : (isNight ? _controller.transitionToDay : (_controller.currentPhase == GamePhase.day ? _controller.transitionToVoting : _controller.transitionToNight)), style: ElevatedButton.styleFrom(backgroundColor: isNight ? Colors.orange : Colors.indigo), child: Text(_controller.hunterSkillTriggered ? '...' : (isNight ? 'QUA NGÀY' : 'TIẾP TỤC'), style: const TextStyle(color: Colors.white)))),
      ]),
    ]));
  }

  Widget _buildMyRoleSummaryTile() {
    final role = _controller.myPlayer!.role;
    return GestureDetector(onTap: _showMyRoleDetailsBottomSheet, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: role.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.4))), child: Row(children: [Icon(role.icon, color: Colors.white, size: 20), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('VAI TRÒ:', style: TextStyle(color: Colors.white70, fontSize: 9)), Text(role.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))]), const SizedBox(width: 4), const Icon(Icons.info_outline, color: Colors.white, size: 14)])));
  }

  Widget _buildSkillActionButton() {
    final target = _controller.selectedPlayer!; final my = _controller.myPlayer!; final isNight = _controller.currentPhase == GamePhase.night;
    if (_controller.hunterSkillTriggered) return ElevatedButton(onPressed: () => _controller.executeHunterShot(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange), child: const Text('BẮN KÉO THEO', style: TextStyle(color: Colors.white)));
    if (isNight) {
      if (my.role.id == 'cupid' && _controller.lover1 == null) {
        final sel = _controller.cupidSelections.any((p) => p.id == target.id);
        if (_controller.cupidSelections.length < 2 || sel) {
          return ElevatedButton(
            onPressed: () => setState(() { 
              if (sel) _controller.cupidSelections.removeWhere((p) => p.id == target.id); 
              else _controller.cupidSelections.add(target); 
            }), 
            style: ElevatedButton.styleFrom(backgroundColor: sel ? Colors.grey : Colors.pink[300]),
            child: Text(sel ? 'BỎ CHỌN' : 'CHỌN (${_controller.cupidSelections.length}/2)', style: const TextStyle(color: Colors.white))
          );
        }
        return ElevatedButton(onPressed: _controller.executeCupidLink, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink), child: const Text('GHÉP ĐÔI ❤️', style: TextStyle(color: Colors.white)));
      }
      if (my.role.id == 'tien_tri' && !_controller.hasUsedSeerScan && target.isAlive && target.id != my.id && !target.hasBeenScannedBySeer) return ElevatedButton(onPressed: () => _controller.executeSeerScan(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan), child: const Text('SOI BÀI', style: TextStyle(color: Colors.white)));
      if (my.role.id == 'bao_ve' && !_controller.hasUsedBodyguardProtect && target.isAlive && target.id != _controller.lastProtectedPlayerId) return ElevatedButton(onPressed: () => _controller.executeBodyguardProtect(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('BẢO VỆ', style: TextStyle(color: Colors.white)));
      if (my.role.id == 'phu_thuy') {
        final bite = _controller.werewolfTarget?.id == target.id; final heal = _controller.hasHealPotion && bite; final pois = _controller.hasPoisonPotion && target.isAlive && target.id != my.id;
        if (heal && pois) return Row(children: [Expanded(child: ElevatedButton(onPressed: _controller.executeWitchHeal, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('CỨU', style: TextStyle(color: Colors.white)))), const SizedBox(width: 4), Expanded(child: ElevatedButton(onPressed: () => _controller.executeWitchPoison(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: const Text('ĐỘC', style: TextStyle(color: Colors.white))))]);
        if (heal) return ElevatedButton(onPressed: _controller.executeWitchHeal, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('CỨU SỐNG', style: TextStyle(color: Colors.white)));
        if (pois) return ElevatedButton(onPressed: () => _controller.executeWitchPoison(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: const Text('DÙNG ĐỘC', style: TextStyle(color: Colors.white)));
      }
      if (my.role.id == 'soi_nguyen' && _controller.cursedPlayerId == null && target.isAlive && target.role.team != RoleTeam.werewolf) return ElevatedButton(onPressed: () => _controller.executeCurse(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent), child: const Text('NGUYỀN RỦA', style: TextStyle(color: Colors.white)));
      if (my.role.team == RoleTeam.werewolf && target.isAlive && target.role.team != RoleTeam.werewolf && target.id != _controller.cursedPlayerId) return ElevatedButton(onPressed: () => _controller.executeWerewolfBite(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('CẮN TIÊU DIỆT', style: TextStyle(color: Colors.white)));
    } else {
      if (my.role.id == 'xa_thu' && _controller.xathuBullets > 0 && target.isAlive && target.id != my.id) return ElevatedButton(onPressed: () => _controller.executeGunnerShoot(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue), child: const Text('BẮN', style: TextStyle(color: Colors.white)));
    }
    return const SizedBox.shrink();
  }

  void _showMyRoleDetailsBottomSheet() {
    final role = _controller.myPlayer!.role;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), builder: (c) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(role.icon, size: 50, color: role.secondaryColor), const SizedBox(height: 16), Text(role.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Text(role.description, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center), const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F)), child: const Text('ĐÃ HIỂU', style: TextStyle(fontWeight: FontWeight.bold))))])));
  }
}
