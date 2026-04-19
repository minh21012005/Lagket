import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/feed/providers/message_provider.dart';
import '../../../features/feed/providers/history_provider.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/widgets/user_avatar.dart';

// ─── Message list provider ────────────────────────────────────────────────────

/// All photos that have at least one message involving the current user.
/// Strategy: watch all messages sent by the user → group by photoId →
/// join with the photo data from the history stream.
///
/// We piggyback on the historyPhotosProvider so no extra Firestore query is needed.
final messageThreadsProvider = Provider<AsyncValue<List<_PhotoThread>>>((ref) {
  final photosAsync = ref.watch(historyPhotosProvider);
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return const AsyncValue.data([]);

  return photosAsync.whenData((photos) {
    // We'll show a row for every photo the user has sent or received.
    // The presence of messages is loaded lazily inside each row.
    // Sort by createdAt descending (most recent conversation first).
    return photos
        .map((p) => _PhotoThread(photo: p))
        .toList();
  });
});

class _PhotoThread {
  final PhotoModel photo;
  const _PhotoThread({required this.photo});
}

// ─── Message List Screen ──────────────────────────────────────────────────────

class MessageListScreen extends ConsumerWidget {
  const MessageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(messageThreadsProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.primaryGradient.createShader(b),
                          child: Text(
                            'Messages',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: Colors.white,
                              fontSize: 26,
                            ),
                          ),
                        ),
                        Text(
                          'Photo conversations',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  UserAvatar(
                    avatarUrl: user?.avatarUrl,
                    username: user?.displayUsername ?? '?',
                    size: 38,
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Thread list ───────────────────────────────────────────────────
            Expanded(
              child: threadsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.error)),
                ),
                data: (threads) {
                  if (threads.isEmpty) {
                    return _EmptyMessages();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: threads.length,
                    itemBuilder: (_, i) =>
                        _ThreadTile(photo: threads[i].photo),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Thread tile ──────────────────────────────────────────────────────────────

class _ThreadTile extends ConsumerWidget {
  final PhotoModel photo;
  const _ThreadTile({required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(photo.id));
    final senderAsync = ref.watch(historySenderProvider(photo.senderId));

    return messagesAsync.when(
      data: (messages) {
        // Hide photos with no messages
        if (messages.isEmpty) return const SizedBox.shrink();
        final last = messages.last;

        return GestureDetector(
          onTap: () => context.push('/photo/${photo.id}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Photo thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: photo.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photo.imageUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(color: AppColors.surfaceElevated),
                  ),
                ),
                const SizedBox(width: 12),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              senderAsync.value?.displayUsername ?? 'Photo',
                              style: AppTextStyles.labelLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (photo.createdAt != null)
                            Text(
                              DateFormatter.timeAgo(photo.createdAt!),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Iconsax.message_text,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              last.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${messages.length}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Iconsax.arrow_right_3,
                    size: 16, color: AppColors.textHint),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyMessages extends StatelessWidget {
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
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.message,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text('No conversations yet',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'React or send a message to a photo\nand it will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
