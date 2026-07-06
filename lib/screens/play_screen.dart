import 'dart:async';
import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../models/role_definition.dart';
import '../models/online_player.dart';
import '../models/chat_message.dart';
import '../services/game_controller.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

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
    _controller = GameController();
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    final gameOverMsg = _controller.checkGameOver();
    if (gameOverMsg.isNotEmpty && mounted && !_isGameOverDialogShowing) {
      _isGameOverDialogShowing = true;
      final isWin = _controller.isMyWin(gameOverMsg);
      _showGameOverDialog(isWin, gameOverMsg);
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
        title: Row(
          children: [
            Icon(
              isWin ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
              color: isWin ? const Color(0xFFFFD54F) : const Color(0xFFEF5350),
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(isWin ? 'CHIẾN THẮNG!' : 'THẤT BẠI!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isGameOverDialogShowing = false;
              });
              Navigator.of(context).pop();
              _controller.resetGame();
            },
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
        content: const Text('Bạn có chắc muốn rời phòng chơi không? Tiến trình sẽ bị hủy.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('HỦY', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('RỜI PHÒNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: _controller.currentState == PlayState.lobby ? _buildLobbyView() : _buildOnlinePlayingView(),
        ),
      ),
    );
  }

  // --- Lobby Views ---
  Widget _buildLobbyView() {
    return Column(
      children: [
        _buildTopBar('PHÒNG CHỜ ONLINE', showInfo: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoomCodeCard(),
                const SizedBox(height: 16),
                _buildUserProfileCard(),
                const SizedBox(height: 16),
                _buildLobbyPlayerCountCard(),
                const SizedBox(height: 20),
                const Text('DANH SÁCH PHÒNG ĐẤU:', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                _buildConnectedPlayersSimulator(),
                const SizedBox(height: 16),
                _buildChatLogTabs(),
              ],
            ),
          ),
        ),
        _buildLobbyBottomBar(),
      ],
    );
  }

  Widget _buildRoomCodeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MÃ PHÒNG CHƠI:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_controller.roomCode, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _controller.generateRoomCode(),
            icon: const Icon(Icons.refresh, size: 16, color: Colors.black),
            label: const Text('ĐỔI MÃ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          )
        ],
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TÊN HIỂN THỊ CỦA BẠN:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            maxLength: 16,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(counterText: '', hintText: 'Nhập tên hiển thị...', hintStyle: const TextStyle(color: Colors.white30), prefixIcon: const Icon(Icons.person, color: Color(0xFFFFD54F)), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            controller: TextEditingController(text: _controller.userName)..selection = TextSelection.collapsed(offset: _controller.userName.length),
            onChanged: (val) => _controller.updateUserName(val),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyPlayerCountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Số lượng người chơi:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD54F))), child: Text('${_controller.playerCount} Người', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 13, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          Slider(value: _controller.playerCount.toDouble(), min: 6, max: 18, divisions: 12, activeColor: const Color(0xFFFFD54F), onChanged: (value) => _controller.updatePlayerCount(value.toInt())),
        ],
      ),
    );
  }

  Widget _buildConnectedPlayersSimulator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD54F))),
              const SizedBox(width: 12),
              Expanded(child: Text('Đang chờ người chơi... (5 / ${_controller.playerCount})', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) {
              final names = ['Tuấn Tú', 'Khánh Linh', 'Nhật Minh', 'Phương Thảo'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 10, backgroundColor: Colors.blueGrey[800], child: Text('${index + 1}', style: const TextStyle(fontSize: 9, color: Colors.white))),
                        const SizedBox(width: 10),
                        Text(names[index], style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF4CAF50), width: 0.5)),
                      child: const Text('SẴN SÀNG', style: TextStyle(color: Color(0xFF81C784), fontSize: 9, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0F172A),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _controller.isLobbyLoading ? null : () => _controller.startLobbyTransition(),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
          child: _controller.isLobbyLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5)) : const Text('VÀO PHÒNG & BẮT ĐẦU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
      ),
    );
  }

  // --- Playing Views ---
  Widget _buildOnlinePlayingView() {
    return Column(
      children: [
        _buildOnlinePlayTopBar(),
        _buildOnlinePhaseHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _controller.playerCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8),
              itemBuilder: (context, index) {
                final player = _controller.players[index];
                return _buildPlayerOnlineCard(player);
              },
            ),
          ),
        ),
        _buildChatLogTabs(),
        _buildBottomOnlineController(),
      ],
    );
  }

  Widget _buildOnlinePlayTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () async { final pop = await _onWillPop(); if (pop && mounted) _controller.resetGame(); }, icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)),
          Column(children: [
            Text('PHÒNG ONLINE: ${_controller.roomCode}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            if (_controller.phaseTimerSeconds > 0) Text('Thời gian: ${_controller.phaseTimerSeconds}s', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.help_outline, color: Color(0xFFFFD54F))),
        ],
      ),
    );
  }

  Widget _buildOnlinePhaseHeader() {
    final phase = _controller.currentPhase;
    final isNight = phase == GamePhase.night;
    final isVoting = phase == GamePhase.voting;

    String phaseText = '';
    IconData phaseIcon = Icons.wb_sunny;
    Color phaseColor = const Color(0xFFF57F17);

    if (isNight) {
      phaseText = 'BAN ĐÊM - ĐÊM ${_controller.dayNumber}';
      phaseIcon = Icons.nights_stay;
      phaseColor = const Color(0xFF311B92);
    } else if (isVoting) {
      phaseText = 'BỎ PHIẾU - NGÀY ${_controller.dayNumber}';
      phaseIcon = Icons.how_to_vote;
      phaseColor = const Color(0xFFC62828);
    } else {
      phaseText = 'THẢO LUẬN - NGÀY ${_controller.dayNumber}';
      phaseIcon = Icons.wb_sunny;
      phaseColor = const Color(0xFFF57F17);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: phaseColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: phaseColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(phaseIcon, color: isNight ? const Color(0xFFB39DDB) : const Color(0xFFFFD54F), size: 20),
            const SizedBox(width: 8),
            Text(phaseText, style: TextStyle(color: isNight ? const Color(0xFFD1C4E9) : const Color(0xFFFFF59D), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
          ]),
          Text('SỐNG: ${_controller.players.where((p) => p.isAlive).length} / ${_controller.playerCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPlayerOnlineCard(OnlinePlayer player) {
    final isSelected = player.id == _controller.selectedPlayer?.id;
    final revealRole = _controller.shouldRevealRole(player);
    final borderGlowColor = _controller.getPlayerBorderColor(player);
    final roleName = _controller.getPlayerRoleNameDisplay(player);

    return GestureDetector(
      onTap: () {
        if (_controller.currentPhase == GamePhase.voting && player.isAlive && player.id != _controller.myPlayer?.id) {
          _controller.executeVote(player);
        } else {
          _controller.selectPlayer(isSelected ? null : player);
        }
      },
      child: Container(
        decoration: BoxDecoration(color: player.isAlive ? const Color(0xFF1E293B) : const Color(0xFF0F172A).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: borderGlowColor, width: isSelected ? 2.5 : 1.0)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('P${player.id} - ${player.name}', style: TextStyle(color: player.isAlive ? Colors.white : Colors.white30, fontWeight: FontWeight.bold, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Icon(revealRole ? player.role.icon : Icons.help_outline, color: player.isAlive && revealRole ? player.role.secondaryColor : Colors.white24, size: 24),
                  const SizedBox(height: 6),
                  Text(roleName, style: TextStyle(color: player.isAlive && revealRole ? player.role.secondaryColor : Colors.white24, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (!player.isAlive) Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(16)), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.close, color: Color(0xFFEF5350), size: 30), Text('TỬ NẠN', style: TextStyle(color: Color(0xFFEF5350), fontSize: 10, fontWeight: FontWeight.bold))])))),
            if (player.isAlive && player.hasBeenScannedBySeer && player.id != _controller.myPlayer?.id) Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFF00838F), shape: BoxShape.circle), child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 10))),
            if (player.isAlive && _controller.shouldShowLoverHeart(player)) Positioned(top: 6, left: 28, child: const Icon(Icons.favorite, color: Color(0xFFEC407A), size: 12)),
            if (player.isAlive && player.voteCount > 0) Positioned(bottom: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEF5350).withOpacity(0.9), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.how_to_vote, color: Colors.white, size: 10), const SizedBox(width: 2), Text('${player.voteCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]))),
            if (player.id == _controller.myPlayer?.id) Positioned(top: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: player.role.primaryColor, borderRadius: BorderRadius.circular(6)), child: const Text('BẠN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
            if (player.isHost) Positioned(top: 6, left: player.id == _controller.myPlayer?.id ? 32 : 6, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle), child: const Icon(Icons.star, color: Colors.black, size: 8))),
          ],
        ),
      ),
    );
  }

  Widget _buildChatLogTabs() {
    final isWolf = _controller.myPlayer?.role.team == RoleTeam.werewolf;
    final ScrollController scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (scrollController.hasClients) scrollController.jumpTo(scrollController.position.maxScrollExtent); });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            _buildTabButton('TRÒ CHUYỆN 💬', isActive: _showChatTab, onTap: () => setState(() => _showChatTab = true)),
            _buildTabButton('NHẬT KÝ 📜', isActive: !_showChatTab, onTap: () => setState(() => _showChatTab = false)),
          ]),
          const Divider(color: Color(0xFF334155), height: 1),
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: _showChatTab ? ListView.builder(
              controller: scrollController,
              itemCount: _controller.chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _controller.chatMessages[index];
                if (msg.isWerewolfOnly && !isWolf) return const SizedBox.shrink();
                if (msg.isGhost && _controller.myPlayer != null && _controller.myPlayer!.isAlive) return const SizedBox.shrink();
                return _buildChatMessageTile(msg);
              },
            ) : ListView.builder(
              controller: scrollController,
              itemCount: _controller.actionLogs.length,
              itemBuilder: (context, index) => _buildActionLogTile(_controller.actionLogs[index]),
            ),
          ),
          if (_showChatTab) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(padding: const EdgeInsets.all(6.0), child: Row(children: [
              Expanded(child: SizedBox(height: 38, child: TextField(controller: _chatController, enabled: !_controller.isChatDisabled(), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(hintText: _controller.getChatHintText(), hintStyle: TextStyle(color: _controller.isChatDisabled() ? Colors.white24 : Colors.white38, fontSize: 12), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)), onSubmitted: (_) { _controller.sendUserMessage(_chatController.text); _chatController.clear(); }))),
              const SizedBox(width: 6),
              CircleAvatar(radius: 18, backgroundColor: _controller.isChatDisabled() ? const Color(0xFF334155) : const Color(0xFFFFD54F), child: IconButton(icon: Icon(Icons.send, size: 14, color: _controller.isChatDisabled() ? Colors.white30 : Colors.black), onPressed: _controller.isChatDisabled() ? null : () { _controller.sendUserMessage(_chatController.text); _chatController.clear(); })),
            ])),
          ],
        ],
      ),
    );
  }

  Widget _buildChatMessageTile(ChatMessage msg) {
    Color senderColor = Colors.white70;
    if (msg.isSystem) senderColor = const Color(0xFFFFD54F);
    else if (msg.isWerewolfOnly) senderColor = const Color(0xFFEF5350);
    else if (msg.isGhost) senderColor = Colors.white30;
    else if (msg.senderName.contains('(Bạn)')) senderColor = const Color(0xFF81C784);

    return Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: RichText(text: TextSpan(children: [
      if (msg.isWerewolfOnly) const TextSpan(text: '[SÓI] ', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 11)),
      if (msg.isGhost) const TextSpan(text: '[MA 👻] ', style: TextStyle(color: Colors.white24, fontSize: 11)),
      TextSpan(text: '${msg.senderName}: ', style: TextStyle(color: senderColor, fontWeight: FontWeight.bold, fontSize: 11.5)),
      TextSpan(text: msg.content, style: TextStyle(color: msg.isGhost ? Colors.white30 : (msg.isSystem ? const Color(0xFFFFD54F) : Colors.white70), fontSize: 11.5, fontStyle: msg.isGhost ? FontStyle.italic : FontStyle.normal)),
    ])));
  }

  Widget _buildActionLogTile(String log) {
    Color logColor = Colors.white70;
    if (log.startsWith('Hệ thống:')) logColor = const Color(0xFFFFD54F);
    else if (log.startsWith('Tiên Tri:')) logColor = const Color(0xFF26C6DA);
    else if (log.startsWith('Bảo Vệ:')) logColor = const Color(0xFF42A5F5);
    else if (log.startsWith('Phù Thủy:')) logColor = const Color(0xFFAB47BC);
    else if (log.startsWith('Ma Sói:')) logColor = const Color(0xFFEF5350);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Text(log, style: TextStyle(color: logColor, fontSize: 11.5, height: 1.3)));
  }

  Widget _buildTabButton(String label, {required bool isActive, required VoidCallback onTap}) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, decoration: BoxDecoration(color: isActive ? Colors.transparent : const Color(0xFF1E293B).withValues(alpha: 0.5), borderRadius: BorderRadius.only(topLeft: label.startsWith('TRÒ CHUYỆN') ? const Radius.circular(16) : Radius.zero, topRight: label.startsWith('NHẬT KÝ') ? const Radius.circular(16) : Radius.zero)), child: Text(label, style: TextStyle(color: isActive ? const Color(0xFFFFD54F) : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)))));
  }

  Widget _buildTopBar(String title, {bool showInfo = false, VoidCallback? onBack}) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(children: [IconButton(onPressed: onBack ?? () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)), Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2), textAlign: TextAlign.center)), if (showInfo) IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 26)) else const SizedBox(width: 48)]));
  }

  void _showOnlineRulesDialog() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (context) => Container(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('CÁC VAI TRÒ TRÒ CHƠI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)), IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white70))]), const SizedBox(height: 10), Expanded(child: ListView.separated(itemCount: _controller.roleDefinitions.length, separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155), height: 16), itemBuilder: (context, index) => _buildRoleRuleTile(_controller.roleDefinitions[index])))])));
  }

  Widget _buildRoleRuleTile(RoleDefinition role) {
    Color teamColor = role.team == RoleTeam.villager ? const Color(0xFF81C784) : (role.team == RoleTeam.werewolf ? const Color(0xFFE57373) : const Color(0xFFD4E157));
    String teamText = role.team == RoleTeam.villager ? 'Phe Dân Làng' : (role.team == RoleTeam.werewolf ? 'Phe Ma Sói' : 'Phe Thứ Ba');
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: role.primaryColor.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: role.primaryColor, width: 1.5)), child: Icon(role.icon, color: role.secondaryColor, size: 24)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(role.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), const SizedBox(width: 8), Text('($teamText)', style: TextStyle(color: teamColor, fontSize: 12, fontWeight: FontWeight.bold))]), const SizedBox(height: 4), Text(role.description, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3))]))]);
  }

  Widget _buildBottomOnlineController() {
    if (_controller.myPlayer == null) return const SizedBox.shrink();
    final phase = _controller.currentPhase;
    final isNight = phase == GamePhase.night;
    final isVoting = phase == GamePhase.voting;
    final isDead = !_controller.myPlayer!.isAlive;

    String nextPhaseLabel = '';
    IconData nextPhaseIcon = Icons.arrow_forward;
    VoidCallback? onNextPhase;

    if (isNight) {
      nextPhaseLabel = 'QUA NGÀY';
      nextPhaseIcon = Icons.wb_sunny;
      onNextPhase = _controller.transitionToDay;
    } else if (isVoting) {
      nextPhaseLabel = 'KẾT THÚC VOTE';
      nextPhaseIcon = Icons.nights_stay;
      onNextPhase = _controller.transitionToNight;
    } else {
      nextPhaseLabel = 'BỎ PHIẾU';
      nextPhaseIcon = Icons.how_to_vote;
      onNextPhase = _controller.transitionToVoting;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _buildMyRoleSummaryTile(),
          const SizedBox(width: 8),
          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)), child: Text(isDead ? 'Bạn đã tử nạn. Đang ở Chế độ Quan sát.' : _controller.getActionInstructionText(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (isDead) Expanded(child: ElevatedButton.icon(onPressed: () => _controller.resetGame(), icon: const Icon(Icons.exit_to_app), label: const Text('RỜI PHÒNG'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
          if (isDead) const SizedBox(width: 8),
          if (!isDead && _controller.selectedPlayer != null) Expanded(child: _buildSkillActionButton()),
          if (!isDead && _controller.selectedPlayer != null) const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(onPressed: _controller.hunterSkillTriggered ? null : onNextPhase, icon: Icon(_controller.hunterSkillTriggered ? Icons.gps_fixed : nextPhaseIcon), label: Text(_controller.hunterSkillTriggered ? 'ĐANG NỔ SÚNG...' : nextPhaseLabel), style: ElevatedButton.styleFrom(backgroundColor: isNight ? const Color(0xFFF57F17) : (isVoting ? const Color(0xFFC62828) : const Color(0xFF311B92)), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
        ]),
      ]),
    );
  }

  Widget _buildMyRoleSummaryTile() {
    final myRole = _controller.myPlayer!.role;
    return GestureDetector(
      onTap: _showMyRoleDetailsBottomSheet,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: myRole.primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: myRole.primaryColor.withValues(alpha: 0.4))), child: Row(children: [Icon(myRole.icon, color: myRole.secondaryColor, size: 20), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('VAI TRÒ CỦA BẠN:', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)), Text(myRole.name, style: TextStyle(color: myRole.secondaryColor, fontSize: 13, fontWeight: FontWeight.bold))]), const SizedBox(width: 4), const Icon(Icons.info_outline, color: Colors.white38, size: 14)])),
    );
  }

  Widget _buildSkillActionButton() {
    final target = _controller.selectedPlayer!;
    final myPlayer = _controller.myPlayer!;
    final myRoleId = myPlayer.role.id;
    final isNight = _controller.currentPhase == GamePhase.night;

    if (_controller.hunterSkillTriggered) {
      return ElevatedButton.icon(onPressed: () => _controller.executeHunterShot(target), icon: const Icon(Icons.gps_fixed), label: const Text('BẮN KÉO THEO'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
    }

    if (isNight) {
      if (myRoleId == 'cupid' && _controller.lover1 == null) {
        final isSelected = _controller.cupidSelections.any((p) => p.id == target.id);
        if (_controller.cupidSelections.length < 2 || isSelected) {
          return ElevatedButton.icon(
            onPressed: () => setState(() { if (isSelected) _controller.cupidSelections.removeWhere((p) => p.id == target.id); else _controller.cupidSelections.add(target); }),
            icon: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank),
            label: Text(isSelected ? 'BỎ CHỌN' : 'CHỌN (${_controller.cupidSelections.length}/2)'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAD1457), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          );
        } else {
          return ElevatedButton.icon(onPressed: () => _controller.executeCupidLink(), icon: const Icon(Icons.favorite), label: const Text('GHÉP ĐÔI ❤️'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC407A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          );
        }
      }

      if (myRoleId == 'tien_tri') {
        final allowed = !_controller.hasUsedSeerScan && target.isAlive && target.id != myPlayer.id && !target.hasBeenScannedBySeer;
        return ElevatedButton.icon(onPressed: allowed ? () => _controller.executeSeerScan(target) : null, icon: const Icon(Icons.remove_red_eye), label: const Text('SOI BÀI'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00838F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
      }

      if (myRoleId == 'bao_ve') {
        final allowed = !_controller.hasUsedBodyguardProtect && target.isAlive && target.id != _controller.lastProtectedPlayerId;
        return ElevatedButton.icon(onPressed: allowed ? () => _controller.executeBodyguardProtect(target) : null, icon: const Icon(Icons.shield), label: const Text('BẢO VỆ'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
      }

      if (myRoleId == 'phu_thuy') {
        final isTargetBitten = _controller.werewolfTarget?.id == target.id;
        final showHeal = _controller.hasHealPotion && isTargetBitten;
        final showPoison = _controller.hasPoisonPotion && target.isAlive && target.id != myPlayer.id;

        if (showHeal && showPoison) {
          return Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: () => _controller.executeWitchHeal(), icon: const Icon(Icons.health_and_safety), label: const Text('CỨU', style: TextStyle(fontSize: 10)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
            const SizedBox(width: 4),
            Expanded(child: ElevatedButton.icon(onPressed: () => _controller.executeWitchPoison(target), icon: const Icon(Icons.science), label: const Text('ĐỘC', style: TextStyle(fontSize: 10)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
          ]);
        } else if (showHeal) {
          return ElevatedButton.icon(onPressed: () => _controller.executeWitchHeal(), icon: const Icon(Icons.health_and_safety), label: const Text('CỨU'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
        } else if (showPoison) {
          return ElevatedButton.icon(onPressed: () => _controller.executeWitchPoison(target), icon: const Icon(Icons.science), label: const Text('DÙNG ĐỘC'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
        }
      }

      if (myRoleId == 'soi_nguyen' && _controller.cursedPlayerId == null) {
        final allowed = target.isAlive && target.role.team != RoleTeam.werewolf;
        return ElevatedButton.icon(onPressed: allowed ? () => _controller.executeCurse(target) : null, icon: const Icon(Icons.auto_awesome), label: const Text('NGUYỀN RỦA'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
      }

      if (myPlayer.role.team == RoleTeam.werewolf) {
        final allowed = target.isAlive && target.role.team != RoleTeam.werewolf && target.id != _controller.cursedPlayerId;
        return ElevatedButton.icon(onPressed: allowed ? () => _controller.executeWerewolfBite(target) : null, icon: const Icon(Icons.pets), label: const Text('CẮN TIÊU DIỆT'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
      }
    } else {
      if (myRoleId == 'xa_thu' && _controller.xathuBullets > 0 && target.isAlive && target.id != myPlayer.id) {
        return ElevatedButton.icon(onPressed: () => _controller.executeGunnerShoot(target), icon: const Icon(Icons.gps_fixed), label: const Text('BẮN CÔNG KHAI'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0277BD), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)));
      }
    }
    return const SizedBox.shrink();
  }

  void _showMyRoleDetailsBottomSheet() {
    final role = _controller.myPlayer!.role;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (context) => Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: role.primaryColor.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: role.primaryColor, width: 2)), child: Icon(role.icon, size: 50, color: role.secondaryColor)), const SizedBox(height: 16), Text(role.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)), const SizedBox(height: 16), Text(role.description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4), textAlign: TextAlign.center), const SizedBox(height: 24), SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black), child: const Text('ĐÃ HIỂU', style: TextStyle(fontWeight: FontWeight.bold))))])));
  }
}