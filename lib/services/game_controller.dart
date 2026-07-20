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
  // Cấu hình thời gian cho các giai đoạn (Đồng bộ Web & Android)
  static const int durationNight = 20;
  static const int durationDay = 60;
  static const int durationVoting = 15;

  PlayState currentState = PlayState.setup;
  GamePhase currentPhase = GamePhase.night;
  int playerCount = 15;
  String userName = '';
  bool _isNameLoaded = false;
  String roomCode = '';
  bool isLobbyLoading = false;
  int dayNumber = 1;
  int phaseNumber = 0;
  bool isRoomLocked = false;

  List<OnlinePlayer> players = [];
  List<String> lobbyPlayerNames = [];
  OnlinePlayer? myPlayer;
  OnlinePlayer? selectedPlayer;
  List<String> actionLogs = [];
  List<ChatMessage> chatMessages = [];

  int phaseTimerSeconds = 0;
  bool _isTransitioning = false; // Khóa để tránh spam transaction khi hết giờ
  Timer? _phaseTimer;
  Timer? botChatTimer;
  Timer? _heartbeatTimer;       // Heartbeat: cập nhật lastSeen định kỳ
  Timer? _zombieTimer;          // Quét và kick/kill zombie
  Timer? _hunterTimeoutTimer;   // Timeout cho kỹ năng Thợ Săn
  Timer? _endGameTimer;         // Hẹn giờ xóa phòng khi kết thúc game
  Timer? _voteDebounceTimer;    // Debounce cho vote
  Timer? _biteDebounceTimer;    // Debounce cho sói cắn
  StreamSubscription? _roomSubscription;
  StreamSubscription? _messagesSubscription;
  Timestamp? _lastSyncedEndTime;
  int? _myCurrentVoteTargetId; // ID người bị vote hiện tại của người chơi này (chỉ ban ngày)
  int? _myNightBiteTargetId; // ID mục tiêu bị cắn của sói
  int? _lastSyncedVoteId;    // ID đã đồng bộ cuối cùng (để tính toán increment)
  int? _lastSyncedBiteId;    // ID sói cắn đã đồng bộ
  DateTime? _lastVoteTime; // Thời điểm vote gần nhất để tránh nhấp nháy UI (flicker)

  // Dữ liệu theo dõi kết nối
  final Map<String, Timestamp> _serverLastSeenMap = {};
  final Map<String, DateTime> _localLastSeenMap = {};
  String? _currentHostName;

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
  bool xathuHasShotToday = false;
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
    if (state == AppLifecycleState.resumed) {
      // Khi quay lại tab/app, ngay lập tức gửi tín hiệu active
      _updateActivity();

      // Recalculate timer based on server time if available
      if (_lastSyncedEndTime != null) {
        final remaining = _lastSyncedEndTime!.toDate().difference(DateTime.now()).inSeconds;
        phaseTimerSeconds = remaining > 0 ? remaining : 0;
        _startLocalVisualTimer();
        notifyListeners();
      }
    }
  }

  int _lastProcessedPhaseNumber = -1;

  String? winnerMessage;
  String? _activeMatchmakingToken;

  void listenToRoom(String code) {
    _roomSubscription?.cancel();
    _messagesSubscription?.cancel();
    
    _roomSubscription = firestoreSvc.getRoomStream(code).listen((snapshot) {
      if (!snapshot.exists) {
        _handleRoomDeleted();
        return;
      }

      final data = snapshot.data();
      if (data != null) {
        final Map<String, dynamic> playersMapData = Map<String, dynamic>.from(data['players'] ?? {});
        final List playersData = playersMapData.values.toList()..sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));
        
        final int serverPhaseNumber = data['phaseNumber'] ?? 0;
        String? winnerFromServer;
        if (data['status'] == 'ended' && currentState != PlayState.ended) {
          winnerFromServer = data['winner'] ?? '';
        }

        lobbyPlayerNames = playersData.map((p) => p['name'] as String).toList();
        // Giới hạn số lượng người chơi tối đa là 15
        playerCount = (data['playerCount'] ?? playerCount).clamp(4, 15);
        dayNumber = data['dayNumber'] ?? dayNumber;
        phaseNumber = serverPhaseNumber;
        cursedPlayerId = data['cursedPlayerId'];
        xathuRevealed = data['xathuRevealed'] ?? false;
        xathuBullets = data['xathuBullets'] ?? xathuBullets;
        xathuHasShotToday = data['xathuHasShotToday'] ?? false;
        witchReviveTargetId = data['witchReviveTargetId'];

        // Đồng bộ Phe Tình Nhân từ server
        final int? l1Id = data['lover1Id'];
        final int? l2Id = data['lover2Id'];
        if (l1Id != null && l2Id != null && players.isNotEmpty) {
          try {
            lover1 = players.firstWhere((p) => p.id == l1Id);
            lover2 = players.firstWhere((p) => p.id == l2Id);
          } catch (_) {
            lover1 = null;
            lover2 = null;
          }
        } else {
          // Chỉ reset nếu data thực sự không có lover (tránh mất data khi update dở dang)
          if (data.containsKey('lover1Id') && data['lover1Id'] == null) {
            lover1 = null;
            lover2 = null;
          }
        }

        // Đồng bộ mục tiêu Sói cắn từ server
        final int? wTargetId = data['werewolfTargetId'];
        if (wTargetId != null && players.isNotEmpty) {
          try {
            werewolfTarget = players.firstWhere((p) => p.id == wTargetId);
          } catch (_) {
            werewolfTarget = null;
          }
        } else {
          werewolfTarget = null;
        }

        if (data.containsKey('isPublic')) {
          isRoomLocked = !(data['isPublic'] as bool);
        }

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
        if (playersData.isNotEmpty) {
          final hostData = playersData.firstWhere((p) => p['isHost'] == true, orElse: () => null);
          if (hostData != null) _currentHostName = hostData['name'];

          final Map<String, dynamic> dataMap = {
            for (var p in playersData) p['name'].toString().trim(): p
          };

          if (currentState == PlayState.playing) {
            // Lấy dữ liệu của chính mình để kiểm tra tình trạng đồng bộ
            final myDataOnServer = dataMap[userName.trim()];
            // Firestore dùng -1, local dùng null
            final int? serverMyVotedForId = (myDataOnServer?['votedForId'] == -1 || myDataOnServer?['votedForId'] == null) 
                ? null : myDataOnServer?['votedForId'];
            final int? localMyVotedForId = (currentPhase == GamePhase.night) ? _myNightBiteTargetId : _myCurrentVoteTargetId;
            
            // Nếu local và server chưa khớp, ta đang ở trạng thái "Chờ đồng bộ" (Pending)
            final bool isMyVotePending = serverMyVotedForId != localMyVotedForId;
            final int myWeight = (myPlayer?.role.id == 'soi_dau_dan') ? 2 : 1;
            final now = DateTime.now();

            for (int i = 0; i < players.length; i++) {
              final pData = dataMap[players[i].name.trim()];
              if (pData != null) {
                final bool isAliveOnServer = pData['isAlive'] ?? true;
                if (players[i].isAlive && !isAliveOnServer && players[i].name == userName && players[i].role.id == 'tho_san') {
                  if (!hunterSkillTriggered) _triggerHunterSkill(players[i]);
                }

                players[i].isAlive = isAliveOnServer;
                players[i].isHost = pData['isHost'] ?? false;
                players[i].isProtected = pData['isProtected'] ?? false;
                players[i].isPoisoned = pData['isPoisoned'] ?? false;
                players[i].wasProtectedByBodyguard = pData['wasProtectedByBodyguard'] ?? false;
                players[i].wasHealedByWitch = pData['wasHealedByWitch'] ?? false;

                // CƠ CHẾ VÁ VOTE (PATCHING) - CHỐNG FLICKER TUYỆT ĐỐI
                int displayVoteCount = pData['voteCount'] ?? 0;
                if (isMyVotePending) {
                  if (players[i].id == localMyVotedForId) displayVoteCount += myWeight;
                  if (players[i].id == serverMyVotedForId) displayVoteCount -= myWeight;
                }
                players[i].voteCount = displayVoteCount.clamp(0, 99);
                players[i].votedForId = pData['votedForId']; 

                if (players[i].name.trim() == userName.trim()) {
                  myPlayer = players[i];
                  // 3. CHỈ ĐỒNG BỘ NGƯỢC NẾU SERVER ĐÃ KHỚP HOẶC QUÁ 3 GIÂY (Tránh nhảy số)
                  bool hasSynced = serverMyVotedForId == localMyVotedForId;
                  if (localMyVotedForId == null || _lastVoteTime == null || now.difference(_lastVoteTime!).inSeconds > 3 || hasSynced) {
                    if (currentPhase == GamePhase.night) {
                      _myNightBiteTargetId = serverMyVotedForId;
                      _lastSyncedBiteId = serverMyVotedForId;
                    } else {
                      _myCurrentVoteTargetId = serverMyVotedForId;
                      _lastSyncedVoteId = serverMyVotedForId;
                    }
                  }
                }
                players[i].isTargeted = false;
              }
            }

            // TỐI ƯU: Tính toán lại mục tiêu dẫn đầu của Sói dựa trên dữ liệu vote mới nhất từ server
            if (currentPhase == GamePhase.night) {
              _updateWerewolfLeadingTarget();
            } else {
              werewolfTarget = null;
            }
          }
        }

        // ĐỒNG BỘ GIAI ĐOẠN (PHASE): Luôn cập nhật phase từ server để UI đồng bộ
        if (data['currentPhase'] != null) {
          currentPhase = GamePhase.values.firstWhere((e) => e.name == data['currentPhase'], orElse: () => currentPhase);
          
          if (serverPhaseNumber > _lastProcessedPhaseNumber) {
            if (currentState == PlayState.playing) {
              _lastProcessedPhaseNumber = serverPhaseNumber;
              _handlePhaseTransitionFromServer(currentPhase);
            }
          }
        }

        if (data['status'] == 'playing' && currentState == PlayState.lobby) {
          _handleGameStarted(playersData);
        }

        // XỬ LÝ KẾT THÚC GAME SAU KHI ĐÃ ĐỒNG BỘ DỮ LIỆU CỦA SNAPSHOT NÀY
        if (winnerFromServer != null) {
          _handleGameEnd(winnerFromServer);
          return;
        }

        notifyListeners();
      }
    });

    // LẮNG NGHE TIN NHẮN TỪ SUBCOLLECTION (TỐI ƯU DỮ LIỆU)
    _messagesSubscription = firestoreSvc.getMessagesStream(code).listen((snapshot) {
      chatMessages = snapshot.docs.map((doc) {
        final m = doc.data();
        return ChatMessage(
          senderName: m['senderName'] ?? '',
          content: m['content'] ?? '',
          targetName: m['targetName'],
          isSystem: m['isSystem'] ?? false,
          isWerewolfOnly: m['isWerewolfOnly'] ?? false,
          isGhost: m['isGhost'] ?? false,
          time: (m['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).where((m) {
        if (m.isSystem) return true;
        if (m.isWerewolfOnly) return myPlayer?.role.team == RoleTeam.werewolf;
        if (m.isGhost) return myPlayer != null && !myPlayer!.isAlive;
        return true;
      }).toList().reversed.toList(); // Đảo ngược vì descending: true
      notifyListeners();
    });
  }

  void _handleGameEnd(String winner) {
    currentState = PlayState.ended;
    winnerMessage = winner == 'nerd' ? '${langSvc.t('role_nerd')} thắng!' :
                   winner == 'werewolves' ? 'Ma Sói thắng!' :
                   winner == 'villagers' ? 'Dân Làng thắng!' : 'Phe Tình Nhân thắng! ❤️';

    _phaseTimer?.cancel();

    if (roomCode.isNotEmpty) {
      final bool isHost = _currentHostName == userName || myPlayer?.isHost == true;
      final codeToDelete = roomCode;

      _endGameTimer?.cancel();
      _endGameTimer = Timer(const Duration(seconds: 10), () {
        if (isHost) {
          firestoreSvc.deleteRoom(codeToDelete);
        }
        if (roomCode == codeToDelete || roomCode.isEmpty) {
          _roomSubscription?.cancel();
          _messagesSubscription?.cancel();
          _roomSubscription = null;
          _messagesSubscription = null;
          roomCode = '';
          currentState = PlayState.setup;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void _handleRoomDeleted() {
    _roomSubscription?.cancel();
    _messagesSubscription?.cancel();
    _roomSubscription = null;
    _messagesSubscription = null;
    roomCode = '';
    currentState = PlayState.setup;
    notifyListeners();
  }

  void _handleGameStarted(List playersData) {
    players = playersData.map((p) {
      final roleId = p['roleId'] ?? 'dan';
      final role = roleDefinitions.firstWhere((r) => r.id == roleId, orElse: () => roleDefinitions[0]);

      final player = OnlinePlayer(
        id: p['id'] ?? 0,
        name: p['name'],
        role: role,
        isHost: p['isHost'] ?? false,
        isAlive: p['isAlive'] ?? true,
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
      
      // CATCH-UP: Nếu trong lúc chờ 5s, server đã chuyển phase, xử lý ngay
      if (phaseNumber > _lastProcessedPhaseNumber) {
        _lastProcessedPhaseNumber = phaseNumber;
        _handlePhaseTransitionFromServer(currentPhase);
      }

      dayNumber = 1;
      currentPhase = GamePhase.night;
      hasHealPotion = true;
      hasPoisonPotion = true;
      werewolfTarget = null;
      xathuBullets = 2;
      xathuRevealed = false;
      xathuHasShotToday = false;
      addLog('${langSvc.t('system')}: ${langSvc.t('match_started')}');
      notifyListeners();
    });
  }

  // --- 1. QUẢN LÝ THỜI GIAN VÀ ĐỒNG BỘ ---
  void _startLocalVisualTimer() {
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (phaseTimerSeconds > 0) {
        phaseTimerSeconds--;
        notifyListeners();
      } else {
        // Khi hết giờ: Chế độ Online gọi Server liên tục cho đến khi phase đổi, Offline xử lý locally
        if (roomCode.isNotEmpty) {
          if (!_isTransitioning) {
            _isTransitioning = true;
            _triggerNextPhaseOnFirestore();
          }
        } else {
          timer.cancel();
          _triggerNextPhaseOffline();
        }
      }
    });
  }

  void _triggerNextPhaseOnFirestore() {
    // TỐI ƯU: Chỉ Host được kích hoạt ngay lập tức. Các máy khác chờ 3s đề phòng Host lag.
    final isHost = (_currentHostName == userName);
    if (isHost) {
      _executePhaseTransition();
    } else {
      Future.delayed(const Duration(seconds: 3), () {
        if (roomCode.isNotEmpty && _isTransitioning) {
          _executePhaseTransition();
        }
      });
    }
  }

  void _executePhaseTransition() {
    String next;
    int duration;
    if (currentPhase == GamePhase.night) {
      next = 'day';
      duration = durationDay;
    } else if (currentPhase == GamePhase.day) {
      next = 'voting';
      duration = durationVoting;
    } else {
      next = 'night';
      duration = durationNight;
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

  // --- 2. XỬ LÝ CHUYỂN GIAI ĐOẠN ---
  void _handlePhaseTransitionFromServer(GamePhase newPhase) {
    // Reset khóa chuyển phase khi đã nhận được phase mới từ server
    _isTransitioning = false;

    // Trong chế độ Online, chúng ta không tự tính toán kết quả locally
    // vì Server (Firestore Transaction) đã làm điều đó và cập nhật vào danh sách players.

    currentPhase = newPhase;
    // RESET LOCAL INTENT KHI CHUYỂN PHASE ĐỂ TRÁNH VOTE ẢO
    _myNightBiteTargetId = null;
    _myCurrentVoteTargetId = null;
    _lastSyncedVoteId = null;
    _lastSyncedBiteId = null;
    _lastVoteTime = null;

    if (newPhase == GamePhase.day) {
      if (roomCode.isEmpty) {
        _processNightResults(); // Chỉ chạy offline
      } else {
        _resetLocalNightStates();
      }
    } else if (newPhase == GamePhase.voting) {
      if (roomCode.isEmpty) {
        _processDayResults(); // Chỉ chạy offline
      } else {
        _resetLocalDayStates();
      }
      // Thông báo kênh chat Sói cho phe Sói
      if (myPlayer?.role.team == RoleTeam.werewolf && myPlayer!.isAlive) {
        addLog('${langSvc.t('system')}: ${langSvc.t('wolf_chat_open')}');
        // Cũng thêm vào chat message để hiện trong tab Sói
        chatMessages.add(ChatMessage(
          senderName: langSvc.t('system'),
          content: langSvc.t('wolf_chat_open'),
          isSystem: true,
          isWerewolfOnly: true, // Chỉ Sói thấy log này trong chat
          time: DateTime.now(),
        ));
      }
    } else if (newPhase == GamePhase.night) {
      if (roomCode.isEmpty) {
        _processVotingResults(); // Chỉ chạy offline
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
      await firestoreSvc.createRoom(roomCode, userName, playerCount, isPublic: !isRoomLocked);
      listenToRoom(roomCode);
      _startHeartbeat(); // Bắt đầu heartbeat khi tạo phòng
      _startZombieDetection(); // Bắt đầu phát hiện Zombie
    } catch (e) {
      currentState = PlayState.setup;
      notifyListeners();
    }
  }

  Future<void> joinExistingRoom(String code, String name) async {
    try {
      String finalName = name;
      bool joined = false;
      int attempts = 0;

      while (!joined && attempts < 5) {
        try {
          await firestoreSvc.joinRoom(code, finalName);
          joined = true;
        } catch (e) {
          if (e.toString().contains('username_already_exists')) {
            finalName = '${name}_${Random().nextInt(99)}';
            attempts++;
          } else {
            rethrow;
          }
        }
      }

      if (!joined) {
        throw Exception('Cannot join room due to name conflict');
      }

      roomCode = code;
      userName = finalName;
      currentState = PlayState.lobby;
      listenToRoom(roomCode);
      _startHeartbeat(); // Bắt đầu heartbeat khi vào phòng
      _startZombieDetection(); // Bắt đầu phát hiện Zombie
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveRoom() async {
    if (roomCode.isNotEmpty) {
      final codeToLeave = roomCode;

      _roomSubscription?.cancel();
      _messagesSubscription?.cancel();
      _heartbeatTimer?.cancel();
      _zombieTimer?.cancel();
      _serverLastSeenMap.clear();
      _localLastSeenMap.clear();
      _currentHostName = null;
      _heartbeatTimer = null;
      roomCode = '';
      currentState = PlayState.setup;
      isRoomLocked = false;
      notifyListeners();

      firestoreSvc.leaveRoom(codeToLeave, userName).catchError((e) => debugPrint(e.toString()));
    }
  }

  void toggleRoomLock(bool locked) {
    isRoomLocked = locked;
    notifyListeners();
    if (roomCode.isNotEmpty && currentState == PlayState.lobby) {
      final isHost = lobbyPlayerNames.isNotEmpty && lobbyPlayerNames[0] == userName;
      if (isHost) {
        firestoreSvc.updateRoomData(roomCode, {'isPublic': !locked});
      }
    }
  }

  /// Bắt đầu gửi heartbeat định kỳ (60 giây) lên Firestore
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _updateActivity();
    });
    _updateActivity();
  }

  /// Cập nhật thời gian hoạt động cuối cùng của người chơi
  void _updateActivity() {
    if (roomCode.isNotEmpty && userName.isNotEmpty) {
      firestoreSvc.updateLastSeen(roomCode, userName);
    }
  }

  /// Phát hiện Zombie (Rút gọn cho ổn định Free Tier)
  void _startZombieDetection() {
    // Chỉ Host kiểm tra để tiết kiệm Read.
    _zombieTimer?.cancel();
    _zombieTimer = Timer.periodic(const Duration(seconds: 30), (_) {
       // Trong bản Free tier, ta có thể tạm tắt logic Kick tự động để giảm Read tốn kém, 
       // hoặc chỉ truy vấn subcollection 'presence' khi thực sự cần.
    });
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
      
      // CATCH-UP: Nếu trong lúc chờ 5s, server đã chuyển phase, xử lý ngay
      if (phaseNumber > _lastProcessedPhaseNumber) {
        _lastProcessedPhaseNumber = phaseNumber;
        _handlePhaseTransitionFromServer(currentPhase);
      }

      dayNumber = 1;
      currentPhase = GamePhase.night;
      hasHealPotion = true;
      hasPoisonPotion = true;
      werewolfTarget = null;
      xathuBullets = 2;
      xathuRevealed = false;
      xathuHasShotToday = false;
      addLog('${langSvc.t('system')}: ${langSvc.t('quick_match_started')}');
      simulateWerewolfNightTarget();
      startPhaseTimer(durationNight);
      notifyListeners();
    });
  }

  Future<void> startOnlineMatchmaking() async {
    if (roomCode.isNotEmpty && currentState == PlayState.lobby) return;

    final String sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    _activeMatchmakingToken = sessionToken;

    await _ensureNameLoaded();
    if (_activeMatchmakingToken != sessionToken) return;

    currentState = PlayState.matchmaking;
    notifyListeners();

    try {
       // Attempt 1: Search immediately
      String? foundRoomCode = await firestoreSvc.findPublicRoom();
      
      if (foundRoomCode != null && _activeMatchmakingToken == sessionToken) {
        try {
          _roomSubscription?.cancel();
          await joinExistingRoom(foundRoomCode, userName);
          if (_activeMatchmakingToken == sessionToken) {
            _activeMatchmakingToken = null;
            return;
          }
        } catch (e) {
          debugPrint('Matchmaking: Room $foundRoomCode full/invalid, will try creating or searching again.');
        }
      }

      // If no room found, wait a random short time to let someone else create one
      // OR to be the one who creates it.
      if (_activeMatchmakingToken == sessionToken) {
        int randomWait = 500 + Random().nextInt(1500); // 0.5s - 2s
        await Future.delayed(Duration(milliseconds: randomWait));
      }

      if (_activeMatchmakingToken != sessionToken || currentState != PlayState.matchmaking) return;

      // Attempt 2: Search one more time
      foundRoomCode = await firestoreSvc.findPublicRoom();
      if (foundRoomCode != null && _activeMatchmakingToken == sessionToken) {
        try {
          await joinExistingRoom(foundRoomCode, userName);
          _activeMatchmakingToken = null;
          return;
        } catch (e) {
          // ignore
        }
      }

      // Final: Create a new room if still none found
      if (_activeMatchmakingToken == sessionToken && currentState == PlayState.matchmaking) {
        debugPrint('Matchmaking: No active rooms found, creating new lobby...');
        generateRoomCode();
        // Giới hạn tối đa 15 người
        playerCount = 15;
        isRoomLocked = false;
        await createRoom();
        _activeMatchmakingToken = null;
      }
    } catch (e) {
      if (_activeMatchmakingToken == sessionToken) {
        currentState = PlayState.setup;
        _activeMatchmakingToken = null;
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
    _zombieTimer?.cancel();
    _serverLastSeenMap.clear();
    _localLastSeenMap.clear();
    _currentHostName = null;
    currentState = PlayState.lobby;
    isRoomLocked = false;
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
    // Giới hạn cứng tối đa 15 người
    final int safeCount = count.clamp(4, 15);
    playerCount = safeCount;
    notifyListeners();
    // Đồng bộ số lượng người chơi tối đa lên Firestore để những người đang join thấy được
    if (roomCode.isNotEmpty && (_currentHostName == userName || myPlayer?.isHost == true)) {
      firestoreSvc.updateRoomData(roomCode, {'playerCount': safeCount});
    }
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

    Map<String, dynamic> playersMap = {};
    for (var p in players) {
      playersMap['p${p.id}'] = {
        'id': p.id,
        'name': p.name,
        'roleId': p.role.id,
        'isHost': p.isHost,
        'isAlive': p.isAlive,
        'voteCount': p.voteCount,
        'votedForId': p.votedForId,
        'isProtected': p.isProtected,
        'isPoisoned': p.isPoisoned,
        'wasProtectedByBodyguard': p.wasProtectedByBodyguard,
        'wasHealedByWitch': p.wasHealedByWitch,
      };
    }

    firestoreSvc.updateRoomData(roomCode, {
      'dayNumber': dayNumber,
      'currentPhase': currentPhase.name,
      'players': playersMap,
      'werewolfTargetId': werewolfTarget?.id,
      'witchReviveTargetId': witchReviveTargetId,
    });
  }

  bool shouldRevealRole(OnlinePlayer player) {
    if (currentState == PlayState.ended) return true;
    if (!player.isAlive || player.id == myPlayer?.id) return true;
    if (myPlayer?.role.team == RoleTeam.werewolf && player.role.team == RoleTeam.werewolf) return true;

    // Tiên tri chỉ thấy vai trò của người đã soi vào BAN ĐÊM
    if (player.hasBeenScannedBySeer && currentPhase == GamePhase.night) return true;

    if (lover1 != null && lover2 != null) {
      if ((myPlayer?.id == lover1!.id && player.id == lover2!.id) || (myPlayer?.id == lover2!.id && player.id == lover1!.id)) return true;
    }
    if (xathuRevealed && player.role.id == 'xa_thu') return true;
    return false;
  }

  Color getPlayerBorderColor(OnlinePlayer player) {
    if (!player.isAlive) return Colors.grey[700]!;
    if (player.id == myPlayer?.id) return player.role.primaryColor;
    if (myPlayer?.role.team == RoleTeam.werewolf && player.role.team == RoleTeam.werewolf) return const Color(0xFFEF5350).withValues(alpha: 0.5);
    if (player.hasBeenScannedBySeer) {
      final isWolf = player.role.team == RoleTeam.werewolf || player.id == cursedPlayerId;
      return isWolf ? const Color(0xFFEF5350) : const Color(0xFF81C784);
    }
    return Colors.white24;
  }

  String getPlayerRoleNameDisplay(OnlinePlayer player) {
    if (!shouldRevealRole(player)) return 'ẨN VAI TRÒ';
    // Bản thân luôn thấy vai trò thật của mình, không bị đánh lừa bởi lời nguyền
    if (player.id == myPlayer?.id) return player.role.name;
    // Đối với người khác (như Tiên Tri), nếu bị nguyền thì hiện Ma Sói
    if (currentState != PlayState.ended && player.id == cursedPlayerId && player.isAlive) return 'role_soi';
    return player.role.name;
  }

  IconData getPlayerRoleIconDisplay(OnlinePlayer player) {
    if (!shouldRevealRole(player)) return Icons.help_outline;
    // Bản thân luôn thấy icon thật của mình
    if (player.id == myPlayer?.id) return player.role.icon;
    // Đối với người khác, nếu bị nguyền thì hiện icon sói
    if (currentState != PlayState.ended && player.id == cursedPlayerId && player.isAlive) {
      return Icons.pets;
    }
    return player.role.icon;
  }

  Color getPlayerRoleColorDisplay(OnlinePlayer player) {
    if (!shouldRevealRole(player)) return Colors.transparent;
    // Bản thân luôn thấy màu thật của mình
    if (player.id == myPlayer?.id) return player.role.secondaryColor;
    // Đối với người khác, nếu bị nguyền thì hiện màu đỏ của sói
    if (currentState != PlayState.ended && player.id == cursedPlayerId && player.isAlive) {
      return const Color(0xFFEF5350); // Màu đỏ đặc trưng của Ma Sói
    }
    return player.role.secondaryColor;
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

    final isGhost = myPlayer != null ? !myPlayer!.isAlive : false;
    // Ưu tiên kênh Hồn ma nếu đã chết, nếu còn sống và là Sói vào ban đêm thì vào kênh Sói
    final isWolfChannel = !isGhost && (forceWerewolfOnly || (currentPhase == GamePhase.night && myPlayer?.role.team == RoleTeam.werewolf));

    if (roomCode.isEmpty) {
      // OFFLINE: Thêm tin nhắn local và giả lập phản hồi bot
      chatMessages.add(ChatMessage(senderName: userName, content: text, isWerewolfOnly: isWolfChannel, isGhost: isGhost, time: DateTime.now()));
      simulateBotChatResponse(text);
      notifyListeners();
    } else {
      // ONLINE: Gửi lên Firestore (stream sẽ tự cập nhật lại chatMessages)
      firestoreSvc.sendChatMessage(roomCode, {
        'senderName': userName,
        'content': text,
        'isWerewolfOnly': isWolfChannel,
        'isGhost': isGhost,
        'isSystem': false,
        'time': Timestamp.now()
      });
    }
    _updateActivity();
  }

  bool isChatDisabled() {
    if (currentState != PlayState.playing) return false;
    if (myPlayer != null && !myPlayer!.isAlive) return false; // Hồn ma luôn có thể chat
    if (currentPhase == GamePhase.night) return myPlayer?.role.team != RoleTeam.werewolf;
    return false;
  }

  String getChatHintText() {
    if (currentState != PlayState.playing) return langSvc.t('chat_hint');
    if (myPlayer != null && !myPlayer!.isAlive) return langSvc.t('chat_ghost_hint');
    if (currentPhase == GamePhase.night) {
      return myPlayer?.role.team == RoleTeam.werewolf ? langSvc.t('chat_wolf_hint') : langSvc.t('chat_night_disabled');
    }
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
      final isHost = myPlayer?.isHost ?? (lobbyPlayerNames.isNotEmpty && lobbyPlayerNames[0].trim() == userName.trim());
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
      startPhaseTimer(durationDay);
    }
    notifyListeners();
  }

  void transitionToVoting() {
    if (currentState == PlayState.ended || hunterSkillTriggered) return;
    stopPeriodicBotChat();
    _processDayResults();
    currentPhase = GamePhase.voting;
    startPhaseTimer(durationVoting);
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
      startPhaseTimer(durationNight);
    }
    notifyListeners();
  }

  void _processNightResults() {
    // TÍNH TOÁN MỤC TIÊU CỦA SÓI: Chỉ giết 1 người duy nhất có số phiếu cao nhất
    Map<int, int> biteVotes = {};
    for (var p in players.where((p) => p.isAlive && p.role.team == RoleTeam.werewolf)) {
      if (p.votedForId != null && p.votedForId != -1) {
        // CHỈ TÍNH VOTE NẾU MỤC TIÊU KHÔNG PHẢI LÀ SÓI
        try {
          final target = players.firstWhere((pl) => pl.id == p.votedForId);
          if (target.role.team != RoleTeam.werewolf) {
            int weight = (p.role.id == 'soi_dau_dan') ? 2 : 1;
            biteVotes[p.votedForId!] = (biteVotes[p.votedForId!] ?? 0) + weight;
          }
        } catch (_) {}
      }
    }

    int? finalWolfTargetId;
    if (biteVotes.isNotEmpty) {
      int maxVotes = 0;
      for (var v in biteVotes.values) {
        if (v > maxVotes) maxVotes = v;
      }
      List<int> tiedTargets = biteVotes.entries.where((e) => e.value == maxVotes).map((e) => e.key).toList();
      
      // Xử lý hòa: Chọn ngẫu nhiên 1 người trong số những người bị vote nhiều nhất
      finalWolfTargetId = tiedTargets[Random().nextInt(tiedTargets.length)];
    }

    // Xử lý Phù Thủy hồi sinh trước
    if (witchReviveTargetId != null) {
      final target = players.firstWhere((p) => p.id == witchReviveTargetId);
      target.isAlive = true;
      target.isProtected = true;
    }

    // Sau đó mới tính toán cái chết
    if (finalWolfTargetId != null) {
      final victim = players.firstWhere((p) => p.id == finalWolfTargetId);
      if (!victim.isProtected && victim.id != witchReviveTargetId) {
        killPlayer(victim, langSvc.t('night_casualty').replaceFirst('%s', victim.name));
      }
    }
    
    for (var p in players) {
      if (p.isPoisoned && p.isAlive) {
        killPlayer(p, langSvc.t('poison_casualty').replaceFirst('%s', p.name));
      }
    }
    
    witchReviveTargetId = null;
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
      p.votedForId = null; // Xóa dấu vết vote ban đêm
      p.isTargeted = false;
      p.wasProtectedByBodyguard = false;
      p.wasHealedByWitch = false;
      p.hasBeenScannedBySeer = false; // Reset hiệu lực soi khi trời sáng
    }
    hasUsedSeerScan = false;
    hasUsedBodyguardProtect = false;
    hasUsedHealThisNight = false;
    hasUsedPoisonThisNight = false;
    xathuHasShotToday = false;
    cursedPlayerId = null;
    selectedPlayer = null;
    werewolfTarget = null;
    witchReviveTargetId = null; // Reset mục tiêu hồi sinh của Phù Thủy
    cupidSelections.clear();    // Reset lựa chọn ghép đôi
    _myNightBiteTargetId = null; // Reset mục tiêu cắn khi bắt đầu ngày mới
  }

  void _resetLocalDayStates() {
    addLog(langSvc.t('voting_start'));
    _myCurrentVoteTargetId = null; // Reset vote target mỗi khi vào ban ngày
    for (var p in players) {
      p.voteCount = 0;
      p.isTargeted = false;
    }
  }

  void _resetLocalVotingStates() {
    _myCurrentVoteTargetId = null; // Reset vote target khi bắt đầu đêm mới
    for (var p in players) {
      p.voteCount = 0;
      p.isTargeted = false; // Reset isTargeted khi bắt đầu đêm mới
    }
    addLog('${langSvc.t('night_number')} $dayNumber ${langSvc.t('night_start')}');
  }

  void executeVote(OnlinePlayer target) {
    // CHỈ CHO PHÉP VOTE NẾU: Mục tiêu còn sống VÀ Bản thân còn sống
    if (myPlayer == null || !myPlayer!.isAlive || !target.isAlive) return;
    
    const weight = 1;
    final bool isCanceling = _myCurrentVoteTargetId == target.id;
    final oldTargetId = _myCurrentVoteTargetId;
    
    _myCurrentVoteTargetId = isCanceling ? null : target.id;
    _lastVoteTime = DateTime.now();

    for (var p in players) {
      if (oldTargetId != null && p.id == oldTargetId) {
        p.voteCount = (p.voteCount - weight).clamp(0, 999);
      }
      if (!isCanceling && p.id == target.id) {
        p.voteCount += weight;
      }
      if (p.name == userName) p.votedForId = _myCurrentVoteTargetId;
    }

    if (roomCode.isNotEmpty) {
      _voteDebounceTimer?.cancel();
      _voteDebounceTimer = Timer(const Duration(milliseconds: 150), () {
        if (roomCode.isNotEmpty && _myCurrentVoteTargetId != _lastSyncedVoteId) {
          firestoreSvc.submitVote(roomCode, myPlayer!.id, _lastSyncedVoteId, _myCurrentVoteTargetId);
          _lastSyncedVoteId = _myCurrentVoteTargetId;
        }
      });
    }
    _updateActivity();
    notifyListeners();
  }

  void killPlayer(OnlinePlayer player, String reason) {
    if (!player.isAlive) return;
    player.isAlive = false;

    // Chỉ thêm log nếu không phải đang trong trận online (online dùng system messages)
    if (roomCode.isEmpty) {
      addLog(reason);
    }

    if (lover1 != null && lover2 != null) {
      if (player.id == lover1!.id && lover2!.isAlive) {
        killPlayer(lover2!, langSvc.t('lover_tragedy'));
      } else if (player.id == lover2!.id && lover1!.isAlive) {
        killPlayer(lover1!, langSvc.t('lover_tragedy'));
      }
    }

    // Logic kỹ năng thợ săn
    if (player.role.id == 'tho_san') {
      if (player.id == myPlayer?.id) {
        if (roomCode.isNotEmpty) {
          _triggerHunterSkill(player); // Online: kích hoạt và set timeout
        } else {
          hunterSkillTriggered = true;
          hunterWhoDied = player;
        }
      } else if (roomCode.isEmpty) {
        simulateBotHunterShot(player);
      }
    }
  }

  void executeSeerScan(OnlinePlayer target) {
    target.hasBeenScannedBySeer = true;
    hasUsedSeerScan = true;
    final isW = target.role.team == RoleTeam.werewolf || target.id == cursedPlayerId;
    addLog(langSvc.t('seer_result').replaceFirst('%s', target.name).replaceFirst('%s', isW ? langSvc.t('wolf_red') : langSvc.t('villager_green')));
    if (roomCode.isNotEmpty) {
      // Online: chỉ cập nhật field cục bộ (hasBeenScannedBySeer chỉ lưu local)
      // Không cần đồng bộ lên server vì chỉ Tiên Tri mới thấy
    } else {
      syncGameState();
    }
    selectedPlayer = null;
    _updateActivity();
    notifyListeners();
  }

  void executeBodyguardProtect(OnlinePlayer target) {
    target.isProtected = true;
    target.wasProtectedByBodyguard = true;
    hasUsedBodyguardProtect = true;
    lastProtectedPlayerId = target.id;
    addLog(langSvc.t('guard_log').replaceFirst('%s', target.name));
    if (roomCode.isNotEmpty) {
      // Online: dùng Transaction để chỉ cập nhật đúng các field của mục tiêu
      firestoreSvc.updatePlayerField(roomCode, target.id, {
        'isProtected': true,
        'wasProtectedByBodyguard': true,
      });
    } else {
      syncGameState();
    }
    selectedPlayer = null;
    _updateActivity();
    notifyListeners();
  }

  void executeWitchHeal(OnlinePlayer target) {
    final bool wasDead = !target.isAlive;
    
    // Cập nhật trạng thái local ngay lập tức
    target.isAlive = true;
    target.isProtected = true;
    target.wasHealedByWitch = true;
    witchReviveTargetId = target.id;
    hasHealPotion = false;
    hasUsedHealThisNight = true;

    // Ghi nhật ký với key đúng từ language_service
    if (wasDead) {
      addLog(langSvc.t('witch_revive_log').replaceFirst('%s', target.name));
    } else {
      addLog(langSvc.t('witch_save_log').replaceFirst('%s', target.name));
    }

    if (roomCode.isNotEmpty) {
      // ONLINE: Sử dụng transaction gộp để đảm bảo tính nguyên tử
      firestoreSvc.useWitchHeal(roomCode, target.id);
    } else {
      // OFFLINE: đồng bộ toàn bộ trạng thái
      syncGameState();
    }
    
    selectedPlayer = null;
    _updateActivity();
    notifyListeners();
  }


  void executeWitchPoison(OnlinePlayer target) {
    target.isPoisoned = true;
    hasPoisonPotion = false;
    hasUsedPoisonThisNight = true;
    if (roomCode.isNotEmpty) {
      firestoreSvc.updatePlayerField(roomCode, target.id, {'isPoisoned': true});
    } else {
      syncGameState();
    }
    selectedPlayer = null;
    _updateActivity();
    notifyListeners();
  }

  void executeWerewolfBite(OnlinePlayer target) {
    // CHỈ CHO PHÉP CẮN NẾU: Bản thân còn sống VÀ mục tiêu còn sống VÀ không phải đồng đội
    if (myPlayer == null || !myPlayer!.isAlive || !target.isAlive || target.role.team == RoleTeam.werewolf) return;
    
    final weight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    final bool isCanceling = _myNightBiteTargetId == target.id;
    final oldBiteId = _myNightBiteTargetId;
    
    _myNightBiteTargetId = isCanceling ? null : target.id;
    _lastVoteTime = DateTime.now();

    for (var p in players) {
      if (oldBiteId != null && p.id == oldBiteId) {
        p.voteCount = (p.voteCount - weight).clamp(0, 999);
      }
      if (!isCanceling && p.id == target.id) {
        p.voteCount += weight;
      }
      if (p.name == userName) p.votedForId = _myNightBiteTargetId;
    }

    _updateWerewolfLeadingTarget();

    if (roomCode.isNotEmpty) {
      _biteDebounceTimer?.cancel();
      _biteDebounceTimer = Timer(const Duration(milliseconds: 150), () {
        if (roomCode.isNotEmpty && _myNightBiteTargetId != _lastSyncedBiteId) {
          firestoreSvc.submitBite(roomCode, myPlayer!.id, myPlayer!.role.id, _lastSyncedBiteId, _myNightBiteTargetId);
          _lastSyncedBiteId = _myNightBiteTargetId;
        }
      });
    }
    _updateActivity();
    notifyListeners();
  }

  void cancelWerewolfBite() {
    // CHỈ CHO PHÉP HỦY NẾU: Bản thân còn sống
    if (myPlayer == null || !myPlayer!.isAlive || _myNightBiteTargetId == null) return;

    final weight = myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    final oldBiteId = _myNightBiteTargetId;
    _myNightBiteTargetId = null;
    _lastVoteTime = DateTime.now();

    for (var p in players) {
      if (p.id == oldBiteId) p.voteCount = (p.voteCount - weight).clamp(0, 999);
      if (p.name == userName) p.votedForId = null;
    }
    _updateWerewolfLeadingTarget();

    if (roomCode.isNotEmpty) {
      _biteDebounceTimer?.cancel();
      _biteDebounceTimer = Timer(const Duration(milliseconds: 150), () {
        if (roomCode.isNotEmpty && _myNightBiteTargetId != _lastSyncedBiteId) {
          firestoreSvc.submitBite(roomCode, myPlayer!.id, myPlayer!.role.id, _lastSyncedBiteId, null);
          _lastSyncedBiteId = null;
        }
      });
    }
    _updateActivity();
    notifyListeners();
  }

  void _updateWerewolfLeadingTarget() {
    OnlinePlayer? leader;
    int maxV = 0;
    bool isTie = false;
    for (var p in players) {
      if (p.voteCount > maxV) {
        maxV = p.voteCount;
        leader = p;
        isTie = false;
      } else if (p.voteCount == maxV && maxV > 0) {
        isTie = true;
      }
    }
    // Đồng bộ với server: Nếu huề phiếu thì không có mục tiêu dẫn đầu (hiển thị đồng đều)
    werewolfTarget = isTie ? null : leader;
  }

  void executeCupidLink() {
    if (currentPhase != GamePhase.night) return; // Bảo vệ: Chỉ cho phép ghép đôi ban đêm
    if (cupidSelections.length < 2) return;

    lover1 = cupidSelections[0];
    lover2 = cupidSelections[1];
    if (roomCode.isNotEmpty) {
      firestoreSvc.updateRoomData(roomCode, {'lover1Id': lover1!.id, 'lover2Id': lover2!.id});
    } else {
      syncGameState();
    }
    selectedPlayer = null;
    _updateActivity();
    notifyListeners();
  }

  void executeCurse(OnlinePlayer target) {
    cursedPlayerId = target.id;
    addLog(langSvc.t('curse_log').replaceFirst('%s', target.name));
    if (roomCode.isNotEmpty) {
      firestoreSvc.updateRoomData(roomCode, {'cursedPlayerId': cursedPlayerId});
    } else {
      syncGameState();
    }
    _updateActivity();
    notifyListeners();
  }

  void cancelCurse() {
    cursedPlayerId = null;
    if (roomCode.isNotEmpty) {
      firestoreSvc.updateRoomData(roomCode, {'cursedPlayerId': null});
    } else {
      syncGameState();
    }
    _updateActivity();
    notifyListeners();
  }

  void cancelBodyguardProtect() {
    Map<int, Map<String, dynamic>> updates = {};
    for (var p in players) {
      if (p.wasProtectedByBodyguard) {
        p.isProtected = false;
        p.wasProtectedByBodyguard = false;
        updates[p.id] = {'isProtected': false, 'wasProtectedByBodyguard': false};
      }
    }
    hasUsedBodyguardProtect = false;
    lastProtectedPlayerId = null;
    if (roomCode.isNotEmpty && updates.isNotEmpty) {
      firestoreSvc.updateMultiplePlayerFields(roomCode, updates);
    } else if (roomCode.isEmpty) {
      syncGameState();
    }
    _updateActivity();
    notifyListeners();
  }

  void cancelWitchAction() {
    Map<int, Map<String, dynamic>> updates = {};
    if (hasUsedHealThisNight) {
      for (var p in players) {
        if (p.wasHealedByWitch) {
          p.wasHealedByWitch = false;
          p.isProtected = false;
          // Nếu người này vừa được hồi sinh, trả họ về trạng thái chết
          if (p.id == witchReviveTargetId) {
            p.isAlive = false;
            updates[p.id] = {'wasHealedByWitch': false, 'isProtected': false, 'isAlive': false};
          } else {
            updates[p.id] = {'wasHealedByWitch': false, 'isProtected': false};
          }
        }
      }
      hasHealPotion = true;
      hasUsedHealThisNight = false;
      if (roomCode.isNotEmpty) {
        if (updates.isNotEmpty) firestoreSvc.updateMultiplePlayerFields(roomCode, updates);
        firestoreSvc.updateRoomData(roomCode, {'witchReviveTargetId': null});
      } else {
        syncGameState();
      }
      witchReviveTargetId = null;
    } else if (hasUsedPoisonThisNight) {
      for (var p in players) {
        if (p.isPoisoned) {
          p.isPoisoned = false;
          updates[p.id] = {'isPoisoned': false};
        }
      }
      hasPoisonPotion = true;
      hasUsedPoisonThisNight = false;
      if (roomCode.isNotEmpty && updates.isNotEmpty) {
        firestoreSvc.updateMultiplePlayerFields(roomCode, updates);
      } else if (roomCode.isEmpty) {
        syncGameState();
      }
    }
    _updateActivity();
    notifyListeners();
  }

  void executeGunnerShoot(OnlinePlayer target) {
    if (xathuBullets <= 0 || xathuHasShotToday || !target.isAlive) return;
    xathuBullets--;
    xathuRevealed = true;
    xathuHasShotToday = true;
    killPlayer(target, langSvc.t('gunner_log').replaceFirst('%s', target.name));
    
    if (roomCode.isNotEmpty) {
      // TỐI ƯU: Gộp tất cả cập nhật vào 1 Transaction duy nhất để đạt tốc độ < 0.1s cho máy khác
      firestoreSvc.executeKillAction(
        roomCode: roomCode,
        targetId: target.id,
        roomUpdates: {
          'xathuRevealed': true,
          'xathuBullets': xathuBullets,
          'xathuHasShotToday': true,
        },
        systemMessage: {
          'senderName': 'system',
          'content': 'gunner_log',
          'targetName': target.name,
          'isSystem': true,
        }
      );
    } else {
      syncGameState();
    }
    
    selectedPlayer = null;
    _updateActivity();
    checkGameOver();
    notifyListeners();
  }

  void executeHunterShot(OnlinePlayer? target) {
    _hunterTimeoutTimer?.cancel();
    hunterSkillTriggered = false;

    if (target != null) {
      killPlayer(target, langSvc.t('hunter_log').replaceFirst('%s', target.name));
      
      if (roomCode.isNotEmpty) {
        // TỐI ƯU: Gộp tất cả cập nhật vào 1 Transaction duy nhất
        firestoreSvc.executeKillAction(
          roomCode: roomCode,
          targetId: target.id,
          roomUpdates: {'hunterSkillActive': false},
          systemMessage: {
            'senderName': 'system',
            'content': 'hunter_log',
            'targetName': target.name,
            'isSystem': true,
          }
        );
      }
    } else {
      // Nếu thợ săn không bắn ai
      if (roomCode.isNotEmpty) {
        firestoreSvc.updateRoomData(roomCode, {'hunterSkillActive': false});
      }
    }

    _updateActivity();
    final gameOver = checkGameOver();

    // NẾU HẾT GIỜ TRONG LÚC THỢ SĂN ĐANG CHỌN -> CHUYỂN GIAI ĐOẠN NGAY SAU KHI BẮN
    if (gameOver.isEmpty && phaseTimerSeconds <= 0) {
      if (roomCode.isNotEmpty) {
        _triggerNextPhaseOnFirestore();
      } else {
        _triggerNextPhaseOffline();
      }
    }

    notifyListeners();
  }

  /// Thợ Săn chết: kích hoạt kỹ năng + đặt timeout 15 giây
  void _triggerHunterSkill(OnlinePlayer hunter) {
    if (roomCode.isEmpty) return;
    hunterSkillTriggered = true;
    hunterWhoDied = hunter;
    firestoreSvc.setHunterSkillActive(roomCode, true, hunterPlayerId: hunter.id);
    notifyListeners();

    // Timeout 15 giây: nếu Thợ Săn không bắn, tự động bỏ qua
    _hunterTimeoutTimer?.cancel();
    _hunterTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (hunterSkillTriggered) {
        debugPrint('Hunter timeout: auto-skipping hunter skill');
        executeHunterShot(null);
      }
    });
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
    if (winnerMessage != null) return winnerMessage!;
    if (currentState != PlayState.playing || players.isEmpty) return '';

    // 1. Kiểm tra Kẻ Ngốc (Nerd) bị treo cổ
    if (isNerdHanged) {
      winnerMessage = '${langSvc.t('role_nerd')} thắng!';
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return winnerMessage!;
    }

    // 2. Kiểm tra Phe Tình Nhân
    final bool bothLoversAlive = lover1 != null && lover2 != null && lover1!.isAlive && lover2!.isAlive;
    int aliveCount = players.where((p) => p.isAlive).length;

    if (bothLoversAlive) {
      // Phe Tình Nhân chỉ thắng khi là những người duy nhất sống sót (hoặc + Cupid)
      if (aliveCount == 2 || (aliveCount == 3 && players.any((p) => p.isAlive && p.role.id == 'cupid'))) {
        winnerMessage = 'Phe Tình Nhân đã giành chiến thắng! ❤️';
        currentState = PlayState.ended;
        _phaseTimer?.cancel();
        return winnerMessage!;
      }
      return ''; // NẾU TÌNH NHÂN CÒN SỐNG: Chưa phân định thắng thua đội Dân/Sói
    }

    int w = players.where((p) => p.isAlive && p.role.team == RoleTeam.werewolf).length;
    int g = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf).length;

    // 3. Phe Dân Làng thắng
    if (w == 0) {
      winnerMessage = 'Dân Làng thắng!';
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return winnerMessage!;
    }

    // 4. Phe Ma Sói thắng
    if (w >= g) {
      winnerMessage = 'Ma Sói thắng!';
      currentState = PlayState.ended;
      _phaseTimer?.cancel();
      return winnerMessage!;
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
          // BAN NGÀY: Mọi người (kể cả Sói đầu đàn) đều chỉ có 1 phiếu
          t[Random().nextInt(t.length)].voteCount += 1;
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
    final targets = players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf).toList();
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
    _messagesSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _hunterTimeoutTimer?.cancel();
    _zombieTimer?.cancel();
    super.dispose();
  }
}
