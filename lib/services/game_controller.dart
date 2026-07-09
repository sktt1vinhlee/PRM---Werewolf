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
  static final Set<String> activeRooms = {};

  PlayState currentState = PlayState.setup;
  GamePhase currentPhase = GamePhase.night;
  int playerCount = 15;
  String userName = ''; // Sẽ được load từ SharedPreferences
  bool _isNameLoaded = false;
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
  StreamSubscription? _roomSubscription;

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
      difficulty: 1, lore: 'lore_dan', tips: ['tip_dan_1', 'tip_dan_2']
    ),
    RoleDefinition(
      id: 'soi', name: 'role_soi', description: 'role_soi_desc', team: RoleTeam.werewolf, icon: Icons.pets, 
      primaryColor: const Color(0xFFC62828), secondaryColor: const Color(0xFFEF5350), isUnique: false,
      difficulty: 2, lore: 'lore_soi', tips: ['tip_soi_1', 'tip_soi_2']
    ),
    RoleDefinition(
      id: 'soi_nguyen', name: 'role_soi_nguyen', description: 'role_soi_nguyen_desc', team: RoleTeam.werewolf, icon: Icons.auto_awesome, 
      primaryColor: const Color(0xFF8E24AA), secondaryColor: const Color(0xFFBA68C8), isUnique: true,
      difficulty: 4, lore: 'lore_soi_nguyen', tips: ['tip_soi_nguyen_1']
    ),
    RoleDefinition(
      id: 'soi_dau_dan', name: 'role_soi_dau_dan', description: 'role_soi_dau_dan_desc', team: RoleTeam.werewolf, icon: Icons.gavel, 
      primaryColor: const Color(0xFFD84315), secondaryColor: const Color(0xFFFF7043), isUnique: true,
      difficulty: 3, lore: 'lore_soi_dau_dan', tips: ['tip_soi_dau_dan_1']
    ),
    RoleDefinition(
      id: 'xa_thu', name: 'role_xa_thu', description: 'role_xa_thu_desc', team: RoleTeam.villager, icon: Icons.gps_fixed, 
      primaryColor: const Color(0xFF0277BD), secondaryColor: const Color(0xFF29B6F6), isUnique: true,
      difficulty: 3, lore: 'lore_xa_thu', tips: ['tip_xa_thu_1']
    ),
    RoleDefinition(
      id: 'tien_tri', name: 'role_tien_tri', description: 'role_tien_tri_desc', team: RoleTeam.villager, icon: Icons.remove_red_eye, 
      primaryColor: const Color(0xFF00838F), secondaryColor: const Color(0xFF26C6DA), isUnique: true,
      difficulty: 3, lore: 'lore_tien_tri', tips: ['tip_tien_tri_1', 'tip_tien_tri_2']
    ),
    RoleDefinition(
      id: 'cupid', name: 'role_cupid', description: 'role_cupid_desc', team: RoleTeam.villager, icon: Icons.favorite, 
      primaryColor: const Color(0xFFAD1457), secondaryColor: const Color(0xFFEC407A), isUnique: true,
      difficulty: 4, lore: 'lore_cupid', tips: ['tip_cupid_1']
    ),
    RoleDefinition(
      id: 'tho_san', name: 'role_tho_san', description: 'role_tho_san_desc', team: RoleTeam.villager, icon: Icons.colorize, 
      primaryColor: const Color(0xFFEF6C00), secondaryColor: const Color(0xFFFFA726), isUnique: true,
      difficulty: 2, lore: 'lore_tho_san', tips: ['tip_tho_san_1']
    ),
    RoleDefinition(
      id: 'bao_ve', name: 'role_bao_ve', description: 'role_bao_ve_desc', team: RoleTeam.villager, icon: Icons.shield, 
      primaryColor: const Color(0xFF1565C0), secondaryColor: const Color(0xFF42A5F5), isUnique: true,
      difficulty: 4, lore: 'lore_bao_ve', tips: ['tip_bao_ve_1', 'tip_bao_ve_2']
    ),
    RoleDefinition(
      id: 'phu_thuy', name: 'role_phu_thuy', description: 'role_phu_thuy_desc', team: RoleTeam.villager, icon: Icons.science, 
      primaryColor: const Color(0xFF6A1B9A), secondaryColor: const Color(0xFFAB47BC), isUnique: true,
      difficulty: 5, lore: 'lore_phu_thuy', tips: ['tip_phu_thuy_1', 'tip_phu_thuy_2']
    ),
    RoleDefinition(
      id: 'nerd', name: 'role_nerd', description: 'role_nerd_desc', team: RoleTeam.neutral, icon: Icons.psychology, 
      primaryColor: const Color(0xFF9E9D24), secondaryColor: const Color(0xFFD4E157), isUnique: true,
      difficulty: 4, lore: 'lore_nerd', tips: ['tip_nerd_1']
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

  /// Đảm bảo tên đã được load trước khi thực hiện hành động
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
    // Trạng thái detached hoặc inactive (iOS) thường xảy ra khi app bị đóng
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      if (roomCode.isNotEmpty) {
        // Nếu là Host, thực hiện xóa nhanh phòng
        final isHost = lobbyPlayerNames.isNotEmpty && lobbyPlayerNames[0] == userName;
        if (isHost) {
          firestoreSvc.deleteRoom(roomCode);
        } else {
          leaveRoom();
        }
      }
    }
  }

  void listenToRoom(String code) {
    _roomSubscription?.cancel();
    _roomSubscription = firestoreSvc.getRoomStream(code).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final String status = data['status'] ?? 'waiting';
          final List playersData = data['players'] ?? [];
          final List messagesData = data['messages'] ?? [];
          final List? statusData = data['playerStatuses'];
          
          lobbyPlayerNames = playersData.map((p) => p['name'] as String).toList();
          playerCount = data['playerCount'] ?? playerCount;
          dayNumber = data['dayNumber'] ?? dayNumber;
          cursedPlayerId = data['cursedPlayerId'];
          
          if (data['werewolfTargetId'] != null) {
            werewolfTarget = players.firstWhere((p) => p.id == data['werewolfTargetId'], orElse: () => players[0]);
          } else {
            werewolfTarget = null;
          }

          if (data['lover1Id'] != null && data['lover2Id'] != null) {
            lover1 = players.firstWhere((p) => p.id == data['lover1Id'], orElse: () => players[0]);
            lover2 = players.firstWhere((p) => p.id == data['lover2Id'], orElse: () => players[0]);
          }

          if (data['currentPhase'] != null) {
            currentPhase = GamePhase.values.firstWhere(
              (e) => e.name == data['currentPhase'], 
              orElse: () => currentPhase
            );
          }

          // Cập nhật trạng thái người chơi
          if (statusData != null && players.isNotEmpty) {
            for (var s in statusData) {
              final p = players.firstWhere((player) => player.id == s['id'], orElse: () => players[0]);
              p.isAlive = s['isAlive'] ?? p.isAlive;
              p.voteCount = s['voteCount'] ?? p.voteCount;
              p.isTargeted = s['isTargeted'] ?? p.isTargeted;
              p.isProtected = s['isProtected'] ?? p.isProtected;
              p.isPoisoned = s['isPoisoned'] ?? p.isPoisoned;
              p.wasProtectedByBodyguard = s['wasProtectedByBodyguard'] ?? p.wasProtectedByBodyguard;
              p.wasHealedByWitch = s['wasHealedByWitch'] ?? p.wasHealedByWitch;
              p.hasBeenScannedBySeer = s['hasBeenScannedBySeer'] ?? p.hasBeenScannedBySeer;
            }
          }

          // Cập nhật tin nhắn chat từ Firebase
          chatMessages = messagesData.map((m) => ChatMessage(
            senderName: m['senderName'],
            content: m['content'],
            isSystem: m['isSystem'] ?? false,
            isWerewolfOnly: m['isWerewolfOnly'] ?? false,
            isGhost: m['isGhost'] ?? false,
            time: (m['time'] as Timestamp).toDate(),
          )).toList();

          if (status == 'playing' && currentState == PlayState.lobby) {
            _handleGameStarted(playersData);
          }

          // Tự động bắt đầu nếu đủ 15 người (Dùng người chơi đầu tiên trong danh sách làm người khởi tạo)
          final isFirstPlayer = playersData.isNotEmpty && playersData[0]['name'] == userName;
          if (isFirstPlayer && status == 'waiting' && playersData.length >= 15 && roomCode.isNotEmpty) {
            startGame();
          }
          
          notifyListeners();
        }
      }
    });
  }

  void _handleGameStarted(List playersData) async {
    // Chuyển đổi dữ liệu từ Firestore sang danh sách OnlinePlayer nội bộ
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

    // Đồng bộ các trạng thái đặc biệt nếu có
    final roomData = (await FirebaseFirestore.instance.collection('rooms').doc(roomCode).get()).data();
    if (roomData != null) {
      if (roomData['lover1Id'] != null && roomData['lover2Id'] != null) {
        lover1 = players.firstWhere((p) => p.id == roomData['lover1Id']);
        lover2 = players.firstWhere((p) => p.id == roomData['lover2Id']);
      }
      cursedPlayerId = roomData['cursedPlayerId'];
    }

    // Tự động vào trận sau 5 giây hiển thị vai trò
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
      
      if (myPlayer?.role.team == RoleTeam.werewolf) {
        chatMessages.add(ChatMessage(
          senderName: langSvc.t('system'),
          content: langSvc.t('wolf_chat_open'),
          isSystem: true,
          isWerewolfOnly: true,
          time: DateTime.now()
        ));
      }
      
      if (roomCode.isEmpty) simulateWerewolfNightTarget();
      startPhaseTimer(15);
      notifyListeners();
    });
  }

  void generateRoomCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    roomCode = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> createRoom() async {
    // 1. Cập nhật UI local ngay lập tức (Optimistic UI)
    currentState = PlayState.lobby;
    lobbyPlayerNames = [userName];
    notifyListeners();

    try {
      // 2. Bắn data lên Firebase trong background
      await firestoreSvc.createRoom(roomCode, userName, playerCount);
      
      // 3. Lắng nghe
      listenToRoom(roomCode);
    } catch (e) {
      debugPrint('Failed to create room on Firebase: $e');
      // Rollback nếu lỗi
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
      debugPrint('Failed to join room on Firebase: $e');
      rethrow;
    }
  }

  Future<void> leaveRoom() async {
    if (roomCode.isNotEmpty) {
      final codeToLeave = roomCode;
      _roomSubscription?.cancel();
      
      // 1. Xóa trạng thái local ngay lập tức
      roomCode = '';
      currentState = PlayState.setup;
      notifyListeners();

      // 2. Gọi Firebase xóa trong background (không await để giảm delay UI)
      firestoreSvc.leaveRoom(codeToLeave, userName).catchError((e) {
        debugPrint('Error during background leave: $e');
      });
    }
  }

  void startQuickMatch({bool isOnline = false}) async {
    await _ensureNameLoaded();
    
    if (isOnline) {
      startOnlineMatchmaking();
      return;
    }

    roomCode = ''; // Xóa mã phòng để kích hoạt chế độ Offline
    playerCount = 15;
    final random = Random();
    
    // 1. Chuẩn bị danh sách (Bạn + 14 bots)
    List<String> finalNames = [userName];
    final botNames = ['Minh Đức', 'Khánh Linh', 'Tuấn Tú', 'Hoài Thu', 'Gia Bảo', 'Quỳnh Anh', 'Nhật Minh', 'Phương Thảo', 'Thanh Lâm', 'Mai Chi', 'Trí Dũng', 'Ngọc Diệp', 'Quang Hải', 'Thúy Hạnh', 'Bảo Nam'];
    
    for (int i = 0; i < 14; i++) {
      finalNames.add('${botNames[i]} (Bot)');
    }

    // 2. Phân vai trò
    List<RoleDefinition> roles = [];
    int targetWolves = 4; 
    List<RoleDefinition> wolfPool = [];
    
    wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_dau_dan'));
    wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_nguyen'));
    while (wolfPool.length < targetWolves) {
      wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi'));
    }
    
    roles.addAll(wolfPool);
    List<RoleDefinition> specials = roleDefinitions.where((r) => r.isUnique && r.team != RoleTeam.werewolf).toList()..shuffle(random);
    roles.addAll(specials.take(min(specials.length, playerCount - roles.length)));
    
    while (roles.length < playerCount) {
      roles.add(roleDefinitions.firstWhere((r) => r.id == 'dan'));
    }
    roles.shuffle(random);

    // 3. Khởi tạo danh sách người chơi nội bộ
    players = List.generate(playerCount, (i) => OnlinePlayer(
      id: i + 1,
      name: finalNames[i],
      role: roles[i],
      isHost: finalNames[i] == userName,
    ));

    // Nhận diện bản thân
    myPlayer = players.firstWhere((p) => p.name == userName);

    // 4. Chuyển thẳng sang màn hình lật vai trò
    currentState = PlayState.roleReveal;
    notifyListeners();

    // 5. Tự động vào trận sau 5 giây
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
      
      if (myPlayer?.role.team == RoleTeam.werewolf) {
        chatMessages.add(ChatMessage(
          senderName: langSvc.t('system'),
          content: langSvc.t('wolf_chat_open'),
          isSystem: true,
          isWerewolfOnly: true,
          time: DateTime.now()
        ));
      }
      
      simulateWerewolfNightTarget();
      startPhaseTimer(15);
      notifyListeners();
    });
  }

  Future<void> startOnlineMatchmaking() async {
    await _ensureNameLoaded();
    currentState = PlayState.matchmaking;
    isLobbyLoading = true;
    notifyListeners();

    try {
      // Thử tìm phòng có sẵn trong tối đa 3 lần (mỗi lần cách nhau 2 giây)
      // để tăng khả năng lấp đầy các phòng đang chờ thay vì tạo phòng mới ngay lập tức
      for (int i = 0; i < 3; i++) {
        String? foundRoomCode = await firestoreSvc.findPublicRoom();

        if (foundRoomCode != null) {
          await joinExistingRoom(foundRoomCode, userName);
          isLobbyLoading = false;
          notifyListeners();
          return;
        }

        // Đợi một chút trước khi thử lại hoặc tạo phòng mới
        if (i < 2) await Future.delayed(const Duration(seconds: 2));
      }

      // Nếu không tìm thấy phòng nào sau thời gian chờ, tiến hành tạo phòng công khai mới
      generateRoomCode();
      await firestoreSvc.createRoom(roomCode, userName, 15, isPublic: true);
      currentState = PlayState.lobby;
      listenToRoom(roomCode);
    } catch (e) {
      debugPrint('Matchmaking failed: $e');
      isLobbyLoading = false;
      notifyListeners();
      return;
    }

    isLobbyLoading = false;
    notifyListeners();
  }

  void startLobbyTransition() {
    isLobbyLoading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1000), () {
      final names = ['Minh Đức', 'Khánh Linh', 'Tuấn Tú', 'Hoài Thu', 'Gia Bảo', 'Quỳnh Anh', 'Nhật Minh', 'Phương Thảo'];
      while (lobbyPlayerNames.length < playerCount) {
        lobbyPlayerNames.add(names[lobbyPlayerNames.length % names.length]);
      }
      isLobbyLoading = false;
      notifyListeners();
    });
  }

  void startGame() {
    // 1. Chỉ lấy danh sách người chơi thật đang có trong phòng
    final actualPlayerCount = lobbyPlayerNames.length;
    
    // Yêu cầu tối thiểu 4 người để bắt đầu game
    if (actualPlayerCount < 4) {
      addLog('${langSvc.t('system')}: ${langSvc.currentLanguage == AppLanguage.vi ? "Cần tối thiểu 4 người để bắt đầu trận đấu!" : "Need at least 4 players to start the match!"}');
      return;
    }

    final random = Random();
    List<String> finalNames = List.from(lobbyPlayerNames);

    // 2. Phân vai trò dựa trên số lượng người chơi thực tế
    List<RoleDefinition> roles = [];
    int targetWolves = max(1, (actualPlayerCount / 4).round());
    List<RoleDefinition> wolfPool = [];
    
    if (random.nextBool() && targetWolves >= 2) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_dau_dan'));
    if (random.nextBool() && targetWolves >= 2) wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi_nguyen'));
    while (wolfPool.length < targetWolves) {
      wolfPool.add(roleDefinitions.firstWhere((r) => r.id == 'soi'));
    }
    
    roles.addAll(wolfPool);
    List<RoleDefinition> specials = roleDefinitions.where((r) => r.isUnique && r.team != RoleTeam.werewolf).toList()..shuffle(random);
    roles.addAll(specials.take(min(specials.length, actualPlayerCount - roles.length)));
    
    while (roles.length < actualPlayerCount) roles.add(roleDefinitions.firstWhere((r) => r.id == 'dan'));
    roles.shuffle(random);

    // 3. Tạo dữ liệu người chơi để bắn lên Firebase
    List<Map<String, dynamic>> playersWithRoles = [];
    for (int i = 0; i < actualPlayerCount; i++) {
      playersWithRoles.add({
        'name': finalNames[i],
        'roleId': roles[i].id,
        'isHost': i == 0,
        'isReady': true,
        'isBot': false, // Không tạo thêm bot
      });
    }

    // 4. Cập nhật Firestore (Cập nhật cả playerCount thực tế)
    firestoreSvc.startGame(roomCode, playersWithRoles);
    // Cập nhật lại số lượng người chơi thực tế trên document phòng
    FirebaseFirestore.instance.collection('rooms').doc(roomCode).update({
      'playerCount': actualPlayerCount
    });
  }

  void resetGame() {
    stopPeriodicBotChat();
    _phaseTimer?.cancel();
    currentState = PlayState.lobby;
    selectedPlayer = null;
    players = [];
    isNerdHanged = false;
    witchReviveTargetId = null;
    myPlayer = null;
    actionLogs = [];
    generateRoomCode();
    initializeLobbyChat();
    notifyListeners();
  }

  void updatePlayerCount(int count) { playerCount = count; notifyListeners(); }
  void selectPlayer(OnlinePlayer? player) { selectedPlayer = player; notifyListeners(); }

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
    chatMessages = [
      ChatMessage(senderName: langSvc.t('system'), content: langSvc.t('lobby_created'), isSystem: true, time: DateTime.now()),
    ];
    actionLogs = ['${langSvc.t('system')}: ${langSvc.t('joined_room').replaceFirst('%s', roomCode)}'];
  }

  void sendUserMessage(String text) {
    if (text.trim().isEmpty) return;
    
    final isWolfChannel = currentPhase == GamePhase.night && myPlayer?.role.team == RoleTeam.werewolf;
    final isGhost = myPlayer != null ? !myPlayer!.isAlive : false;
    
    if (roomCode.isEmpty) {
      // Chế độ chơi nhanh (Offline/Local)
      chatMessages.add(ChatMessage(
        senderName: userName,
        content: text,
        isWerewolfOnly: isWolfChannel,
        isGhost: isGhost,
        time: DateTime.now(),
      ));
      simulateBotChatResponse(text);
      notifyListeners();
    } else {
      // Chế độ Online
      final messageData = {
        'senderName': userName,
        'content': text,
        'isWerewolfOnly': isWolfChannel,
        'isGhost': isGhost,
        'isSystem': false,
        'time': Timestamp.now(),
      };
      firestoreSvc.sendChatMessage(roomCode, messageData);
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

    phaseTimerSeconds = seconds;
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (phaseTimerSeconds > 0) {
        phaseTimerSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        
        // Chỉ Host mới thực hiện chuyển phase trong chế độ Online
        final isHost = lobbyPlayerNames.isNotEmpty && lobbyPlayerNames[0] == userName;
        if (roomCode.isNotEmpty && !isHost) return;

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

  void transitionToDay() async {
    if (currentState == PlayState.ended || hunterSkillTriggered) return;
    stopPeriodicBotChat();
    OnlinePlayer? finalVictim;
    int maxV = 0;
    for (var p in players) {
      if (p.voteCount > maxV) { maxV = p.voteCount; finalVictim = p; }
      else if (p.voteCount == maxV && maxV > 0 && Random().nextBool()) finalVictim = p;
    }
    if (finalVictim != null && !finalVictim.isProtected) {
      killPlayer(finalVictim, langSvc.t('night_casualty').replaceFirst('%s', finalVictim.name));
    }
    for (var p in players) {
      if (p.isPoisoned && p.isAlive) {
        killPlayer(p, langSvc.t('poison_casualty').replaceFirst('%s', p.name));
      }
    }
    
    // Hồi sinh người chơi được Phù Thủy cứu (hiệu lực khi trời sáng)
    if (witchReviveTargetId != null) {
      final p = players.firstWhere((player) => player.id == witchReviveTargetId);
      p.isAlive = true;
      witchReviveTargetId = null;
    }

    notifyListeners(); // Cập nhật để mọi người thấy log tử nạn trong đêm

    // Dừng lại 2 giây để mọi người đọc thông báo kết quả đêm qua
    await Future.delayed(const Duration(seconds: 2));
    if (currentState == PlayState.ended) return;

    addLog('${langSvc.t('system')}: ${langSvc.t('sunrise')}');
    for (var p in players) { p.isProtected = false; p.isPoisoned = false; p.voteCount = 0; p.isTargeted = false; p.wasProtectedByBodyguard = false; p.wasHealedByWitch = false; }
    hasUsedSeerScan = false; hasUsedBodyguardProtect = false; hasUsedHealThisNight = false; hasUsedPoisonThisNight = false;
    cursedPlayerId = null; selectedPlayer = null; currentPhase = GamePhase.day;
    
    syncGameState();
    
    if (checkGameOver().isEmpty) { startPeriodicBotChat(); startPhaseTimer(60); }
    notifyListeners();
  }

  void transitionToVoting() {
    if (currentState == PlayState.ended || hunterSkillTriggered) return;
    stopPeriodicBotChat();
    addLog('${langSvc.t('system')}: ${langSvc.t('voting_start')}');
    currentPhase = GamePhase.voting;
    for (var p in players) { p.voteCount = 0; p.isTargeted = false; }
    _simulateBotVotesGradually();
    
    syncGameState();
    
    startPhaseTimer(15);
    notifyListeners();
  }

  void transitionToNight() async {
    if (currentState == PlayState.ended || hunterSkillTriggered) return;
    stopPeriodicBotChat();
    List<OnlinePlayer> alive = players.where((p) => p.isAlive).toList();
    OnlinePlayer? hanged; 
    int maxV = 0;

    for (var p in alive) {
      if (p.voteCount > maxV) { 
        maxV = p.voteCount; 
        hanged = p; 
      }
      else if (p.voteCount == maxV && maxV > 0 && Random().nextBool()) {
        hanged = p;
      }
    }

    // Nếu số vote <= 1 thì không ai bị treo cổ
    if (hanged != null && maxV > 1) {
      if (hanged.role.id == 'nerd') isNerdHanged = true;
      killPlayer(hanged, '${hanged.name} ${langSvc.t('lynched')}');
    } else {
      addLog('${langSvc.t('system')}: ${langSvc.t('no_lynch')}');
    }
    
    notifyListeners(); // Cập nhật để mọi người thấy log tử nạn

    // Dừng lại 2 giây để mọi người đọc thông báo kết quả vote
    await Future.delayed(const Duration(seconds: 2));
    if (currentState == PlayState.ended) return;

    for (var p in players) p.voteCount = 0;
    dayNumber++; 
    currentPhase = GamePhase.night; 
    selectedPlayer = null;
    addLog('${langSvc.t('system')}: ${langSvc.t('night_number')} $dayNumber ${langSvc.t('night_start')}');
    
    syncGameState();
    
    if (checkGameOver().isEmpty) { 
      simulateWerewolfNightTarget();
      startPhaseTimer(15); 
    }
    notifyListeners();
  }

  void executeVote(OnlinePlayer target) {
    final weight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    for (var p in players) if (p.isTargeted) { p.voteCount -= weight; p.isTargeted = false; }
    target.voteCount += weight; target.isTargeted = true;
    
    syncGameState();
    notifyListeners();
  }

  void killPlayer(OnlinePlayer player, String reason) {
    if (!player.isAlive) return;
    player.isAlive = false; addLog(reason);
    if (lover1 != null && lover2 != null) {
      if (player.id == lover1!.id && lover2!.isAlive) killPlayer(lover2!, langSvc.t('lover_tragedy'));
      else if (player.id == lover2!.id && lover1!.isAlive) killPlayer(lover1!, langSvc.t('lover_tragedy'));
    }
    if (player.role.id == 'tho_san') {
      if (player.id == myPlayer?.id) { hunterSkillTriggered = true; hunterWhoDied = player; }
      else simulateBotHunterShot(player);
    }
  }

  void executeSeerScan(OnlinePlayer target) {
    target.hasBeenScannedBySeer = true; hasUsedSeerScan = true;
    final isW = target.role.team == RoleTeam.werewolf || target.id == cursedPlayerId;
    addLog(langSvc.t('seer_result').replaceFirst('%s', target.name).replaceFirst('%s', isW ? langSvc.t('wolf_red') : langSvc.t('villager_green')));
    
    syncGameState();
    selectedPlayer = null; notifyListeners();
  }

  void executeBodyguardProtect(OnlinePlayer target) {
    target.isProtected = true; target.wasProtectedByBodyguard = true;
    hasUsedBodyguardProtect = true; lastProtectedPlayerId = target.id;
    addLog(langSvc.t('guard_log').replaceFirst('%s', target.name));
    
    syncGameState();
    selectedPlayer = null; notifyListeners();
  }

  void executeWitchHeal(OnlinePlayer target) {
    if (target.role.team != RoleTeam.villager) {
      addLog('${langSvc.t('system')}: Bình cứu không có tác dụng với phe khác!');
      selectedPlayer = null;
      notifyListeners();
      return;
    }

    if (target.isAlive) {
      // Bảo vệ người sắp bị cắn (có hiệu lực ngay để chặn cái chết lúc bình minh)
      target.isProtected = true;
      target.wasHealedByWitch = true;
      addLog(langSvc.t('witch_save_log').replaceFirst('%s', target.name));
    } else {
      // Hồi sinh người đã chết (đánh dấu để hồi sinh khi trời sáng)
      witchReviveTargetId = target.id;
      target.wasHealedByWitch = true;
      addLog(langSvc.t('witch_revive_log').replaceFirst('%s', target.name));
    }

    hasHealPotion = false;
    hasUsedHealThisNight = true;
    
    syncGameState();
    selectedPlayer = null;
    notifyListeners();
  }

  void executeWitchPoison(OnlinePlayer target) {
    target.isPoisoned = true; hasPoisonPotion = false; hasUsedPoisonThisNight = true;
    addLog(langSvc.t('witch_poison_log').replaceFirst('%s', target.name));
    
    syncGameState();
    selectedPlayer = null; notifyListeners();
  }

  void executeWerewolfBite(OnlinePlayer target) {
    executeVote(target); _updateWerewolfLeadingTarget(); 
    syncGameState();
    notifyListeners();
  }

  void cancelWerewolfBite() {
    final weight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    for (var p in players) if (p.isTargeted) { p.voteCount -= weight; p.isTargeted = false; }
    _updateWerewolfLeadingTarget(); 
    syncGameState();
    notifyListeners();
  }

  void _updateWerewolfLeadingTarget() {
    OnlinePlayer? leader; int maxV = 0;
    for (var p in players) if (p.voteCount > maxV) { maxV = p.voteCount; leader = p; }
    werewolfTarget = leader;
  }

  void executeCupidLink() {
    lover1 = cupidSelections[0]; lover2 = cupidSelections[1];
    addLog(langSvc.t('cupid_log').replaceFirst('%s', lover1!.name).replaceFirst('%s', lover2!.name));
    cupidSelections = []; 
    
    // Đồng bộ thông tin người tình lên Firebase nếu cần (hoặc dùng statusMap)
    // Để đơn giản, ta có thể thêm loverIds vào room data
    if (roomCode.isNotEmpty) {
      firestoreSvc.updateRoomData(roomCode, {
        'lover1Id': lover1!.id,
        'lover2Id': lover2!.id,
      });
    }
    
    syncGameState();
    selectedPlayer = null; notifyListeners();
  }

  void executeCurse(OnlinePlayer target) { 
    cursedPlayerId = target.id; 
    addLog(langSvc.t('curse_log').replaceFirst('%s', target.name)); 
    
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
    for (var p in players) if (p.wasProtectedByBodyguard) { p.isProtected = false; p.wasProtectedByBodyguard = false; }
    hasUsedBodyguardProtect = false; lastProtectedPlayerId = null; notifyListeners();
  }

  void cancelWitchAction() {
    if (hasUsedHealThisNight) {
      for (var p in players) p.wasHealedByWitch = false;
      hasHealPotion = true; hasUsedHealThisNight = false;
    } else if (hasUsedPoisonThisNight) {
      for (var p in players) p.isPoisoned = false;
      hasPoisonPotion = true; hasUsedPoisonThisNight = false;
    }
    notifyListeners();
  }

  void executeGunnerShoot(OnlinePlayer target) {
    if (xathuBullets <= 0 || !target.isAlive) return;
    xathuBullets--; xathuRevealed = true;
    killPlayer(target, langSvc.t('gunner_log').replaceFirst('%s', target.name));
    
    syncGameState();
    selectedPlayer = null; checkGameOver(); notifyListeners();
  }

  void executeHunterShot(OnlinePlayer target) {
    hunterSkillTriggered = false; killPlayer(target, langSvc.t('hunter_log').replaceFirst('%s', target.name));
    syncGameState();
    checkGameOver(); notifyListeners();
  }

  String getActionInstructionText() {
    if (hunterSkillTriggered) return langSvc.t('instruction_hunter');
    if (selectedPlayer == null) {
      if (currentPhase == GamePhase.night) {
        if (myPlayer!.role.id == 'cupid' && lover1 == null) return langSvc.t('instruction_cupid');
        return langSvc.t('instruction_skill');
      }
      return currentPhase == GamePhase.day ? langSvc.t('instruction_discuss') : langSvc.t('instruction_vote');
    }
    return '${langSvc.t('instruction_target')} ${selectedPlayer!.name}';
  }

  String checkGameOver() {
    if (currentState != PlayState.playing || players.isEmpty) return '';
    if (isNerdHanged) {
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      final winMsg = langSvc.currentLanguage == AppLanguage.vi ? 'đã thắng!' : 'has won!';
      return '${langSvc.t('role_nerd')} $winMsg';
    }
    int w = players.where((p) => p.isAlive && (p.role.team == RoleTeam.werewolf || p.id == cursedPlayerId)).length;
    int g = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != cursedPlayerId).length;
    if (w == 0) {
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return (langSvc.currentLanguage == AppLanguage.vi ? 'Phe Dân Làng giành chiến thắng!' : 'Villagers won!');
    }
    if (w >= g) {
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return (langSvc.currentLanguage == AppLanguage.vi ? 'Phe Ma Sói giành chiến thắng!' : 'Werewolves won!');
    }
    return '';
  }

  bool isMyWin(String msg) {
    if (myPlayer == null) return false;
    if (msg.contains('Nerd') || msg.contains('Ngốc')) return myPlayer!.role.id == 'nerd';
    return (myPlayer!.role.team == RoleTeam.werewolf && (msg.contains('Sói') || msg.contains('Werewolves'))) || (myPlayer!.role.team != RoleTeam.werewolf && (msg.contains('Dân') || msg.contains('Villagers')));
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
      if (bots.isNotEmpty) { chatMessages.add(ChatMessage(senderName: bots[Random().nextInt(bots.length)].name, content: langSvc.t('bot_calm_down'), time: DateTime.now())); notifyListeners(); }
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
        ? ['Nghi P${t.id} nha.', 'P${t.id} im quá.', 'Soi P${t.id} đi.', 'Tui dân mà!'][Random().nextInt(4)]
        : ['Suspecting P${t.id}.', 'P${t.id} is too quiet.', 'Scan P${t.id}.', 'I am villager!'][Random().nextInt(4)];
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
        final weight = b.role.id == 'soi_dau_dan' ? 2 : 1;
        target.voteCount += weight;
        _updateWerewolfLeadingTarget();
        notifyListeners();
      });
    }
  }

  void simulateBotHunterShot(OnlinePlayer h) {
    final t = players.where((p) => p.isAlive && p.id != h.id).toList();
    if (t.isNotEmpty) killPlayer(t[Random().nextInt(t.length)], langSvc.t('hunter_took_down'));
  }

  void addLog(String log) { actionLogs.add(log); notifyListeners(); }
  @override void dispose() { 
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
