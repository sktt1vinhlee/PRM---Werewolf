import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum PlayState { lobby, playing }
enum GamePhase { night, day }
enum RoleTeam { villager, werewolf, neutral }

class RoleDefinition {
  final String id;
  final String name;
  final String description;
  final RoleTeam team;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isUnique;

  RoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.team,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isUnique,
  });
}

class OnlinePlayer {
  final int id;
  final String name;
  final RoleDefinition role;
  bool isAlive;
  int voteCount;
  bool isTargeted;
  bool hasBeenScannedBySeer;
  bool isProtected;
  bool isPoisoned;

  OnlinePlayer({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
    this.voteCount = 0,
    this.isTargeted = false,
    this.hasBeenScannedBySeer = false,
    this.isProtected = false,
    this.isPoisoned = false,
  });
}

class ChatMessage {
  final String senderName;
  final String content;
  final bool isWerewolfOnly;
  final bool isGhost;
  final bool isSystem;
  final DateTime time;

  ChatMessage({
    required this.senderName,
    required this.content,
    this.isWerewolfOnly = false,
    this.isGhost = false,
    this.isSystem = false,
    required this.time,
  });
}

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  PlayState _currentState = PlayState.lobby;
  GamePhase _currentPhase = GamePhase.night;
  int _playerCount = 12;
  String _userName = 'Sói Đầu Đàn';
  String _roomCode = '';
  bool _canPop = false;
  bool _isLobbyLoading = false;
  int _dayNumber = 1;

  List<OnlinePlayer> _players = [];
  OnlinePlayer? _myPlayer;
  OnlinePlayer? _selectedPlayer;
  List<String> _actionLogs = [];

  // Simulated Chat
  List<ChatMessage> _chatMessages = [];
  bool _showChatTab = true;
  Timer? _botChatTimer;
  final TextEditingController _chatController = TextEditingController();

  // Night action variables
  bool _hasUsedSeerScan = false;
  bool _hasUsedBodyguardProtect = false;
  int? _lastProtectedPlayerId;
  bool _hasHealPotion = true;
  bool _hasPoisonPotion = true;
  bool _hasUsedHealThisNight = false;
  bool _hasUsedPoisonThisNight = false;
  OnlinePlayer? _werewolfTarget;

  // Role states
  OnlinePlayer? _lover1;
  OnlinePlayer? _lover2;
  int? _cursedPlayerId;
  int _xathuBullets = 2;
  bool _xathuRevealed = false;
  bool _hunterSkillTriggered = false;
  OnlinePlayer? _hunterWhoDied;
  List<OnlinePlayer> _cupidSelections = [];

  static final List<RoleDefinition> _roleDefinitions = [
    RoleDefinition(
      id: 'dan',
      name: 'Dân Làng',
      description: 'Không có chức năng, giết hết sói thì win.',
      team: RoleTeam.villager,
      icon: Icons.person,
      primaryColor: const Color(0xFF2E7D32),
      secondaryColor: const Color(0xFF4CAF50),
      isUnique: false,
    ),
    RoleDefinition(
      id: 'soi',
      name: 'Ma Sói',
      description: 'Giết dân ban đêm. Số sói bằng số dân thì win.',
      team: RoleTeam.werewolf,
      icon: Icons.pets,
      primaryColor: const Color(0xFFC62828),
      secondaryColor: const Color(0xFFEF5350),
      isUnique: false,
    ),
    RoleDefinition(
      id: 'soi_nguyen',
      name: 'Sói Nguyền',
      description: 'Nguyền 1 dân thành sói, khi tiên tri xem thg dân thành sói.',
      team: RoleTeam.werewolf,
      icon: Icons.auto_awesome,
      primaryColor: const Color(0xFF8E24AA),
      secondaryColor: const Color(0xFFBA68C8),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'soi_dau_dan',
      name: 'Sói Đầu Đàn',
      description: '1 vote = 2 vote sói thường.',
      team: RoleTeam.werewolf,
      icon: Icons.gavel,
      primaryColor: const Color(0xFFD84315),
      secondaryColor: const Color(0xFFFF7043),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'xa_thu',
      name: 'Xạ Thủ',
      description: 'Có 2 viên đạn, chỉ bắn vào ban ngày, bắn lần đầu thì lộ role.',
      team: RoleTeam.villager,
      icon: Icons.gps_fixed,
      primaryColor: const Color(0xFF0277BD),
      secondaryColor: const Color(0xFF29B6F6),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'tien_tri',
      name: 'Tiên Tri',
      description: 'Soi sói, phe dân.',
      team: RoleTeam.villager,
      icon: Icons.remove_red_eye,
      primaryColor: const Color(0xFF00838F),
      secondaryColor: const Color(0xFF26C6DA),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'cupid',
      name: 'Cupid',
      description: 'Ghép 2 đứa với nhau. (2 đứa xem thẻ nhau, chết cả đôi), phe dân.',
      team: RoleTeam.villager,
      icon: Icons.favorite,
      primaryColor: const Color(0xFFAD1457),
      secondaryColor: const Color(0xFFEC407A),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'tho_san',
      name: 'Thợ Săn',
      description: 'Chết thì đem thêm 1 đứa chết cùng, phe dân.',
      team: RoleTeam.villager,
      icon: Icons.colorize,
      primaryColor: const Color(0xFFEF6C00),
      secondaryColor: const Color(0xFFFFA726),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'bao_ve',
      name: 'Bảo Vệ',
      description: 'Mỗi đêm bảo vệ 1 đứa, không được bảo vệ 1 đứa 2 đêm liên tục, phe dân.',
      team: RoleTeam.villager,
      icon: Icons.shield,
      primaryColor: const Color(0xFF1565C0),
      secondaryColor: const Color(0xFF42A5F5),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'phu_thuy',
      name: 'Phù Thủy',
      description: '1 bình cứu 1 bình giết ban đêm thích dùng lúc nào cũng được, phe dân.',
      team: RoleTeam.villager,
      icon: Icons.science,
      primaryColor: const Color(0xFF6A1B9A),
      secondaryColor: const Color(0xFFAB47BC),
      isUnique: true,
    ),
    RoleDefinition(
      id: 'nerd',
      name: 'Kẻ Ngốc (Nerd)',
      description: 'Thằng ngu, bên t3 nó chết treo cổ thì nó win.',
      team: RoleTeam.neutral,
      icon: Icons.psychology,
      primaryColor: const Color(0xFF9E9D24),
      secondaryColor: const Color(0xFFD4E157),
      isUnique: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _generateRoomCode();
    _initializeLobbyChat();
  }

  @override
  void dispose() {
    _botChatTimer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  void _generateRoomCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    _roomCode = 'WS-${List.generate(6, (index) => chars[random.nextInt(chars.length)]).join()}';
  }

  void _initializeLobbyChat() {
    _chatMessages = [
      ChatMessage(
        senderName: 'Hệ thống',
        content: 'Tạo phòng thành công. Đang chờ người chơi khác kết nối...',
        isSystem: true,
        time: DateTime.now(),
      ),
      ChatMessage(
        senderName: 'Tuấn Tú',
        content: 'Chào cả phòng nha, có ai ở đây chưa?',
        time: DateTime.now().subtract(const Duration(seconds: 15)),
      ),
      ChatMessage(
        senderName: 'Khánh Linh',
        content: 'Hello, chúc mọi người game mới vui vẻ nhé!',
        time: DateTime.now().subtract(const Duration(seconds: 10)),
      ),
    ];
    _actionLogs = [
      'Hệ thống: Bạn đã kết nối và tham gia phòng $_roomCode.',
      'Hệ thống: Tuấn Tú đã tham gia phòng.',
      'Hệ thống: Khánh Linh đã tham gia phòng.',
    ];
  }

  void _initializeOnlineGame() {
    final random = Random();
    List<RoleDefinition> allocatedRoles = [];

    _lover1 = null;
    _lover2 = null;
    _cursedPlayerId = null;
    _xathuBullets = 2;
    _xathuRevealed = false;
    _hunterSkillTriggered = false;
    _hunterWhoDied = null;
    _cupidSelections = [];

    int targetWolves = max(1, (_playerCount / 4).round());
    List<RoleDefinition> wolfPool = [];
    bool hasAlpha = random.nextBool() && targetWolves >= 2;
    if (hasAlpha) {
      wolfPool.add(_roleDefinitions.firstWhere((r) => r.id == 'soi_dau_dan'));
    }
    bool hasCursed = random.nextBool() && targetWolves >= (hasAlpha ? 3 : 2);
    if (hasCursed) {
      wolfPool.add(_roleDefinitions.firstWhere((r) => r.id == 'soi_nguyen'));
    }
    while (wolfPool.length < targetWolves) {
      wolfPool.add(_roleDefinitions.firstWhere((r) => r.id == 'soi'));
    }
    allocatedRoles.addAll(wolfPool);

    List<RoleDefinition> specialPool = _roleDefinitions
        .where((r) => r.isUnique && r.team != RoleTeam.werewolf)
        .toList();
    specialPool.shuffle(random);

    int remainingSlots = _playerCount - targetWolves;
    int maxSpecials = min(specialPool.length, remainingSlots);
    int targetSpecials = maxSpecials > 1 ? random.nextInt(maxSpecials) + 1 : maxSpecials;
    if (targetSpecials > remainingSlots) targetSpecials = remainingSlots;

    List<RoleDefinition> selectedSpecials = specialPool.take(targetSpecials).toList();
    allocatedRoles.addAll(selectedSpecials);

    RoleDefinition villagerDef = _roleDefinitions.firstWhere((r) => r.id == 'dan');
    while (allocatedRoles.length < _playerCount) {
      allocatedRoles.add(villagerDef);
    }

    allocatedRoles.shuffle(random);

    final names = [
      'Minh Đức', 'Khánh Linh', 'Sơn Hải', 'Tuấn Tú', 'Hoài Thu',
      'Gia Bảo', 'Quỳnh Anh', 'Nhật Minh', 'Phương Thảo', 'Hồng Quân',
      'Thanh Lâm', 'Mai Chi', 'Trí Dũng', 'Ngọc Diệp', 'Thu Trang',
      'Thế Anh', 'Yến Vy', 'Văn Nam'
    ];
    names.shuffle(random);

    int myIndex = random.nextInt(_playerCount);

    List<OnlinePlayer> list = [];
    for (int i = 0; i < _playerCount; i++) {
      String pName = i == myIndex ? '$_userName (Bạn)' : names[i % names.length];
      list.add(OnlinePlayer(
        id: i + 1,
        name: pName,
        role: allocatedRoles[i],
      ));
    }

    setState(() {
      _players = list;
      _myPlayer = list[myIndex];
      _selectedPlayer = null;
      _dayNumber = 1;
      _currentPhase = GamePhase.night;
      _hasHealPotion = true;
      _hasPoisonPotion = true;
      _hasUsedSeerScan = false;
      _hasUsedBodyguardProtect = false;
      _lastProtectedPlayerId = null;

      _actionLogs = [
        'Hệ thống: Phòng đấu $_roomCode đã được khởi tạo!',
        'Hệ thống: Bạn đã kết nối. Vai trò của bạn hiển thị phía dưới.',
        'Hệ thống: Trò chơi BẮT ĐẦU! Hãy tiêu diệt phe đối địch.',
        'Hệ thống: ĐÊM 1 bắt đầu. Đêm tối buông xuống, sói đang thức giấc...'
      ];

      _chatMessages = [
        ChatMessage(
          senderName: 'Hệ thống',
          content: 'Trận đấu bắt đầu! Kênh chat tổng mở thảo luận vào Ban Ngày.',
          isSystem: true,
          time: DateTime.now(),
        ),
      ];

      if (_myPlayer!.role.team == RoleTeam.werewolf) {
        _chatMessages.add(ChatMessage(
          senderName: 'Hệ thống',
          content: 'Kênh chat Bầy Sói đã mở.Trò chuyện bí mật vào Ban Đêm!',
          isSystem: true,
          isWerewolfOnly: true,
          time: DateTime.now(),
        ));
      }

      _currentState = PlayState.playing;
    });

    bool botIsCupid = list.any((p) => p.role.id == 'cupid') && _myPlayer?.role.id != 'cupid';
    if (botIsCupid) {
      final loversPool = List<OnlinePlayer>.from(list);
      loversPool.shuffle(random);
      _lover1 = loversPool[0];
      _lover2 = loversPool[1];
    }

    _simulateWerewolfNightTarget();
  }

  void _simulateWerewolfNightTarget() {
    final random = Random();
    List<OnlinePlayer> victims = _players
        .where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != _myPlayer?.id && p.id != _cursedPlayerId)
        .toList();

    if (victims.isEmpty) {
      victims = _players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != _cursedPlayerId).toList();
    }

    if (victims.isNotEmpty) {
      _werewolfTarget = victims[random.nextInt(victims.length)];
    }
  }

  void _addLog(String log) {
    setState(() {
      _actionLogs.add(log);
    });
  }

  void _killPlayer(OnlinePlayer player, String reason) {
    if (!player.isAlive) return;

    setState(() {
      player.isAlive = false;
      _addLog(reason);
    });

    if (_lover1 != null && _lover2 != null) {
      if (player.id == _lover1!.id && _lover2!.isAlive) {
        _killPlayer(_lover2!, 'Hệ thống: ${_lover1!.name} đã hy sinh. ${_lover2!.name} đau đớn tự sát chết theo! 💔');
      } else if (player.id == _lover2!.id && _lover1!.isAlive) {
        _killPlayer(_lover1!, 'Hệ thống: ${_lover2!.name} đã hy sinh. ${_lover1!.name} đau đớn tự sát chết theo! 💔');
      }
    }

    if (player.role.id == 'tho_san') {
      if (player.id == _myPlayer?.id) {
        setState(() {
          _hunterSkillTriggered = true;
          _hunterWhoDied = player;
        });
        _addLog('Thợ Săn: Bạn đã chết! Chọn 1 người chơi để kéo theo.');
      } else {
        _simulateBotHunterShot(player);
      }
    }
  }

  void _simulateBotHunterShot(OnlinePlayer hunter) {
    final random = Random();
    List<OnlinePlayer> suspects = _players
        .where((p) => p.isAlive && p.id != hunter.id)
        .toList();
    if (suspects.isNotEmpty) {
      final victim = suspects[random.nextInt(suspects.length)];
      _killPlayer(victim, 'Thợ Săn: ${hunter.name} trước khi chết đã nổ súng kéo theo ${victim.name} (Vai trò: ${victim.role.name})! 🎯');
    }
  }

  void _executeSeerScan(OnlinePlayer target) {
    if (_hasUsedSeerScan) return;
    setState(() {
      target.hasBeenScannedBySeer = true;
      _hasUsedSeerScan = true;
      final isWolf = target.role.team == RoleTeam.werewolf || target.id == _cursedPlayerId;
      _addLog('Tiên Tri: Bạn đã soi ${target.name}. Kết quả: Phe ${isWolf ? "MA SÓI 🔴" : "DÂN LÀNG 🟢"}');
      _selectedPlayer = null;
    });
  }

  void _executeBodyguardProtect(OnlinePlayer target) {
    if (_hasUsedBodyguardProtect || target.id == _lastProtectedPlayerId) return;
    setState(() {
      target.isProtected = true;
      _hasUsedBodyguardProtect = true;
      _lastProtectedPlayerId = target.id;
      _addLog('Bảo Vệ: Bạn đã bảo vệ ${target.name} đêm nay.');
      _selectedPlayer = null;
    });
  }

  void _executeWitchHeal() {
    if (!_hasHealPotion || _werewolfTarget == null || _hasUsedHealThisNight) return;
    setState(() {
      _werewolfTarget!.isProtected = true;
      _hasHealPotion = false;
      _hasUsedHealThisNight = true;
      _addLog('Phù Thủy: Bạn đã sử dụng Bình Hồi Sinh cứu ${_werewolfTarget!.name}.');
      _selectedPlayer = null;
    });
  }

  void _executeWitchPoison(OnlinePlayer target) {
    if (!_hasPoisonPotion || !target.isAlive || _hasUsedPoisonThisNight) return;
    setState(() {
      target.isPoisoned = true;
      _hasPoisonPotion = false;
      _hasUsedPoisonThisNight = true;
      _addLog('Phù Thủy: Bạn đã sử dụng Bình Thuốc Độc lên ${target.name}.');
      _selectedPlayer = null;
    });
  }

  void _executeWerewolfBite(OnlinePlayer target) {
    setState(() {
      _werewolfTarget = target;
      _addLog('Ma Sói: Bạn quyết định cắn ${target.name} cùng bầy sói.');
      _selectedPlayer = null;
    });
  }

  void _executeCupidLink() {
    if (_cupidSelections.length != 2) return;
    setState(() {
      _lover1 = _cupidSelections[0];
      _lover2 = _cupidSelections[1];
      _addLog('Cupid: Kết đôi tình nhân thành công cho ${_lover1!.name} và ${_lover2!.name}! ❤️');
      if (_myPlayer?.id == _lover1!.id) {
        _addLog('Hệ thống: Bạn đã bị Cupid ghép đôi với ${_lover2!.name}!');
      } else if (_myPlayer?.id == _lover2!.id) {
        _addLog('Hệ thống: Bạn đã bị Cupid ghép đôi với ${_lover1!.name}!');
      }
      _selectedPlayer = null;
      _cupidSelections = [];
    });
  }

  void _executeCurse(OnlinePlayer target) {
    if (_cursedPlayerId != null) return;
    setState(() {
      _cursedPlayerId = target.id;
      _addLog('Sói Nguyền: Bạn đã nguyền rủa ${target.name}. Họ đã thành Sói.');
      _selectedPlayer = null;
    });
  }

  void _executeGunnerShoot(OnlinePlayer target) {
    if (_xathuBullets <= 0) return;
    setState(() {
      _xathuBullets--;
      if (!_xathuRevealed) {
        _xathuRevealed = true;
        _addLog('Xạ Thủ: Bạn bắn súng công khai! Lộ diện là XẠ THỦ.');
      }
      _selectedPlayer = null;
    });
    _killPlayer(target, 'Xạ Thủ: Bạn đã bắn chết ${target.name}! Vai trò: ${target.role.name}');
    _checkGameOver();
  }

  void _executeHunterShot(OnlinePlayer target) {
    if (!_hunterSkillTriggered || _hunterWhoDied == null) return;
    final name = _hunterWhoDied!.name;
    setState(() {
      _hunterSkillTriggered = false;
      _hunterWhoDied = null;
      _selectedPlayer = null;
    });
    _killPlayer(target, 'Thợ Săn: Bạn ($name) trước khi ngã xuống đã bắn chết ${target.name}! Vai trò: ${target.role.name}');
    _checkGameOver();
  }

  void _executeVote(OnlinePlayer target) {
    final voteWeight = _myPlayer?.role.id == 'soi_dau_dan' ? 2 : 1;
    setState(() {
      for (var p in _players) {
        if (p.isTargeted) {
          p.voteCount -= voteWeight;
          p.isTargeted = false;
        }
      }
      target.voteCount += voteWeight;
      target.isTargeted = true;
      _addLog('Thảo Luận: Bạn bỏ phiếu vote ${target.name} ($voteWeight phiếu).');
      _selectedPlayer = null;
    });
  }

  void _transitionToDay() {
    if (_hunterSkillTriggered) return;
    _stopPeriodicBotChat();

    if (_werewolfTarget != null && !_werewolfTarget!.isProtected) {
      _killPlayer(_werewolfTarget!, 'Hệ thống: Đêm qua, ${_werewolfTarget!.name} đã bị Ma Sói cắn chết! 🩸');
    }

    for (var p in _players) {
      if (p.isPoisoned && p.isAlive) {
        _killPlayer(p, 'Hệ thống: Đêm qua, Phù Thủy đã độc chết ${p.name}! 🧪');
      }
    }

    setState(() {
      _addLog('Hệ thống: Bình minh đã lên! Hãy tập trung thảo luận.');

      if (_dayNumber == 1 && _lover1 != null && _lover2 != null) {
        if (_myPlayer?.id == _lover1!.id) {
          _addLog('Hệ thống: Bạn đã bị Cupid ghép đôi với ${_lover2!.name}! ❤️');
        } else if (_myPlayer?.id == _lover2!.id) {
          _addLog('Hệ thống: Bạn đã bị Cupid ghép đôi với ${_lover1!.name}! ❤️');
        }
      }

      for (var p in _players) {
        p.isProtected = false;
        p.isPoisoned = false;
        p.voteCount = 0;
        p.isTargeted = false;
      }
      _hasUsedSeerScan = false;
      _hasUsedBodyguardProtect = false;
      _hasUsedHealThisNight = false;
      _hasUsedPoisonThisNight = false;
      _selectedPlayer = null;

      _currentPhase = GamePhase.day;
    });

    _checkGameOver();
    if (_currentState == PlayState.playing) {
      _startPeriodicBotChat();
    }
  }

  void _transitionToNight() {
    if (_hunterSkillTriggered) return;
    _stopPeriodicBotChat();

    final random = Random();
    List<OnlinePlayer> alivePlayers = _players.where((p) => p.isAlive).toList();

    for (var voter in alivePlayers) {
      if (voter.id == _myPlayer?.id) continue;

      List<OnlinePlayer> suspects = alivePlayers.where((p) => p.id != voter.id).toList();
      if (suspects.isNotEmpty) {
        final target = suspects[random.nextInt(suspects.length)];
        final voteWeight = voter.role.id == 'soi_dau_dan' ? 2 : 1;
        setState(() {
          target.voteCount += voteWeight;
        });
      }
    }

    OnlinePlayer? hangedPlayer;
    int maxVotes = 0;
    for (var p in alivePlayers) {
      if (p.voteCount > maxVotes) {
        maxVotes = p.voteCount;
        hangedPlayer = p;
      }
    }

    if (hangedPlayer != null && maxVotes > 0) {
      final isWolf = hangedPlayer.role.team == RoleTeam.werewolf || hangedPlayer.id == _cursedPlayerId;
      _killPlayer(hangedPlayer, 'Hệ thống: ${hangedPlayer.name} bị treo cổ với $maxVotes phiếu! Vai trò thực tế: ${hangedPlayer.role.name} (${isWolf ? "Phe Sói" : "Phe Dân"}) ⚖️');
    } else {
      _addLog('Hệ thống: Hòa phiếu. Không ai bị treo cổ hôm nay.');
    }

    setState(() {
      for (var p in _players) {
        p.voteCount = 0;
        p.isTargeted = false;
      }
      _selectedPlayer = null;
      _dayNumber++;
      _currentPhase = GamePhase.night;
      _addLog('Hệ thống: ĐÊM $_dayNumber bắt đầu. Mọi người nhắm mắt ngủ...');
    });

    _checkGameOver();
    if (_currentState == PlayState.playing) {
      _simulateWerewolfNightTarget();
    }
  }

  void _checkGameOver() {
    int aliveWolves = _players.where((p) => p.isAlive && (p.role.team == RoleTeam.werewolf || p.id == _cursedPlayerId)).length;
    int aliveGood = _players.where((p) => p.isAlive && p.role.team != RoleTeam.werewolf && p.id != _cursedPlayerId).length;

    bool isGameOver = false;
    bool isWin = false;
    String message = '';

    if (aliveWolves == 0) {
      isGameOver = true;
      isWin = _myPlayer?.role.team != RoleTeam.werewolf;
      message = 'Phe Dân Làng giành chiến thắng!';
    } else if (aliveWolves >= aliveGood) {
      isGameOver = true;
      isWin = _myPlayer?.role.team == RoleTeam.werewolf || _myPlayer?.id == _cursedPlayerId;
      message = 'Phe Ma Sói giành chiến thắng!';
    }

    if (isGameOver) {
      _stopPeriodicBotChat();
      _showGameOverDialog(isWin, message);
      return;
    }

    if (_myPlayer != null && !_myPlayer!.isAlive && !_actionLogs.contains('Hệ thống: Bạn đã tử nạn! Bạn đã bước vào Chế độ Quan sát (Spectator Mode). 👻')) {
      _stopPeriodicBotChat();
      _addLog('Hệ thống: Bạn đã tử nạn! Bạn đã bước vào Chế độ Quan sát (Spectator Mode). 👻');
    }
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
            Text(
              isWin ? 'CHIẾN THẮNG!' : 'THẤT BẠI!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black,
            ),
            child: const Text('QUAY VỀ PHÒNG CHỜ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendUserMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    final isNight = _currentState == PlayState.playing && _currentPhase == GamePhase.night;
    final isWolfChannel = isNight && _myPlayer?.role.team == RoleTeam.werewolf;

    setState(() {
      _chatMessages.add(ChatMessage(
        senderName: '$_userName (Bạn)',
        content: text,
        isWerewolfOnly: isWolfChannel,
        isGhost: _currentState == PlayState.playing && _myPlayer != null && !_myPlayer!.isAlive,
        time: DateTime.now(),
      ));
    });

    _simulateBotChatResponse(text);
  }

  void _simulateBotChatResponse(String userMessage) {
    final random = Random();
    final isNight = _currentState == PlayState.playing && _currentPhase == GamePhase.night;

    List<OnlinePlayer> aliveBots = [];
    if (_currentState == PlayState.playing) {
      aliveBots = _players.where((p) => p.isAlive && p.id != _myPlayer?.id).toList();
      if (isNight) {
        if (_myPlayer?.role.team == RoleTeam.werewolf) {
          aliveBots = aliveBots.where((p) => p.role.team == RoleTeam.werewolf).toList();
        } else {
          return;
        }
      }
    } else {
      aliveBots = [
        OnlinePlayer(id: 1, name: 'Tuấn Tú', role: _roleDefinitions[0]),
        OnlinePlayer(id: 2, name: 'Khánh Linh', role: _roleDefinitions[0]),
        OnlinePlayer(id: 3, name: 'Nhật Minh', role: _roleDefinitions[0]),
        OnlinePlayer(id: 4, name: 'Phương Thảo', role: _roleDefinitions[0]),
      ];
    }

    if (aliveBots.isEmpty) return;
    final bot = aliveBots[random.nextInt(aliveBots.length)];

    String replyContent = '';
    final lowerMsg = userMessage.toLowerCase();

    if (_currentState == PlayState.lobby) {
      if (lowerMsg.contains('chào') || lowerMsg.contains('hello') || lowerMsg.contains('hi')) {
        final replies = ['Chào $_userName nhé!', 'Hi bạn hiền!', 'Hello, chúc bạn game này vui vẻ.'];
        replyContent = replies[random.nextInt(replies.length)];
      } else if (lowerMsg.contains('sẵn sàng') || lowerMsg.contains('chơi') || lowerMsg.contains('go')) {
        final replies = ['Ok tui sẵn sàng.', 'Vào trận thôi ae.', 'Ready rồi nhé.'];
        replyContent = replies[random.nextInt(replies.length)];
      } else {
        final replies = ['Game này đông ghê.', 'Mong không bị treo cổ oan.', 'Hóng làm ma sói quá haha.'];
        replyContent = replies[random.nextInt(replies.length)];
      }
    } else if (_currentState == PlayState.playing) {
      if (isNight) {
        if (lowerMsg.contains('cắn') || lowerMsg.contains('p') || RegExp(r'\d+').hasMatch(lowerMsg)) {
          final target = _extractPlayerMention(lowerMsg);
          final replies = ['Cắn $target đi!', 'Ok nhất trí.', 'Đồng ý cắn người đó.'];
          replyContent = replies[random.nextInt(replies.length)];
        } else {
          final replies = ['Tập trung cắn dân ae.', 'Bình tĩnh bàn bạc nhé.'];
          replyContent = replies[random.nextInt(replies.length)];
        }
      } else {
        if (lowerMsg.contains('sói') || lowerMsg.contains('treo') || lowerMsg.contains('vote') || lowerMsg.contains('p') || RegExp(r'\d+').hasMatch(lowerMsg)) {
          final target = _extractPlayerMention(lowerMsg);
          final replies = ['Ủa $target thật hả?', 'Tôi cũng nghi $target.', 'Ủa $target tự bào chữa đi!'];
          replyContent = replies[random.nextInt(replies.length)];
        } else {
          final replies = ['Tiên tri có thông tin gì chưa?', 'Tôi dân chính hiệu nhé ae!', 'Đừng vote bừa nha.'];
          replyContent = replies[random.nextInt(replies.length)];
        }
      }
    }

    if (replyContent.isEmpty) return;

    Timer(Duration(milliseconds: 600 + random.nextInt(600)), () {
      if (mounted) {
        setState(() {
          _chatMessages.add(ChatMessage(
            senderName: bot.name,
            content: replyContent,
            isWerewolfOnly: isNight && _myPlayer?.role.team == RoleTeam.werewolf,
            isGhost: _currentState == PlayState.playing && !bot.isAlive,
            time: DateTime.now(),
          ));
        });
      }
    });
  }

  String _extractPlayerMention(String msg) {
    final match = RegExp(r'p\d+').firstMatch(msg);
    if (match != null) return match.group(0)!.toUpperCase();
    final numMatch = RegExp(r'\d+').firstMatch(msg);
    if (numMatch != null) return 'P${numMatch.group(0)}';
    return 'người đó';
  }

  void _startPeriodicBotChat() {
    _botChatTimer?.cancel();
    _botChatTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (_currentState == PlayState.playing && _currentPhase == GamePhase.day) {
        _simulatePeriodicBotChat();
      }
    });
  }

  void _stopPeriodicBotChat() {
    _botChatTimer?.cancel();
    _botChatTimer = null;
  }

  void _simulatePeriodicBotChat() {
    final random = Random();
    List<OnlinePlayer> aliveBots = _players
        .where((p) => p.isAlive && p.id != _myPlayer?.id)
        .toList();
    if (aliveBots.isEmpty) return;

    final bot = aliveBots[random.nextInt(aliveBots.length)];
    List<OnlinePlayer> suspects = _players.where((p) => p.isAlive && p.id != bot.id).toList();

    String msg = '';
    if (suspects.isNotEmpty) {
      final suspect = suspects[random.nextInt(suspects.length)];
      final replies = [
        'Mọi người nghĩ sao về P${suspect.id}?',
        'P${suspect.id} nãy giờ im lặng quá.',
        'Tiên tri nên soi P${suspect.id} thử xem.',
        'Tôi thấy nghi P${suspect.id} nha ae.'
      ];
      msg = replies[random.nextInt(replies.length)];
    }

    if (msg.isNotEmpty && mounted) {
      setState(() {
        _chatMessages.add(ChatMessage(
          senderName: bot.name,
          content: msg,
          time: DateTime.now(),
        ));
      });
    }
  }

  Widget _buildChatLogTabs() {
    final isPlaying = _currentState == PlayState.playing;
    final isNight = isPlaying && _currentPhase == GamePhase.night;
    final isWolf = _myPlayer?.role.team == RoleTeam.werewolf;

    bool isChatDisabled = false;
    String chatHintText = 'Nhập tin nhắn...';

    if (isPlaying) {
      if (isNight) {
        if (!isWolf) {
          isChatDisabled = true;
          chatHintText = 'Ban đêm không thể nói chuyện.';
        } else {
          chatHintText = 'Chat Bầy Sói...';
        }
      } else if (_myPlayer != null && !_myPlayer!.isAlive) {
        chatHintText = 'Kênh Hồn Ma...';
      }
    }

    final ScrollController scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildTabButton('TRÒ CHUYỆN 💬', isActive: _showChatTab, onTap: () {
                setState(() {
                  _showChatTab = true;
                });
              }),
              _buildTabButton('NHẬT KÝ 📜', isActive: !_showChatTab, onTap: () {
                setState(() {
                  _showChatTab = false;
                });
              }),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 1),
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: _showChatTab
                ? ListView.builder(
              controller: scrollController,
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                if (msg.isWerewolfOnly && !isWolf) return const SizedBox.shrink();
                if (msg.isGhost && _myPlayer != null && _myPlayer!.isAlive) return const SizedBox.shrink();

                Color senderColor = Colors.white70;
                if (msg.isSystem) {
                  senderColor = const Color(0xFFFFD54F);
                } else if (msg.isWerewolfOnly) {
                  senderColor = const Color(0xFFEF5350);
                } else if (msg.isGhost) {
                  senderColor = Colors.white30;
                } else if (msg.senderName.contains('(Bạn)')) {
                  senderColor = const Color(0xFF81C784);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        if (msg.isWerewolfOnly)
                          const TextSpan(text: '[SÓI] ', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 11)),
                        if (msg.isGhost)
                          const TextSpan(text: '[MA 👻] ', style: TextStyle(color: Colors.white24, fontSize: 11)),
                        TextSpan(
                          text: '${msg.senderName}: ',
                          style: TextStyle(color: senderColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        TextSpan(
                          text: msg.content,
                          style: TextStyle(
                            color: msg.isGhost ? Colors.white30 : (msg.isSystem ? const Color(0xFFFFD54F) : Colors.white70),
                            fontSize: 11.5,
                            fontStyle: msg.isGhost ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
                : ListView.builder(
              controller: scrollController,
              itemCount: _actionLogs.length,
              itemBuilder: (context, index) {
                final log = _actionLogs[index];
                Color logColor = Colors.white70;

                if (log.startsWith('Hệ thống:')) {
                  logColor = const Color(0xFFFFD54F);
                } else if (log.startsWith('Tiên Tri:')) {
                  logColor = const Color(0xFF26C6DA);
                } else if (log.startsWith('Bảo Vệ:')) {
                  logColor = const Color(0xFF42A5F5);
                } else if (log.startsWith('Phù Thủy:')) {
                  logColor = const Color(0xFFAB47BC);
                } else if (log.startsWith('Ma Sói:')) {
                  logColor = const Color(0xFFEF5350);
                } else if (log.startsWith('Thảo Luận:')) {
                  logColor = const Color(0xFF81C784);
                } else if (log.startsWith('Xạ Thủ:')) {
                  logColor = const Color(0xFF29B6F6);
                } else if (log.startsWith('Thợ Săn:')) {
                  logColor = const Color(0xFFFFA726);
                } else if (log.startsWith('Cupid:')) {
                  logColor = const Color(0xFFEC407A);
                } else if (log.startsWith('Sói Nguyền:')) {
                  logColor = const Color(0xFFBA68C8);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(log, style: TextStyle(color: logColor, fontSize: 11.5, height: 1.3)),
                );
              },
            ),
          ),
          if (_showChatTab) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _chatController,
                        enabled: !isChatDisabled,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: chatHintText,
                          hintStyle: TextStyle(color: isChatDisabled ? Colors.white24 : Colors.white38, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendUserMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isChatDisabled ? const Color(0xFF334155) : const Color(0xFFFFD54F),
                    child: IconButton(
                      icon: Icon(Icons.send, size: 14, color: isChatDisabled ? Colors.white30 : Colors.black),
                      onPressed: isChatDisabled ? null : _sendUserMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, {required bool isActive, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Colors.transparent : const Color(0xFF1E293B).withValues(alpha: 0.5),
            borderRadius: BorderRadius.only(
              topLeft: label.startsWith('TRÒ CHUYỆN') ? const Radius.circular(16) : Radius.zero,
              topRight: label.startsWith('NHẬT KÝ') ? const Radius.circular(16) : Radius.zero,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFFFD54F) : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _resetGame() {
    _stopPeriodicBotChat();
    setState(() {
      _currentState = PlayState.lobby;
      _selectedPlayer = null;
      _userName = 'Sói Đầu Đàn';
      _generateRoomCode();
      _players = [];
      _myPlayer = null;
      _actionLogs = [];
      _canPop = false;
      _isLobbyLoading = false;
      _lover1 = null;
      _lover2 = null;
      _cursedPlayerId = null;
      _xathuBullets = 2;
      _xathuRevealed = false;
      _hunterSkillTriggered = false;
      _hunterWhoDied = null;
      _cupidSelections = [];
      _initializeLobbyChat();
    });
  }

  Future<bool> _onWillPop() async {
    if (_currentState == PlayState.lobby) return true;
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Thoát game?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc muốn rời phòng chơi không? Tiến trình sẽ bị hủy.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('HỦY', style: TextStyle(color: Colors.white60)),
          ),
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
    final bool allowedToPop = _currentState == PlayState.lobby || _canPop;
    return PopScope(
      canPop: allowedToPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          setState(() {
            _canPop = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (navigator.mounted) navigator.pop();
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: _buildCurrentStateView(),
        ),
      ),
    );
  }

  Widget _buildCurrentStateView() {
    switch (_currentState) {
      case PlayState.lobby:
        return _buildLobbyView();
      case PlayState.playing:
        return _buildOnlinePlayingView();
    }
  }

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
                const Text(
                  'DANH SÁCH PHÒNG ĐẤU:',
                  style: TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
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
              Text(_roomCode, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _generateRoomCode();
                _actionLogs.add('Hệ thống: Mã phòng thay đổi thành $_roomCode');
              });
            },
            icon: const Icon(Icons.refresh, size: 16, color: Colors.black),
            label: const Text('ĐỔI MÃ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TÊN HIỂN THỊ CỦA BẠN:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            maxLength: 16,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Nhập tên hiển thị...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.person, color: Color(0xFFFFD54F)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            controller: TextEditingController(text: _userName)..selection = TextSelection.collapsed(offset: _userName.length),
            onChanged: (val) => _userName = val,
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyPlayerCountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Số lượng người chơi:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Text('$_playerCount Người', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _playerCount.toDouble(),
            min: 6,
            max: 18,
            divisions: 12,
            activeColor: const Color(0xFFFFD54F),
            onChanged: (value) => setState(() => _playerCount = value.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedPlayersSimulator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD54F))),
              const SizedBox(width: 12),
              Expanded(child: Text('Đang chờ người chơi... (5 / $_playerCount)', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4CAF50), width: 0.5),
                      ),
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
          onPressed: _isLobbyLoading
              ? null
              : () {
            setState(() => _isLobbyLoading = true);
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) _initializeOnlineGame();
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
          child: _isLobbyLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
              : const Text('VÀO PHÒNG & BẮT ĐẦU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
      ),
    );
  }

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
              itemCount: _playerCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                final player = _players[index];
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
          IconButton(
            onPressed: () async {
              final pop = await _onWillPop();
              if (pop && mounted) _resetGame();
            },
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          Text('PHÒNG ONLINE: $_roomCode', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.help_outline, color: Color(0xFFFFD54F))),
        ],
      ),
    );
  }

  Widget _buildOnlinePhaseHeader() {
    final isNight = _currentPhase == GamePhase.night;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF311B92).withValues(alpha: 0.3) : const Color(0xFFF57F17).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNight ? const Color(0xFF5E35B1).withValues(alpha: 0.5) : const Color(0xFFFBC02D).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isNight ? Icons.nights_stay : Icons.wb_sunny, color: isNight ? const Color(0xFFB39DDB) : const Color(0xFFFFD54F), size: 20),
              const SizedBox(width: 8),
              Text(
                isNight ? 'BAN ĐÊM - ĐÊM $_dayNumber' : 'BAN NGÀY - NGÀY $_dayNumber',
                style: TextStyle(
                  color: isNight ? const Color(0xFFD1C4E9) : const Color(0xFFFFF59D),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          Text('SỐNG: ${_players.where((p) => p.isAlive).length} / $_playerCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPlayerOnlineCard(OnlinePlayer player) {
    final isMe = player.id == _myPlayer?.id;
    final isSelected = player.id == _selectedPlayer?.id;

    bool revealRole = false;
    Color borderGlowColor = Colors.white24;

    if (!player.isAlive) {
      revealRole = true;
      borderGlowColor = Colors.grey[700]!;
    } else if (isMe) {
      revealRole = true;
      borderGlowColor = player.role.primaryColor;
    } else if (_myPlayer != null && _myPlayer!.role.team == RoleTeam.werewolf && player.role.team == RoleTeam.werewolf) {
      revealRole = true;
      borderGlowColor = const Color(0xFFEF5350);
    } else if (player.hasBeenScannedBySeer) {
      revealRole = true;
      final isWolf = player.role.team == RoleTeam.werewolf || player.id == _cursedPlayerId;
      borderGlowColor = isWolf ? const Color(0xFFEF5350) : const Color(0xFF81C784);
    } else if (_lover1 != null && _lover2 != null) {
      if (_myPlayer?.id == _lover1!.id && player.id == _lover2!.id) {
        revealRole = true;
      } else if (_myPlayer?.id == _lover2!.id && player.id == _lover1!.id) {
        revealRole = true;
      }
    } else if (_xathuRevealed && player.role.id == 'xa_thu') {
      revealRole = true;
      borderGlowColor = player.role.primaryColor;
    }

    if (isSelected) borderGlowColor = const Color(0xFFFFD54F);

    return GestureDetector(
      onTap: () => setState(() => _selectedPlayer = isSelected ? null : player),
      child: Container(
        decoration: BoxDecoration(
          color: player.isAlive ? const Color(0xFF1E293B) : const Color(0xFF0F172A).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderGlowColor, width: isSelected ? 2.5 : 1.0),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'P${player.id} - ${player.name}',
                    style: TextStyle(color: player.isAlive ? Colors.white : Colors.white30, fontWeight: FontWeight.bold, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Icon(revealRole ? player.role.icon : Icons.help_outline, color: player.isAlive && revealRole ? player.role.secondaryColor : Colors.white24, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    revealRole ? (player.id == _cursedPlayerId && player.isAlive ? 'Ma Sói (Nguyền)' : player.role.name) : 'ẨN VAI TRÒ',
                    style: TextStyle(color: player.isAlive && revealRole ? player.role.secondaryColor : Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!player.isAlive)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(16)),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, color: Color(0xFFEF5350), size: 30),
                        Text('TỬ NẠN', style: TextStyle(color: Color(0xFFEF5350), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            if (player.isAlive && player.hasBeenScannedBySeer && !isMe)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Color(0xFF00838F), shape: BoxShape.circle),
                  child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 10),
                ),
              ),
            if (player.isAlive && !isMe && _myPlayer != null && _myPlayer!.role.team == RoleTeam.werewolf && player.role.team == RoleTeam.werewolf)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFC62828), borderRadius: BorderRadius.circular(4)),
                  child: const Text('BẦY SÓI', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
            if (player.isAlive && _lover1 != null && _lover2 != null) ...[
                  () {
                bool showHeart = false;
                final isUserCupid = _myPlayer?.role.id == 'cupid';
                final isUserLover = _myPlayer?.id == _lover1!.id || _myPlayer?.id == _lover2!.id;
                if ((isUserCupid || isUserLover) && (player.id == _lover1!.id || player.id == _lover2!.id)) {
                  showHeart = true;
                }
                return showHeart
                    ? Positioned(
                  top: 6,
                  left: 28,
                  child: const Icon(Icons.favorite, color: Color(0xFFEC407A), size: 12),
                )
                    : const SizedBox.shrink();
              }(),
            ],
            if (player.isAlive && player.voteCount > 0)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEF5350).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.how_to_vote, color: Colors.white, size: 10),
                      const SizedBox(width: 2),
                      Text('${player.voteCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            if (isMe)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: player.role.primaryColor, borderRadius: BorderRadius.circular(6)),
                  child: const Text('BẠN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOnlineController() {
    if (_myPlayer == null) return const SizedBox.shrink();

    final myRole = _myPlayer!.role;
    final isNight = _currentPhase == GamePhase.night;
    final isDead = !_myPlayer!.isAlive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _showMyRoleDetailsBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: myRole.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: myRole.primaryColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(myRole.icon, color: myRole.secondaryColor, size: 20),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('VAI TRÒ CỦA BẠN:', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                          Text(myRole.name, style: TextStyle(color: myRole.secondaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline, color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    isDead ? 'Bạn đã tử nạn. Đang ở Chế độ Quan sát.' : _getActionInstructionText(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isDead)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetGame,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('RỜI PHÒNG', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              if (isDead) const SizedBox(width: 8),
              if (!isDead && _selectedPlayer != null) ...[
                Expanded(child: _buildSkillActionButton()),
                const SizedBox(width: 8),
              ],
              if (_hunterSkillTriggered && _selectedPlayer != null && _selectedPlayer!.isAlive && _selectedPlayer!.id != _myPlayer!.id) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _executeHunterShot(_selectedPlayer!),
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('BẮN KÉO THEO', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _hunterSkillTriggered ? null : (isNight ? _transitionToDay : _transitionToNight),
                  icon: Icon(isNight ? Icons.wb_sunny : Icons.nights_stay),
                  label: Text(
                    _hunterSkillTriggered
                        ? 'ĐANG NỔ SÚNG...'
                        : (isDead
                        ? (isNight ? 'THEO DÕI (QUA NGÀY)' : 'THEO DÕI (TREO CỔ)')
                        : (isNight ? 'QUA NGÀY (THẢO LUẬN)' : 'TREO CỔ / KẾT THÚC NGÀY')),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isNight ? const Color(0xFFF57F17) : const Color(0xFF311B92),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getActionInstructionText() {
    if (_hunterSkillTriggered) {
      return 'BẠN ĐÃ CHẾT! Hãy chọn 1 người chơi và bấm [BẮN KÉO THEO] để tiêu diệt họ cùng bạn!';
    }
    if (_selectedPlayer == null) {
      if (_currentPhase == GamePhase.night) {
        if (_myPlayer!.role.id == 'cupid' && _lover1 == null) return 'Hãy chọn lần lượt 2 người và bấm Ghép đôi.';
        if (_myPlayer!.role.id == 'tien_tri' && !_hasUsedSeerScan) return 'Hãy chọn 1 người để soi bài.';
        if (_myPlayer!.role.id == 'bao_ve' && !_hasUsedBodyguardProtect) return 'Hãy chọn 1 người để đặt khiên bảo vệ.';
        if (_myPlayer!.role.id == 'phu_thuy') {
          if (_hasHealPotion && _werewolfTarget != null) return '${_werewolfTarget!.name} bị cắn. Cứu họ?';
          return 'Hãy chọn mục tiêu để dùng bình thuốc.';
        }
        if (_myPlayer!.role.id == 'soi_nguyen' && _cursedPlayerId == null) return 'Có thể chọn 1 người để Nguyền rủa.';
        if (_myPlayer!.role.team == RoleTeam.werewolf) return 'Hãy chọn một nạn nhân để cắn càn đêm nay.';
        return 'Nhắm mắt đi ngủ. Nhấn [QUA NGÀY] để cập nhật.';
      } else {
        String instr = 'Thảo luận với mọi người và chọn 1 người để vote.';
        if (_myPlayer!.role.id == 'xa_thu' && _xathuBullets > 0) {
          instr += ' Bạn có thể bắn người ban ngày (Đạn: $_xathuBullets/2).';
        }
        return instr;
      }
    } else {
      if (_myPlayer!.role.id == 'cupid' && _lover1 == null) {
        return 'Đang chọn tình nhân: ${_cupidSelections.map((p) => p.name).join(", ")}';
      }
      return 'Mục tiêu đang chọn: ${_selectedPlayer!.name}';
    }
  }

  Widget _buildSkillActionButton() {
    final target = _selectedPlayer!;
    final isNight = _currentPhase == GamePhase.night;
    final myRoleId = _myPlayer!.role.id;

    if (isNight) {
      if (myRoleId == 'cupid' && _lover1 == null) {
        final isSelected = _cupidSelections.any((p) => p.id == target.id);
        if (_cupidSelections.length < 2 || isSelected) {
          return ElevatedButton.icon(
            onPressed: () {
              setState(() {
                if (isSelected) {
                  _cupidSelections.removeWhere((p) => p.id == target.id);
                } else {
                  _cupidSelections.add(target);
                }
              });
            },
            icon: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank),
            label: Text(isSelected ? 'BỎ CHỌN' : 'CHỌN (${_cupidSelections.length}/2)', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAD1457), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          );
        } else if (_cupidSelections.length == 2) {
          return ElevatedButton.icon(
            onPressed: _executeCupidLink,
            icon: const Icon(Icons.favorite),
            label: const Text('GHÉP ĐÔI ❤️', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC407A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          );
        }
      }

      if (myRoleId == 'tien_tri') {
        final allowed = !_hasUsedSeerScan && target.isAlive && target.id != _myPlayer!.id && !target.hasBeenScannedBySeer;
        return ElevatedButton.icon(
          onPressed: allowed ? () => _executeSeerScan(target) : null,
          icon: const Icon(Icons.remove_red_eye),
          label: const Text('SOI VAI TRÒ', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00838F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
        );
      }

      if (myRoleId == 'bao_ve') {
        final allowed = !_hasUsedBodyguardProtect && target.isAlive && target.id != _lastProtectedPlayerId;
        return ElevatedButton.icon(
          onPressed: allowed ? () => _executeBodyguardProtect(target) : null,
          icon: const Icon(Icons.shield),
          label: Text(target.id == _lastProtectedPlayerId ? 'BỊ CHẶN BẢO VỆ' : 'BẢO VỆ ĐÊM NAY', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
        );
      }

      if (myRoleId == 'phu_thuy') {
        final showHeal = _hasHealPotion && _werewolfTarget != null && target.id == _werewolfTarget!.id;
        final showPoison = _hasPoisonPotion && target.isAlive && target.id != _myPlayer!.id;

        return Row(
          children: [
            if (showHeal)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _executeWitchHeal,
                  icon: const Icon(Icons.favorite),
                  label: const Text('CỨU SỐNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            if (showHeal && showPoison) const SizedBox(width: 4),
            if (showPoison)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _executeWitchPoison(target),
                  icon: const Icon(Icons.science),
                  label: const Text('ĐỘC DƯỢC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
          ],
        );
      }

      if (myRoleId == 'soi_nguyen') {
        final allowed = _cursedPlayerId == null && target.isAlive && target.role.team != RoleTeam.werewolf;
        return ElevatedButton.icon(
          onPressed: allowed ? () => _executeCurse(target) : null,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('NGUYỀN RỦA 🔮', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
        );
      }

      if (_myPlayer!.role.team == RoleTeam.werewolf) {
        final allowed = target.isAlive && target.role.team != RoleTeam.werewolf && target.id != _cursedPlayerId;
        return ElevatedButton.icon(
          onPressed: allowed ? () => _executeWerewolfBite(target) : null,
          icon: const Icon(Icons.pets),
          label: const Text('CẮN TIÊU DIỆT', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
        );
      }
    } else {
      final isGunner = myRoleId == 'xa_thu';
      final showVote = target.isAlive && target.id != _myPlayer!.id && !target.isTargeted;
      final showShoot = isGunner && _xathuBullets > 0 && target.isAlive && target.id != _myPlayer!.id;

      return Row(
        children: [
          if (showVote)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _executeVote(target),
                icon: const Icon(Icons.how_to_vote),
                label: const Text('BỎ PHIẾU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          if (showVote && showShoot) const SizedBox(width: 4),
          if (showShoot)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _executeGunnerShoot(target),
                icon: const Icon(Icons.gps_fixed),
                label: Text('BẮN ($_xathuBullets/2)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0277BD), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTopBar(String title, {bool showInfo = false, VoidCallback? onBack}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(onPressed: onBack ?? () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2), textAlign: TextAlign.center)),
          if (showInfo)
            IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 26))
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _showOnlineRulesDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CÁC VAI TRÒ TRÒ CHƠI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: _roleDefinitions.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155), height: 16),
                  itemBuilder: (context, index) {
                    final role = _roleDefinitions[index];
                    Color teamColor;
                    String teamText;

                    switch (role.team) {
                      case RoleTeam.villager:
                        teamColor = const Color(0xFF81C784);
                        teamText = 'Phe Dân Làng';
                        break;
                      case RoleTeam.werewolf:
                        teamColor = const Color(0xFFE57373);
                        teamText = 'Phe Ma Sói';
                        break;
                      case RoleTeam.neutral:
                        teamColor = const Color(0xFFD4E157);
                        teamText = 'Phe Thứ Ba';
                        break;
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: role.primaryColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: role.primaryColor, width: 1.5),
                          ),
                          child: Icon(role.icon, color: role.secondaryColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(role.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Text('($teamText)', style: TextStyle(color: teamColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(role.description, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMyRoleDetailsBottomSheet() {
    if (_myPlayer == null) return;
    final role = _myPlayer!.role;
    Color teamColor = const Color(0xFF81C784);
    String teamText = 'PHE DÂN LÀNG';

    switch (role.team) {
      case RoleTeam.villager:
        teamColor = const Color(0xFF81C784);
        teamText = 'PHE DÂN LÀNG';
        break;
      case RoleTeam.werewolf:
        teamColor = const Color(0xFFE57373);
        teamText = 'PHE MA SÓI';
        break;
      case RoleTeam.neutral:
        teamColor = const Color(0xFFD4E157);
        teamText = 'PHE TRUNG LẬP';
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: role.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: role.primaryColor, width: 2),
                ),
                child: Icon(role.icon, size: 50, color: role.secondaryColor),
              ),
              const SizedBox(height: 16),
              Text(role.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(teamText, style: TextStyle(color: teamColor, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              const SizedBox(height: 16),
              Text(role.description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
                  child: const Text('ĐÃ HIỂU', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}