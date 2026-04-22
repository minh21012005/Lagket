import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/friend/providers/friend_provider.dart';
import '../../../shared/models/conversation_model.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/user_model.dart';

// ─── Conversation list ────────────────────────────────────────────────────────

/// Real-time stream of all conversations for the current user, newest first.
final conversationListProvider =
    StreamProvider<List<ConversationModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .watchConversations(currentUser.id);
});

// ─── Conversation detail ──────────────────────────────────────────────────────

/// Real-time stream of messages for a given conversation, oldest first.
final conversationDetailProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  if (conversationId.isEmpty) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .watchConversationMessages(conversationId);
});

// ─── Other user cache ─────────────────────────────────────────────────────────

/// Fetch a user by id – used to display the other participant's info.
final conversationUserProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  return ref.watch(firestoreServiceProvider).getUser(userId);
});

// ─── Combined Friends & Chats ────────────────────────────────────────────────

class ChatListItem {
  final UserModel friend;
  final ConversationModel? conversation;
  ChatListItem({required this.friend, this.conversation});
}

final allChatsProvider = Provider<AsyncValue<List<ChatListItem>>>((ref) {
  final friendsAsync = ref.watch(friendUsersProvider);
  final conversationsAsync = ref.watch(conversationListProvider);
  final currentUser = ref.watch(currentUserProvider).value;

  if (currentUser == null) return const AsyncValue.data([]);
  if (friendsAsync.isLoading || conversationsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (friendsAsync.hasError) return AsyncValue.error(friendsAsync.error!, friendsAsync.stackTrace!);
  if (conversationsAsync.hasError) return AsyncValue.error(conversationsAsync.error!, conversationsAsync.stackTrace!);

  final friends = friendsAsync.value ?? [];
  final conversations = conversationsAsync.value ?? [];

  final List<ChatListItem> items = [];

  for (final friend in friends) {
    // Find if a conversation already exists for this friend
    // Use firstWhereOrNull for safety
    ConversationModel? conv;
    try {
      conv = conversations.firstWhere(
        (c) => c.participants.contains(friend.id),
      );
    } catch (_) {
      conv = null;
    }

    items.add(ChatListItem(
      friend: friend,
      conversation: conv,
    ));
  }

  // Sắp xếp: Những người có tin nhắn mới nhất lên đầu, còn lại xếp theo tên
  items.sort((a, b) {
    final timeA = a.conversation?.updatedAt;
    final timeB = b.conversation?.updatedAt;

    if (timeA != null && timeB != null) {
      return timeB.compareTo(timeA);
    }
    if (timeA != null) return -1;
    if (timeB != null) return 1;
    return a.friend.displayUsername.compareTo(b.friend.displayUsername);
  });

  return AsyncValue.data(items);
});

// ─── Get-or-create helper ─────────────────────────────────────────────────────

/// Returns the conversation id for the pair (currentUser, otherUser).
/// Creates the conversation if it doesn't exist yet.
///
/// Usage:
/// ```dart
/// final convId = await ref.read(
///   getOrCreateConversationProvider((myId, otherId)).future,
/// );
/// ```
final getOrCreateConversationProvider =
    FutureProvider.family<String, (String, String)>((ref, args) async {
  final (userA, userB) = args;
  if (userA.isEmpty || userB.isEmpty) return '';
  return ref
      .read(firestoreServiceProvider)
      .getOrCreateConversation(userA, userB);
});
