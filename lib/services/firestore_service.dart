import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Tạo phòng mới trên Firestore
  Future<void> createRoom(String roomCode, String hostName, int playerCount, {bool isPublic = true}) async {
    try {
      await _db.collection('rooms').doc(roomCode).set({
        'roomCode': roomCode,
        'hostName': hostName,
        'playerCount': playerCount,
        'currentPlayersCount': 1,
        'status': 'waiting', // waiting, playing, ended
        'isPublic': isPublic,
        'createdAt': FieldValue.serverTimestamp(),
        'phaseNumber': 0,
        'players': [
          {
            'name': hostName,
            'isHost': true,
            'isReady': true,
          }
        ],
        'messages': [
          {
            'senderName': 'system',
            'content': 'lobby_created',
            'isSystem': true,
            'isWerewolfOnly': false,
            'isGhost': false,
            'time': Timestamp.now(),
          }
        ],
      });
      debugPrint('Room $roomCode created successfully');
    } catch (e) {
      debugPrint('Error creating room: $e');
      rethrow;
    }
  }

  /// Xóa phòng ngay lập tức
  Future<void> deleteRoom(String roomCode) async {
    try {
      await _db.collection('rooms').doc(roomCode).delete();
      debugPrint('Room $roomCode deleted');
    } catch (e) {
      debugPrint('Error deleting room: $e');
    }
  }

  /// Tham gia vào phòng đã có
  Future<void> joinRoom(String roomCode, String userName) async {
    try {
      final roomRef = _db.collection('rooms').doc(roomCode);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) {
          throw Exception('Room not found');
        }

        final data = snapshot.data();
        List players = List.from(data?['players'] ?? []);
        int limit = data?['playerCount'] ?? 15;

        if (players.length >= limit) {
          throw Exception('Room is full');
        }

        bool exists = players.any((p) => p['name'] == userName);
        if (exists) {
          throw Exception('username_already_exists');
        }
        players.add({
          'name': userName,
          'isHost': false,
          'isReady': false,
        });
        transaction.update(roomRef, {
          'players': players,
          'currentPlayersCount': players.length,
        });
      });
    } catch (e) {
      debugPrint('Error joining room: $e');
      rethrow;
    }
  }

  /// Thoát khỏi phòng
  Future<void> leaveRoom(String roomCode, String userName) async {
    try {
      final roomRef = _db.collection('rooms').doc(roomCode);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);

        int index = players.indexWhere((p) => p['name'] == userName);
        if (index == -1) return;

        bool wasHost = players[index]['isHost'] == true;
        players.removeAt(index);

        if (players.isEmpty) {
          transaction.delete(roomRef);
        } else {
          if (wasHost) {
            players[0]['isHost'] = true;
            players[0]['isReady'] = true;
            transaction.update(roomRef, {
              'players': players,
              'currentPlayersCount': players.length,
              'hostName': players[0]['name'],
            });
          } else {
            transaction.update(roomRef, {
              'players': players,
              'currentPlayersCount': players.length,
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  /// Lắng nghe thay đổi của phòng
  Stream<DocumentSnapshot<Map<String, dynamic>>> getRoomStream(String roomCode) {
    return _db.collection('rooms').doc(roomCode).snapshots();
  }

  /// Kiểm tra phòng có tồn tại không
  Future<bool> checkRoomExists(String roomCode) async {
    try {
      final doc = await _db.collection('rooms').doc(roomCode).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Bắt đầu game
  Future<void> startGame(String roomCode, List<Map<String, dynamic>> playersWithRoles) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'status': 'playing',
        'players': playersWithRoles,
        'startedAt': FieldValue.serverTimestamp(),
        'currentPhase': 'night',
        'phaseNumber': 1,
        'dayNumber': 1,
        'phaseEndTime': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 15))), // Ban đêm đầu tiên 15s
        'messages': FieldValue.arrayUnion([
          {
            'senderName': 'system',
            'content': 'match_started',
            'isSystem': true,
            'time': Timestamp.now(),
          }
        ]),
      });
    } catch (e) {
      debugPrint('Error starting game: $e');
      rethrow;
    }
  }

  /// CHUYỂN PHASE AN TOÀN VÀ TÍNH TOÁN KẾT QUẢ
  Future<void> secureNextPhase(String roomCode, int expectedPhaseNumber, String nextPhase, int durationSeconds) async {
    final roomRef = _db.collection('rooms').doc(roomCode);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        int currentPN = data['phaseNumber'] ?? 0;
        if (currentPN != expectedPhaseNumber) return;

        List players = List.from(data['players'] ?? []);
        List messages = [];
        String currentPhase = data['currentPhase'] ?? 'night';

        if (currentPhase == 'night') {
          // TÍNH TOÁN NẠN NHÂN DỰA TRÊN PHIẾU BẦU CỦA SÓI
          int maxVotes = 0;
          int? victimId;
          for (var p in players) {
            int v = p['voteCount'] ?? 0;
            if (v > maxVotes) {
              maxVotes = v;
              victimId = p['id'];
            }
          }

          int? reviveId = data['witchReviveTargetId'];

          for (var p in players) {
            if (p['id'] == victimId && victimId != null) {
              if (p['isProtected'] != true && p['id'] != reviveId) {
                p['isAlive'] = false;
                messages.add({'senderName': 'system', 'content': 'night_casualty', 'targetName': p['name'], 'isSystem': true, 'time': Timestamp.now()});
              }
            }
            if (p['isPoisoned'] == true) {
              p['isAlive'] = false;
              messages.add({'senderName': 'system', 'content': 'poison_casualty', 'targetName': p['name'], 'isSystem': true, 'time': Timestamp.now()});
            }
            p['isProtected'] = false;
            p['isPoisoned'] = false;
            p['voteCount'] = 0;
            p['votedForId'] = null; // QUAN TRỌNG: Reset dấu vết vote của từng người
            p['wasProtectedByBodyguard'] = false;
            p['wasHealedByWitch'] = false;
          }
        }
        else if (currentPhase == 'voting') {
          // TÍNH TOÁN NGƯỜI BỊ TREO CỔ
          int maxVotes = 0;
          dynamic hangedPlayer;
          bool isTie = false;

          for (var p in players) {
            int v = p['voteCount'] ?? 0;
            if (v > maxVotes) {
              maxVotes = v;
              hangedPlayer = p;
              isTie = false;
            } else if (v == maxVotes && v > 0) {
              isTie = true;
            }
          }

          // Chỉ treo cổ nếu có người bị vote nhiều nhất và không bị huề phiếu (và phải > 1 phiếu)
          if (hangedPlayer != null && maxVotes > 1 && !isTie) {
            hangedPlayer['isAlive'] = false;
            messages.add({'senderName': 'system', 'content': 'lynched', 'targetName': hangedPlayer['name'], 'isSystem': true, 'time': Timestamp.now()});
            if (hangedPlayer['roleId'] == 'nerd') {
              transaction.update(roomRef, {'status': 'ended', 'winner': 'nerd'});
            }
          }
          for (var p in players) {
            p['voteCount'] = 0;
            p['votedForId'] = null; // QUAN TRỌNG: Reset dấu vết vote của từng người
          }
        }

        Map<String, dynamic> updates = {
          'currentPhase': nextPhase,
          'phaseNumber': currentPN + 1,
          'phaseEndTime': Timestamp.fromDate(DateTime.now().add(Duration(seconds: durationSeconds))),
          'players': players,
          'werewolfTargetId': null,
          'witchReviveTargetId': null,
        };

        if (nextPhase == 'night') {
          updates['dayNumber'] = (data['dayNumber'] ?? 1) + 1;
        }

        transaction.update(roomRef, updates);
        if (messages.isNotEmpty) {
          transaction.update(roomRef, {'messages': FieldValue.arrayUnion(messages)});
        }

        // --- KIỂM TRA THẮNG CUỘC TRÊN SERVER ---
        int wolves = players.where((p) => p['isAlive'] == true && (p['roleId'] == 'soi' || p['roleId'] == 'soi_nguyen' || p['roleId'] == 'soi_dau_dan')).length;
        int others = players.where((p) => p['isAlive'] == true && !(p['roleId'] == 'soi' || p['roleId'] == 'soi_nguyen' || p['roleId'] == 'soi_dau_dan')).length;

        if (wolves == 0) {
          transaction.update(roomRef, {'status': 'ended', 'winner': 'villagers'});
        } else if (wolves >= others) {
          transaction.update(roomRef, {'status': 'ended', 'winner': 'werewolves'});
        }
      });
    } catch (e) {
      debugPrint('Error in secureNextPhase: $e');
    }
  }

  /// Xử lý Vote an toàn bằng Transaction
  Future<void> submitVoteTransaction(String roomCode, String voterName, int newTargetId, int weight) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);

        int voterIndex = players.indexWhere((p) => p['name'] == voterName);
        if (voterIndex == -1) return;

        int? oldTargetId = players[voterIndex]['votedForId'];
        if (oldTargetId == newTargetId) return;

        bool changed = false;

        if (oldTargetId != null && oldTargetId != -1) {
          int oldTargetIdx = players.indexWhere((p) => p['id'] == oldTargetId);
          if (oldTargetIdx != -1) {
            players[oldTargetIdx]['voteCount'] = (players[oldTargetIdx]['voteCount'] ?? 0) - weight;
            if (players[oldTargetIdx]['voteCount'] < 0) players[oldTargetIdx]['voteCount'] = 0;
            changed = true;
          }
        }

        if (newTargetId != -1) {
          int newTargetIdx = players.indexWhere((p) => p['id'] == newTargetId);
          if (newTargetIdx != -1) {
            players[newTargetIdx]['voteCount'] = (players[newTargetIdx]['voteCount'] ?? 0) + weight;
            changed = true;
          }
        }

        players[voterIndex]['votedForId'] = newTargetId;
        changed = true;

        if (changed) {
          transaction.update(roomRef, {'players': players});
        }
      });
    } catch (e) {
      debugPrint('Error in submitVoteTransaction: $e');
    }
  }

  /// Để tương thích với code cũ nếu chưa cập nhật hết
  Future<void> nextPhase(String roomCode, String phase, int durationSeconds) async {
    try {
      final endTime = DateTime.now().add(Duration(seconds: durationSeconds));
      await _db.collection('rooms').doc(roomCode).update({
        'currentPhase': phase,
        'phaseEndTime': Timestamp.fromDate(endTime),
      });
    } catch (e) {
      debugPrint('Error updating phase: $e');
    }
  }

  /// Gửi tin nhắn chat vào phòng
  Future<void> sendChatMessage(String roomCode, Map<String, dynamic> messageData) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'messages': FieldValue.arrayUnion([messageData]),
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// Cập nhật dữ liệu phòng
  Future<void> updateRoomData(String roomCode, Map<String, dynamic> data) async {
    try {
      await _db.collection('rooms').doc(roomCode).update(data);
    } catch (e) {
      debugPrint('Error updating room data: $e');
    }
  }

  /// Tìm phòng ghép trận Online - Ưu tiên phòng đông người nhất để nhanh đủ người
  Future<String?> findPublicRoom() async {
    try {
      final snapshot = await _db
          .collection('rooms')
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: 'waiting')
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final data = a.data();
        final dataB = b.data();
        int countA = data['currentPlayersCount'] ?? 0;
        int countB = dataB['currentPlayersCount'] ?? 0;
        if (countA != countB) return countB.compareTo(countA);
        Timestamp? timeA = data['createdAt'];
        Timestamp? timeB = dataB['createdAt'];
        if (timeA != null && timeB != null) return timeA.compareTo(timeB);
        return 0;
      });

      for (var doc in docs) {
        final data = doc.data();
        int current = data['currentPlayersCount'] ?? 0;
        int limit = data['playerCount'] ?? 15;
        if (current < limit) return doc.id;
      }
    } catch (e) {
      debugPrint('Error finding public room: $e');
      rethrow;
    }
    return null;
  }

  /// Cập nhật 1 hoặc nhiều thuộc tính của người chơi bằng Transaction
  Future<void> updatePlayerField(String roomCode, int targetPlayerId, Map<String, dynamic> fields) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);

        for (var p in players) {
          if (p['id'] == targetPlayerId) {
            fields.forEach((key, value) => p[key] = value);
            break;
          }
        }
        transaction.update(roomRef, {'players': players});
      });
    } catch (e) {
      debugPrint('Error in updatePlayerField: $e');
    }
  }

  /// Cập nhật thuộc tính trên NHIỀU người chơi cùng lúc (dùng cho reset phase)
  Future<void> updateMultiplePlayerFields(String roomCode, Map<int, Map<String, dynamic>> updates) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);

        for (var p in players) {
          final id = p['id'] as int?;
          if (id != null && updates.containsKey(id)) {
            updates[id]!.forEach((key, value) => p[key] = value);
          }
        }
        transaction.update(roomRef, {'players': players});
      });
    } catch (e) {
      debugPrint('Error in updateMultiplePlayerFields: $e');
    }
  }

  /// Heartbeat: cập nhật lastSeen của người chơi để phát hiện Zombie Players
  Future<void> updateLastSeen(String roomCode, String playerName) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);

        for (var p in players) {
          if (p['name'] == playerName) {
            p['lastSeen'] = Timestamp.now();
            break;
          }
        }
        transaction.update(roomRef, {'players': players});
      });
    } catch (e) {
      debugPrint('Error in updateLastSeen: $e');
    }
  }

  /// Set hunterSkillActive flag trên Firebase để chờ Thợ Săn bắn
  Future<void> setHunterSkillActive(String roomCode, bool active, {int? hunterPlayerId}) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'hunterSkillActive': active,
        'hunterPlayerId': hunterPlayerId,
        'hunterSkillSetAt': active ? Timestamp.now() : null,
      });
    } catch (e) {
      debugPrint('Error in setHunterSkillActive: $e');
    }
  }

  /// Cập nhật trạng thái công khai/riêng tư của phòng
  Future<void> updateRoomPrivacy(String roomCode, bool isPublic) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'isPublic': isPublic,
      });
    } catch (e) {
      debugPrint('Error updating room privacy: $e');
    }
  }
}

final firestoreSvc = FirestoreService();
