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
        'xathuRevealed': false,
        'xathuBullets': 2,
        'xathuHasShotToday': false,
        'cursedPlayerId': null,
        'winner': null,
        'phaseEndTime': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 20))), // Đồng bộ với durationNight=20
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
        Map<String, dynamic> updates = {
          'currentPhase': nextPhase,
          'phaseNumber': currentPN + 1,
          'phaseEndTime': Timestamp.fromDate(DateTime.now().add(Duration(seconds: durationSeconds))),
          'werewolfTargetId': null,
          'witchReviveTargetId': null,
        };

        if (currentPhase == 'night') {
          // 1. TỔNG HỢP PHIẾU BẦU CỦA SÓI
          Map<int, int> biteVotes = {};
          for (var p in players) {
            final voterRole = p['roleId'] ?? '';
            final isWolf = voterRole == 'soi' || voterRole == 'soi_nguyen' || voterRole == 'soi_dau_dan';
            
            if (isWolf && p['votedForId'] != null && p['votedForId'] != -1) {
              final targetId = p['votedForId'];
              // Kiểm tra mục tiêu có phải là Sói không (Bảo vệ đồng đội)
              final target = players.firstWhere((pl) => pl['id'] == targetId, orElse: () => null);
              if (target != null) {
                final targetRole = target['roleId'] ?? '';
                final isTargetWolf = targetRole == 'soi' || targetRole == 'soi_nguyen' || targetRole == 'soi_dau_dan';
                if (!isTargetWolf) {
                  int weight = (voterRole == 'soi_dau_dan') ? 2 : 1;
                  biteVotes[targetId] = (biteVotes[targetId] ?? 0) + weight;
                }
              }
            }
          }

          // 2. CHỌN DUY NHẤT 1 NẠN NHÂN CỦA SÓI
          int? finalWolfTargetId;
          if (biteVotes.isNotEmpty) {
            int maxVotes = 0;
            biteVotes.forEach((_, v) { if (v > maxVotes) maxVotes = v; });
            
            List<int> tiedTargets = [];
            biteVotes.forEach((id, v) { if (v == maxVotes) tiedTargets.add(id); });
            
            // Xử lý hòa: Chọn ngẫu nhiên 1 người
            finalWolfTargetId = tiedTargets[Random().nextInt(tiedTargets.length)];
          }

          int? reviveId = data['witchReviveTargetId'];
          bool wolfKillSuccess = false;

          for (var p in players) {
            bool isTargetedByWolf = (finalWolfTargetId != null && p['id'] == finalWolfTargetId);
            bool isSavedByWitch = (p['id'] == reviveId && reviveId != null);

            // Xử lý cái chết của Sói (Chỉ thực hiện cho 1 người duy nhất)
            if (isTargetedByWolf && !wolfKillSuccess) {
              if (p['isAlive'] == true && p['isProtected'] != true && !isSavedByWitch) {
                p['isAlive'] = false;
                wolfKillSuccess = true;
                messages.add({
                  'senderName': 'system', 
                  'content': 'night_casualty', 
                  'targetName': p['name'], 
                  'isSystem': true, 
                  'time': Timestamp.now()
                });
              }
            }
            
            // Phù Thủy cứu
            if (isSavedByWitch) {
              p['isAlive'] = true; 
              p['isProtected'] = true;
              p['wasHealedByWitch'] = true;
            }

            // Phù Thủy độc
            if (p['isPoisoned'] == true && p['isAlive'] == true) {
              p['isAlive'] = false;
              messages.add({
                'senderName': 'system', 
                'content': 'poison_casualty', 
                'targetName': p['name'], 
                'isSystem': true, 
                'time': Timestamp.now()
              });
            }
            
            // Reset trạng thái đêm
            p['isProtected'] = false;
            p['isPoisoned'] = false;
            p['voteCount'] = 0;
            p['votedForId'] = null;
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
              updates['status'] = 'ended';
              updates['winner'] = 'nerd';
            }
          } else {
            messages.add({'senderName': 'system', 'content': 'no_lynch', 'isSystem': true, 'time': Timestamp.now()});
          }
          for (var p in players) {
            p['voteCount'] = 0;
            p['votedForId'] = null; // QUAN TRỌNG: Reset dấu vết vote của từng người
          }
        }

        if (nextPhase == 'day') {
          messages.add({'senderName': 'system', 'content': 'sunrise', 'isSystem': true, 'time': Timestamp.now()});
        } else if (nextPhase == 'voting') {
          messages.add({'senderName': 'system', 'content': 'voting_start', 'isSystem': true, 'time': Timestamp.now()});
        } else if (nextPhase == 'night') {
          messages.add({'senderName': 'system', 'content': 'night_start', 'isSystem': true, 'time': Timestamp.now()});
        }

        updates['players'] = players;

        // --- KIỂM TRA TỬ NẠN CÙNG NHAU (LOVER LINK) ---
        final int? l1Id = data['lover1Id'];
        final int? l2Id = data['lover2Id'];
        if (l1Id != null && l2Id != null) {
          bool l1Dead = players.any((p) => p['id'] == l1Id && p['isAlive'] == false);
          bool l2Dead = players.any((p) => p['id'] == l2Id && p['isAlive'] == false);

          if (l1Dead || l2Dead) {
            for (var p in players) {
              if ((p['id'] == l1Id || p['id'] == l2Id) && p['isAlive'] == true) {
                p['isAlive'] = false;
                messages.add({
                  'senderName': 'system',
                  'content': 'lover_tragedy',
                  'targetName': p['name'],
                  'isSystem': true,
                  'time': Timestamp.now()
                });
              }
            }
          }
        }

        if (nextPhase == 'night') {
          updates['dayNumber'] = (data['dayNumber'] ?? 1) + 1;
        }

        if (nextPhase == 'day') {
          updates['cursedPlayerId'] = null; // Reset lời nguyền khi trời sáng
          updates['xathuHasShotToday'] = false;
        }

        transaction.update(roomRef, updates);
        if (messages.isNotEmpty) {
          transaction.update(roomRef, {'messages': FieldValue.arrayUnion(messages)});
        }

        // --- KIỂM TRA THẮNG CUỘC TRÊN SERVER ---
        // Nếu Nerd đã thắng (status ended), không kiểm tra các điều kiện thắng khác
        if (updates['status'] == 'ended') return;

        // KIỂM TRA TÌNH NHÂN CÒN SỐNG: Nếu 2 tình nhân còn sống, chưa phân định thắng thua đội ngay
        final int? lover1Id = data['lover1Id'];
        final int? lover2Id = data['lover2Id'];
        bool bothLoversAlive = false;
        if (lover1Id != null && lover2Id != null) {
          bool l1Alive = players.any((p) => p['id'] == lover1Id && p['isAlive'] == true);
          bool l2Alive = players.any((p) => p['id'] == lover2Id && p['isAlive'] == true);
          bothLoversAlive = l1Alive && l2Alive;
        }

        int wolves = players.where((p) => p['isAlive'] == true && (p['roleId'] == 'soi' || p['roleId'] == 'soi_nguyen' || p['roleId'] == 'soi_dau_dan')).length;
        int others = players.where((p) => p['isAlive'] == true && !(p['roleId'] == 'soi' || p['roleId'] == 'soi_nguyen' || p['roleId'] == 'soi_dau_dan')).length;
        int totalAlive = wolves + others;

        if (bothLoversAlive) {
          // Phe Tình Nhân thắng khi chỉ còn họ (hoặc thêm Cupid) sống sót
          if (totalAlive == 2 || (totalAlive == 3 && players.any((p) => p['isAlive'] == true && p['roleId'] == 'cupid'))) {
            transaction.update(roomRef, {'status': 'ended', 'winner': 'lovers'});
          }
          return; // Tạm dừng các điều kiện thắng Phe Dân/Sói nếu Tình Nhân còn sống
        }

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

        // ĐIỀU CHỈNH ONLINE: Ban ngày mọi phiếu bầu đều có trọng số là 1 (theo yêu cầu)
        // Bất kể client gửi weight bao nhiêu, server sẽ dùng 1.
        const int actualWeight = 1;

        int? oldTargetId = players[voterIndex]['votedForId'];
        if (oldTargetId == newTargetId) return;

        bool changed = false;

        if (oldTargetId != null && oldTargetId != -1) {
          int oldTargetIdx = players.indexWhere((p) => p['id'] == oldTargetId);
          if (oldTargetIdx != -1) {
            players[oldTargetIdx]['voteCount'] = (players[oldTargetIdx]['voteCount'] ?? 0) - actualWeight;
            if (players[oldTargetIdx]['voteCount'] < 0) players[oldTargetIdx]['voteCount'] = 0;
            changed = true;
          }
        }

        if (newTargetId != -1) {
          int newTargetIdx = players.indexWhere((p) => p['id'] == newTargetId);
          if (newTargetIdx != -1) {
            players[newTargetIdx]['voteCount'] = (players[newTargetIdx]['voteCount'] ?? 0) + actualWeight;
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

  /// Phù Thủy sử dụng bình cứu
  Future<void> useWitchHeal(String roomCode, int targetId) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);

        for (var p in players) {
          if (p['id'] == targetId) {
            p['isAlive'] = true;
            p['isProtected'] = true;
            p['wasHealedByWitch'] = true;
            break;
          }
        }
        transaction.update(roomRef, {
          'players': players,
          'witchReviveTargetId': targetId,
        });
      });
    } catch (e) {
      debugPrint('Error in useWitchHeal: $e');
    }
  }

  /// Thực hiện hành động tiêu diệt (Xạ Thủ, Thợ Săn, Phù Thủy độc) trong 1 Transaction duy nhất để đạt tốc độ cao nhất
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

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);
        List messages = List.from(data['messages'] ?? []);

        // 1. Cập nhật trạng thái người chơi
        for (var p in players) {
          if (p['id'] == targetId) {
            p['isAlive'] = false;
            break;
          }
        }

        // 2. Gộp các cập nhật của phòng
        Map<String, dynamic> finalUpdates = {
          'players': players,
        };
        if (roomUpdates != null) {
          finalUpdates.addAll(roomUpdates);
        }

        // 3. Thêm tin nhắn hệ thống nếu có
        if (systemMessage != null) {
          messages.add(systemMessage);
          finalUpdates['messages'] = messages;
        }

        transaction.update(roomRef, finalUpdates);
      }, maxAttempts: 2); // Giảm maxAttempts để phản hồi nhanh hoặc lỗi sớm
    } catch (e) {
      debugPrint('Error in executeKillAction: $e');
    }
  }

  /// Xử lý Bite của Sói (Gộp vote và werewolfTargetId)
  Future<void> submitBiteTransaction(String roomCode, String voterName, int newTargetId, int weight) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        List players = List.from(data['players'] ?? []);

        int voterIndex = players.indexWhere((p) => p['name'] == voterName);
        if (voterIndex == -1) return;

        // ĐIỀU CHỈNH ONLINE: Server tự xác định trọng số dựa trên vai trò thực tế
        final int actualWeight = players[voterIndex]['roleId'] == 'soi_dau_dan' ? 2 : 1;
        debugPrint('Transaction: $voterName (role: ${players[voterIndex]['roleId']}) votes $newTargetId with weight $actualWeight');

        int? oldTargetId = players[voterIndex]['votedForId'];
        if (oldTargetId == newTargetId) return;

        if (oldTargetId != null && oldTargetId != -1) {
          int oldTargetIdx = players.indexWhere((p) => p['id'] == oldTargetId);
          if (oldTargetIdx != -1) {
            players[oldTargetIdx]['voteCount'] = (players[oldTargetIdx]['voteCount'] ?? 0) - actualWeight;
            if (players[oldTargetIdx]['voteCount'] < 0) players[oldTargetIdx]['voteCount'] = 0;
          }
        }

        if (newTargetId != -1) {
          int newTargetIdx = players.indexWhere((p) => p['id'] == newTargetId);
          if (newTargetIdx != -1) {
            players[newTargetIdx]['voteCount'] = (players[newTargetIdx]['voteCount'] ?? 0) + actualWeight;
          }
        }

        players[voterIndex]['votedForId'] = newTargetId;

        // Tính toán lại werewolfTargetId ngay trong Transaction với luật Đồng thuận (Consensus)
        int maxV = 0;
        int? leadingTargetId;
        bool isTie = false;
        for (var p in players) {
          int v = p['voteCount'] ?? 0;
          if (v > maxV) {
            maxV = v;
            leadingTargetId = p['id'];
            isTie = false;
          } else if (v == maxV && v > 0) {
            isTie = true;
          }
        }

        transaction.update(roomRef, {
          'players': players,
          'werewolfTargetId': isTie ? null : leadingTargetId,
        });
      }, maxAttempts: 2);
    } catch (e) {
      debugPrint('Error in submitBiteTransaction: $e');
    }
  }
}

final firestoreSvc = FirestoreService();
