import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/reaction_model.dart';

/// Real-time reactions for a given photo.
final reactionsProvider =
    StreamProvider.family<List<ReactionModel>, String>((ref, photoId) {
  if (photoId.isEmpty) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchReactions(photoId);
});

/// Helper: the current user's reaction for a photo (null if none).
/// Used to highlight the active reaction button.
final myReactionProvider =
    Provider.family<ReactionModel?, (String photoId, String userId)>((ref, args) {
  final (photoId, userId) = args;
  final reactions = ref.watch(reactionsProvider(photoId)).value ?? [];
  try {
    return reactions.firstWhere((r) => r.userId == userId);
  } catch (_) {
    return null;
  }
});
