import 'dart:math';
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
        'players': {
          'p1': {
            'id': 1,
            'name': hostName,
            'isHost': true,
            'isReady': true,
            'isAlive': true,
            'voteCount': 0,
            'votedForId': null,
          }
        },
        'presence': {
          hostName: FieldValue.serverTimestamp(),
        },
      });
      
      // Tạo tin nhắn khởi tạo trong subcollection
      await _db.collection('rooms').doc(roomCode).collection('messages').add({
        'senderName': 'system',
        'content': 'lobby_created',
        'isSystem': true,
        'isWerewolfOnly': false,
        'isGhost': false,
        'time': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Room $roomCode created successfully');
    } catch (e) {
      debugPrint('Error creating room: $e');
      rethrow;
    }
  }

  /// Xóa phòng
  Future<void> deleteRoom(String roomCode) async {
    try {
      // Lưu ý: Firebase không tự xóa subcollection khi xóa document cha. 
      // Nhưng với quy mô này, ta có thể tạm chấp nhận hoặc dùng cloud function sau.
      await _db.collection('rooms').doc(roomCode).delete();
      debugPrint('Room $roomCode deleted');
    } catch (e) {
      debugPrint('Error deleting room: $e');
    }
  }

  /// Tham gia phòng
  Future<void> joinRoom(String roomCode, String userName) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) throw Exception('Room not found');

        final data = snapshot.data()!;
        Map<String, dynamic> players = Map<String, dynamic>.from(data['players'] ?? {});
        int limit = data['playerCount'] ?? 15;

        if (players.length >= limit) throw Exception('Room is full');
        
        bool exists = players.values.any((p) => p['name'] == userName);
        if (exists) throw Exception('username_already_exists');

        int nextId = players.length + 1;
        String playerKey = 'p$nextId';

        transaction.update(roomRef, {
          'players.$playerKey': {
            'id': nextId,
            'name': userName,
            'isHost': false,
            'isReady': false,
            'isAlive': true,
            'voteCount': 0,
            'votedForId': null,
          },
          'currentPlayersCount': players.length + 1,
          'presence.$userName': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Error joining room: $e');
      rethrow;
    }
  }

  /// Thoát phòng
  Future<void> leaveRoom(String roomCode, String userName) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        Map<String, dynamic> players = Map<String, dynamic>.from(data['players'] ?? {});
        
        String? targetKey;
        players.forEach((key, value) {
          if (value['name'] == userName) targetKey = key;
        });

        if (targetKey == null) return;

        bool wasHost = players[targetKey]['isHost'] == true;
        players.remove(targetKey);

        if (players.isEmpty) {
          transaction.delete(roomRef);
        } else {
          Map<String, dynamic> updates = {
            'players': players, // Ghi đè lại map sau khi xóa
            'currentPlayersCount': players.length,
            'presence.$userName': FieldValue.delete(),
          };

          if (wasHost) {
            String firstKey = players.keys.first;
            updates['players.$firstKey.isHost'] = true;
            updates['players.$firstKey.isReady'] = true;
            updates['hostName'] = players[firstKey]['name'];
          }
          transaction.update(roomRef, updates);
        }
      });
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  /// Heartbeat tối ưu
  Future<void> updateLastSeen(String roomCode, String playerName) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'presence.$playerName': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Bỏ qua lỗi heartbeat
    }
  }

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

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(String roomCode) {
    return _db.collection('rooms')
        .doc(roomCode)
        .collection('messages')
        .orderBy('time', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> sendChatMessage(String roomCode, Map<String, dynamic> messageData) async {
    try {
      // Đảm bảo dùng server timestamp để đồng bộ
      messageData['time'] = FieldValue.serverTimestamp();
      await _db.collection('rooms').doc(roomCode).collection('messages').add(messageData);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> startGame(String roomCode, List<Map<String, dynamic>> playersList) async {
    try {
      Map<String, dynamic> playersMap = {};
      for (var p in playersList) {
        playersMap['p${p['id']}'] = p;
      }

      await _db.collection('rooms').doc(roomCode).update({
        'status': 'playing',
        'players': playersMap,
        'startedAt': FieldValue.serverTimestamp(),
        'currentPhase': 'night',
        'phaseNumber': 1,
        'dayNumber': 1,
        'winner': null,
        'phaseEndTime': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 20))),
      });
      
      await sendChatMessage(roomCode, {
        'senderName': 'system',
        'content': 'match_started',
        'isSystem': true,
        'isWerewolfOnly': false,
        'isGhost': false,
      });
    } catch (e) {
      debugPrint('Error starting game: $e');
      rethrow;
    }
  }

  /// Cập nhật dữ liệu phòng (Dùng update thông thường thay vì transaction khi không cần đọc)
  Future<void> updateRoomData(String roomCode, Map<String, dynamic> data) async {
    try {
      await _db.collection('rooms').doc(roomCode).update(data);
    } catch (e) {
      debugPrint('Error updating room data: $e');
    }
  }

  /// CHUYỂN PHASE AN TOÀN - TỐI ƯU
  Future<void> secureNextPhase(String roomCode, int expectedPhaseNumber, String nextPhase, int durationSeconds) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        int currentPN = data['phaseNumber'] ?? 0;
        if (currentPN != expectedPhaseNumber) return;

        Map<String, dynamic> players = Map<String, dynamic>.from(data['players'] ?? {});
        List<Map<String, dynamic>> messagesToAdd = [];
        String currentPhase = data['currentPhase'] ?? 'night';
        
        Map<String, dynamic> updates = {
          'currentPhase': nextPhase,
          'phaseNumber': currentPN + 1,
          'phaseEndTime': Timestamp.fromDate(DateTime.now().add(Duration(seconds: durationSeconds))),
          'werewolfTargetId': null,
          'witchReviveTargetId': null,
        };

        if (currentPhase == 'night') {
          // XỬ LÝ KẾT QUẢ ĐÊM
          Map<int, int> biteVotes = {};
          players.forEach((key, p) {
            final voterRole = p['roleId'] ?? '';
            final isWolf = voterRole == 'soi' || voterRole == 'soi_nguyen' || voterRole == 'soi_dau_dan';
            if (isWolf && p['votedForId'] != null && p['votedForId'] != -1) {
              int targetId = p['votedForId'];
              int weight = (voterRole == 'soi_dau_dan') ? 2 : 1;
              biteVotes[targetId] = (biteVotes[targetId] ?? 0) + weight;
            }
          });

          int? finalWolfTargetId;
          if (biteVotes.isNotEmpty) {
            int maxV = biteVotes.values.reduce(max);
            List<int> tied = biteVotes.entries.where((e) => e.value == maxV).map((e) => e.key).toList();
            finalWolfTargetId = tied[Random().nextInt(tied.length)];
          }

          int? reviveId = data['witchReviveTargetId'];
          bool wolfKillSuccess = false;

          players.forEach((key, p) {
            bool isTargetedByWolf = (finalWolfTargetId != null && p['id'] == finalWolfTargetId);
            bool isSavedByWitch = (p['id'] == reviveId && reviveId != null);

            if (isTargetedByWolf && !wolfKillSuccess) {
              if (p['isAlive'] == true && p['isProtected'] != true && !isSavedByWitch) {
                p['isAlive'] = false;
                wolfKillSuccess = true;
                messagesToAdd.add({'senderName': 'system', 'content': 'night_casualty', 'targetName': p['name'], 'isSystem': true});
              }
            }
            if (isSavedByWitch) {
              p['isAlive'] = true;
              p['isProtected'] = true;
            }
            if (p['isPoisoned'] == true && p['isAlive'] == true) {
              p['isAlive'] = false;
              messagesToAdd.add({'senderName': 'system', 'content': 'poison_casualty', 'targetName': p['name'], 'isSystem': true});
            }
            
            // Reset
            p['isProtected'] = false;
            p['isPoisoned'] = false;
            p['voteCount'] = 0;
            p['votedForId'] = null;
          });
        } else if (currentPhase == 'voting') {
          // XỬ LÝ TREO CỔ
          int maxVotes = 0;
          String? hangedKey;
          bool isTie = false;

          players.forEach((key, p) {
            int v = p['voteCount'] ?? 0;
            if (v > maxVotes) {
              maxVotes = v;
              hangedKey = key;
              isTie = false;
            } else if (v == maxVotes && v > 0) {
              isTie = true;
            }
          });

          if (hangedKey != null && maxVotes > 1 && !isTie) {
            players[hangedKey!]['isAlive'] = false;
            messagesToAdd.add({'senderName': 'system', 'content': 'lynched', 'targetName': players[hangedKey!]['name'], 'isSystem': true});
            if (players[hangedKey!]['roleId'] == 'nerd') {
              updates['status'] = 'ended';
              updates['winner'] = 'nerd';
            }
          } else {
            messagesToAdd.add({'senderName': 'system', 'content': 'no_lynch', 'isSystem': true});
          }
          players.forEach((key, p) {
            p['voteCount'] = 0;
            p['votedForId'] = null;
          });
        }

        if (nextPhase == 'day') {
          messagesToAdd.add({'senderName': 'system', 'content': 'sunrise', 'isSystem': true});
          updates['cursedPlayerId'] = null;
          updates['xathuHasShotToday'] = false;
        } else if (nextPhase == 'night') {
          messagesToAdd.add({'senderName': 'system', 'content': 'night_start', 'isSystem': true});
          updates['dayNumber'] = (data['dayNumber'] ?? 1) + 1;
        } else if (nextPhase == 'voting') {
          messagesToAdd.add({'senderName': 'system', 'content': 'voting_start', 'isSystem': true});
        }

        // Kiểm tra Lover tragedy
        final int? l1Id = data['lover1Id'];
        final int? l2Id = data['lover2Id'];
        if (l1Id != null && l2Id != null) {
          bool dead = players.values.any((p) => (p['id'] == l1Id || p['id'] == l2Id) && p['isAlive'] == false);
          if (dead) {
            players.forEach((key, p) {
              if ((p['id'] == l1Id || p['id'] == l2Id) && p['isAlive'] == true) {
                p['isAlive'] = false;
                messagesToAdd.add({'senderName': 'system', 'content': 'lover_tragedy', 'targetName': p['name'], 'isSystem': true});
              }
            });
          }
        }

        updates['players'] = players;
        transaction.update(roomRef, updates);

        // Gửi tin nhắn hệ thống
        for (var msg in messagesToAdd) {
          msg['time'] = FieldValue.serverTimestamp();
          transaction.set(roomRef.collection('messages').doc(), msg);
        }

        // KIỂM TRA THẮNG CUỘC
        if (updates['status'] == 'ended') return;

        int wolves = players.values.where((p) => p['isAlive'] == true && (p['roleId'] == 'soi' || p['roleId'] == 'soi_nguyen' || p['roleId'] == 'soi_dau_dan')).length;
        int others = players.values.where((p) => p['isAlive'] == true && !(p['roleId'] == 'soi' || p['roleId'] == 'soi_nguyen' || p['roleId'] == 'soi_dau_dan')).length;

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

  /// Vote an toàn dùng Dot Notation (Cực kỳ tối ưu, ít xung đột)
  Future<void> submitVoteTransaction(String roomCode, String voterName, int? newTargetId) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        Map<String, dynamic> players = Map<String, dynamic>.from(data['players'] ?? {});
        
        String? voterKey;
        players.forEach((key, value) { if (value['name'] == voterName) voterKey = key; });
        if (voterKey == null) return;

        int? oldTargetId = players[voterKey!]['votedForId'];
        if (oldTargetId == newTargetId) return;

        Map<String, dynamic> updates = {};
        
        // Trừ vote cũ
        if (oldTargetId != null) {
          String? oldKey;
          players.forEach((k, v) { if (v['id'] == oldTargetId) oldKey = k; });
          if (oldKey != null) {
            int current = players[oldKey]['voteCount'] ?? 0;
            updates['players.$oldKey.voteCount'] = max(0, current - 1);
          }
        }

        // Cộng vote mới
        if (newTargetId != null && newTargetId != -1) {
          String? newKey;
          players.forEach((k, v) { if (v['id'] == newTargetId) newKey = k; });
          if (newKey != null) {
            int current = players[newKey]['voteCount'] ?? 0;
            updates['players.$newKey.voteCount'] = current + 1;
          }
        }

        updates['players.$voterKey.votedForId'] = newTargetId == -1 ? null : newTargetId;
        transaction.update(roomRef, updates);
      });
    } catch (e) {
      debugPrint('Error in submitVoteTransaction: $e');
    }
  }

  /// Sói cắn an toàn dùng Dot Notation
  Future<void> submitBiteTransaction(String roomCode, String voterName, int? newTargetId) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        Map<String, dynamic> players = Map<String, dynamic>.from(data['players'] ?? {});
        
        String? voterKey;
        players.forEach((key, value) { if (value['name'] == voterName) voterKey = key; });
        if (voterKey == null) return;

        final int weight = players[voterKey!]['roleId'] == 'soi_dau_dan' ? 2 : 1;
        int? oldTargetId = players[voterKey!]['votedForId'];
        if (oldTargetId == newTargetId) return;

        Map<String, dynamic> updates = {};

        if (oldTargetId != null) {
          String? oldKey;
          players.forEach((k, v) { if (v['id'] == oldTargetId) oldKey = k; });
          if (oldKey != null) {
            int current = players[oldKey]['voteCount'] ?? 0;
            updates['players.$oldKey.voteCount'] = max(0, current - weight);
          }
        }

        if (newTargetId != null && newTargetId != -1) {
          String? newKey;
          players.forEach((k, v) { if (v['id'] == newTargetId) newKey = k; });
          if (newKey != null) {
            int current = players[newKey]['voteCount'] ?? 0;
            updates['players.$newKey.voteCount'] = current + weight;
          }
        }

        updates['players.$voterKey.votedForId'] = newTargetId == -1 ? null : newTargetId;
        transaction.update(roomRef, updates);
      });
    } catch (e) {
      debugPrint('Error in submitBiteTransaction: $e');
    }
  }

  Future<void> updateMultiplePlayerFields(String roomCode, Map<int, Map<String, dynamic>> updates) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      final snapshot = await roomRef.get();
      if (!snapshot.exists) return;
      Map<String, dynamic> players = Map<String, dynamic>.from(snapshot.data()!['players'] ?? {});
      
      Map<String, dynamic> finalUpdates = {};
      updates.forEach((id, fields) {
        String? targetKey;
        players.forEach((k, v) { if (v['id'] == id) targetKey = k; });
        if (targetKey != null) {
          fields.forEach((key, value) => finalUpdates['players.$targetKey.$key'] = value);
        }
      });
      if (finalUpdates.isNotEmpty) await roomRef.update(finalUpdates);
    } catch (e) {
      debugPrint('Error in updateMultiplePlayerFields: $e');
    }
  }

  Future<void> useWitchHeal(String roomCode, int targetId) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        Map<String, dynamic> players = Map<String, dynamic>.from(snapshot.data()!['players'] ?? {});
        String? targetKey;
        players.forEach((k, v) { if (v['id'] == targetId) targetKey = k; });
        
        if (targetKey != null) {
          transaction.update(roomRef, {
            'players.$targetKey.isAlive': true,
            'players.$targetKey.isProtected': true,
            'witchReviveTargetId': targetId,
          });
        }
      });
    } catch (e) {
      debugPrint('Error in useWitchHeal: $e');
    }
  }

  Future<void> setHunterSkillActive(String roomCode, bool active, {int? hunterPlayerId}) async {
    try {
      await _db.collection('rooms').doc(roomCode).update({
        'hunterSkillActive': active,
        'hunterPlayerId': hunterPlayerId,
        'hunterSkillSetAt': active ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      debugPrint('Error in setHunterSkillActive: $e');
    }
  }

  Future<String?> findPublicRoom() async {
    try {
      final snapshot = await _db.collection('rooms')
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: 'waiting')
          .limit(10)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if ((data['currentPlayersCount'] ?? 0) < (data['playerCount'] ?? 15)) {
          return doc.id;
        }
      }
    } catch (e) {
      debugPrint('Error finding public room: $e');
    }
    return null;
  }
  
  Future<void> updatePlayerField(String roomCode, int targetPlayerId, Map<String, dynamic> fields) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      final snapshot = await roomRef.get();
      if (!snapshot.exists) return;
      
      Map<String, dynamic> players = Map<String, dynamic>.from(snapshot.data()!['players'] ?? {});
      String? targetKey;
      players.forEach((k, v) { if (v['id'] == targetPlayerId) targetKey = k; });
      
      if (targetKey != null) {
        Map<String, dynamic> updates = {};
        fields.forEach((key, value) => updates['players.$targetKey.$key'] = value);
        await roomRef.update(updates);
      }
    } catch (e) {
      debugPrint('Error in updatePlayerField: $e');
    }
  }

  Future<void> executeKillAction({
    required String roomCode,
    required int targetId,
    Map<String, dynamic>? roomUpdates,
    Map<String, dynamic>? systemMessage,
  }) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        Map<String, dynamic> players = Map<String, dynamic>.from(snapshot.data()!['players'] ?? {});
        String? targetKey;
        players.forEach((k, v) { if (v['id'] == targetId) targetKey = k; });

        Map<String, dynamic> finalUpdates = roomUpdates ?? {};
        if (targetKey != null) {
          finalUpdates['players.$targetKey.isAlive'] = false;
        }

        transaction.update(roomRef, finalUpdates);
        
        if (systemMessage != null) {
          systemMessage['time'] = FieldValue.serverTimestamp();
          transaction.set(roomRef.collection('messages').doc(), systemMessage);
        }
      });
    } catch (e) {
      debugPrint('Error in executeKillAction: $e');
    }
  }
}

final firestoreSvc = FirestoreService();
