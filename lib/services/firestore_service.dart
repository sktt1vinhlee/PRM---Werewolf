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
      debugPrint('Room $roomCode created successfully on Firebase');
    } catch (e) {
      debugPrint('Error creating room: $e');
      rethrow;
    }
  }

  /// Xóa phòng ngay lập tức (dùng khi thoát gấp)
  Future<void> deleteRoom(String roomCode) async {
    try {
      await _db.collection('rooms').doc(roomCode).delete();
      debugPrint('===> FIRESTORE: Đã xóa phòng $roomCode (Quick Delete)');
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
        
        // Kiểm tra xem đã có người chơi này chưa (tránh trùng lặp nếu ấn nhanh)
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
        if (!snapshot.exists) {
          return;
        }

        final List players = List.from(snapshot.data()?['players'] ?? []);
        
        // Tìm người chơi thoát
        int index = players.indexWhere((p) => p['name'] == userName);
        if (index == -1) {
          return;
        }

        bool wasHost = players[index]['isHost'] == true;
        players.removeAt(index);

        if (players.isEmpty) {
          // XÓA HOÀN TOÀN DOCUMENT PHÒNG TRÊN FIRESTORE nếu không còn ai
          transaction.delete(roomRef);
          debugPrint('===> FIRESTORE: Đã xóa document phòng $roomCode.');
        } else {
          // Nếu người thoát là Host, chuyển quyền cho người tiếp theo
          if (wasHost) {
            players[0]['isHost'] = true;
            players[0]['isReady'] = true;
            debugPrint('===> FIRESTORE: Chuyển quyền Host phòng $roomCode cho ${players[0]['name']}.');
          }

          // Cập nhật danh sách và số lượng người chơi
          transaction.update(roomRef, {
            'players': players,
            'currentPlayersCount': players.length,
            'hostName': players[0]['name'], // Cập nhật tên host mới nếu cần
          });
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
      debugPrint('Error starting game: $e');
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
      debugPrint('Error sending message: $e');
    }
  }

  /// Cập nhật dữ liệu phòng (dùng để đồng bộ trạng thái game)
  Future<void> updateRoomData(String roomCode, Map<String, dynamic> data) async {
    try {
      await _db.collection('rooms').doc(roomCode).update(data);
    } catch (e) {
      debugPrint('Error updating room data: $e');
    }
  }

  /// Tìm phòng ghép trận Online (Ưu tiên phòng sắp đầy)
  Future<String?> findPublicRoom() async {
    try {
      // Tìm phòng công khai, đang chờ, chưa đầy và ưu tiên phòng có nhiều người nhất
      final snapshot = await _db
          .collection('rooms')
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: 'waiting')
          .orderBy('currentPlayersCount', descending: true)
          .limit(5) // Lấy top 5 phòng gần đầy nhất
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
