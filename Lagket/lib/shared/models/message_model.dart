import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of message stored in a conversation.
enum MessageType {
  text,
  reaction,
  photo_reply;

  static MessageType fromString(String v) =>
      MessageType.values.firstWhere((e) => e.name == v,
          orElse: () => MessageType.text);
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageType type;

  /// Nullable – set for reaction and photo_reply messages.
  final String? photoId;
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    this.photoId,
    this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      conversationId: map['conversationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      type: MessageType.fromString(map['type'] as String? ?? 'text'),
      photoId: map['photoId'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'conversationId': conversationId,
        'senderId': senderId,
        'content': content,
        'type': type.name,
        if (photoId != null) 'photoId': photoId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
