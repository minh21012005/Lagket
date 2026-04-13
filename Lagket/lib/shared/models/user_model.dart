import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String displayUsername;
  final String avatarUrl;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.displayUsername,
    required this.avatarUrl,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayUsername: map['displayUsername'] ?? map['username'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'username': username,
        'displayUsername': displayUsername,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? displayUsername,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayUsername: displayUsername ?? this.displayUsername,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
