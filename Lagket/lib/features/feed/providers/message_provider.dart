import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/message_model.dart';

/// Real-time messages for a given photo, oldest first.
final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, photoId) {
  if (photoId.isEmpty) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchMessages(photoId);
});
