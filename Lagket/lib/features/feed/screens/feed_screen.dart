import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/feed_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/photo_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppColors.primaryGradient.createShader(b),
              child: Text('Inbox 📬',
                  style: AppTextStyles.headlineLarge
                      .copyWith(color: Colors.white)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.widgets_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.push('/widget'),
          ),
        ],
      ),
      body: feedAsync.when(
        data: (photos) {
          if (photos.isEmpty) return _EmptyFeed(currentUser: currentUser);
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async => ref.invalidate(feedProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final photo = photos[i];
                return _FeedCell(photo: photo);
              },
            ),
          );
        },
        loading: () => _LoadingGrid(),
        error: (e, _) => Center(
          child: Text('Error loading feed: $e',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.error)),
        ),
      ),
    );
  }
}

// ─── Feed cell (fetches sender lazily) ───────────────────────────────────────

class _FeedCell extends ConsumerWidget {
  final PhotoModel photo;
  const _FeedCell({required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderAsync = ref.watch(_senderProvider(photo.senderId));
    return PhotoCard(
      photo: photo,
      sender: senderAsync.value,
      onTap: () => context.push('/photo/${photo.id}'),
    );
  }
}

final _senderProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.watch(firestoreServiceProvider).getUser(userId);
});

// ─── Empty feed ───────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  final UserModel? currentUser;
  const _EmptyFeed({this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text('No photos yet',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'When a friend sends you a photo,\nit will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => context.push('/friends/add'),
              icon: const Icon(Icons.person_add_rounded,
                  color: AppColors.primary),
              label: Text('Add friends',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer loading grid ─────────────────────────────────────────────────────

class _LoadingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
