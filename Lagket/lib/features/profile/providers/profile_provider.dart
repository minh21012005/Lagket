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

  Future<bool> updateUsername(String username) async {
    state = state.copyWith(isLoading: true, error: null, saved: false);
    try {
      await _fs.updateUser(_userId, {
        'username': username.toLowerCase().trim(),
        'displayUsername': username.trim(),
      });
      state = state.copyWith(isLoading: false, saved: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateAvatar(File imageFile) async {
    state = state.copyWith(isLoading: true, error: null, saved: false);
    try {
      final url = await _storage.uploadAvatar(
          file: imageFile, userId: _userId);
      await _fs.updateUser(_userId, {'avatarUrl': url});
      state = state.copyWith(isLoading: false, saved: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearSaved() => state = state.copyWith(saved: false);
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return ProfileNotifier(
    ref.watch(firestoreServiceProvider),
    StorageService(),
    user?.id ?? '',
  );
});
