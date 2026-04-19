import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/photo_model.dart';
import '../../shared/models/reaction_model.dart';
import '../../shared/models/message_model.dart';
import '../../shared/models/friend_request_model.dart';
import '../../shared/models/friendship_model.dart';
import '../constants/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── User ───────────────────────────────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    final doc =
        await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((snap) =>
            snap.exists ? UserModel.fromMap(snap.data()!, snap.id) : null);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update(data);
  }

  Future<List<UserModel>> searchUsersByUsername(String query) async {
    final snap = await _db
        .collection(AppConstants.usersCollection)
        .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .limit(20)
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .toList();
  }

  // ─── Photos ─────────────────────────────────────────────────────────────────

  Future<String> createPhoto(PhotoModel photo) async {
    final doc = _db.collection(AppConstants.photosCollection).doc();
    final model = photo.copyWith(id: doc.id);
    await doc.set(model.toMap());
    return doc.id;
  }

  Stream<List<PhotoModel>> watchFeed(String userId) {
    return _db
        .collection(AppConstants.photosCollection)
        .where('receiverIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.feedPageSize)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PhotoModel.fromMap(d.data(), d.id)).toList());
  }

  Future<PhotoModel?> getPhoto(String photoId) async {
    final doc = await _db
        .collection(AppConstants.photosCollection)
        .doc(photoId)
        .get();
    if (!doc.exists) return null;
    return PhotoModel.fromMap(doc.data()!, doc.id);
  }

  // ─── Friends ─────────────────────────────────────────────────────────────────

  Future<void> createFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    final doc = _db.collection(AppConstants.friendRequestsCollection).doc();
    await doc.set({
      'id': doc.id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<FriendRequestModel>> watchIncomingRequests(String userId) {
    return _db
        .collection(AppConstants.friendRequestsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequestModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<FriendRequestModel>> watchOutgoingRequests(String userId) {
    return _db
        .collection(AppConstants.friendRequestsCollection)
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequestModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> respondToFriendRequest({
    required String requestId,
    required String status, // 'accepted' | 'rejected'
    required String fromUserId,
    required String toUserId,
  }) async {
    final batch = _db.batch();

    // Update request status
    batch.update(
      _db.collection(AppConstants.friendRequestsCollection).doc(requestId),
      {'status': status},
    );

    if (status == 'accepted') {
      // Create both-direction friendship docs
      final f1 = _db.collection(AppConstants.friendshipsCollection).doc();
      final f2 = _db.collection(AppConstants.friendshipsCollection).doc();

      batch.set(f1, {
        'id': f1.id,
        'userId': fromUserId,
        'friendId': toUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(f2, {
        'id': f2.id,
        'userId': toUserId,
        'friendId': fromUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Stream<List<FriendshipModel>> watchFriendships(String userId) {
    return _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendshipModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> removeFriendship({
    required String userId,
    required String friendId,
  }) async {
    final batch = _db.batch();

    final q1 = await _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: userId)
        .where('friendId', isEqualTo: friendId)
        .get();

    final q2 = await _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: friendId)
        .where('friendId', isEqualTo: userId)
        .get();

    for (final d in [...q1.docs, ...q2.docs]) {
      batch.delete(d.reference);
    }

    await batch.commit();
  }

  Future<bool> areFriends(String userId, String otherUserId) async {
    final snap = await _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: userId)
        .where('friendId', isEqualTo: otherUserId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<bool> hasPendingRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    final snap = await _db
        .collection(AppConstants.friendRequestsCollection)
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ─── History ──────────────────────────────────────────────────────────────────

  /// Combined history stream: sent + received, deduplicated, sorted newest first.
  Stream<List<PhotoModel>> watchCombinedHistory(String userId) {
    // We return the received stream and merge sent on top.
    // A simple approach: use the receiverIds stream as base and add own sent.
    final col = _db.collection(AppConstants.photosCollection);

    final receivedStream = col
        .where('receiverIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    final sentStream = col
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    // Merge the two QuerySnapshots by listening to both and re-emitting on change.
    return _mergeTwoPhotoStreams(sentStream, receivedStream);
  }

  Stream<List<PhotoModel>> _mergeTwoPhotoStreams(
    Stream<QuerySnapshot<Map<String, dynamic>>> a,
    Stream<QuerySnapshot<Map<String, dynamic>>> b,
  ) async* {
    List<PhotoModel> latestA = [];
    List<PhotoModel> latestB = [];
    bool aReady = false;
    bool bReady = false;

    final controller = StreamController<List<PhotoModel>>.broadcast();

    a.listen((snap) {
      latestA = snap.docs.map((d) => PhotoModel.fromMap(d.data(), d.id)).toList();
      aReady = true;
      if (bReady) controller.add(_mergePhotos(latestA, latestB));
    });

    b.listen((snap) {
      latestB = snap.docs.map((d) => PhotoModel.fromMap(d.data(), d.id)).toList();
      bReady = true;
      if (aReady) controller.add(_mergePhotos(latestA, latestB));
    });

    yield* controller.stream;
  }

  List<PhotoModel> _mergePhotos(List<PhotoModel> a, List<PhotoModel> b) {
    final map = <String, PhotoModel>{};
    for (final p in [...a, ...b]) {
      map[p.id] = p;
    }
    final merged = map.values.toList();
    merged.sort((x, y) {
      if (x.createdAt == null) return 1;
      if (y.createdAt == null) return -1;
      return y.createdAt!.compareTo(x.createdAt!);
    });
    return merged;
  }

  /// Stream of photos sent by a user in a given year (for calendar view).
  /// Requires a composite Firestore index: senderId ASC + createdAt ASC.
  Stream<List<PhotoModel>> watchSentPhotosForYear(String userId, int year) {
    final start = Timestamp.fromDate(DateTime(year));
    final end = Timestamp.fromDate(DateTime(year + 1));
    return _db
        .collection(AppConstants.photosCollection)
        .where('senderId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => PhotoModel.fromMap(d.data(), d.id)).toList());
  }

  /// Count of photos sent by this user (for profile stats).
  Future<int> getSentPhotoCount(String userId) async {
    final snap = await _db
        .collection(AppConstants.photosCollection)
        .where('senderId', isEqualTo: userId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ─── Reactions ────────────────────────────────────────────────────────────────

  /// Upsert a reaction. Each user can have at most ONE reaction per photo
  /// (document id = `<photoId>_<userId>` to enforce uniqueness cheaply).
  Future<void> upsertReaction({
    required String photoId,
    required String userId,
    required ReactionType type,
  }) async {
    final docId = '${photoId}_$userId';
    await _db.collection(AppConstants.reactionsCollection).doc(docId).set({
      'photoId': photoId,
      'userId': userId,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a user's reaction from a photo.
  Future<void> removeReaction({required String photoId, required String userId}) async {
    final docId = '${photoId}_$userId';
    await _db.collection(AppConstants.reactionsCollection).doc(docId).delete();
  }

  /// Real-time stream of all reactions for a single photo.
  Stream<List<ReactionModel>> watchReactions(String photoId) {
    return _db
        .collection(AppConstants.reactionsCollection)
        .where('photoId', isEqualTo: photoId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReactionModel.fromMap(d.data(), d.id)).toList());
  }

  // ─── Messages ─────────────────────────────────────────────────────────────────

  /// Add a message to a photo.
  Future<void> addMessage({
    required String photoId,
    required String senderId,
    required String content,
  }) async {
    final doc = _db.collection(AppConstants.messagesCollection).doc();
    await doc.set({
      'id': doc.id,
      'photoId': photoId,
      'senderId': senderId,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of messages for a photo, oldest first.
  Stream<List<MessageModel>> watchMessages(String photoId) {
    return _db
        .collection(AppConstants.messagesCollection)
        .where('photoId', isEqualTo: photoId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
  }
}
