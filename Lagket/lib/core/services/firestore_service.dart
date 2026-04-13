import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/photo_model.dart';
import '../../shared/models/friend_request_model.dart';
import '../../shared/models/friendship_model.dart';

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
}
