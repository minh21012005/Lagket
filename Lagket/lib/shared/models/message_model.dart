import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String photoId;
  final String senderId;
  final String content;
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.photoId,
    required this.senderId,
    required this.content,
    this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      photoId: map['photoId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'photoId': photoId,
        'senderId': senderId,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
