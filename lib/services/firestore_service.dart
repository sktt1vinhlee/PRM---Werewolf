import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Tạo phòng mới trên Firestore
  Future<void> createRoom(String roomCode, String hostName, int playerCount) async {
    try {
      await _db.collection('rooms').doc(roomCode).set({
        'roomCode': roomCode,
        'hostName': hostName,
        'playerCount': playerCount,
        'status': 'waiting', // waiting, playing, ended
        'createdAt': FieldValue.serverTimestamp(),
        'players': [
          {
            'name': hostName,
            'isHost': true,
            'isReady': true,
          }
        ],
        'messages': [
          {
            'senderName': 'Hệ thống',
            'content': 'Phòng đã được tạo thành công!',
            'isSystem': true,
            'isWerewolfOnly': false,
            'isGhost': false,
            'time': Timestamp.now(),
          }
        ],
      });
      print('Room $roomCode created successfully on Firebase');
    } catch (e) {
      print('Error creating room: $e');
      rethrow;
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

        List players = List.from(snapshot.data()?['players'] ?? []);
        
        // Kiểm tra xem đã có người chơi này chưa (tránh trùng lặp nếu ấn nhanh)
        bool exists = players.any((p) => p['name'] == userName);
        if (!exists) {
          players.add({
            'name': userName,
            'isHost': false,
            'isReady': false,
          });
          transaction.update(roomRef, {'players': players});
        }
      });
    } catch (e) {
      print('Error joining room: $e');
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

        List players = List.from(snapshot.data()?['players'] ?? []);
        players.removeWhere((p) => p['name'] == userName);

        if (players.isEmpty) {
          // XÓA HOÀN TOÀN DOCUMENT PHÒNG TRÊN FIRESTORE
          transaction.delete(roomRef);
          print('===> FIRESTORE: Đã xóa document phòng $roomCode vì không còn người chơi.');
        } else {
          // Nếu người thoát là Host, chuyển quyền Host cho người tiếp theo
          bool wasHost = false;
          final List originalPlayers = snapshot.data()?['players'] ?? [];
          for (var p in originalPlayers) {
            if (p['name'] == userName && p['isHost'] == true) {
              wasHost = true;
              break;
            }
          }

          if (wasHost && players.isNotEmpty) {
            players[0]['isHost'] = true;
            players[0]['isReady'] = true;
            // Cập nhật lại cả hostName ở cấp document để đồng bộ
            transaction.update(roomRef, {
              'players': players,
              'hostName': players[0]['name']
            });
          } else {
            transaction.update(roomRef, {'players': players});
          }
        }
      });
    } catch (e) {
      print('Error leaving room: $e');
    }
  }

  /// Lắng nghe thay đổi của phòng
  Stream<DocumentSnapshot<Map<String, dynamic>>> getRoomStream(String roomCode) {
    return _db.collection('rooms').doc(roomCode).snapshots();
  }

  /// Kiểm tra phòng có tồn tại không
  Future<bool> checkRoomExists(String roomCode) async {
    final doc = await _db.collection('rooms').doc(roomCode).get();
    return doc.exists;
  }

  /// Bắt đầu game (chỉ Host gọi)
  Future<void> startGame(String roomCode, List<Map<String, dynamic>> playersWithRoles) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'status': 'playing',
        'players': playersWithRoles,
        'startedAt': FieldValue.serverTimestamp(),
        'messages': [], // Khởi tạo mảng chat trống
      });
    } catch (e) {
      print('Error starting game: $e');
      rethrow;
    }
  }

  /// Gửi tin nhắn chat vào phòng
  Future<void> sendChatMessage(String roomCode, Map<String, dynamic> messageData) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'messages': FieldValue.arrayUnion([messageData]),
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }
}

final firestoreSvc = FirestoreService();
