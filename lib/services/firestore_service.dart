import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Tạo phòng mới trên Firestore
  Future<void> createRoom(String roomCode, String hostName, int playerCount, {bool isPublic = false}) async {
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
        if (!exists) {
          players.add({
            'name': userName,
            'isHost': false,
            'isReady': false,
          });
          transaction.update(roomRef, {
            'players': players,
            'currentPlayersCount': players.length,
          });
        }
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
        'phaseEndTime': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 30))),
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
          int? victimId = data['werewolfTargetId'];
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
            p['wasProtectedByBodyguard'] = false;
            p['wasHealedByWitch'] = false;
          }
        } 
        else if (currentPhase == 'voting') {
          int maxVotes = 0;
          dynamic hangedPlayer;
          for (var p in players) {
            if ((p['voteCount'] ?? 0) > maxVotes) {
              maxVotes = p['voteCount'];
              hangedPlayer = p;
            }
          }
          if (hangedPlayer != null && maxVotes > 1) {
            hangedPlayer['isAlive'] = false;
            messages.add({'senderName': 'system', 'content': 'lynched', 'targetName': hangedPlayer['name'], 'isSystem': true, 'time': Timestamp.now()});
            if (hangedPlayer['roleId'] == 'nerd') {
              transaction.update(roomRef, {'status': 'ended', 'winner': 'nerd'});
            }
          }
          for (var p in players) {
            p['voteCount'] = 0;
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
      });
    } catch (e) {
      debugPrint('Error in secureNextPhase: $e');
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

  /// Tìm phòng ghép trận Online
  Future<String?> findPublicRoom() async {
    try {
      final snapshot = await _db
          .collection('rooms')
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: 'waiting')
          .orderBy('currentPlayersCount', descending: true)
          .limit(5)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        int current = data['currentPlayersCount'] ?? 0;
        int limit = data['playerCount'] ?? 15;
        if (current < limit) {
          return doc.id;
        }
      }
    } catch (e) {
      debugPrint('Error finding public room: $e');
    }
    return null;
  }
}

final firestoreSvc = FirestoreService();
