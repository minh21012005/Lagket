import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileState {
  final bool isLoading;
  final String? error;
  final bool saved;

  const ProfileState({
    this.isLoading = false,
    this.error,
    this.saved = false,
  });

  ProfileState copyWith({bool? isLoading, String? error, bool? saved}) =>
      ProfileState(
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        saved: saved ?? this.saved,
      );
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final FirestoreService _fs;
  final StorageService _storage;
  final String _userId;

  ProfileNotifier(this._fs, this._storage, this._userId)
      : super(const ProfileState());

  Future<bool> updateProfile({required String username, File? avatarFile}) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true, error: null, saved: false);
    try {
      final Map<String, dynamic> updates = {
        'username': username.toLowerCase().trim(),
        'displayUsername': username.trim(),
      };

      if (avatarFile != null) {
        final url = await _storage.uploadAvatar(file: avatarFile, userId: _userId);
        updates['avatarUrl'] = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      await _fs.updateUser(_userId, updates);
      
      // If the notifier is still mounted, update the state.
      // If it's already disposed (because the screen closed), just return success.
      if (mounted) {
        state = state.copyWith(isLoading: false, saved: true);
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      return false;
    }
  }

  void clearSaved() => state = state.copyWith(saved: false);
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  // Only watch the ID to avoid rebuilding the notifier when other fields (like avatarUrl) change
  final userId = ref.watch(currentUserProvider.select((u) => u.value?.id)) ?? '';
  
  return ProfileNotifier(
    ref.watch(firestoreServiceProvider),
    StorageService(),
    userId,
  );
});
