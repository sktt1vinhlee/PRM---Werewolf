class ChatMessage {
  final String senderName;
  final String content;
  final String? targetName;
  final bool isWerewolfOnly;
  final bool isGhost;
  final bool isSystem;
  final DateTime time;

  ChatMessage({
    required this.senderName,
    required this.content,
    this.targetName,
    this.isWerewolfOnly = false,
    this.isGhost = false,
    this.isSystem = false,
    required this.time,
  });
}
