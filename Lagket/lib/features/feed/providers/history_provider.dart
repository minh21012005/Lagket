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
  final DateTime? date;
  const HistoryFilter({this.date});
}

class AllPhotosFilter extends HistoryFilter {
  const AllPhotosFilter({super.date});
}

class MyPhotosFilter extends HistoryFilter {
  const MyPhotosFilter({super.date});
}

class FriendPhotosFilter extends HistoryFilter {
  final String friendId;
  final String friendName;
  const FriendPhotosFilter({
    required this.friendId,
    required this.friendName,
    super.date,
  });
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
    // 1. Base filter by sender
    Iterable<PhotoModel> filtered = photos;
    
    if (filter is MyPhotosFilter) {
      filtered = photos.where((p) => p.senderId == currentUser?.id);
    } else if (filter is FriendPhotosFilter) {
      filtered = photos.where((p) => p.senderId == filter.friendId);
    }

    // 2. Apply date filter if present
    if (filter.date != null) {
      final d = filter.date!;
      filtered = filtered.where((p) {
        if (p.createdAt == null) return false;
        final ct = p.createdAt!;
        return ct.year == d.year && ct.month == d.month && ct.day == d.day;
      });
    }

    return filtered.toList();
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

/// Photos grouped by their normalized date [DateTime(y, m, d)].
/// The list is sorted by createdAt descending (newest first).
final photosByDateProvider = Provider<Map<DateTime, List<PhotoModel>>>((ref) {
  final photos = ref.watch(calendarPhotosProvider).value ?? [];
  final map = <DateTime, List<PhotoModel>>{};
  
  for (final photo in photos) {
    if (photo.createdAt == null) continue;
    final d = photo.createdAt!;
    final key = DateTime(d.year, d.month, d.day);
    
    if (!map.containsKey(key)) {
      map[key] = [];
    }
    map[key]!.add(photo);
  }

  // Sort each list by newest first
  for (final key in map.keys) {
    map[key]!.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  }

  return map;
});
