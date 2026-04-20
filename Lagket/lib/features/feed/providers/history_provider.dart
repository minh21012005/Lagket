import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friend/providers/friend_provider.dart';

// ─── Filter & view mode enums ─────────────────────────────────────────────────

enum HistoryViewMode { single, grid }

/// Describes which photos to show.
sealed class HistoryFilter {
  const HistoryFilter();
}

class AllPhotosFilter extends HistoryFilter {
  const AllPhotosFilter();
}

class MyPhotosFilter extends HistoryFilter {
  const MyPhotosFilter();
}

class FriendPhotosFilter extends HistoryFilter {
  final String friendId;
  final String friendName;
  const FriendPhotosFilter({required this.friendId, required this.friendName});
}

// ─── State providers ──────────────────────────────────────────────────────────

/// Controls grid vs. single-photo view.
final historyViewModeProvider =
    StateProvider<HistoryViewMode>((ref) => HistoryViewMode.single);

/// Active filter selection.
final historyFilterProvider =
    StateProvider<HistoryFilter>((ref) => const AllPhotosFilter());

/// Current page index in the PageView (used to jump from grid tap → single view).
final historyPageIndexProvider = StateProvider<int>((ref) => 0);

// ─── Data stream ──────────────────────────────────────────────────────────────

/// All photos for the current user (sent + received), newest first.
final historyPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .watchCombinedHistory(currentUser.id);
});

/// Filtered view of historyPhotosProvider based on historyFilterProvider.
final filteredHistoryProvider = Provider<AsyncValue<List<PhotoModel>>>((ref) {
  final all = ref.watch(historyPhotosProvider);
  final filter = ref.watch(historyFilterProvider);
  final currentUser = ref.watch(currentUserProvider).value;

  return all.whenData((photos) {
    switch (filter) {
      case AllPhotosFilter():
        return photos;
      case MyPhotosFilter():
        return photos
            .where((p) => p.senderId == currentUser?.id)
            .toList();
      case FriendPhotosFilter(:final friendId):
        return photos
            .where((p) => p.senderId == friendId)
            .toList();
    }
  });
});

// ─── Sender cache ─────────────────────────────────────────────────────────────

final historySenderProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.watch(firestoreServiceProvider).getUser(userId);
});

// ─── Friend list for filter chips ────────────────────────────────────────────

/// Re-export friendUsersProvider for use in history screen without extra import.
final historyFriendListProvider = Provider<AsyncValue<List<UserModel>>>((ref) {
  return ref.watch(friendUsersProvider);
});

// ─── Calendar providers ───────────────────────────────────────────────────────

/// All photos sent by the current user in the current year.
final calendarPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  final year = DateTime.now().year;
  return ref
      .watch(firestoreServiceProvider)
      .watchSentPhotosForYear(user.id, year);
});

/// Photos keyed by their normalized date [DateTime(y, m, d)] for O(1) lookup.
/// When multiple photos exist on the same day, keeps the most recently created.
final photosByDateProvider = Provider<Map<DateTime, PhotoModel>>((ref) {
  final photos = ref.watch(calendarPhotosProvider).value ?? [];
  final map = <DateTime, PhotoModel>{};
  for (final photo in photos) {
    if (photo.createdAt == null) continue;
    final d = photo.createdAt!;
    final key = DateTime(d.year, d.month, d.day);
    // Keep the later photo if multiple on same day.
    if (!map.containsKey(key) ||
        photo.createdAt!.isAfter(map[key]!.createdAt!)) {
      map[key] = photo;
    }
  }
  return map;
});
