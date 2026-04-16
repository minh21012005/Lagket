import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../constants/cloudinary_config.dart';

/// Uploads images to Cloudinary using the unsigned upload preset.
///
/// Public method signatures are identical to the old FirebaseStorageService
/// so no callers need to change.
///
/// Platform notes:
///  • Android/iOS  — pass a [File]; bytes are read from disk.
///  • Web          — use [uploadPhotoBytes] / [uploadAvatarBytes] which
///                   accept [Uint8List] directly (file I/O is unavailable).
class StorageService {
  final _uuid = const Uuid();

  // ─── Internal helpers ────────────────────────────────────────────────────────

  /// Posts [bytes] to the Cloudinary unsigned upload endpoint.
  ///
  /// [folder]   – Cloudinary folder (e.g. `lagket/photos/uid123`)
  /// [publicId] – optional; when set Cloudinary always overwrites that asset
  ///              (useful for avatars so old files are replaced automatically).
  Future<String> _upload({
    required Uint8List bytes,
    required String folder,
    String? publicId,
  }) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: publicId != null ? '$publicId.jpg' : '${_uuid.v4()}.jpg',
        ),
      );

    if (publicId != null) {
      request.fields['public_id'] = publicId;
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception('Cloudinary upload failed [${streamedResponse.statusCode}]: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;

    // `secure_url` is always HTTPS — exactly what we store in Firestore.
    final url = json['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary returned no secure_url. Response: $body');
    }
    return url;
  }

  // ─── File-based API (Android / iOS) ──────────────────────────────────────────

  /// Uploads a one-off photo sent to friends and returns its HTTPS URL.
  ///
  /// Stored under: `lagket/photos/<senderId>/<uuid>`
  Future<String> uploadPhoto({
    required File file,
    required String senderId,
  }) async {
    final bytes = await file.readAsBytes();
    return _upload(
      bytes: bytes,
      folder: '${CloudinaryConfig.photosFolder}/$senderId',
    );
  }

  /// Uploads a user avatar and returns its HTTPS URL.
  ///
  /// Uses `public_id = userId` so re-uploading always **overwrites** the same
  /// Cloudinary asset — no orphaned files accumulate over time.
  ///
  /// Stored under: `lagket/avatars/<userId>`
  Future<String> uploadAvatar({
    required File file,
    required String userId,
  }) async {
    final bytes = await file.readAsBytes();
    return _upload(
      bytes: bytes,
      folder: CloudinaryConfig.avatarsFolder,
      publicId: userId,
    );
  }

  // ─── Bytes-based API (Web) ────────────────────────────────────────────────────

  /// Web-safe variant of [uploadPhoto] that accepts raw image bytes.
  Future<String> uploadPhotoBytes({
    required Uint8List bytes,
    required String senderId,
  }) =>
      _upload(
        bytes: bytes,
        folder: '${CloudinaryConfig.photosFolder}/$senderId',
      );

  /// Web-safe variant of [uploadAvatar] that accepts raw image bytes.
  Future<String> uploadAvatarBytes({
    required Uint8List bytes,
    required String userId,
  }) =>
      _upload(
        bytes: bytes,
        folder: CloudinaryConfig.avatarsFolder,
        publicId: userId,
      );

  // ─── Deletion ─────────────────────────────────────────────────────────────────

  /// No-op: Cloudinary deletion requires the API secret, which must NEVER
  /// be embedded in a mobile app. Old photo URLs remain valid (Cloudinary's
  /// free tier is generous: 25 GB storage). If you add a backend later,
  /// call the Cloudinary Admin API from there.
  Future<void> deleteByUrl(String url) async {
    // intentionally left empty
  }
}
