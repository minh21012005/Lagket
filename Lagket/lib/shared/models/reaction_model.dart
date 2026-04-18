import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported reaction types. Stored as strings in Firestore so new types can
/// be added without a schema migration.
enum ReactionType {
  like('👍'),
  love('❤️'),
  fire('🔥'),
  laugh('😂'),
  wow('😮');

  final String emoji;
  const ReactionType(this.emoji);

  static ReactionType fromString(String value) =>
      ReactionType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ReactionType.like,
      );
}

class ReactionModel {
  final String id;
  final String photoId;
  final String userId;
  final ReactionType type;
  final DateTime? createdAt;

  const ReactionModel({
    required this.id,
    required this.photoId,
    required this.userId,
    required this.type,
    this.createdAt,
  });

  factory ReactionModel.fromMap(Map<String, dynamic> map, String id) {
    return ReactionModel(
      id: id,
      photoId: map['photoId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: ReactionType.fromString(map['type'] as String? ?? 'like'),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'photoId': photoId,
        'userId': userId,
        'type': type.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
