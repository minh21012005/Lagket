import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/models/photo_model.dart';
import '../../auth/providers/auth_provider.dart';

final feedProvider = StreamProvider<List<PhotoModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchFeed(currentUser.id);
});

final feedSendersCacheProvider =
    StateProvider<Map<String, dynamic>>((ref) => {});
