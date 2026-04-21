import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoModel {
  final String id;
  final String senderId;
  final List<String> receiverIds;
  final String imageUrl;
  final String? caption;
  final DateTime? createdAt;
  final bool isPrivate;

  const PhotoModel({
    required this.id,
    required this.senderId,
    required this.receiverIds,
    required this.imageUrl,
    this.caption,
    this.createdAt,
    this.isPrivate = false,
  });

  factory PhotoModel.fromMap(Map<String, dynamic> map, String id) {
    return PhotoModel(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverIds: List<String>.from(map['receiverIds'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      caption: map['caption'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      isPrivate: map['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'receiverIds': receiverIds,
        'imageUrl': imageUrl,
        'caption': caption,
        'createdAt': FieldValue.serverTimestamp(),
        'isPrivate': isPrivate,
      };

  PhotoModel copyWith({
    String? id,
    String? senderId,
    List<String>? receiverIds,
    String? imageUrl,
    String? caption,
    DateTime? createdAt,
    bool? isPrivate,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverIds: receiverIds ?? this.receiverIds,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
