import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/models/friendship_model.dart';
import '../../../shared/models/friend_request_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

// ─── Friendships list ─────────────────────────────────────────────────────────

final friendshipsProvider = StreamProvider<List<FriendshipModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchFriendships(user.id);
});

// ─── Friend user models ───────────────────────────────────────────────────────

final friendUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final friendships = ref.watch(friendshipsProvider).value ?? [];
  final fs = ref.watch(firestoreServiceProvider);
  final users = await Future.wait(
    friendships.map((f) => fs.getUser(f.friendId)),
  );
  return users.whereType<UserModel>().toList();
});

// ─── Incoming friend requests ────────────────────────────────────────────────

final incomingRequestsProvider =
    StreamProvider<List<FriendRequestModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchIncomingRequests(user.id);
});

// ─── Outgoing friend requests ─────────────────────────────────────────────────

final outgoingRequestsProvider =
    StreamProvider<List<FriendRequestModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchOutgoingRequests(user.id);
});

// ─── Friend notifier ─────────────────────────────────────────────────────────

class FriendState {
  final bool isLoading;
  final String? error;
  const FriendState({this.isLoading = false, this.error});
  FriendState copyWith({bool? isLoading, String? error}) =>
      FriendState(isLoading: isLoading ?? this.isLoading, error: error);
}

class FriendNotifier extends StateNotifier<FriendState> {
  final FirestoreService _fs;
  final String _currentUserId;

  FriendNotifier(this._fs, this._currentUserId) : super(const FriendState());

  Future<bool> sendRequest(String toUserId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Check if already friends
      final areFriends =
          await _fs.areFriends(_currentUserId, toUserId);
      if (areFriends) {
        state = state.copyWith(
            isLoading: false, error: 'You are already friends!');
        return false;
      }

      // Check pending
      final hasPending = await _fs.hasPendingRequest(
          fromUserId: _currentUserId, toUserId: toUserId);
      if (hasPending) {
        state = state.copyWith(
            isLoading: false, error: 'Request already sent!');
        return false;
      }

      await _fs.createFriendRequest(
          fromUserId: _currentUserId, toUserId: toUserId);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> acceptRequest(FriendRequestModel request) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _fs.respondToFriendRequest(
        requestId: request.id,
        status: 'accepted',
        fromUserId: request.fromUserId,
        toUserId: request.toUserId,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectRequest(FriendRequestModel request) async {
    try {
      await _fs.respondToFriendRequest(
        requestId: request.id,
        status: 'rejected',
        fromUserId: request.fromUserId,
        toUserId: request.toUserId,
      );
    } catch (_) {}
  }

  Future<void> removeFriend(String friendId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _fs.removeFriendship(
          userId: _currentUserId, friendId: friendId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final friendNotifierProvider =
    StateNotifierProvider<FriendNotifier, FriendState>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return FriendNotifier(
    ref.watch(firestoreServiceProvider),
    user?.id ?? '',
  );
});

// ─── User search ──────────────────────────────────────────────────────────────

final userSearchQueryProvider = StateProvider<String>((ref) => '');

final userSearchProvider = FutureProvider<List<UserModel>>((ref) async {
  final query = ref.watch(userSearchQueryProvider);
  if (query.trim().length < 2) return [];
  return ref.watch(firestoreServiceProvider).searchUsersByUsername(query.trim());
});
