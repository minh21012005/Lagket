import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime? createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.createdAt,
  });

  factory FriendRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return FriendRequestModel(
      id: id,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      status: _parseStatus(map['status']),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  static FriendRequestStatus _parseStatus(String? value) {
    switch (value) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      default:
        return FriendRequestStatus.pending;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
