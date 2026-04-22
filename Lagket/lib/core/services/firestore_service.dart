import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/photo_model.dart';
import '../../shared/models/reaction_model.dart';
import '../../shared/models/message_model.dart';
import '../../shared/models/conversation_model.dart';
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

  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'fcmToken': token,
    });
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

  // ─── Photos ────────────────────────────────────────────────────────────────

  Stream<List<PhotoModel>> watchSentPhotos(String userId) {
    return _db
        .collection(AppConstants.photosCollection)
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PhotoModel.fromMap(d.data(), d.id)).toList());
  }

  Future<int> getSentPhotoCount(String userId) async {
    final snap = await _db
        .collection(AppConstants.photosCollection)
        .where('senderId', isEqualTo: userId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Stream<List<PhotoModel>> watchSentPhotosForYear(String userId, int year) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31, 23, 59, 59);

    return _db
        .collection(AppConstants.photosCollection)
        .where('senderId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PhotoModel.fromMap(d.data(), d.id)).toList());
  }

  Future<String> createPhoto(PhotoModel photo) async {
    final doc = _db.collection(AppConstants.photosCollection).doc();
    final newPhoto = photo.copyWith(id: doc.id);
    await doc.set(newPhoto.toMap());
    return doc.id;
  }

  Future<void> deletePhoto(String photoId) async {
    // 1. Delete the photo document
    await _db.collection(AppConstants.photosCollection).doc(photoId).delete();

    // 2. Delete reactions associated with this photo
    final reactions = await _db
        .collection(AppConstants.reactionsCollection)
        .where('photoId', isEqualTo: photoId)
        .get();
    
    final batch = _db.batch();
    for (var doc in reactions.docs) {
      batch.delete(doc.reference);
    }
    
    // 3. Delete reply messages associated with this photo
    final messages = await _db
        .collectionGroup(AppConstants.messagesCollection)
        .where('photoId', isEqualTo: photoId)
        .get();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ─── Feed ──────────────────────────────────────────────────────────────────

  Stream<List<PhotoModel>> watchFeed(String currentUserId) async* {
    final friendsSnap = _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: currentUserId)
        .snapshots();

    await for (final snap in friendsSnap) {
      final friendIds = snap.docs.map((d) => d.data()['friendId'] as String).toList();

      yield* _db
          .collection(AppConstants.photosCollection)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => PhotoModel.fromMap(d.data(), d.id))
              .where((photo) {
                // Hiển thị nếu:
                // 1. Là ảnh của mình (kể cả private)
                // 2. Là ảnh của bạn bè và KHÔNG phải là private
                if (photo.senderId == currentUserId) return true;
                if (friendIds.contains(photo.senderId) && !photo.isPrivate) return true;
                return false;
              })
              .toList());
    }
  }

  // ─── Reactions ─────────────────────────────────────────────────────────────

  Stream<List<ReactionModel>> watchReactions(String photoId) {
    return _db
        .collection(AppConstants.reactionsCollection)
        .where('photoId', isEqualTo: photoId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReactionModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> upsertReaction({
    required String photoId,
    required String userId,
    required ReactionType type,
  }) async {
    final id = '${photoId}_$userId';
    await _db.collection(AppConstants.reactionsCollection).doc(id).set({
      'id': id,
      'photoId': photoId,
      'userId': userId,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeReaction({
    required String photoId,
    required String userId,
  }) async {
    final id = '${photoId}_$userId';
    await _db.collection(AppConstants.reactionsCollection).doc(id).delete();
  }

  // ─── Friends & Requests ─────────────────────────────────────────────────────

  Stream<List<FriendshipModel>> watchFriendships(String userId) {
    return _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendshipModel.fromMap(d.data(), d.id))
            .toList());
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
    required String status,
    required String fromUserId,
    required String toUserId,
  }) async {
    final batch = _db.batch();

    batch.update(
      _db.collection(AppConstants.friendRequestsCollection).doc(requestId),
      {'status': status},
    );

    if (status == 'accepted') {
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

  Future<void> createFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    final id = '${fromUserId}_$toUserId';
    await _db.collection(AppConstants.friendRequestsCollection).doc(id).set({
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> areFriends(String user1, String user2) async {
    final snap = await _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: user1)
        .where('friendId', isEqualTo: user2)
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

  Future<void> removeFriendship({
    required String userId,
    required String friendId,
  }) async {
    final batch = _db.batch();

    // 1. Delete friendship documents
    final snap1 = await _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: userId)
        .where('friendId', isEqualTo: friendId)
        .get();

    final snap2 = await _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: friendId)
        .where('friendId', isEqualTo: userId)
        .get();

    for (var d in snap1.docs) batch.delete(d.reference);
    for (var d in snap2.docs) batch.delete(d.reference);

    // 2. Find and delete conversation
    final participants = [userId, friendId]..sort();
    final convSnap = await _db
        .collection(AppConstants.conversationsCollection)
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (convSnap.docs.isNotEmpty) {
      final convDoc = convSnap.docs.first;
      
      // Delete all messages in sub-collection first
      final messagesSnap = await convDoc.reference
          .collection(AppConstants.messagesCollection)
          .get();
      
      for (var m in messagesSnap.docs) {
        batch.delete(m.reference);
      }

      // Delete the conversation document itself
      batch.delete(convDoc.reference);
    }

    await batch.commit();
  }

  Stream<List<UserModel>> watchFriends(String userId) {
    return _db
        .collection(AppConstants.friendshipsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final friends = <UserModel>[];
      for (final doc in snap.docs) {
        final friendId = doc.data()['friendId'] as String;
        final user = await getUser(friendId);
        if (user != null) friends.add(user);
      }
      return friends;
    });
  }

  // ─── Messaging ─────────────────────────────────────────────────────────────

  Stream<List<ConversationModel>> watchConversations(String userId) {
    return _db
        .collection(AppConstants.conversationsCollection)
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ConversationModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<MessageModel>> watchConversationMessages(String conversationId) {
    return _db
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .collection(AppConstants.messagesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
  }

  Future<String> getOrCreateConversation(String user1, String user2) async {
    final participants = [user1, user2]..sort();
    final snap = await _db
        .collection(AppConstants.conversationsCollection)
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) return snap.docs.first.id;

    final doc = _db.collection(AppConstants.conversationsCollection).doc();
    await doc.set({
      'id': doc.id,
      'participants': participants,
      'lastMessage': '',
      'lastMessageSenderId': '',
      'readBy': [user1, user2],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final batch = _db.batch();
    final msgDoc = _db
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .collection(AppConstants.messagesCollection)
        .doc();

    batch.set(msgDoc, {
      'id': msgDoc.id,
      'senderId': senderId,
      'content': content,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection(AppConstants.conversationsCollection).doc(conversationId), {
      'lastMessage': content,
      'lastMessageSenderId': senderId,
      'readBy': [senderId],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> sendPhotoReplyMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required String photoId,
  }) async {
    final batch = _db.batch();
    final msgDoc = _db
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .collection(AppConstants.messagesCollection)
        .doc();

    batch.set(msgDoc, {
      'id': msgDoc.id,
      'senderId': senderId,
      'content': content,
      'type': 'photo_reply',
      'photoId': photoId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection(AppConstants.conversationsCollection).doc(conversationId), {
      'lastMessage': 'Replied to a photo: $content',
      'lastMessageSenderId': senderId,
      'readBy': [senderId],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> sendReactionMessage({
    required String conversationId,
    required String senderId,
    required String reactionEmoji,
    required String photoId,
  }) async {
    await sendPhotoReplyMessage(
      conversationId: conversationId,
      senderId: senderId,
      content: 'Reacted with $reactionEmoji',
      photoId: photoId,
    );
  }

  Stream<List<MessageModel>> watchMessages(String photoId) {
    // This seems to be for watching messages related to a specific photo (replies)
    // We use collectionGroup to find all messages with this photoId
    return _db
        .collectionGroup(AppConstants.messagesCollection)
        .where('photoId', isEqualTo: photoId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> markConversationAsRead(String conversationId, String userId) async {
    await _db
        .collection(AppConstants.conversationsCollection)
        .doc(conversationId)
        .update({
      'readBy': FieldValue.arrayUnion([userId]),
    });
  }

  // ─── Combined History ──────────────────────────────────────────────────────

  Stream<List<PhotoModel>> watchCombinedHistory(String currentUserId) async* {
    yield* watchFeed(currentUserId);
  }

  Future<PhotoModel?> getPhoto(String photoId) async {
    final doc = await _db.collection(AppConstants.photosCollection).doc(photoId).get();
    if (!doc.exists) return null;
    return PhotoModel.fromMap(doc.data()!, doc.id);
  }
}
