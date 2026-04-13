class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Lagket';
  static const String appTagline = 'Share your world, one frame at a time';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String photosCollection = 'photos';
  static const String friendshipsCollection = 'friendships';
  static const String friendRequestsCollection = 'friend_requests';

  // Storage paths
  static const String avatarsPath = 'avatars';
  static const String photosPath = 'photos';

  // Shared prefs keys
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyPermissionsDone = 'permissions_done';

  // Pagination
  static const int feedPageSize = 20;

  // Timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);

  // Max sizes
  static const int maxUsernameLenght = 20;
  static const int minUsernameLength = 3;

  // Regex
  static const String usernameRegex = r'^[a-zA-Z0-9_]+$';
}
