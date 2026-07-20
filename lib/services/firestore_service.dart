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
      });
      
      await _updatePresence(roomCode, hostName);
      
      await _db.collection('rooms').doc(roomCode).collection('messages').add({
        'senderName': 'system',
        'content': 'lobby_created',
        'isSystem': true,
        'time': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating room: $e');
      rethrow;
    }
  }

  /// Heartbeat riêng biệt (Tối ưu: Không làm phiền các máy khác tải lại phòng)
  Future<void> _updatePresence(String roomCode, String playerName) async {
    try {
      await _db.collection('rooms').doc(roomCode).collection('presence').doc(playerName).set({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Presence error: $e');
    }
  }

  Future<void> updateLastSeen(String roomCode, String playerName) => _updatePresence(roomCode, playerName);

  Future<void> deleteRoom(String roomCode) async {
    try {
      await _db.collection('rooms').doc(roomCode).delete();
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  Future<void> joinRoom(String roomCode, String userName) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) throw Exception('Room not found');

        final data = snapshot.data()!;
        Map<String, dynamic> players = Map<String, dynamic>.from(data['players'] ?? {});
        if (players.length >= (data['playerCount'] ?? 15)) throw Exception('Room is full');
        if (players.values.any((p) => p['name'] == userName)) throw Exception('username_already_exists');

        int maxId = 0;
        for (var p in players.values) {
          if (p['id'] > maxId) maxId = p['id'];
        }
        int nextId = maxId + 1;

        transaction.update(roomRef, {
          'players.p$nextId': {
            'id': nextId,
            'name': userName,
            'isHost': false,
            'isReady': false,
            'isAlive': true,
            'voteCount': 0,
            'votedForId': null,
          },
          'currentPlayersCount': players.length + 1,
        });
      });
      await _updatePresence(roomCode, userName);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveRoom(String roomCode, String userName) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        Map<String, dynamic> players = Map<String, dynamic>.from(snapshot.data()!['players'] ?? {});
        String? targetKey;
        players.forEach((k, v) { if (v['name'] == userName) targetKey = k; });

        if (targetKey == null) return;
        bool wasHost = players[targetKey]['isHost'] == true;
        players.remove(targetKey);

        if (players.isEmpty) {
          transaction.delete(roomRef);
        } else {
          Map<String, dynamic> updates = {'players': players, 'currentPlayersCount': players.length};
          if (wasHost) {
            String firstKey = players.keys.first;
            updates['players.$firstKey.isHost'] = true;
            updates['hostName'] = players[firstKey]['name'];
          }
          transaction.update(roomRef, updates);
        }
      });
      await _db.collection('rooms').doc(roomCode).collection('presence').doc(userName).delete();
    } catch (e) {
      debugPrint('Error leaving: $e');
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getRoomStream(String roomCode) {
    return _db.collection('rooms').doc(roomCode).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(String roomCode) {
    return _db.collection('rooms').doc(roomCode).collection('messages').orderBy('time', descending: true).limit(50).snapshots();
  }

  Future<void> sendChatMessage(String roomCode, Map<String, dynamic> messageData) async {
    messageData['time'] = FieldValue.serverTimestamp();
    await _db.collection('rooms').doc(roomCode).collection('messages').add(messageData);
  }

  Future<void> startGame(String roomCode, List<Map<String, dynamic>> playersList) async {
    Map<String, dynamic> playersMap = {};
    for (var p in playersList) { playersMap['p${p['id']}'] = p; }
    await _db.collection('rooms').doc(roomCode).update({
      'status': 'playing',
      'players': playersMap,
      'currentPhase': 'night',
      'phaseNumber': 1,
      'dayNumber': 1,
      'phaseEndTime': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 20))),
    });
  }

  Future<void> secureNextPhase(String roomCode, int expectedPhaseNumber, String nextPhase, int durationSeconds) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        final data = snapshot.data()!;
        if ((data['phaseNumber'] ?? 0) != expectedPhaseNumber) return;

        Map<String, dynamic> players = Map<String, dynamic>.from(data['players'] ?? {});
        List<Map<String, dynamic>> logs = [];
        
        Map<String, dynamic> updates = {
          'currentPhase': nextPhase,
          'phaseNumber': expectedPhaseNumber + 1,
          'phaseEndTime': Timestamp.fromDate(DateTime.now().add(Duration(seconds: durationSeconds))),
          'werewolfTargetId': null,
          'witchReviveTargetId': null,
        };

        if (data['currentPhase'] == 'night') {
          // Logic Night Result
          Map<int, int> biteVotes = {};
          for (var p in players.values) {
            final voterRole = p['roleId'] ?? '';
            final isWolf = voterRole == 'soi' || voterRole == 'soi_nguyen' || voterRole == 'soi_dau_dan';
            if (isWolf && p['votedForId'] != null && p['votedForId'] != -1) {
              int targetId = p['votedForId'];
              int weight = (voterRole == 'soi_dau_dan') ? 2 : 1;
              biteVotes[targetId] = (biteVotes[targetId] ?? 0) + weight;
            }
          }

          int? finalWolfTargetId;
          if (biteVotes.isNotEmpty) {
            int maxV = biteVotes.values.reduce(max);
            List<int> tied = biteVotes.entries.where((e) => e.value == maxV).map((e) => e.key).toList();
            finalWolfTargetId = tied[Random().nextInt(tied.length)];
          }

          int? reviveId = data['witchReviveTargetId'];
          bool wolfKillSuccess = false;

          for (var p in players.values) {
            bool isTargetedByWolf = (finalWolfTargetId != null && p['id'] == finalWolfTargetId);
            bool isSavedByWitch = (p['id'] == reviveId && reviveId != null);

            if (isTargetedByWolf && !wolfKillSuccess) {
              if (p['isAlive'] == true && p['isProtected'] != true && !isSavedByWitch) {
                p['isAlive'] = false;
                wolfKillSuccess = true;
                logs.add({'senderName': 'system', 'content': 'night_casualty', 'targetName': p['name'], 'isSystem': true});
              }
            }
            if (isSavedByWitch) {
              p['isAlive'] = true;
              p['isProtected'] = true;
            }
            if (p['isPoisoned'] == true && p['isAlive'] == true) {
              p['isAlive'] = false;
              logs.add({'senderName': 'system', 'content': 'poison_casualty', 'targetName': p['name'], 'isSystem': true});
            }
            p['isProtected'] = false; p['isPoisoned'] = false; p['voteCount'] = 0; p['votedForId'] = null;
          }
        } else if (data['currentPhase'] == 'voting') {
          // Logic Treo cổ
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
            logs.add({'senderName': 'system', 'content': 'lynched', 'targetName': players[hangedKey!]['name'], 'isSystem': true});
            if (players[hangedKey!]['roleId'] == 'nerd') {
              updates['status'] = 'ended';
              updates['winner'] = 'nerd';
            }
          } else {
            logs.add({'senderName': 'system', 'content': 'no_lynch', 'isSystem': true});
          }
          for (var p in players.values) { p['voteCount'] = 0; p['votedForId'] = null; }
        }

        if (nextPhase == 'day') {
          logs.add({'senderName': 'system', 'content': 'sunrise', 'isSystem': true});
          updates['cursedPlayerId'] = null;
          updates['xathuHasShotToday'] = false;
        } else if (nextPhase == 'night') {
          logs.add({'senderName': 'system', 'content': 'night_start', 'isSystem': true});
          updates['dayNumber'] = (data['dayNumber'] ?? 1) + 1;
        } else if (nextPhase == 'voting') {
          logs.add({'senderName': 'system', 'content': 'voting_start', 'isSystem': true});
        }

        updates['players'] = players;
        transaction.update(roomRef, updates);
        
        for (var log in logs) {
          log['time'] = FieldValue.serverTimestamp();
          transaction.set(roomRef.collection('messages').doc(), log);
        }

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
      debugPrint('Phase error: $e');
    }
  }

  Future<void> submitVote(String roomCode, int voterId, int? oldId, int? newId) async {
    final ref = _db.collection('rooms').doc(roomCode);
    Map<String, dynamic> up = {'players.p$voterId.votedForId': newId};
    if (oldId != null && oldId != -1) up['players.p$oldId.voteCount'] = FieldValue.increment(-1);
    if (newId != null && newId != -1) up['players.p$newId.voteCount'] = FieldValue.increment(1);
    await ref.update(up);
  }

  Future<void> submitBite(String roomCode, int voterId, String roleId, int? oldId, int? newId) async {
    final ref = _db.collection('rooms').doc(roomCode);
    int w = roleId == 'soi_dau_dan' ? 2 : 1;
    Map<String, dynamic> up = {'players.p$voterId.votedForId': newId};
    if (oldId != null && oldId != -1) up['players.p$oldId.voteCount'] = FieldValue.increment(-w);
    if (newId != null && newId != -1) up['players.p$newId.voteCount'] = FieldValue.increment(w);
    await ref.update(up);
  }

  Future<bool> checkRoomExists(String code) async {
    try {
      final d = await _db.collection('rooms').doc(code).get();
      return d.exists;
    } catch (_) { return false; }
  }

  Future<void> updateRoomData(String code, Map<String, dynamic> data) => _db.collection('rooms').doc(code).update(data);

  Future<void> updatePlayerField(String roomCode, int targetId, Map<String, dynamic> fields) async {
    Map<String, dynamic> updates = {};
    fields.forEach((k, v) => updates['players.p$targetId.$k'] = v);
    await _db.collection('rooms').doc(roomCode).update(updates);
  }

  Future<void> updateMultiplePlayerFields(String roomCode, Map<int, Map<String, dynamic>> updates) async {
    Map<String, dynamic> finalUpdates = {};
    updates.forEach((id, fields) {
      fields.forEach((k, v) => finalUpdates['players.p$id.$k'] = v);
    });
    await _db.collection('rooms').doc(roomCode).update(finalUpdates);
  }

  Future<void> useWitchHeal(String roomCode, int targetId) async {
    await _db.collection('rooms').doc(roomCode).update({
      'players.p$targetId.isAlive': true,
      'players.p$targetId.isProtected': true,
      'witchReviveTargetId': targetId,
    });
  }

  Future<void> executeKillAction({required String roomCode, required int targetId, Map<String, dynamic>? roomUpdates, Map<String, dynamic>? systemMessage}) async {
    final roomRef = _db.collection('rooms').doc(roomCode);
    await _db.runTransaction((transaction) async {
      Map<String, dynamic> updates = roomUpdates ?? {};
      updates['players.p$targetId.isAlive'] = false;
      transaction.update(roomRef, updates);
      if (systemMessage != null) {
        systemMessage['time'] = FieldValue.serverTimestamp();
        transaction.set(roomRef.collection('messages').doc(), systemMessage);
      }
    });
  }

  Future<void> setHunterSkillActive(String roomCode, bool active, {int? hunterPlayerId}) async {
    await _db.collection('rooms').doc(roomCode).update({
      'hunterSkillActive': active,
      'hunterPlayerId': hunterPlayerId,
      'hunterSkillSetAt': active ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<String?> findPublicRoom() async {
    try {
      final s = await _db.collection('rooms').where('isPublic', isEqualTo: true).where('status', isEqualTo: 'waiting').limit(10).get();
      if (s.docs.isEmpty) return null;
      for (var d in s.docs) {
        final data = d.data();
        if ((data['currentPlayersCount'] ?? 0) < (data['playerCount'] ?? 15)) return d.id;
      }
    } catch (_) {}
    return null;
  }
}
final firestoreSvc = FirestoreService();
