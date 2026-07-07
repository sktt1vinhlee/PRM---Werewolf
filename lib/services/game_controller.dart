import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../models/role_definition.dart';
import '../models/online_player.dart';
import '../models/chat_message.dart';

class GameController extends ChangeNotifier {
  static final Set<String> activeRooms = {}; // Lưu trữ các mã phòng đang hoạt động

  PlayState currentState = PlayState.lobby;
  GamePhase currentPhase = GamePhase.night;
  int playerCount = 12;
  String userName = 'Sói Đầu Đàn';
  String roomCode = '';
  bool isLobbyLoading = false;
  int dayNumber = 1;

  List<OnlinePlayer> players = [];
  List<String> lobbyPlayerNames = [];
  OnlinePlayer? myPlayer;
  OnlinePlayer? selectedPlayer;
  List<String> actionLogs = [];
  List<ChatMessage> chatMessages = [];
  
  int phaseTimerSeconds = 0;
  Timer? _phaseTimer;
  Timer? botChatTimer;

  bool hasUsedSeerScan = false;
  bool hasUsedBodyguardProtect = false;
  int? lastProtectedPlayerId;
  bool hasHealPotion = true;
  bool hasPoisonPotion = true;
  bool hasUsedHealThisNight = false;
  bool hasUsedPoisonThisNight = false;
  OnlinePlayer? werewolfTarget;

  OnlinePlayer? lover1;
  OnlinePlayer? lover2;
  int? cursedPlayerId;
  int xathuBullets = 2;
  bool xathuRevealed = false;
  bool hunterSkillTriggered = false;
  OnlinePlayer? hunterWhoDied;
  List<OnlinePlayer> cupidSelections = [];

  final List<RoleDefinition> roleDefinitions = [
    RoleDefinition(id: 'dan', name: 'Dân Làng', description: 'Tìm kiếm và bỏ phiếu tiêu diệt bầy Sói bằng sức mạnh đoàn kết ban ngày.', team: RoleTeam.villager, icon: Icons.person, primaryColor: const Color(0xFF2E7D32), secondaryColor: const Color(0xFF4CAF50), isUnique: false),
    RoleDefinition(id: 'soi', name: 'Ma Sói', description: 'Thống nhất sát hại một nạn nhân mỗi đêm và ẩn mình khéo léo giữa dân làng.', team: RoleTeam.werewolf, icon: Icons.pets, primaryColor: const Color(0xFFC62828), secondaryColor: const Color(0xFFEF5350), isUnique: false),
    RoleDefinition(id: 'soi_nguyen', name: 'Sói Nguyền', description: 'Chọn một người để nguyền rủa; nếu người đó bị cắn, họ sẽ gia nhập phe Sói.', team: RoleTeam.werewolf, icon: Icons.auto_awesome, primaryColor: const Color(0xFF8E24AA), secondaryColor: const Color(0xFFBA68C8), isUnique: true),
    RoleDefinition(id: 'soi_dau_dan', name: 'Sói Đầu Đàn', description: 'Lá phiếu bình chọn của Sói Đầu Đàn trong bầy Sói có giá trị gấp đôi.', team: RoleTeam.werewolf, icon: Icons.gavel, primaryColor: const Color(0xFFD84315), secondaryColor: const Color(0xFFFF7043), isUnique: true),
    RoleDefinition(id: 'xa_thu', name: 'Xạ Thủ', description: 'Có 2 viên đạn để bắn vào ban ngày. Khi bắn lần đầu, tiếng súng nổ lớn sẽ khiến vai trò bị tiết lộ.', team: RoleTeam.villager, icon: Icons.gps_fixed, primaryColor: const Color(0xFF0277BD), secondaryColor: const Color(0xFF29B6F6), isUnique: true),
    RoleDefinition(id: 'tien_tri', name: 'Tiên Tri', description: 'Mỗi đêm soi 1 người chơi để biết họ thuộc phe Dân Làng hay phe Ma Sói.', team: RoleTeam.villager, icon: Icons.remove_red_eye, primaryColor: const Color(0xFF00838F), secondaryColor: const Color(0xFF26C6DA), isUnique: true),
    RoleDefinition(id: 'cupid', name: 'Cupid', description: 'Ghép đôi 2 người; nếu một người qua đời, người còn lại cũng sẽ chết theo.', team: RoleTeam.villager, icon: Icons.favorite, primaryColor: const Color(0xFFAD1457), secondaryColor: const Color(0xFFEC407A), isUnique: true),
    RoleDefinition(id: 'tho_san', name: 'Thợ Săn', description: 'Ngay khi hy sinh, có thể chọn nổ súng kéo theo một người chơi khác.', team: RoleTeam.villager, icon: Icons.colorize, primaryColor: const Color(0xFFEF6C00), secondaryColor: const Color(0xFFFFA726), isUnique: true),
    RoleDefinition(id: 'bao_ve', name: 'Bảo Vệ', description: 'Mỗi đêm bảo vệ 1 người khỏi Sói (không bảo vệ 1 người 2 đêm liên tiếp).', team: RoleTeam.villager, icon: Icons.shield, primaryColor: const Color(0xFF1565C0), secondaryColor: const Color(0xFF42A5F5), isUnique: true),
    RoleDefinition(id: 'phu_thuy', name: 'Phù Thủy', description: 'Sở hữu 1 bình cứu người chết trong đêm và 1 bình thuốc độc để sát hại.', team: RoleTeam.villager, icon: Icons.science, primaryColor: const Color(0xFF6A1B9A), secondaryColor: const Color(0xFFAB47BC), isUnique: true),
    RoleDefinition(id: 'nerd', name: 'Kẻ Ngốc', description: 'Giành chiến thắng duy nhất nếu bị dân làng bỏ phiếu treo cổ vào ban ngày.', team: RoleTeam.neutral, icon: Icons.psychology, primaryColor: const Color(0xFF9E9D24), secondaryColor: const Color(0xFFD4E157), isUnique: true),
  ];

  GameController({String? initialRoomCode}) {
    if (initialRoomCode != null) {
      roomCode = initialRoomCode;
      // Giả lập phòng đã có Host, bạn là người tham gia
      lobbyPlayerNames = ['Chủ phòng', userName];
    } else {
      generateRoomCode();
      // Bạn là Host, phòng ban đầu chỉ có mình bạn
      lobbyPlayerNames = [userName];
    }
    initializeLobbyChat();
  }

  void generateRoomCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    roomCode = 'WS-${List.generate(6, (index) => chars[random.nextInt(chars.length)]).join()}';
    activeRooms.add(roomCode); // Đưa mã phòng vào danh sách hoạt động khi tạo mới
    notifyListeners();
  }

  void startLobbyTransition() {
    isLobbyLoading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1000), () => initializeOnlineGame());
  }

  void resetGame() {
    stopPeriodicBotChat();
    _phaseTimer?.cancel();
    currentState = PlayState.lobby;
    selectedPlayer = null;
    players = [];
    myPlayer = null;
    actionLogs = [];
    isLobbyLoading = false;
    generateRoomCode();
    initializeLobbyChat();
    notifyListeners();
  }

  void updateUserName(String name) { 
    // Cập nhật tên trong danh sách phòng chờ
    int index = lobbyPlayerNames.indexOf(userName);
    if (index != -1) {
      lobbyPlayerNames[index] = name;
    }
    userName = name; 
    notifyListeners(); 
  }
  void updatePlayerCount(int count) { playerCount = count; notifyListeners(); }
  void selectPlayer(OnlinePlayer? player) { selectedPlayer = player; notifyListeners(); }

  bool shouldRevealRole(OnlinePlayer player) {
    if (!player.isAlive) return true;
    if (player.id == myPlayer?.id) return true;
    if (myPlayer?.role.team == RoleTeam.werewolf && player.role.team == RoleTeam.werewolf) return true;
    if (player.hasBeenScannedBySeer) return true;
    if (lover1 != null && lover2 != null) {
      if (myPlayer?.id == lover1!.id && player.id == lover2!.id) return true;
      if (myPlayer?.id == lover2!.id && player.id == lover1!.id) return true;
    }
    if (xathuRevealed && player.role.id == 'xa_thu') return true;
    return false;
  }

  Color getPlayerBorderColor(OnlinePlayer player) {
    if (selectedPlayer?.id == player.id) return const Color(0xFFFFD54F);
    if (!player.isAlive) return Colors.grey[700]!;
    if (player.id == myPlayer?.id) return player.role.primaryColor;
    if (myPlayer?.role.team == RoleTeam.werewolf && player.role.team == RoleTeam.werewolf) return const Color(0xFFEF5350);
    if (player.hasBeenScannedBySeer) {
      final isWolf = player.role.team == RoleTeam.werewolf || player.id == cursedPlayerId;
      return isWolf ? const Color(0xFFEF5350) : const Color(0xFF81C784);
    }
    return Colors.white24;
  }

  String getPlayerRoleNameDisplay(OnlinePlayer player) {
    if (!shouldRevealRole(player)) return 'ẨN VAI TRÒ';
    if (player.id == cursedPlayerId && player.isAlive) return 'Ma Sói (Nguyền)';
    return player.role.name;
  }

  bool shouldShowLoverHeart(OnlinePlayer player) {
    if (!player.isAlive || lover1 == null || lover2 == null) return false;
    final isLover = player.id == lover1!.id || player.id == lover2!.id;
    final canSee = myPlayer?.role.id == 'cupid' || myPlayer?.id == lover1!.id || myPlayer?.id == lover2!.id;
    return isLover && canSee;
  }

  void initializeLobbyChat() {
    chatMessages = [
      ChatMessage(senderName: 'Hệ thống', content: 'Tạo phòng thành công. Đang chờ người chơi...', isSystem: true, time: DateTime.now()),
      ChatMessage(senderName: 'Tuấn Tú', content: 'Chào cả phòng nha!', time: DateTime.now().subtract(const Duration(seconds: 15))),
    ];
    actionLogs = ['Hệ thống: Bạn đã tham gia phòng $roomCode.', 'Hệ thống: Tuấn Tú đã tham gia phòng.'];
  }

  void sendUserMessage(String text) {
    if (text.trim().isEmpty) return;
    final isWolfChannel = currentPhase == GamePhase.night && myPlayer?.role.team == RoleTeam.werewolf;
    chatMessages.add(ChatMessage(
      senderName: '$userName (Bạn)',
      content: text,
      isWerewolfOnly: isWolfChannel,
      isGhost: !myPlayer!.isAlive,
      time: DateTime.now(),
    ));
    simulateBotChatResponse(text);
    notifyListeners();
  }

  bool isChatDisabled() {
    if (currentState != PlayState.playing) return false;
    if (currentPhase == GamePhase.night) return myPlayer?.role.team != RoleTeam.werewolf;
    return false;
  }

  String getChatHintText() {
    if (currentState != PlayState.playing) return 'Nhập tin nhắn...';
    if (currentPhase == GamePhase.night) return myPlayer?.role.team != RoleTeam.werewolf ? 'Ban đêm không thể nói chuyện.' : 'Chat Bầy Sói...';
    if (!myPlayer!.isAlive) return 'Kênh Hồn Ma...';
    return 'Nhập tin nhắn...';
  }

  void startPhaseTimer(int seconds) {
    _phaseTimer?.cancel();
    phaseTimerSeconds = seconds;
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (phaseTimerSeconds > 0) {
        phaseTimerSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        if (currentPhase == GamePhase.night) transitionToDay();
        else if (currentPhase == GamePhase.day) transitionToVoting();
        else transitionToNight();
      }
    });
  }

  void transitionToDay() {
    if (hunterSkillTriggered) return;
    stopPeriodicBotChat();
    if (werewolfTarget != null && !werewolfTarget!.isProtected) killPlayer(werewolfTarget!, 'Hệ thống: Đêm qua, ${werewolfTarget!.name} đã bị Ma Sói cắn chết! 🩸');
    for (var p in players) if (p.isPoisoned && p.isAlive) killPlayer(p, 'Hệ thống: Đêm qua, Phù Thủy đã độc chết ${p.name}! 🧪');
    addLog('Hệ thống: Bình minh đã lên! Thảo luận (60s).');
    for (var p in players) {
      p.isProtected = false; p.isPoisoned = false; p.voteCount = 0; p.isTargeted = false;
      p.wasProtectedByBodyguard = false; p.wasHealedByWitch = false;
    }
    hasUsedSeerScan = false; hasUsedBodyguardProtect = false; hasUsedHealThisNight = false; hasUsedPoisonThisNight = false;
    selectedPlayer = null; currentPhase = GamePhase.day;
    if (checkGameOver().isEmpty) { startPeriodicBotChat(); startPhaseTimer(60); }
    notifyListeners();
  }

  void transitionToVoting() {
    if (hunterSkillTriggered) return;
    stopPeriodicBotChat();
    addLog('Hệ thống: Bắt đầu bỏ phiếu (15s)!');
    currentPhase = GamePhase.voting;
    for (var p in players) { p.voteCount = 0; p.isTargeted = false; }
    _simulateBotVotesGradually();
    startPhaseTimer(15);
    notifyListeners();
  }

  void transitionToNight() {
    if (hunterSkillTriggered) return;
    stopPeriodicBotChat();
    List<OnlinePlayer> alive = players.where((p) => p.isAlive).toList();
    OnlinePlayer? hanged; int maxV = 0;
    for (var p in alive) {
      if (p.voteCount > maxV) { maxV = p.voteCount; hanged = p; }
      else if (p.voteCount == maxV && maxV > 0 && Random().nextBool()) hanged = p;
    }
    if (hanged != null && maxV > 0) {
      final isW = hanged.role.team == RoleTeam.werewolf || hanged.id == cursedPlayerId;
      killPlayer(hanged, 'Hệ thống: ${hanged.name} bị treo cổ! Vai trò: ${hanged.role.name} (${isW ? "Phe Sói" : "Phe Dân"}) ⚖️');
    } else addLog('Hệ thống: Không ai bị treo cổ.');
    for (var p in players) p.voteCount = 0;
    dayNumber++; currentPhase = GamePhase.night; selectedPlayer = null;
    addLog('Hệ thống: ĐÊM $dayNumber bắt đầu.');
    if (checkGameOver().isEmpty) { simulateWerewolfNightTarget(); startPhaseTimer(15); }
    notifyListeners();
  }

  void executeVote(OnlinePlayer target) {
    final weight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    for (var p in players) if (p.isTargeted) { p.voteCount -= weight; p.isTargeted = false; }
    target.voteCount += weight; target.isTargeted = true;
    notifyListeners();
  }

  void initializeOnlineGame() {
    final random = Random(); List<RoleDefinition> roles = [];
    int targetWolves = max(1, (playerCount / 4).round());
    List<RoleDefinition> wolfPool = [];
    if (random.nextBool() && targetWolves >= 2) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_dau_dan'));
    if (random.nextBool() && targetWolves >= 2) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_nguyen'));
    while (wolfPool.length < targetWolves) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi'));
    roles.addAll(wolfPool);
    List<RoleDefinition> specials = roleDefinitions.where((r) => r.isUnique && r.team != RoleTeam.werewolf).toList()..shuffle(random);
    roles.addAll(specials.take(min(specials.length, playerCount - roles.length)));
    while (roles.length < playerCount) roles.add(roleDefinitions.firstWhere((r) => r.id == 'dan'));
    roles.shuffle(random);
    final names = ['Minh Đức', 'Khánh Linh', 'Tuấn Tú', 'Hoài Thu', 'Gia Bảo', 'Quỳnh Anh', 'Nhật Minh', 'Phương Thảo', 'Thanh Lâm', 'Mai Chi', 'Trí Dũng', 'Ngọc Diệp'];
    int myIdx = random.nextInt(playerCount);
    players = List.generate(playerCount, (i) => OnlinePlayer(id: i + 1, name: i == myIdx ? '$userName (Bạn)' : names[i % names.length], role: roles[i], isHost: i == 0));
    myPlayer = players[myIdx];

    // Chuyển sang trạng thái lật thẻ bài (Role Reveal) trước khi bắt đầu
    currentState = PlayState.roleReveal;
    isLobbyLoading = false;
    notifyListeners();

    // Sau 5 giây xem role mới chính thức vào Đêm 1
    Future.delayed(const Duration(seconds: 5), () {
      if (currentState != PlayState.roleReveal) return; // Tránh trường hợp đã reset game
      currentState = PlayState.playing;
      dayNumber = 1;
      currentPhase = GamePhase.night;
      hasHealPotion = true; hasPoisonPotion = true; werewolfTarget = null;
      xathuBullets = 2; xathuRevealed = false;
      actionLogs = ['Hệ thống: Trò chơi BẮT ĐẦU!', 'Hệ thống: ĐÊM 1 bắt đầu.'];
      chatMessages = [ChatMessage(senderName: 'Hệ thống', content: 'Trận đấu bắt đầu!', isSystem: true, time: DateTime.now())];
      if (myPlayer!.role.team == RoleTeam.werewolf) chatMessages.add(ChatMessage(senderName: 'Hệ thống', content: 'Kênh chat Bầy Sói đã mở.', isSystem: true, isWerewolfOnly: true, time: DateTime.now()));
      simulateWerewolfNightTarget();
      startPhaseTimer(15);
      notifyListeners();
    });
  }

  void killPlayer(OnlinePlayer player, String reason) {
    if (!player.isAlive) return;
    player.isAlive = false; addLog(reason);
    if (lover1 != null && lover2 != null) {
      if (player.id == lover1!.id && lover2!.isAlive) killPlayer(lover2!, 'Hệ thống: Tình nhân hy sinh! 💔');
      else if (player.id == lover2!.id && lover1!.isAlive) killPlayer(lover1!, 'Hệ thống: Tình nhân hy sinh! 💔');
    }
    if (player.role.id == 'tho_san') {
      if (player.id == myPlayer?.id) { hunterSkillTriggered = true; hunterWhoDied = player; }
      else simulateBotHunterShot(player);
    }
  }

  void executeSeerScan(OnlinePlayer target) {
    target.hasBeenScannedBySeer = true; hasUsedSeerScan = true;
    final isW = target.role.team == RoleTeam.werewolf || target.id == cursedPlayerId;
    addLog('Tiên Tri: ${target.name} là Phe ${isW ? "SÓI 🔴" : "DÂN 🟢"}');
    selectedPlayer = null; notifyListeners();
  }

  void executeBodyguardProtect(OnlinePlayer target) {
    target.isProtected = true; target.wasProtectedByBodyguard = true;
    hasUsedBodyguardProtect = true; lastProtectedPlayerId = target.id;
    addLog('Bảo Vệ: Bạn đã bảo vệ ${target.name}.');
    selectedPlayer = null; notifyListeners();
  }

  void executeWitchHeal() {
    werewolfTarget!.isProtected = true; werewolfTarget!.wasHealedByWitch = true;
    hasHealPotion = false; hasUsedHealThisNight = true;
    addLog('Phù Thủy: Bạn đã cứu ${werewolfTarget!.name}.');
    selectedPlayer = null; notifyListeners();
  }

  void executeWitchPoison(OnlinePlayer target) {
    target.isPoisoned = true; hasPoisonPotion = false; hasUsedPoisonThisNight = true;
    addLog('Phù Thủy: Bạn đã độc chết ${target.name}.');
    selectedPlayer = null; notifyListeners();
  }

  void executeWerewolfBite(OnlinePlayer target) { werewolfTarget = target; notifyListeners(); }

  void executeCupidLink() {
    lover1 = cupidSelections[0]; lover2 = cupidSelections[1];
    addLog('Cupid: Kết đôi ${lover1!.name} & ${lover2!.name}! ❤️');
    cupidSelections = []; selectedPlayer = null; notifyListeners();
  }

  void executeCurse(OnlinePlayer target) { cursedPlayerId = target.id; addLog('Sói Nguyền: Đã nguyền rủa ${target.name}.'); notifyListeners(); }

  void executeGunnerShoot(OnlinePlayer target) {
    if (xathuBullets <= 0 || !target.isAlive) return;
    xathuBullets--; 
    xathuRevealed = true;
    
    chatMessages.add(ChatMessage(
      senderName: 'Hệ thống', 
      content: 'ĐOÀNG! Tiếng súng chói tai vang lên, Xạ Thủ đã lộ diện và tiêu diệt ${target.name}!', 
      isSystem: true, 
      time: DateTime.now()
    ));
    
    killPlayer(target, 'Xạ Thủ: Đã nổ súng bắn chết ${target.name}!');
    selectedPlayer = null;
    checkGameOver(); 
    notifyListeners();
  }

  void executeHunterShot(OnlinePlayer target) {
    hunterSkillTriggered = false; killPlayer(target, 'Thợ Săn: Đã bắn chết ${target.name}!');
    checkGameOver(); notifyListeners();
  }

  String getActionInstructionText() {
    if (hunterSkillTriggered) return 'CHỌN 1 NGƯỜI VÀ BẤM [BẮN KÉO THEO]!';
    if (selectedPlayer == null) {
      if (currentPhase == GamePhase.night) {
        if (myPlayer!.role.id == 'cupid' && lover1 == null) return 'Chọn 2 người để Ghép đôi.';
        return 'Thực hiện kỹ năng của bạn...';
      }
      return currentPhase == GamePhase.day ? 'Thảo luận sôi nổi (60s).' : 'Chạm người chơi để vote.';
    }
    return 'Mục tiêu: ${selectedPlayer!.name}';
  }

  String checkGameOver() {
    if (currentState != PlayState.playing || players.isEmpty) return '';
    int w = players.where((p) => p.isAlive && (p.role.team == RoleTeam.werewolf || p.id == cursedPlayerId)).length;
    int g = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != cursedPlayerId).length;
    if (w == 0) { stopPeriodicBotChat(); _phaseTimer?.cancel(); return 'Phe Dân Làng giành chiến thắng!'; }
    if (w >= g) { stopPeriodicBotChat(); _phaseTimer?.cancel(); return 'Phe Ma Sói giành chiến thắng!'; }
    return '';
  }

  bool isMyWin(String msg) {
    if (myPlayer == null) return false;
    return (myPlayer!.role.team == RoleTeam.werewolf && msg.contains('Ma Sói')) || (myPlayer!.role.team != RoleTeam.werewolf && msg.contains('Dân Làng'));
  }

  void _simulateBotVotesGradually() {
    final bots = players.where((p) => p.isAlive && p.id != myPlayer?.id).toList();
    for (var b in bots) {
      Timer(Duration(milliseconds: 500 + Random().nextInt(12000)), () {
        if (currentPhase != GamePhase.voting || currentState != PlayState.playing) return;
        final t = players.where((p) => p.isAlive && p.id != b.id).toList();
        if (t.isNotEmpty) { t[Random().nextInt(t.length)].voteCount += (b.role.id == 'soi_dau_dan' ? 2 : 1); notifyListeners(); }
      });
    }
  }

  void simulateBotChatResponse(String msg) {
    Timer(const Duration(milliseconds: 800), () {
      final bots = players.where((p) => p.isAlive && p.id != myPlayer?.id).toList();
      if (bots.isNotEmpty) { chatMessages.add(ChatMessage(senderName: bots[Random().nextInt(bots.length)].name, content: 'Bình tĩnh nha ae.', time: DateTime.now())); notifyListeners(); }
    });
  }

  void startPeriodicBotChat() {
    botChatTimer?.cancel();
    botChatTimer = Timer.periodic(const Duration(seconds: 8), (t) => _simulateRandomBotChat());
  }

  void stopPeriodicBotChat() => botChatTimer?.cancel();

  void _simulateRandomBotChat() {
    if (currentState != PlayState.playing || currentPhase != GamePhase.day) return;
    final bots = players.where((p) => p.isAlive && p.id != myPlayer?.id).toList();
    if (bots.isEmpty) return;
    final b = bots[Random().nextInt(bots.length)];
    final s = players.where((p) => p.isAlive && p.id != b.id).toList();
    if (s.isNotEmpty) {
      final t = s[Random().nextInt(s.length)];
      final c = ['Nghi P${t.id} nha.', 'P${t.id} im quá.', 'Soi P${t.id} đi.', 'Tui dân mà!'][Random().nextInt(4)];
      chatMessages.add(ChatMessage(senderName: b.name, content: c, time: DateTime.now()));
      notifyListeners();
    }
  }

  void simulateWerewolfNightTarget() {
    final v = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != cursedPlayerId).toList();
    if (v.isNotEmpty) werewolfTarget = v[Random().nextInt(v.length)];
    notifyListeners();
  }

  void simulateBotHunterShot(OnlinePlayer h) {
    final t = players.where((p) => p.isAlive && p.id != h.id).toList();
    if (t.isNotEmpty) killPlayer(t[Random().nextInt(t.length)], 'Thợ Săn kéo theo 1 người!');
  }

  void addLog(String log) { actionLogs.add(log); notifyListeners(); }
  @override void dispose() { _phaseTimer?.cancel(); botChatTimer?.cancel(); super.dispose(); }
}
