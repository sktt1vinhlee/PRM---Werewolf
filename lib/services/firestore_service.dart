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

  /// Lắng nghe thay đổi của phòng
  Stream<DocumentSnapshot<Map<String, dynamic>>> getRoomStream(String roomCode) {
    return _db.collection('rooms').doc(roomCode).snapshots();
  }

  /// Kiểm tra phòng có tồn tại không
  Future<bool> checkRoomExists(String roomCode) async {
    final doc = await _db.collection('rooms').doc(roomCode).get();
    return doc.exists;
  }
}

final firestoreSvc = FirestoreService();
