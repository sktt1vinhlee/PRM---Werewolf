import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../models/role_definition.dart';
import '../models/online_player.dart';
import '../models/chat_message.dart';

class GameController extends ChangeNotifier {
  // ==========================================
  // STATE VARIABLES
  // ==========================================
  PlayState currentState = PlayState.lobby;
  GamePhase currentPhase = GamePhase.night;
  int playerCount = 12;
  String userName = 'Sói Đầu Đàn';
  String roomCode = '';
  bool isLobbyLoading = false;
  int dayNumber = 1;

  List<OnlinePlayer> players = [];
  OnlinePlayer? myPlayer;
  OnlinePlayer? selectedPlayer;
  List<String> actionLogs = [];
  List<ChatMessage> chatMessages = [];

  // Timer state
  int phaseTimerSeconds = 0;
  Timer? _phaseTimer;

  // Night action variables
  bool hasUsedSeerScan = false;
  bool hasUsedBodyguardProtect = false;
  int? lastProtectedPlayerId;
  bool hasHealPotion = true;
  bool hasPoisonPotion = true;
  bool hasUsedHealThisNight = false;
  bool hasUsedPoisonThisNight = false;
  OnlinePlayer? werewolfTarget;

  // Role states
  OnlinePlayer? lover1;
  OnlinePlayer? lover2;
  int? cursedPlayerId;
  int xathuBullets = 2;
  bool xathuRevealed = false;
  bool hunterSkillTriggered = false;
  OnlinePlayer? hunterWhoDied;
  List<OnlinePlayer> cupidSelections = [];

  Timer? botChatTimer;

  // ==========================================
  // ROLE DEFINITIONS
  // ==========================================
  final List<RoleDefinition> roleDefinitions = [
    RoleDefinition(id: 'dan', name: 'Dân Làng', description: 'Không có chức năng, giết hết sói thì win.', team: RoleTeam.villager, icon: Icons.person, primaryColor: const Color(0xFF2E7D32), secondaryColor: const Color(0xFF4CAF50), isUnique: false),
    RoleDefinition(id: 'soi', name: 'Ma Sói', description: 'Giết dân ban đêm. Số sói bằng số dân thì win.', team: RoleTeam.werewolf, icon: Icons.pets, primaryColor: const Color(0xFFC62828), secondaryColor: const Color(0xFFEF5350), isUnique: false),
    RoleDefinition(id: 'soi_nguyen', name: 'Sói Nguyền', description: 'Nguyền 1 dân thành sói, khi tiên tri xem thg dân thành sói.', team: RoleTeam.werewolf, icon: Icons.auto_awesome, primaryColor: const Color(0xFF8E24AA), secondaryColor: const Color(0xFFBA68C8), isUnique: true),
    RoleDefinition(id: 'soi_dau_dan', name: 'Sói Đầu Đàn', description: '1 vote = 2 vote sói thường.', team: RoleTeam.werewolf, icon: Icons.gavel, primaryColor: const Color(0xFFD84315), secondaryColor: const Color(0xFFFF7043), isUnique: true),
    RoleDefinition(id: 'xa_thu', name: 'Xạ Thủ', description: 'Có 2 viên đạn, chỉ bắn vào ban ngày, bắn lần đầu thì lộ role.', team: RoleTeam.villager, icon: Icons.gps_fixed, primaryColor: const Color(0xFF0277BD), secondaryColor: const Color(0xFF29B6F6), isUnique: true),
    RoleDefinition(id: 'tien_tri', name: 'Tiên Tri', description: 'Soi sói, phe dân.', team: RoleTeam.villager, icon: Icons.remove_red_eye, primaryColor: const Color(0xFF00838F), secondaryColor: const Color(0xFF26C6DA), isUnique: true),
    RoleDefinition(id: 'cupid', name: 'Cupid', description: 'Ghép 2 đứa với nhau. (2 đứa xem thẻ nhau, chết cả đôi), phe dân.', team: RoleTeam.villager, icon: Icons.favorite, primaryColor: const Color(0xFFAD1457), secondaryColor: const Color(0xFFEC407A), isUnique: true),
    RoleDefinition(id: 'tho_san', name: 'Thợ Săn', description: 'Chết thì đem thêm 1 đứa chết cùng, phe dân.', team: RoleTeam.villager, icon: Icons.colorize, primaryColor: const Color(0xFFEF6C00), secondaryColor: const Color(0xFFFFA726), isUnique: true),
    RoleDefinition(id: 'bao_ve', name: 'Bảo Vệ', description: 'Mỗi đêm bảo vệ 1 đứa, không được bảo vệ 1 đứa 2 đêm liên tục, phe dân.', team: RoleTeam.villager, icon: Icons.shield, primaryColor: const Color(0xFF1565C0), secondaryColor: const Color(0xFF42A5F5), isUnique: true),
    RoleDefinition(id: 'phu_thuy', name: 'Phù Thủy', description: '1 bình cứu 1 bình giết ban đêm thích dùng lúc nào cũng được, phe dân.', team: RoleTeam.villager, icon: Icons.science, primaryColor: const Color(0xFF6A1B9A), secondaryColor: const Color(0xFFAB47BC), isUnique: true),
    RoleDefinition(id: 'nerd', name: 'Kẻ Ngốc (Nerd)', description: 'Thằng ngu, bên t3 nó chết treo cổ thì nó win.', team: RoleTeam.neutral, icon: Icons.psychology, primaryColor: const Color(0xFF9E9D24), secondaryColor: const Color(0xFFD4E157), isUnique: true),
  ];

  GameController() {
    generateRoomCode();
    initializeLobbyChat();
  }

  // ==========================================
  // ROOM API
  // ==========================================
  void generateRoomCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    roomCode = 'WS-${List.generate(6, (index) => chars[random.nextInt(chars.length)]).join()}';
    notifyListeners();
  }

  void startLobbyTransition() {
    isLobbyLoading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1000), () {
      initializeOnlineGame();
    });
  }

  void resetGame() {
    stopPeriodicBotChat();
    _phaseTimer?.cancel();
    currentState = PlayState.lobby;
    selectedPlayer = null;
    generateRoomCode();
    players = [];
    myPlayer = null;
    actionLogs = [];
    isLobbyLoading = false;
    lover1 = null;
    lover2 = null;
    cursedPlayerId = null;
    xathuBullets = 2;
    xathuRevealed = false;
    hunterSkillTriggered = false;
    hunterWhoDied = null;
    cupidSelections = [];
    initializeLobbyChat();
    notifyListeners();
  }

  // ==========================================
  // PLAYER API
  // ==========================================
  void updateUserName(String name) {
    userName = name;
    notifyListeners();
  }

  void updatePlayerCount(int count) {
    playerCount = count;
    notifyListeners();
  }

  void selectPlayer(OnlinePlayer? player) {
    selectedPlayer = player;
    notifyListeners();
  }

  // Logic Moved from PlayScreen UI
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
    if (xathuRevealed && player.role.id == 'xa_thu') return player.role.primaryColor;
    return Colors.white24;
  }

  String getPlayerRoleNameDisplay(OnlinePlayer player) {
    if (!shouldRevealRole(player)) return 'ẨN VAI TRÒ';
    if (player.id == cursedPlayerId && player.isAlive) return 'Ma Sói (Nguyền)';
    return player.role.name;
  }

  bool shouldShowLoverHeart(OnlinePlayer player) {
    if (!player.isAlive) return false;
    if (lover1 == null || lover2 == null) return false;
    final isUserCupid = myPlayer?.role.id == 'cupid';
    final isUserLover = myPlayer?.id == lover1!.id || myPlayer?.id == lover2!.id;
    if ((isUserCupid || isUserLover) && (player.id == lover1!.id || player.id == lover2!.id)) {
      return true;
    }
    return false;
  }

  // ==========================================
  // CHAT API
  // ==========================================
  void initializeLobbyChat() {
    chatMessages = [
      ChatMessage(senderName: 'Hệ thống', content: 'Tạo phòng thành công. Đang chờ người chơi khác kết nối...', isSystem: true, time: DateTime.now()),
      ChatMessage(senderName: 'Tuấn Tú', content: 'Chào cả phòng nha, có ai ở đây chưa?', time: DateTime.now().subtract(const Duration(seconds: 15))),
      ChatMessage(senderName: 'Khánh Linh', content: 'Hello, chúc mọi người game mới vui vẻ nhé!', time: DateTime.now().subtract(const Duration(seconds: 10))),
    ];
    actionLogs = [
      'Hệ thống: Bạn đã kết nối và tham gia phòng $roomCode.',
      'Hệ thống: Tuấn Tú đã tham gia phòng.',
      'Hệ thống: Khánh Linh đã tham gia phòng.',
    ];
    notifyListeners();
  }

  void sendUserMessage(String text) {
    if (text.trim().isEmpty) return;
    final isNight = currentState == PlayState.playing && currentPhase == GamePhase.night;
    final isWolfChannel = isNight && myPlayer?.role.team == RoleTeam.werewolf;
    chatMessages.add(ChatMessage(
      senderName: '$userName (Bạn)',
      content: text,
      isWerewolfOnly: isWolfChannel,
      isGhost: currentState == PlayState.playing && myPlayer != null && !myPlayer!.isAlive,
      time: DateTime.now(),
    ));
    simulateBotChatResponse(text);
    notifyListeners();
  }

  bool isChatDisabled() {
    if (currentState != PlayState.playing) return false;
    if (currentPhase == GamePhase.night) {
      return myPlayer?.role.team != RoleTeam.werewolf;
    }
    return false;
  }

  String getChatHintText() {
    if (currentState != PlayState.playing) return 'Nhập tin nhắn...';
    if (currentPhase == GamePhase.night) {
      if (myPlayer?.role.team != RoleTeam.werewolf) return 'Ban đêm không thể nói chuyện.';
      return 'Chat Bầy Sói...';
    }
    if (myPlayer != null && !myPlayer!.isAlive) return 'Kênh Hồn Ma...';
    return 'Nhập tin nhắn...';
  }

  // ==========================================
  // VOTE & PHASE API
  // ==========================================
  void startPhaseTimer(int seconds) {
    _phaseTimer?.cancel();
    phaseTimerSeconds = seconds;
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (phaseTimerSeconds > 0) {
        phaseTimerSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        if (currentPhase == GamePhase.night) {
          transitionToDay();
        } else if (currentPhase == GamePhase.day) {
          transitionToVoting();
        } else {
          transitionToNight();
        }
      }
    });
  }

  void transitionToDay() {
    if (hunterSkillTriggered) return;
    stopPeriodicBotChat();
    if (werewolfTarget != null && !werewolfTarget!.isProtected) {
      killPlayer(werewolfTarget!, 'Hệ thống: Đêm qua, ${werewolfTarget!.name} đã bị Ma Sói cắn chết! 🩸');
    }
    for (var p in players) {
      if (p.isPoisoned && p.isAlive) killPlayer(p, 'Hệ thống: Đêm qua, Phù Thủy đã độc chết ${p.name}! 🧪');
    }
    addLog('Hệ thống: Bình minh đã lên! Bắt đầu thảo luận (60s).');
    if (dayNumber == 1 && lover1 != null && lover2 != null) {
      if (myPlayer?.id == lover1!.id) addLog('Hệ thống: Bạn đã bị Cupid ghép đôi with ${lover2!.name}! ❤️');
      else if (myPlayer?.id == lover2!.id) addLog('Hệ thống: Bạn đã bị Cupid ghép đôi with ${lover1!.name}! ❤️');
    }
    for (var p in players) {
      p.isProtected = false;
      p.isPoisoned = false;
      p.voteCount = 0;
      p.isTargeted = false;
    }
    hasUsedSeerScan = false;
    hasUsedBodyguardProtect = false;
    hasUsedHealThisNight = false;
    hasUsedPoisonThisNight = false;
    selectedPlayer = null;
    currentPhase = GamePhase.day;
    checkGameOver();
    if (currentState == PlayState.playing) {
      startPeriodicBotChat();
      startPhaseTimer(60);
    }
    notifyListeners();
  }

  void transitionToVoting() {
    if (hunterSkillTriggered) return;
    stopPeriodicBotChat();
    addLog('Hệ thống: Hết thời gian thảo luận. Bắt đầu bỏ phiếu (15s)!');
    currentPhase = GamePhase.voting;
    selectedPlayer = null;

    // Reset all votes before starting new voting session
    for (var p in players) {
      p.voteCount = 0;
      p.isTargeted = false;
    }

    _simulateBotVotesGradually();
    startPhaseTimer(15);
    notifyListeners();
  }

  void _simulateBotVotesGradually() {
    final random = Random();
    final alivePlayers = players.where((p) => p.isAlive).toList();
    final bots = alivePlayers.where((p) => p.id != myPlayer?.id).toList();

    for (var bot in bots) {
      // Bots will vote at random times during the 15s window
      Timer(Duration(milliseconds: 500 + random.nextInt(12000)), () {
        if (currentPhase != GamePhase.voting || currentState != PlayState.playing) return;

        final targets = alivePlayers.where((p) => p.id != bot.id).toList();
        if (targets.isNotEmpty) {
          final target = targets[random.nextInt(targets.length)];
          final weight = bot.role.id == 'soi_dau_dan' ? 2 : 1;
          target.voteCount += weight;
          notifyListeners();
        }
      });
    }
  }

  void transitionToNight() {
    if (hunterSkillTriggered) return;
    stopPeriodicBotChat();

    List<OnlinePlayer> alivePlayers = players.where((p) => p.isAlive).toList();

    OnlinePlayer? hangedPlayer;
    int maxVotes = 0;
    for (var p in alivePlayers) {
      if (p.voteCount > maxVotes) {
        maxVotes = p.voteCount;
        hangedPlayer = p;
      } else if (p.voteCount == maxVotes && maxVotes > 0) {
        // Simple tie-breaker: 50% chance to switch or keep
        if (Random().nextBool()) hangedPlayer = p;
      }
    }

    if (hangedPlayer != null && maxVotes > 0) {
      final isWolf = hangedPlayer.role.team == RoleTeam.werewolf || hangedPlayer.id == cursedPlayerId;
      killPlayer(hangedPlayer, 'Hệ thống: ${hangedPlayer.name} bị treo cổ với $maxVotes phiếu! Vai trò thực tế: ${hangedPlayer.role.name} (${isWolf ? "Phe Sói" : "Phe Dân"}) ⚖️');
    } else {
      addLog('Hệ thống: Hòa phiếu hoặc không ai bị vote. Không ai bị treo cổ hôm nay.');
    }

    for (var p in players) {
      p.voteCount = 0;
      p.isTargeted = false;
    }
    selectedPlayer = null;
    dayNumber++;
    currentPhase = GamePhase.night;
    addLog('Hệ thống: ĐÊM $dayNumber bắt đầu. Mọi người nhắm mắt ngủ...');
    checkGameOver();
    if (currentState == PlayState.playing) {
      simulateWerewolfNightTarget();
      startPhaseTimer(15);
    }
    notifyListeners();
  }

  void executeVote(OnlinePlayer target) {
    final voteWeight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    for (var p in players) {
      if (p.isTargeted) {
        p.voteCount -= voteWeight;
        p.isTargeted = false;
      }
    }
    target.voteCount += voteWeight;
    target.isTargeted = true;
    addLog('Thảo Luận: Bạn bỏ phiếu vote ${target.name} ($voteWeight phiếu).');
    selectedPlayer = null;
    notifyListeners();
  }

  // ==========================================
  // ROLE & SKILL API
  // ==========================================
  void initializeOnlineGame() {
    final random = Random();
    List<RoleDefinition> allocatedRoles = [];
    lover1 = null; lover2 = null; cursedPlayerId = null; xathuBullets = 2; xathuRevealed = false;
    hunterSkillTriggered = false; hunterWhoDied = null; cupidSelections = [];

    int targetWolves = max(1, (playerCount / 4).round());
    List<RoleDefinition> wolfPool = [];
    if (random.nextBool() && targetWolves >= 2) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_dau_dan'));
    if (random.nextBool() && targetWolves >= 2) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_nguyen'));
    while (wolfPool.length < targetWolves) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi'));
    allocatedRoles.addAll(wolfPool);

    List<RoleDefinition> specialPool = roleDefinitions.where((r) => r.isUnique && r.team != RoleTeam.werewolf).toList();
    specialPool.shuffle(random);
    int remainingSlots = playerCount - targetWolves;
    int targetSpecials = min(specialPool.length, remainingSlots);
    allocatedRoles.addAll(specialPool.take(targetSpecials));

    RoleDefinition villagerDef = roleDefinitions.firstWhere((r) => r.id == 'dan');
    while (allocatedRoles.length < playerCount) allocatedRoles.add(villagerDef);
    allocatedRoles.shuffle(random);

    final names = ['Minh Đức', 'Khánh Linh', 'Sơn Hải', 'Tuấn Tú', 'Hoài Thu', 'Gia Bảo', 'Quỳnh Anh', 'Nhật Minh', 'Phương Thảo', 'Hồng Quân', 'Thanh Lâm', 'Mai Chi', 'Trí Dũng', 'Ngọc Diệp', 'Thu Trang', 'Thế Anh', 'Yến Vy', 'Văn Nam'];
    names.shuffle(random);
    int myIndex = random.nextInt(playerCount);

    List<OnlinePlayer> list = [];
    for (int i = 0; i < playerCount; i++) {
      list.add(OnlinePlayer(
        id: i + 1,
        name: i == myIndex ? '$userName (Bạn)' : names[i % names.length],
        role: allocatedRoles[i],
        isHost: i == 0,
      ));
    }

    players = list;
    myPlayer = list[myIndex];
    selectedPlayer = null; dayNumber = 1; currentPhase = GamePhase.night;
    hasHealPotion = true; hasPoisonPotion = true; hasUsedSeerScan = false; hasUsedBodyguardProtect = false; lastProtectedPlayerId = null;

    actionLogs = ['Hệ thống: Phòng đấu $roomCode đã được khởi tạo!', 'Hệ thống: Bạn đã kết nối.', 'Hệ thống: Trò chơi BẮT ĐẦU!', 'Hệ thống: ĐÊM 1 bắt đầu.'];
    chatMessages = [ChatMessage(senderName: 'Hệ thống', content: 'Trận đấu bắt đầu!', isSystem: true, time: DateTime.now())];
    if (myPlayer!.role.team == RoleTeam.werewolf) chatMessages.add(ChatMessage(senderName: 'Hệ thống', content: 'Kênh chat Bầy Sói đã mở.', isSystem: true, isWerewolfOnly: true, time: DateTime.now()));

    currentState = PlayState.playing;
    isLobbyLoading = false;
    simulateWerewolfNightTarget();
    startPhaseTimer(15);
    notifyListeners();
  }

  void killPlayer(OnlinePlayer player, String reason) {
    if (!player.isAlive) return;
    player.isAlive = false;
    addLog(reason);
    if (lover1 != null && lover2 != null) {
      if (player.id == lover1!.id && lover2!.isAlive) killPlayer(lover2!, 'Hệ thống: ${lover1!.name} đã hy sinh. ${lover2!.name} tự sát! 💔');
      else if (player.id == lover2!.id && lover1!.isAlive) killPlayer(lover1!, 'Hệ thống: ${lover2!.name} đã hy sinh. ${lover1!.name} tự sát! 💔');
    }
    if (player.role.id == 'tho_san') {
      if (player.id == myPlayer?.id) {
        hunterSkillTriggered = true;
        hunterWhoDied = player;
      } else simulateBotHunterShot(player);
    }
    notifyListeners();
  }

  // Skill Methods
  void executeSeerScan(OnlinePlayer target) {
    if (hasUsedSeerScan) return;
    target.hasBeenScannedBySeer = true;
    hasUsedSeerScan = true;
    final isWolf = target.role.team == RoleTeam.werewolf || target.id == cursedPlayerId;
    addLog('Tiên Tri: Bạn đã soi ${target.name}. Kết quả: Phe ${isWolf ? "MA SÓI 🔴" : "DÂN LÀNG 🟢"}');
    selectedPlayer = null;
    notifyListeners();
  }

  void executeBodyguardProtect(OnlinePlayer target) {
    if (hasUsedBodyguardProtect || target.id == lastProtectedPlayerId) return;
    target.isProtected = true;
    hasUsedBodyguardProtect = true;
    lastProtectedPlayerId = target.id;
    addLog('Bảo Vệ: Bạn đã bảo vệ ${target.name} đêm nay.');
    selectedPlayer = null;
    notifyListeners();
  }

  void executeWitchHeal() {
    if (!hasHealPotion || werewolfTarget == null || hasUsedHealThisNight) return;
    werewolfTarget!.isProtected = true;
    hasHealPotion = false;
    hasUsedHealThisNight = true;
    addLog('Phù Thủy: Bạn đã cứu ${werewolfTarget!.name}.');
    selectedPlayer = null;
    notifyListeners();
  }

  void executeWitchPoison(OnlinePlayer target) {
    if (!hasPoisonPotion || !target.isAlive || hasUsedPoisonThisNight) return;
    target.isPoisoned = true;
    hasPoisonPotion = false;
    hasUsedPoisonThisNight = true;
    addLog('Phù Thủy: Bạn đã dùng độc lên ${target.name}.');
    selectedPlayer = null;
    notifyListeners();
  }

  void executeWerewolfBite(OnlinePlayer target) {
    werewolfTarget = target;
    addLog('Ma Sói: Bạn quyết định cắn ${target.name}.');
    selectedPlayer = null;
    notifyListeners();
  }

  void executeCupidLink() {
    if (cupidSelections.length != 2) return;
    lover1 = cupidSelections[0];
    lover2 = cupidSelections[1];
    addLog('Cupid: Kết đôi ${lover1!.name} và ${lover2!.name}! ❤️');
    selectedPlayer = null;
    cupidSelections = [];
    notifyListeners();
  }

  void executeCurse(OnlinePlayer target) {
    if (cursedPlayerId != null) return;
    cursedPlayerId = target.id;
    addLog('Sói Nguyền: Bạn đã nguyền rủa ${target.name}.');
    selectedPlayer = null;
    notifyListeners();
  }

  void executeGunnerShoot(OnlinePlayer target) {
    if (xathuBullets <= 0) return;
    xathuBullets--;
    xathuRevealed = true;
    selectedPlayer = null;
    killPlayer(target, 'Xạ Thủ: Đã bắn chết ${target.name}!');
    checkGameOver();
    notifyListeners();
  }

  void executeHunterShot(OnlinePlayer target) {
    if (!hunterSkillTriggered || hunterWhoDied == null) return;
    hunterSkillTriggered = false;
    final hunterName = hunterWhoDied!.name;
    hunterWhoDied = null;
    selectedPlayer = null;
    killPlayer(target, 'Thợ Săn ($hunterName) đã bắn chết ${target.name}!');
    checkGameOver();
    notifyListeners();
  }

  // ==========================================
  // UI LOGIC API (Moved from PlayScreen)
  // ==========================================
  String getActionInstructionText() {
    if (hunterSkillTriggered) return 'BẠN ĐÃ CHẾT! Hãy chọn 1 người chơi và bấm [BẮN KÉO THEO]!';
    if (selectedPlayer == null) {
      if (currentPhase == GamePhase.night) {
        if (myPlayer!.role.id == 'cupid' && lover1 == null) return 'Hãy chọn lần lượt 2 người và bấm Ghép đôi.';
        if (myPlayer!.role.id == 'tien_tri' && !hasUsedSeerScan) return 'Hãy chọn 1 người để soi bài.';
        if (myPlayer!.role.id == 'bao_ve' && !hasUsedBodyguardProtect) return 'Hãy chọn 1 người để đặt khiên bảo vệ.';
        if (myPlayer!.role.id == 'phu_thuy') {
          if (hasHealPotion && werewolfTarget != null) return '${werewolfTarget!.name} bị cắn. Cứu họ?';
          return 'Hãy chọn mục tiêu để dùng bình thuốc.';
        }
        if (myPlayer!.role.id == 'soi_nguyen' && cursedPlayerId == null) return 'Có thể chọn 1 người để Nguyền rủa.';
        if (myPlayer!.role.team == RoleTeam.werewolf) return 'Hãy chọn một nạn nhân để cắn càn đêm nay.';
        return 'Nhắm mắt đi ngủ. Chờ chuyển phase...';
      } else if (currentPhase == GamePhase.day) {
        return 'Hãy thảo luận sôi nổi với mọi người (60s).';
      } else {
        String instr = 'Thời gian bỏ phiếu! Hãy chọn 1 người để vote treo cổ.';
        if (myPlayer!.role.id == 'xa_thu' && xathuBullets > 0) instr += ' Bạn có thể bắn (Đạn: $xathuBullets/2).';
        return instr;
      }
    } else {
      if (myPlayer!.role.id == 'cupid' && lover1 == null) return 'Đang chọn: ${cupidSelections.map((p) => p.name).join(", ")}';
      return 'Mục tiêu đang chọn: ${selectedPlayer!.name}';
    }
  }

  String checkGameOver() {
    if (currentState != PlayState.playing || players.isEmpty) return '';
    int aliveWolves = players.where((p) => p.isAlive && (p.role.team == RoleTeam.werewolf || p.id == cursedPlayerId)).length;
    int aliveGood = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != cursedPlayerId).length;
    if (aliveWolves == 0) {
      _phaseTimer?.cancel();
      stopPeriodicBotChat();
      return 'Phe Dân Làng giành chiến thắng!';
    } else if (aliveWolves >= aliveGood) {
      _phaseTimer?.cancel();
      stopPeriodicBotChat();
      return 'Phe Ma Sói giành chiến thắng!';
    }
    return '';
  }

  bool isMyWin(String gameOverMsg) {
    if (myPlayer == null) return false;
    if (myPlayer!.role.team == RoleTeam.werewolf && gameOverMsg.contains('Ma Sói')) return true;
    if (myPlayer!.role.team != RoleTeam.werewolf && gameOverMsg.contains('Dân Làng')) return true;
    return false;
  }

  // ==========================================
  // BOT SIMULATION
  // ==========================================
  void simulateWerewolfNightTarget() {
    final random = Random();
    List<OnlinePlayer> victims = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != cursedPlayerId).toList();
    if (victims.isNotEmpty) werewolfTarget = victims[random.nextInt(victims.length)];
    notifyListeners();
  }

  void simulateBotChatResponse(String userMessage) {
    final random = Random();
    final isNight = currentState == PlayState.playing && currentPhase == GamePhase.night;

    // Lấy danh sách bot có thể chat
    List<OnlinePlayer> aliveBots = [];
    if (currentState == PlayState.playing) {
      aliveBots = players.where((p) => p.isAlive && p.id != myPlayer?.id).toList();
      if (isNight) {
        // Đêm thì chỉ Sói mới chat với nhau
        if (myPlayer?.role.team == RoleTeam.werewolf) {
          aliveBots = aliveBots.where((p) => p.role.team == RoleTeam.werewolf).toList();
        } else {
          return; // Dân không chat đêm
        }
      }
    }

    // Nếu không có player nào (đang ở Lobby lúc chưa init), dùng tên ảo
    final String botName = aliveBots.isNotEmpty
        ? aliveBots[random.nextInt(aliveBots.length)].name
        : ['Tuấn Tú', 'Khánh Linh', 'Nhật Minh', 'Phương Thảo'][random.nextInt(4)];

    String replyContent = '';
    final lowerMsg = userMessage.toLowerCase();

    if (currentState == PlayState.lobby) {
      if (lowerMsg.contains('chào') || lowerMsg.contains('hi') || lowerMsg.contains('hello')) {
        replyContent = ['Chào bạn!', 'Hi nha!', 'Hello, chúc mọi người game vui vẻ.'][random.nextInt(3)];
      } else if (lowerMsg.contains('sẵn sàng') || lowerMsg.contains('go')) {
        replyContent = ['Tui sẵn sàng rồi.', 'Vào thôi ae.', 'Ok luôn!'][random.nextInt(3)];
      } else {
        replyContent = ['Game này đông vui ghê.', 'Mong không làm dân làng.', 'Hóng quá!'][random.nextInt(3)];
      }
    } else {
      // Logic khi đang chơi
      if (isNight) {
        if (lowerMsg.contains('cắn') || RegExp(r'\d+').hasMatch(lowerMsg)) {
          final target = _extractPlayerMention(lowerMsg);
          replyContent = ['Nhất trí, cắn $target đi.', 'Ok, cắn $target.', 'Đồng ý luôn.'][random.nextInt(3)];
        } else {
          replyContent = ['Tập trung cắn dân nha ae.', 'Bình tĩnh bàn bạc.', 'Đừng cắn nhầm sói mình.'][random.nextInt(3)];
        }
      } else {
        if (lowerMsg.contains('soi') || lowerMsg.contains('tiên tri')) {
          replyContent = ['Tiên tri có thông tin gì chưa?', 'Soi được ai chưa?', 'Ai là tiên tri vậy?'][random.nextInt(3)];
        } else if (lowerMsg.contains('vote') || lowerMsg.contains('treo') || RegExp(r'\d+').hasMatch(lowerMsg)) {
          final target = _extractPlayerMention(lowerMsg);
          replyContent = ['Tôi cũng nghi $target.', 'Treo $target thử xem sao.', 'Ủa $target tự bào chữa đi!'][random.nextInt(3)];
        } else {
          replyContent = ['Mọi người thấy ai nghi vấn không?', 'Tôi là dân nhé.', 'Đừng vote bừa nha ae.'][random.nextInt(3)];
        }
      }
    }

    Timer(Duration(milliseconds: 600 + random.nextInt(600)), () {
      chatMessages.add(ChatMessage(
        senderName: botName,
        content: replyContent,
        isWerewolfOnly: isNight && myPlayer?.role.team == RoleTeam.werewolf,
        isGhost: currentState == PlayState.playing && myPlayer != null && !myPlayer!.isAlive,
        time: DateTime.now(),
      ));
      notifyListeners();
    });
  }

  String _extractPlayerMention(String msg) {
    final match = RegExp(r'\d+').firstMatch(msg);
    if (match != null) return 'P${match.group(0)}';
    return 'người đó';
  }

  void startPeriodicBotChat() {
    botChatTimer?.cancel();
    botChatTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (currentState == PlayState.playing && currentPhase == GamePhase.day) {
        _simulateRandomBotChat();
      }
    });
  }

  void stopPeriodicBotChat() {
    botChatTimer?.cancel();
  }

  void _simulateRandomBotChat() {
    final random = Random();
    final aliveBots = players.where((p) => p.isAlive && p.id != myPlayer?.id).toList();
    if (aliveBots.isEmpty) return;

    final bot = aliveBots[random.nextInt(aliveBots.length)];
    final suspects = players.where((p) => p.isAlive && p.id != bot.id).toList();

    String content = '';
    if (suspects.isNotEmpty) {
      final target = suspects[random.nextInt(suspects.length)];
      final templates = [
        'Tui thấy nghi nghi P${target.id} nha.',
        'P${target.id} nãy giờ im hơi lặng tiếng quá.',
        'Mọi người nghĩ sao về P${target.id}?',
        'Tiên tri soi P${target.id} chưa?',
        'P${target.id} có phải dân không vậy?',
        'Tui là dân nha ae, tin tui đi.',
        'Đừng vote bừa, mất dân là thua đó.',
        'Ai có thông tin gì thì nói đi chứ.',
      ];
      content = templates[random.nextInt(templates.length)];
    }

    chatMessages.add(ChatMessage(
      senderName: bot.name,
      content: content,
      time: DateTime.now(),
    ));
    notifyListeners();
  }

  void simulateBotHunterShot(OnlinePlayer hunter) {
    final random = Random();
    List<OnlinePlayer> suspects = players.where((p) => p.isAlive && p.id != hunter.id).toList();
    if (suspects.isNotEmpty) {
      final victim = suspects[random.nextInt(suspects.length)];
      killPlayer(victim, 'Thợ Săn: ${hunter.name} trước khi tử nạn đã kịp nổ súng kéo theo ${victim.name}! 🎯');
    }
  }

  void addLog(String log) {
    actionLogs.add(log);
    notifyListeners();
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    botChatTimer?.cancel();
    super.dispose();
  }
}