import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;

  /// Always exactly 2 user IDs, sorted lexicographically so we can query
  /// by the array without caring about order.
  final List<String> participants;

  /// Preview text shown in the conversation list.
  final String lastMessage;

  final String? lastMessageSenderId;

  final List<String> readBy;

  final DateTime? updatedAt;

  const ConversationModel({
    required this.id,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageSenderId,
    this.readBy = const [],
    this.updatedAt,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      readBy: List<String>.from(map['readBy'] ?? []),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'participants': participants,
        'lastMessage': lastMessage,
        'lastMessageSenderId': lastMessageSenderId,
        'readBy': readBy,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Helper: return the other participant's id (not the current user).
  String otherParticipant(String myId) =>
      participants.firstWhere((p) => p != myId, orElse: () => '');
}
