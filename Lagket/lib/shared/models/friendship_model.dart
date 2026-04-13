import 'package:cloud_firestore/cloud_firestore.dart';

class FriendshipModel {
  final String id;
  final String userId;
  final String friendId;
  final DateTime? createdAt;

  const FriendshipModel({
    required this.id,
    required this.userId,
    required this.friendId,
    this.createdAt,
  });

  factory FriendshipModel.fromMap(Map<String, dynamic> map, String id) {
    return FriendshipModel(
      id: id,
      userId: map['userId'] ?? '',
      friendId: map['friendId'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'friendId': friendId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
