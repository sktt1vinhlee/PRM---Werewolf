import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import '../models/role_definition.dart';
import '../models/online_player.dart';
import '../models/chat_message.dart';
import 'language_service.dart';
import 'firestore_service.dart';

class GameController extends ChangeNotifier with WidgetsBindingObserver {
  PlayState currentState = PlayState.setup;
  GamePhase currentPhase = GamePhase.night;
  int playerCount = 15;
  String userName = '';
  bool _isNameLoaded = false;
  String roomCode = '';
  bool isLobbyLoading = false;
  int dayNumber = 1;
  int phaseNumber = 0;

  List<OnlinePlayer> players = [];
  List<String> lobbyPlayerNames = [];
  OnlinePlayer? myPlayer;
  OnlinePlayer? selectedPlayer;
  List<String> actionLogs = [];
  List<ChatMessage> chatMessages = [];
  
  int phaseTimerSeconds = 0;
  Timer? _phaseTimer;
  Timer? botChatTimer;
  StreamSubscription? _roomSubscription;
  Timestamp? _lastSyncedEndTime;

  bool hasUsedSeerScan = false;
  bool hasUsedBodyguardProtect = false;
  int? lastProtectedPlayerId;
  bool hasHealPotion = true;
  bool hasPoisonPotion = true;
  bool hasUsedHealThisNight = false;
  bool hasUsedPoisonThisNight = false;
  OnlinePlayer? werewolfTarget;
  int? witchReviveTargetId;

  OnlinePlayer? lover1;
  OnlinePlayer? lover2;
  int? cursedPlayerId;
  bool isNerdHanged = false;
  int xathuBullets = 2;
  bool xathuRevealed = false;
  bool hunterSkillTriggered = false;
  OnlinePlayer? hunterWhoDied;
  List<OnlinePlayer> cupidSelections = [];

  final List<RoleDefinition> roleDefinitions = [
    RoleDefinition(
      id: 'dan', name: 'role_dan', description: 'role_dan_desc', team: RoleTeam.villager, icon: Icons.person, 
      primaryColor: const Color(0xFF2E7D32), secondaryColor: const Color(0xFF4CAF50), isUnique: false,
      difficulty: 1, lore: 'role_dan_lore', tips: ['tip_dan_1', 'tip_dan_2']
    ),
    RoleDefinition(
      id: 'soi', name: 'role_soi', description: 'role_soi_desc', team: RoleTeam.werewolf, icon: Icons.pets, 
      primaryColor: const Color(0xFFC62828), secondaryColor: const Color(0xFFEF5350), isUnique: false,
      difficulty: 2, lore: 'role_soi_lore', tips: ['tip_soi_1', 'tip_soi_2']
    ),
    RoleDefinition(
      id: 'soi_nguyen', name: 'role_soi_nguyen', description: 'role_soi_nguyen_desc', team: RoleTeam.werewolf, icon: Icons.auto_awesome, 
      primaryColor: const Color(0xFF8E24AA), secondaryColor: const Color(0xFFBA68C8), isUnique: true,
      difficulty: 4, lore: 'role_soi_nguyen_lore', tips: ['tip_soi_nguyen_1']
    ),
    RoleDefinition(
      id: 'soi_dau_dan', name: 'role_soi_dau_dan', description: 'role_soi_dau_dan_desc', team: RoleTeam.werewolf, icon: Icons.gavel, 
      primaryColor: const Color(0xFFD84315), secondaryColor: const Color(0xFFFF7043), isUnique: true,
      difficulty: 3, lore: 'role_soi_dau_dan_lore', tips: ['tip_soi_dau_dan_1']
    ),
    RoleDefinition(
      id: 'xa_thu', name: 'role_xa_thu', description: 'role_xa_thu_desc', team: RoleTeam.villager, icon: Icons.gps_fixed, 
      primaryColor: const Color(0xFF0277BD), secondaryColor: const Color(0xFF29B6F6), isUnique: true,
      difficulty: 3, lore: 'role_xa_thu_lore', tips: ['tip_xa_thu_1']
    ),
    RoleDefinition(
      id: 'tien_tri', name: 'role_tien_tri', description: 'role_tien_tri_desc', team: RoleTeam.villager, icon: Icons.remove_red_eye, 
      primaryColor: const Color(0xFF00838F), secondaryColor: const Color(0xFF26C6DA), isUnique: true,
      difficulty: 3, lore: 'role_tien_tri_lore', tips: ['tip_tien_tri_1', 'tip_tien_tri_2']
    ),
    RoleDefinition(
      id: 'cupid', name: 'role_cupid', description: 'role_cupid_desc', team: RoleTeam.neutral, icon: Icons.favorite,
      primaryColor: const Color(0xFFAD1457), secondaryColor: const Color(0xFFEC407A), isUnique: true,
      difficulty: 4, lore: 'role_cupid_lore', tips: ['tip_cupid_1']
    ),
    RoleDefinition(
      id: 'tho_san', name: 'role_tho_san', description: 'role_tho_san_desc', team: RoleTeam.villager, icon: Icons.colorize, 
      primaryColor: const Color(0xFFEF6C00), secondaryColor: const Color(0xFFFFA726), isUnique: true,
      difficulty: 2, lore: 'role_tho_san_lore', tips: ['tip_tho_san_1']
    ),
    RoleDefinition(
      id: 'bao_ve', name: 'role_bao_ve', description: 'role_bao_ve_desc', team: RoleTeam.villager, icon: Icons.shield, 
      primaryColor: const Color(0xFF1565C0), secondaryColor: const Color(0xFF42A5F5), isUnique: true,
      difficulty: 4, lore: 'role_bao_ve_lore', tips: ['tip_bao_ve_1', 'tip_bao_ve_2']
    ),
    RoleDefinition(
      id: 'phu_thuy', name: 'role_phu_thuy', description: 'role_phu_thuy_desc', team: RoleTeam.villager, icon: Icons.science, 
      primaryColor: const Color(0xFF6A1B9A), secondaryColor: const Color(0xFFAB47BC), isUnique: true,
      difficulty: 5, lore: 'role_phu_thuy_lore', tips: ['tip_phu_thuy_1', 'tip_phu_thuy_2']
    ),
    RoleDefinition(
      id: 'nerd', name: 'role_nerd', description: 'role_nerd_desc', team: RoleTeam.neutral, icon: Icons.psychology, 
      primaryColor: const Color(0xFF9E9D24), secondaryColor: const Color(0xFFD4E157), isUnique: true,
      difficulty: 4, lore: 'role_nerd_lore', tips: ['tip_nerd_1']
    ),
  ];

  GameController({String? initialRoomCode, String? initialUserName}) {
    WidgetsBinding.instance.addObserver(this);
    _loadSavedName(initialUserName);
    if (initialRoomCode != null) {
      roomCode = initialRoomCode;
      currentState = PlayState.lobby;
      listenToRoom(roomCode);
    } else {
      generateRoomCode();
      currentState = PlayState.setup;
      lobbyPlayerNames = [userName];
    }
    initializeLobbyChat();
  }

  Future<void> _loadSavedName(String? initialUserName) async {
    if (initialUserName != null && initialUserName.isNotEmpty) {
      userName = initialUserName;
      _isNameLoaded = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('player_name');
    userName = savedName ?? 'Người chơi ${Random().nextInt(9999)}';
    _isNameLoaded = true;
    
    if (currentState == PlayState.setup) {
      lobbyPlayerNames = [userName];
      notifyListeners();
    }
  }

  Future<void> _ensureNameLoaded() async {
    if (_isNameLoaded) return;
    int attempts = 0;
    while (!_isNameLoaded && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      if (roomCode.isNotEmpty) {
        firestoreSvc.leaveRoom(roomCode, userName);
      }
    }
  }

  int _lastProcessedPhaseNumber = -1;

  void listenToRoom(String code) {
    _roomSubscription?.cancel();
    _roomSubscription = firestoreSvc.getRoomStream(code).listen((snapshot) {
      if (!snapshot.exists) {
        _handleRoomDeleted();
        return;
      }
      
      final data = snapshot.data();
      if (data != null) {
        final List playersData = data['players'] ?? [];
        final List messagesData = data['messages'] ?? [];
        final int serverPhaseNumber = data['phaseNumber'] ?? 0;
        
        lobbyPlayerNames = playersData.map((p) => p['name'] as String).toList();
        playerCount = data['playerCount'] ?? playerCount;
        dayNumber = data['dayNumber'] ?? dayNumber;
        phaseNumber = serverPhaseNumber;
        cursedPlayerId = data['cursedPlayerId'];

        // ĐỒNG BỘ THỜI GIAN: Chỉ reset timer nếu thời gian kết thúc trên server thay đổi
        if (data['phaseEndTime'] != null) {
          final Timestamp serverEndTime = data['phaseEndTime'];
          if (_lastSyncedEndTime == null || serverEndTime != _lastSyncedEndTime) {
            _lastSyncedEndTime = serverEndTime;
            final remaining = serverEndTime.toDate().difference(DateTime.now()).inSeconds;
            phaseTimerSeconds = remaining > 0 ? remaining : 0;
            _startLocalVisualTimer();
          }
        }

        // CẬP NHẬT TRẠNG THÁI NGƯỜI CHƠI TỪ FIREBASE
        if (playersData.isNotEmpty && currentState == PlayState.playing) {
          for (int i = 0; i < players.length; i++) {
            final pData = playersData.firstWhere((p) => p['name'] == players[i].name, orElse: () => null);
            if (pData != null) {
              players[i].isAlive = pData['isAlive'] ?? true;
              players[i].voteCount = pData['voteCount'] ?? 0;
              players[i].isHost = pData['isHost'] ?? false;
            }
          }
        }

        // CHUYỂN GIAI ĐOẠN: Chỉ xử lý nếu phaseNumber mới lớn hơn cái cũ
        if (data['currentPhase'] != null) {
          final newPhase = GamePhase.values.firstWhere((e) => e.name == data['currentPhase'], orElse: () => currentPhase);
          if (serverPhaseNumber > _lastProcessedPhaseNumber && currentState == PlayState.playing) {
            _lastProcessedPhaseNumber = serverPhaseNumber;
            _handlePhaseTransitionFromServer(newPhase);
          } else {
            currentPhase = newPhase; // Cập nhật phase hiện tại nhưng không xử lý logic transition
          }
        }

        chatMessages = messagesData.map((m) => ChatMessage(
          senderName: m['senderName'],
          content: m['content'],
          targetName: m['targetName'],
          isSystem: m['isSystem'] ?? false,
          time: (m['time'] as Timestamp).toDate(),
        )).toList();

        if (data['status'] == 'playing' && currentState == PlayState.lobby) {
          _handleGameStarted(playersData);
        }
        notifyListeners();
      }
    });
  }

  void _handleRoomDeleted() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    roomCode = '';
    currentState = PlayState.setup;
    notifyListeners();
  }

  void _handleGameStarted(List playersData) {
    players = playersData.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;
      final roleId = p['roleId'] ?? 'dan';
      final role = roleDefinitions.firstWhere((r) => r.id == roleId, orElse: () => roleDefinitions[0]);
      
      final player = OnlinePlayer(
        id: i + 1,
        name: p['name'],
        role: role,
        isHost: p['isHost'] ?? false,
      );

      if (p['name'] == userName) {
        myPlayer = player;
      }
      return player;
    }).toList();

    currentState = PlayState.roleReveal;
    notifyListeners();

    Future.delayed(const Duration(seconds: 5), () {
      if (currentState != PlayState.roleReveal) return;
      currentState = PlayState.playing;
      dayNumber = 1;
      currentPhase = GamePhase.night;
      hasHealPotion = true;
      hasPoisonPotion = true;
      werewolfTarget = null;
      xathuBullets = 2;
      xathuRevealed = false;
      addLog('${langSvc.t('system')}: ${langSvc.t('match_started')}');
      notifyListeners();
    });
  }

  void _startLocalVisualTimer() {
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (phaseTimerSeconds > 0) {
        phaseTimerSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        if (roomCode.isNotEmpty) {
          _triggerNextPhaseOnFirestore();
        } else {
          _triggerNextPhaseOffline();
        }
      }
    });
  }

  void _triggerNextPhaseOnFirestore() {
    String next;
    int duration;
    if (currentPhase == GamePhase.night) {
      next = 'day'; duration = 60;
    } else if (currentPhase == GamePhase.day) {
      next = 'voting'; duration = 15;
    } else {
      next = 'night'; duration = 15;
    }
    firestoreSvc.secureNextPhase(roomCode, phaseNumber, next, duration);
  }

  void _triggerNextPhaseOffline() {
    if (currentPhase == GamePhase.night) {
      transitionToDay();
    } else if (currentPhase == GamePhase.day) {
      transitionToVoting();
    } else {
      transitionToNight();
    }
  }

  void _handlePhaseTransitionFromServer(GamePhase newPhase) {
    final isHost = lobbyPlayerNames.isNotEmpty && lobbyPlayerNames[0] == userName;
    
    // Đảm bảo cập nhật phase locally trước bất kỳ tác vụ nào khác để tránh ghi đè dữ liệu cũ
    currentPhase = newPhase;

    if (newPhase == GamePhase.day) {
      if (roomCode.isEmpty || isHost) {
        _processNightResults();
        // Online: Không gọi syncGameState() ở đây vì server transaction đã cập nhật Firestore rồi
      } else {
        _resetLocalNightStates();
      }
    } else if (newPhase == GamePhase.voting) {
      if (roomCode.isEmpty || isHost) {
        _processDayResults();
        // Online: Không gọi syncGameState() ở đây
      } else {
        _resetLocalDayStates();
      }
    } else if (newPhase == GamePhase.night) {
      if (roomCode.isEmpty || isHost) {
        _processVotingResults();
        // Online: Không gọi syncGameState() ở đây
      } else {
        _resetLocalVotingStates();
      }
    }
    notifyListeners();
  }

  void generateRoomCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    roomCode = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> createRoom() async {
    currentState = PlayState.lobby;
    lobbyPlayerNames = [userName];
    notifyListeners();
    try {
      await firestoreSvc.createRoom(roomCode, userName, playerCount);
      listenToRoom(roomCode);
    } catch (e) {
      currentState = PlayState.setup;
      notifyListeners();
    }
  }

  Future<void> joinExistingRoom(String code, String name) async {
    try {
      await firestoreSvc.joinRoom(code, name);
      roomCode = code;
      userName = name;
      currentState = PlayState.lobby;
      listenToRoom(roomCode);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveRoom() async {
    if (roomCode.isNotEmpty) {
      final codeToLeave = roomCode;
      _roomSubscription?.cancel();
      roomCode = '';
      currentState = PlayState.setup;
      notifyListeners();
      firestoreSvc.leaveRoom(codeToLeave, userName).catchError((e) => debugPrint(e.toString()));
    }
  }

  void startQuickMatch({bool isOnline = false}) async {
    await _ensureNameLoaded();
    if (isOnline) {
      startOnlineMatchmaking();
      return;
    }
    roomCode = '';
    playerCount = 15;
    final random = Random();
    List<String> finalNames = [userName];
    final botNames = ['Minh Đức', 'Khánh Linh', 'Tuấn Tú', 'Hoài Thu', 'Gia Bảo', 'Quỳnh Anh', 'Nhật Minh', 'Phương Thảo', 'Thanh Lâm', 'Mai Chi', 'Trí Dũng', 'Ngọc Diệp', 'Quang Hải', 'Thúy Hạnh', 'Bảo Nam'];
    for (int i = 0; i < 14; i++) {
      finalNames.add('${botNames[i]} (Bot)');
    }
    
    List<RoleDefinition> roles = [];
    int targetWolves = 4; 
    roles.add(roleDefinitions.firstWhere((r) => r.id == 'soi_dau_dan'));
    roles.add(roleDefinitions.firstWhere((r) => r.id == 'soi_nguyen'));
    while (roles.length < targetWolves) {
      roles.add(roleDefinitions.firstWhere((r) => r.id == 'soi'));
    }
    
    List<RoleDefinition> specials = roleDefinitions.where((r) => r.isUnique && r.team != RoleTeam.werewolf).toList()..shuffle(random);
    roles.addAll(specials.take(min(specials.length, playerCount - roles.length)));
    while (roles.length < playerCount) {
      roles.add(roleDefinitions.firstWhere((r) => r.id == 'dan'));
    }
    roles.shuffle(random);

    players = List.generate(playerCount, (i) => OnlinePlayer(
      id: i + 1,
      name: finalNames[i],
      role: roles[i],
      isHost: finalNames[i] == userName,
    ));
    myPlayer = players.firstWhere((p) => p.name == userName);
    currentState = PlayState.roleReveal;
    notifyListeners();

    Future.delayed(const Duration(seconds: 5), () {
      if (currentState != PlayState.roleReveal) return;
      currentState = PlayState.playing;
      dayNumber = 1;
      currentPhase = GamePhase.night;
      hasHealPotion = true;
      hasPoisonPotion = true;
      werewolfTarget = null;
      xathuBullets = 2;
      xathuRevealed = false;
      addLog('${langSvc.t('system')}: ${langSvc.t('quick_match_started')}');
      simulateWerewolfNightTarget();
      startPhaseTimer(15);
      notifyListeners();
    });
  }

  Future<void> startOnlineMatchmaking() async {
    if (roomCode.isNotEmpty && currentState == PlayState.lobby) return;

    await _ensureNameLoaded();
    currentState = PlayState.matchmaking;
    notifyListeners();

    try {
      // THUẬT TOÁN GHÉP TRẬN TỐI ƯU:
      // Thử tìm phòng trong 6 vòng với tốc độ nhanh (mỗi 1.5s)
      // Điều này giúp người dùng "hội quân" vào phòng đông nhất cực nhanh.
      for (int attempt = 0; attempt < 6; attempt++) {
        // Delay ngẫu nhiên ngắn (200-500ms) ở vòng đầu để phân cấp máy khách nào sẽ là người tạo phòng
        int initialJitter = (attempt == 0) ? Random().nextInt(500) : 0;
        await Future.delayed(Duration(milliseconds: 1500 + initialJitter));

        if (currentState != PlayState.matchmaking) return;

        debugPrint('Matchmaking: Searching for best available room (Attempt ${attempt + 1})...');
        String? foundRoomCode = await firestoreSvc.findPublicRoom();

        if (foundRoomCode != null) {
          try {
            await joinExistingRoom(foundRoomCode, userName);
            debugPrint('Matchmaking SUCCESS: Joined room $foundRoomCode');
            return; 
          } catch (e) {
            debugPrint('Matchmaking: Room $foundRoomCode just became full/invalid, searching next...');
          }
        }
      }

      // Nếu sau ~10 giây không tìm thấy phòng phù hợp, mới tiến hành tạo phòng mới
      if (currentState == PlayState.matchmaking) {
        debugPrint('Matchmaking: No active rooms found, creating new lobby...');
        generateRoomCode();
        await firestoreSvc.createRoom(roomCode, userName, 15, isPublic: true);
        
        currentState = PlayState.lobby;
        listenToRoom(roomCode);
      }
    } catch (e) {
      debugPrint('Matchmaking error: $e');
      if (currentState == PlayState.matchmaking) {
        currentState = PlayState.setup;
        notifyListeners();
      }
    }
  }

  void startGame() {
    final actualPlayerCount = lobbyPlayerNames.length;
    if (actualPlayerCount < 4) {
      addLog('${langSvc.t('system')}: Cần tối thiểu 4 người!');
      return;
    }
    final random = Random();
    List<RoleDefinition> roles = [];
    int targetWolves = max(1, (actualPlayerCount / 4).round());
    if (random.nextBool() && targetWolves >= 2) roles.add(roleDefinitions.firstWhere((r) => r.id == 'soi_dau_dan'));
    if (random.nextBool() && targetWolves >= 2) roles.add(roleDefinitions.firstWhere((r) => r.id == 'soi_nguyen'));
    while (roles.length < targetWolves) {
      roles.add(roleDefinitions.firstWhere((r) => r.id == 'soi'));
    }
    
    List<RoleDefinition> specials = roleDefinitions.where((r) => r.isUnique && r.team != RoleTeam.werewolf).toList()..shuffle(random);
    roles.addAll(specials.take(min(specials.length, actualPlayerCount - roles.length)));
    while (roles.length < actualPlayerCount) {
      roles.add(roleDefinitions.firstWhere((r) => r.id == 'dan'));
    }
    roles.shuffle(random);

    List<Map<String, dynamic>> playersWithRoles = [];
    for (int i = 0; i < actualPlayerCount; i++) {
      playersWithRoles.add({'id': i + 1, 'name': lobbyPlayerNames[i], 'roleId': roles[i].id, 'isHost': i == 0, 'isReady': true, 'isAlive': true});
    }
    firestoreSvc.startGame(roomCode, playersWithRoles);
  }

  void resetGame() {
    stopPeriodicBotChat();
    _phaseTimer?.cancel();
    currentState = PlayState.lobby;
    selectedPlayer = null;
    players = [];
    isNerdHanged = false;
    myPlayer = null;
    actionLogs = [];
    generateRoomCode();
    initializeLobbyChat();
    notifyListeners();
  }

  void updatePlayerCount(int count) { 
    playerCount = count; 
    notifyListeners(); 
  }
  
  void selectPlayer(OnlinePlayer? player) {
    if (player == null) {
      selectedPlayer = null;
      notifyListeners();
      return;
    }

    // Logic đặc biệt cho Cupid: Chọn tối đa 2 người, chọn người thứ 3 sẽ đẩy người thứ 1 ra
    if (currentPhase == GamePhase.night && myPlayer?.role.id == 'cupid' && lover1 == null) {
      final exists = cupidSelections.any((p) => p.id == player.id);
      if (exists) {
        cupidSelections.removeWhere((p) => p.id == player.id);
      } else {
        if (cupidSelections.length >= 2) {
          cupidSelections.removeAt(0); // Queue: Loại bỏ người chọn đầu tiên
        }
        cupidSelections.add(player);
      }
      selectedPlayer = player;
      notifyListeners();
      return;
    }

    selectedPlayer = player;
    notifyListeners();
  }

  void syncGameState() {
    if (roomCode.isEmpty) return;
    firestoreSvc.updateRoomData(roomCode, {
      'dayNumber': dayNumber,
      'currentPhase': currentPhase.name,
      'playerStatuses': players.map((p) => p.toStatusMap()).toList(),
      'werewolfTargetId': werewolfTarget?.id,
    });
  }

  bool shouldRevealRole(OnlinePlayer player) {
    if (!player.isAlive || player.id == myPlayer?.id) return true;
    if (myPlayer?.role.team == RoleTeam.werewolf && player.role.team == RoleTeam.werewolf) return true;
    if (player.hasBeenScannedBySeer) return true;
    if (lover1 != null && lover2 != null) {
      if ((myPlayer?.id == lover1!.id && player.id == lover2!.id) || (myPlayer?.id == lover2!.id && player.id == lover1!.id)) return true;
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
    if (player.id == cursedPlayerId && player.isAlive) return 'role_soi';
    return player.role.name;
  }

  bool shouldShowLoverHeart(OnlinePlayer player) {
    if (!player.isAlive || lover1 == null || lover2 == null) return false;
    final isLover = player.id == lover1!.id || player.id == lover2!.id;
    final canSee = myPlayer?.role.id == 'cupid' || myPlayer?.id == lover1!.id || myPlayer?.id == lover2!.id;
    return isLover && canSee;
  }

  void initializeLobbyChat() {
    chatMessages = [ChatMessage(senderName: 'system', content: 'lobby_created', isSystem: true, time: DateTime.now())];
    actionLogs = ['Hệ thống: Đã vào phòng $roomCode'];
  }

  void sendUserMessage(String text, {bool forceWerewolfOnly = false}) {
    if (text.trim().isEmpty) return;
    
    // Nếu forceWerewolfOnly = true hoặc đang trong đêm và là Sói
    final isWolfChannel = forceWerewolfOnly || (currentPhase == GamePhase.night && myPlayer?.role.team == RoleTeam.werewolf);
    final isGhost = myPlayer != null ? !myPlayer!.isAlive : false;
    
    if (roomCode.isEmpty) {
      chatMessages.add(ChatMessage(senderName: userName, content: text, isWerewolfOnly: isWolfChannel, isGhost: isGhost, time: DateTime.now()));
      simulateBotChatResponse(text);
      notifyListeners();
    } else {
      firestoreSvc.sendChatMessage(roomCode, {
        'senderName': userName, 
        'content': text, 
        'isWerewolfOnly': isWolfChannel, 
        'isGhost': isGhost, 
        'isSystem': false, 
        'time': Timestamp.now()
      });
    }
  }

  bool isChatDisabled() {
    if (currentState != PlayState.playing) return false;
    if (currentPhase == GamePhase.night) return myPlayer?.role.team != RoleTeam.werewolf;
    return false;
  }

  String getChatHintText() {
    if (currentState != PlayState.playing) return langSvc.t('chat_hint');
    if (currentPhase == GamePhase.night) return myPlayer?.role.team != RoleTeam.werewolf ? langSvc.t('chat_night_disabled') : langSvc.t('chat_wolf_hint');
    if (myPlayer != null && !myPlayer!.isAlive) return langSvc.t('chat_ghost_hint');
    return langSvc.t('chat_hint');
  }

  void startPhaseTimer(int seconds) {
    _phaseTimer?.cancel();
    if (currentState == PlayState.ended) return;
    if (roomCode.isEmpty) {
      phaseTimerSeconds = seconds;
      _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (phaseTimerSeconds > 0) {
          phaseTimerSeconds--;
          notifyListeners();
        } else {
          timer.cancel();
          _triggerNextPhaseOffline();
        }
      });
    } else {
      final isHost = lobbyPlayerNames.isNotEmpty && lobbyPlayerNames[0] == userName;
      if (isHost) {
        firestoreSvc.updateRoomData(roomCode, {'phaseEndTime': Timestamp.fromDate(DateTime.now().add(Duration(seconds: seconds)))});
      }
    }
  }

  void transitionToDay() async {
    if (currentState == PlayState.ended || hunterSkillTriggered) return;
    stopPeriodicBotChat();
    _processNightResults();
    await Future.delayed(const Duration(seconds: 2));
    if (currentState == PlayState.ended) return;
    currentPhase = GamePhase.day;
    if (checkGameOver().isEmpty) {
      startPeriodicBotChat();
      startPhaseTimer(60);
    }
    notifyListeners();
  }

  void transitionToVoting() {
    if (currentState == PlayState.ended || hunterSkillTriggered) return;
    stopPeriodicBotChat();
    _processDayResults();
    currentPhase = GamePhase.voting;
    startPhaseTimer(15);
    notifyListeners();
  }

  void transitionToNight() async {
    if (currentState == PlayState.ended || hunterSkillTriggered) return;
    stopPeriodicBotChat();
    _processVotingResults();
    await Future.delayed(const Duration(seconds: 2));
    if (currentState == PlayState.ended) return;
    dayNumber++;
    currentPhase = GamePhase.night;
    if (checkGameOver().isEmpty) {
      simulateWerewolfNightTarget();
      startPhaseTimer(15);
    }
    notifyListeners();
  }

  void _processNightResults() {
    OnlinePlayer? finalVictim;
    int maxV = 0;
    for (var p in players) {
      if (p.voteCount > maxV) {
        maxV = p.voteCount;
        finalVictim = p;
      }
    }
    if (finalVictim != null && !finalVictim.isProtected) {
      killPlayer(finalVictim, langSvc.t('night_casualty').replaceFirst('%s', finalVictim.name));
    }
    for (var p in players) {
      if (p.isPoisoned && p.isAlive) {
        killPlayer(p, langSvc.t('poison_casualty').replaceFirst('%s', p.name));
      }
    }
    if (witchReviveTargetId != null) {
      players.firstWhere((p) => p.id == witchReviveTargetId).isAlive = true;
      witchReviveTargetId = null;
    }
    _resetLocalNightStates();
  }

  void _processDayResults() {
    _resetLocalDayStates();
    if (roomCode.isEmpty) _simulateBotVotesGradually();
  }

  void _processVotingResults() {
    List<OnlinePlayer> alive = players.where((p) => p.isAlive).toList();
    OnlinePlayer? hanged;
    int maxV = 0;
    for (var p in alive) {
      if (p.voteCount > maxV) {
        maxV = p.voteCount;
        hanged = p;
      }
    }
    if (hanged != null && maxV > 1) {
      if (hanged.role.id == 'nerd') {
        isNerdHanged = true;
      }
      killPlayer(hanged, '${hanged.name} ${langSvc.t('lynched')}');
    } else {
      addLog(langSvc.t('no_lynch'));
    }
    _resetLocalVotingStates();
  }

  void _resetLocalNightStates() {
    addLog(langSvc.t('sunrise'));
    for (var p in players) {
      p.isProtected = false;
      p.isPoisoned = false;
      p.voteCount = 0;
      p.isTargeted = false;
      p.wasProtectedByBodyguard = false;
      p.wasHealedByWitch = false;
    }
    hasUsedSeerScan = false;
    hasUsedBodyguardProtect = false;
    hasUsedHealThisNight = false;
    hasUsedPoisonThisNight = false;
    cursedPlayerId = null;
    selectedPlayer = null;
    werewolfTarget = null;
  }

  void _resetLocalDayStates() {
    addLog(langSvc.t('voting_start'));
    for (var p in players) {
      p.voteCount = 0;
      p.isTargeted = false;
    }
  }

  void _resetLocalVotingStates() {
    for (var p in players) {
      p.voteCount = 0;
    }
    addLog('${langSvc.t('night_number')} $dayNumber ${langSvc.t('night_start')}');
  }

  void executeVote(OnlinePlayer target) {
    final weight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    for (var p in players) {
      if (p.isTargeted) {
        p.voteCount -= weight;
        p.isTargeted = false;
      }
    }
    target.voteCount += weight;
    target.isTargeted = true;
    syncGameState();
    notifyListeners();
  }

  void killPlayer(OnlinePlayer player, String reason) {
    if (!player.isAlive) return;
    player.isAlive = false;
    addLog(reason);
    if (lover1 != null && lover2 != null) {
      if (player.id == lover1!.id && lover2!.isAlive) {
        killPlayer(lover2!, langSvc.t('lover_tragedy'));
      } else if (player.id == lover2!.id && lover1!.isAlive) {
        killPlayer(lover1!, langSvc.t('lover_tragedy'));
      }
    }
    if (player.role.id == 'tho_san') {
      if (player.id == myPlayer?.id) {
        hunterSkillTriggered = true;
        hunterWhoDied = player;
      } else {
        simulateBotHunterShot(player);
      }
    }
  }

  void executeSeerScan(OnlinePlayer target) {
    target.hasBeenScannedBySeer = true;
    hasUsedSeerScan = true;
    final isW = target.role.team == RoleTeam.werewolf || target.id == cursedPlayerId;
    addLog(langSvc.t('seer_result').replaceFirst('%s', target.name).replaceFirst('%s', isW ? langSvc.t('wolf_red') : langSvc.t('villager_green')));
    syncGameState();
    selectedPlayer = null;
    notifyListeners();
  }

  void executeBodyguardProtect(OnlinePlayer target) {
    target.isProtected = true;
    target.wasProtectedByBodyguard = true;
    hasUsedBodyguardProtect = true;
    lastProtectedPlayerId = target.id;
    addLog(langSvc.t('guard_log').replaceFirst('%s', target.name));
    syncGameState();
    selectedPlayer = null;
    notifyListeners();
  }

  void executeWitchHeal(OnlinePlayer target) {
    if (target.role.team != RoleTeam.villager) return;
    if (target.isAlive) {
      target.isProtected = true;
      target.wasHealedByWitch = true;
    } else {
      witchReviveTargetId = target.id;
      target.wasHealedByWitch = true;
    }
    hasHealPotion = false;
    hasUsedHealThisNight = true;
    syncGameState();
    selectedPlayer = null;
    notifyListeners();
  }

  void executeWitchPoison(OnlinePlayer target) {
    target.isPoisoned = true;
    hasPoisonPotion = false;
    hasUsedPoisonThisNight = true;
    syncGameState();
    selectedPlayer = null;
    notifyListeners();
  }

  void executeWerewolfBite(OnlinePlayer target) {
    executeVote(target);
    _updateWerewolfLeadingTarget();
    syncGameState();
    notifyListeners();
  }

  void cancelWerewolfBite() {
    final weight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    for (var p in players) {
      if (p.isTargeted) {
        p.voteCount -= weight;
        p.isTargeted = false;
      }
    }
    _updateWerewolfLeadingTarget();
    syncGameState();
    notifyListeners();
  }

  void _updateWerewolfLeadingTarget() {
    OnlinePlayer? leader;
    int maxV = 0;
    for (var p in players) {
      if (p.voteCount > maxV) {
        maxV = p.voteCount;
        leader = p;
      }
    }
    werewolfTarget = leader;
  }

  void executeCupidLink() {
    lover1 = cupidSelections[0];
    lover2 = cupidSelections[1];
    if (roomCode.isNotEmpty) {
      firestoreSvc.updateRoomData(roomCode, {'lover1Id': lover1!.id, 'lover2Id': lover2!.id});
    }
    syncGameState();
    selectedPlayer = null;
    notifyListeners();
  }

  void executeCurse(OnlinePlayer target) {
    cursedPlayerId = target.id;
    if (roomCode.isNotEmpty) {
      firestoreSvc.updateRoomData(roomCode, {'cursedPlayerId': cursedPlayerId});
    }
    syncGameState();
    notifyListeners();
  }

  void cancelCurse() {
    cursedPlayerId = null;
    if (roomCode.isNotEmpty) {
      firestoreSvc.updateRoomData(roomCode, {'cursedPlayerId': null});
    }
    syncGameState();
    notifyListeners();
  }
  
  void cancelBodyguardProtect() {
    for (var p in players) {
      if (p.wasProtectedByBodyguard) {
        p.isProtected = false;
        p.wasProtectedByBodyguard = false;
      }
    }
    hasUsedBodyguardProtect = false;
    lastProtectedPlayerId = null;
    notifyListeners();
  }

  void cancelWitchAction() {
    if (hasUsedHealThisNight) {
      for (var p in players) {
        p.wasHealedByWitch = false;
      }
      hasHealPotion = true;
      hasUsedHealThisNight = false;
    } else if (hasUsedPoisonThisNight) {
      for (var p in players) {
        p.isPoisoned = false;
      }
      hasPoisonPotion = true;
      hasUsedPoisonThisNight = false;
    }
    notifyListeners();
  }

  void executeGunnerShoot(OnlinePlayer target) {
    if (xathuBullets <= 0 || !target.isAlive) return;
    xathuBullets--;
    xathuRevealed = true;
    killPlayer(target, langSvc.t('gunner_log').replaceFirst('%s', target.name));
    syncGameState();
    selectedPlayer = null;
    checkGameOver();
    notifyListeners();
  }

  void executeHunterShot(OnlinePlayer target) {
    hunterSkillTriggered = false;
    killPlayer(target, langSvc.t('hunter_log').replaceFirst('%s', target.name));
    syncGameState();
    checkGameOver();
    notifyListeners();
  }

  String getActionInstructionText() {
    if (hunterSkillTriggered) return langSvc.t('instruction_hunter');
    if (selectedPlayer == null) {
      if (currentPhase == GamePhase.night) {
        return (myPlayer!.role.id == 'cupid' && lover1 == null) ? langSvc.t('instruction_cupid') : langSvc.t('instruction_skill');
      }
      return currentPhase == GamePhase.day ? langSvc.t('instruction_discuss') : langSvc.t('instruction_vote');
    }
    return '${langSvc.t('instruction_target')} ${selectedPlayer!.name}';
  }

  String checkGameOver() {
    if (currentState != PlayState.playing || players.isEmpty) return '';
    
    // 1. Kiểm tra Kẻ Ngốc (Nerd) bị treo cổ
    if (isNerdHanged) {
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return '${langSvc.t('role_nerd')} thắng!';
    }

    // 2. Kiểm tra Phe Tình Nhân chiến thắng tuyệt đối
    if (lover1 != null && lover2 != null && lover1!.isAlive && lover2!.isAlive) {
      int aliveCount = players.where((p) => p.isAlive).length;
      // Thắng khi chỉ còn 2 người tình, hoặc 2 người tình + Cupid
      if (aliveCount == 2 || (aliveCount == 3 && players.any((p) => p.isAlive && p.role.id == 'cupid'))) {
        currentState = PlayState.ended;
        _phaseTimer?.cancel();
        return 'Phe Tình Nhân đã giành chiến thắng! ❤️';
      }
    }

    int w = players.where((p) => p.isAlive && (p.role.team == RoleTeam.werewolf || p.id == cursedPlayerId)).length;
    int g = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != cursedPlayerId).length;

    // 3. Phe Dân Làng thắng
    if (w == 0) {
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return 'Dân Làng thắng!';
    }

    // 4. Phe Ma Sói thắng
    if (w >= g) {
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return 'Ma Sói thắng!';
    }

    return '';
  }

  bool isMyWin(String msg) {
    if (myPlayer == null) return false;

    // Nerd Win
    if (msg.contains('Nerd') || msg.contains('Ngốc')) {
      return myPlayer!.role.id == 'nerd';
    }

    // Lovers Faction Win
    if (msg.contains('Tình Nhân') || msg.contains('Lovers')) {
      if (myPlayer!.role.id == 'cupid') return true;
      if (lover1 != null && lover2 != null) {
        if (myPlayer!.id == lover1!.id || myPlayer!.id == lover2!.id) return true;
      }
      return false;
    }

    // Cupid's special condition for other team wins
    if (myPlayer!.role.id == 'cupid') {
      return lover1 != null && lover2 != null && lover1!.isAlive && lover2!.isAlive;
    }

    // Standard Team Wins
    bool isWolfWin = msg.contains('Sói') || msg.contains('Werewolves');
    bool isVillagerWin = msg.contains('Dân') || msg.contains('Villagers');

    if (myPlayer!.role.team == RoleTeam.werewolf) return isWolfWin;
    if (myPlayer!.role.team == RoleTeam.villager) return isVillagerWin;

    return false;
  }

  void _simulateBotVotesGradually() {
    final bots = players.where((p) => p.isAlive && p.id != myPlayer?.id).toList();
    for (var b in bots) {
      Timer(Duration(milliseconds: 500 + Random().nextInt(12000)), () {
        if (currentPhase != GamePhase.voting || currentState != PlayState.playing) return;
        final t = players.where((p) => p.isAlive && p.id != b.id).toList();
        if (t.isNotEmpty) {
          t[Random().nextInt(t.length)].voteCount += (b.role.id == 'soi_dau_dan' ? 2 : 1);
          notifyListeners();
        }
      });
    }
  }

  void simulateBotChatResponse(String msg) {
    Timer(const Duration(milliseconds: 800), () {
      final bots = players.where((p) => p.isAlive && p.id != myPlayer?.id).toList();
      if (bots.isNotEmpty) {
        chatMessages.add(ChatMessage(senderName: bots[Random().nextInt(bots.length)].name, content: langSvc.t('bot_calm_down'), time: DateTime.now()));
        notifyListeners();
      }
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
      final c = langSvc.currentLanguage == AppLanguage.vi 
        ? ['Nghi P${t.id} nha.', 'P${t.id} im quá.', 'Soi P${t.id} đi.'][Random().nextInt(3)] 
        : ['Suspecting P${t.id}.', 'P${t.id} is quiet.', 'Scan P${t.id}.'][Random().nextInt(3)];
      chatMessages.add(ChatMessage(senderName: b.name, content: c, time: DateTime.now()));
      notifyListeners();
    }
  }

  void simulateWerewolfNightTarget() {
    final bots = players.where((p) => p.isAlive && p.id != myPlayer?.id && p.role.team == RoleTeam.werewolf).toList();
    final targets = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != cursedPlayerId).toList();
    if (targets.isEmpty) return;
    for (var b in bots) {
      Timer(Duration(milliseconds: 1000 + Random().nextInt(8000)), () {
        if (currentPhase != GamePhase.night || currentState != PlayState.playing) return;
        final target = targets[Random().nextInt(targets.length)];
        target.voteCount += (b.role.id == 'soi_dau_dan' ? 2 : 1);
        _updateWerewolfLeadingTarget();
        notifyListeners();
      });
    }
  }

  void simulateBotHunterShot(OnlinePlayer h) {
    final t = players.where((p) => p.isAlive && p.id != h.id).toList();
    if (t.isNotEmpty) {
      killPlayer(t[Random().nextInt(t.length)], langSvc.t('hunter_took_down'));
    }
  }

  void addLog(String log) {
    actionLogs.add(log);
    notifyListeners();
  }

  @override 
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (roomCode.isNotEmpty) {
      leaveRoom();
    }
    _phaseTimer?.cancel();
    botChatTimer?.cancel(); 
    _roomSubscription?.cancel();
    super.dispose(); 
  }
}
