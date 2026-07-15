import 'role_definition.dart';

class OnlinePlayer {
  final int id;
  final String name;
  final RoleDefinition role;
  bool isAlive;
  bool isDisconnected;
  int voteCount;
  bool isTargeted;
  bool hasBeenScannedBySeer;
  bool isProtected;
  bool isPoisoned;
  bool isHost;
  bool wasProtectedByBodyguard;
  bool wasHealedByWitch;
  int? votedForId; // ID mục tiêu mà người chơi này đang vote (để đồng bộ)

  OnlinePlayer({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
    this.isDisconnected = false,
    this.voteCount = 0,
    this.isTargeted = false,
    this.hasBeenScannedBySeer = false,
    this.isProtected = false,
    this.isPoisoned = false,
    this.isHost = false,
    this.wasProtectedByBodyguard = false,
    this.wasHealedByWitch = false,
    this.votedForId,
  });

  Map<String, dynamic> toStatusMap() {
    return {
      'id': id,
      'isAlive': isAlive,
      'isDisconnected': isDisconnected,
      'voteCount': voteCount,
      'isTargeted': isTargeted,
      'isProtected': isProtected,
      'isPoisoned': isPoisoned,
      'wasProtectedByBodyguard': wasProtectedByBodyguard,
      'wasHealedByWitch': wasHealedByWitch,
      'hasBeenScannedBySeer': hasBeenScannedBySeer,
    };
  }
}
