import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'game_logic.dart';

/// A lightweight snapshot of an online room's metadata (not the live game
/// state itself — that comes from [FirebaseService.watchRoom]).
class OnlineRoom {
  final String roomId;
  final String code;
  final String hostUid;
  final String? guestUid;
  final String status; // 'waiting' | 'active' | 'finished'
  final String hostName;
  final String? guestName;

  OnlineRoom({
    required this.roomId,
    required this.code,
    required this.hostUid,
    required this.guestUid,
    required this.status,
    required this.hostName,
    required this.guestName,
  });

  factory OnlineRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return OnlineRoom(
      roomId: doc.id,
      code: d['code'] as String,
      hostUid: d['hostUid'] as String,
      guestUid: d['guestUid'] as String?,
      status: d['status'] as String,
      hostName: d['hostName'] as String? ?? 'Player 1',
      guestName: d['guestName'] as String?,
    );
  }
}

/// Central place for every Firebase call this app makes. Keeping it all
/// here means game_screen / lobby widgets never touch Firestore directly.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get uid => _auth.currentUser?.uid;

  /// Signs the device in anonymously if not already signed in. Call this
  /// once at app startup (see main.dart).
  Future<User> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  // ---------------------------------------------------------------------
  // Random matchmaking
  // ---------------------------------------------------------------------
  //
  // Players who tap "Quick Match" add themselves to `matchmaking_queue`.
  // Whoever finds an existing waiting entry claims it (via a transaction)
  // and creates the room; the original entry's `roomId` field is filled in
  // so the first player's listener picks it up too.

  /// Joins the quick-match queue and returns a stream that emits the
  /// roomId once a match is found. Cancel the subscription (and call
  /// [cancelQuickMatch]) if the user backs out before a match happens.
  Stream<String> quickMatch(String displayName) {
    final controller = StreamController<String>();
    _runQuickMatch(displayName, controller);
    return controller.stream;
  }

  String? _myQueueDocId;

  Future<void> _runQuickMatch(
      String displayName, StreamController<String> controller) async {
    try {
      final myUid = uid;
      if (myUid == null) throw StateError('Not signed in');

      final queue = _db.collection('matchmaking_queue');

      // Look for someone already waiting.
      final waiting = await queue
          .where('status', isEqualTo: 'waiting')
          .orderBy('createdAt')
          .limit(5)
          .get();

      DocumentSnapshot<Map<String, dynamic>>? opponent;
      for (final doc in waiting.docs) {
        if (doc.data()['uid'] != myUid) {
          opponent = doc;
          break;
        }
      }

      if (opponent != null) {
        // Try to claim this opponent's queue slot in a transaction so two
        // players racing for the same slot can't both succeed.
        final roomId = await _db.runTransaction<String?>((txn) async {
          final fresh = await txn.get(opponent!.reference);
          if (fresh.data()?['status'] != 'waiting') return null;

          final roomRef = _db.collection('rooms').doc();
          final oppUid = fresh.data()!['uid'] as String;
          final oppName = fresh.data()!['name'] as String? ?? 'Player 1';

          txn.set(roomRef, {
            'code': _generateRoomCode(),
            'hostUid': oppUid,
            'hostName': oppName,
            'guestUid': myUid,
            'guestName': displayName,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'state': GameState().toJson(),
            'lastMoveAt': FieldValue.serverTimestamp(),
          });
          txn.update(opponent.reference, {
            'status': 'matched',
            'roomId': roomRef.id,
          });
          return roomRef.id;
        });

        if (roomId != null) {
          controller.add(roomId);
          await controller.close();
          return;
        }
        // Transaction lost the race — fall through and queue ourselves.
      }

      // No one waiting (or we lost the race) — add ourselves to the queue
      // and listen for someone else to match with us.
      final myDoc = await queue.add({
        'uid': myUid,
        'name': displayName,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'roomId': null,
      });
      _myQueueDocId = myDoc.id;

      final sub = myDoc.snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        final roomId = data['roomId'] as String?;
        if (roomId != null && data['status'] == 'matched') {
          controller.add(roomId);
          controller.close();
        }
      });

      controller.onCancel = () async {
        await sub.cancel();
        await cancelQuickMatch();
      };
    } catch (e, st) {
      controller.addError(e, st);
      await controller.close();
    }
  }

  /// Removes the player's own queue entry (call when leaving the lobby
  /// screen without having matched, or after a match completes).
  Future<void> cancelQuickMatch() async {
    final id = _myQueueDocId;
    if (id == null) return;
    _myQueueDocId = null;
    try {
      await _db.collection('matchmaking_queue').doc(id).delete();
    } catch (_) {
      // Already gone / matched — fine to ignore.
    }
  }

  // ---------------------------------------------------------------------
  // Room codes (private invite)
  // ---------------------------------------------------------------------

  String _generateRoomCode() {
    final rng = Random();
    return List.generate(5, (_) => rng.nextInt(10)).join();
  }

  /// Creates a new room as host and returns its roomId immediately. The
  /// room stays in `waiting` status until a guest joins via [joinRoomByCode].
  Future<String> createRoom(String displayName) async {
    final myUid = uid;
    if (myUid == null) throw StateError('Not signed in');

    final roomRef = _db.collection('rooms').doc();
    await roomRef.set({
      'code': _generateRoomCode(),
      'hostUid': myUid,
      'hostName': displayName,
      'guestUid': null,
      'guestName': null,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
      'state': GameState().toJson(),
      'lastMoveAt': FieldValue.serverTimestamp(),
    });
    return roomRef.id;
  }

  /// Looks up a room by its short code and joins it as guest. Throws a
  /// descriptive [Exception] if the code is invalid or the room is full.
  Future<String> joinRoomByCode(String code, String displayName) async {
    final myUid = uid;
    if (myUid == null) throw StateError('Not signed in');

    final query = await _db
        .collection('rooms')
        .where('code', isEqualTo: code.trim())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Room not found or already full');
    }

    final roomRef = query.docs.first.reference;

    final joined = await _db.runTransaction<bool>((txn) async {
      final fresh = await txn.get(roomRef);
      if (fresh.data()?['status'] != 'waiting') return false;
      txn.update(roomRef, {
        'guestUid': myUid,
        'guestName': displayName,
        'status': 'active',
      });
      return true;
    });

    if (!joined) {
      throw Exception('Someone else just joined this room');
    }
    return roomRef.id;
  }

  /// Cancels a room this player created while still waiting for a guest.
  Future<void> deleteRoom(String roomId) async {
    await _db.collection('rooms').doc(roomId).delete();
  }

  // ---------------------------------------------------------------------
  // Live room + game-state sync
  // ---------------------------------------------------------------------

  Stream<OnlineRoom> watchRoomMeta(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .where((doc) => doc.exists)
        .map(OnlineRoom.fromDoc);
  }

  /// Streams the live [GameState] for a room. Both players listen to this;
  /// whichever side moves writes back through [pushMove].
  Stream<GameState> watchGameState(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .where((doc) => doc.exists && doc.data()!['state'] != null)
        .map((doc) => GameState.fromJson(
            Map<String, dynamic>.from(doc.data()!['state'] as Map)));
  }

  /// Writes a new game state to the room. Uses a transaction keyed on
  /// [expectedMoveCount] so a stale client can't clobber a move that
  /// already landed (e.g. after a dropped connection).
  Future<void> pushMove(
      String roomId, GameState newState, int expectedMoveCount) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    await _db.runTransaction((txn) async {
      final fresh = await txn.get(roomRef);
      final current = fresh.data()?['state'] as Map?;
      final currentMoveCount = (current?['moveCount'] as int?) ?? 0;
      if (currentMoveCount != expectedMoveCount) {
        // Someone else's write already landed; reject silently and let the
        // caller's own listener re-sync from the fresh state.
        throw StateError('stale-move');
      }
      txn.update(roomRef, {
        'state': newState.toJson(),
        'lastMoveAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Marks presence so the opponent can tell if you've left mid-game.
  Future<void> setPresence(String roomId, bool online) async {
    final myUid = uid;
    if (myUid == null) return;
    await _db.collection('rooms').doc(roomId).update({
      'presence.$myUid': online,
      'presence.${myUid}_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveRoom(String roomId) async {
    await setPresence(roomId, false);
  }
}
