import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
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
