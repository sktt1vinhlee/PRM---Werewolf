import 'role_definition.dart';

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
  bool isHost;

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
    this.isHost = false,
  });
}
