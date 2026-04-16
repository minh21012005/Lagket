/// Cloudinary configuration constants.
///
/// cloud_name  : visible on your Cloudinary dashboard (safe to expose).
/// uploadPreset: an *unsigned* upload preset created in
///               Settings → Upload → Upload Presets.
///
/// Folder layout inside Cloudinary:
///   lagket/photos/<senderId>/<uuid>.jpg   – one-off photos sent to friends
///   lagket/avatars/<userId>               – avatar (public_id = userId so
///                                           re-upload always overwrites)
class CloudinaryConfig {
  CloudinaryConfig._();

  static const String cloudName = 'dck0ilev8';
  static const String uploadPreset = 'lagket_upload';

  // Base upload endpoint (never changes for unsigned preset)
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  // Cloudinary folder paths
  static const String photosFolder = 'lagket/photos';
  static const String avatarsFolder = 'lagket/avatars';
}
