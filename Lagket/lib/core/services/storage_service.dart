import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// Upload a photo and return its download URL
  Future<String> uploadPhoto({
    required File file,
    required String senderId,
  }) async {
    final filename = '${_uuid.v4()}.jpg';
    final ref = _storage.ref('${AppConstants.photosPath}/$senderId/$filename');

    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await task.ref.getDownloadURL();
  }

  /// Upload an avatar and return its download URL
  Future<String> uploadAvatar({
    required File file,
    required String userId,
  }) async {
    final ref =
        _storage.ref('${AppConstants.avatarsPath}/$userId/avatar.jpg');

    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await task.ref.getDownloadURL();
  }

  /// Delete a file by its download URL
  Future<void> deleteByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // Ignore if file doesn't exist
    }
  }
}
