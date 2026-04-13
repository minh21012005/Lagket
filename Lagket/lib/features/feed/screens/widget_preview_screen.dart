import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/feed_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/utils/date_formatter.dart';

class WidgetPreviewScreen extends ConsumerWidget {
  const WidgetPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Widget Preview', style: AppTextStyles.headlineMedium),
      ),
      body: feedAsync.when(
        data: (photos) {
          final latest = photos.isNotEmpty ? photos.first : null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How your widget looks',
                    style: AppTextStyles.headlineSmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 20),

                // Small widget
                _WidgetFrame(
                  label: 'Small (2×2)',
                  size: 160,
                  photo: latest,
                  ref: ref,
                ),
                const SizedBox(height: 24),

                // Medium widget
                _WidgetFrame(
                  label: 'Medium (4×2)',
                  size: 160,
                  width: double.infinity,
                  photo: latest,
                  ref: ref,
                ),

                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add the Lagket widget to your home screen to see the latest photo from your friends.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _WidgetFrame extends ConsumerWidget {
  final String label;
  final double size;
  final double? width;
  final PhotoModel? photo;
  final WidgetRef ref;

  const _WidgetFrame({
    required this.label,
    required this.size,
    this.width,
    this.photo,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final senderAsync = photo != null
        ? r.watch(_widgetSenderProvider(photo!.senderId))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          width: width ?? size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              if (photo != null && photo!.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: photo!.imageUrl,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: Icon(Icons.camera_alt_rounded,
                        color: AppColors.textHint, size: 36),
                  ),
                ),

              // Overlay
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.photoOverlay),
              ),

              // Info
              if (senderAsync != null)
                Positioned(
                  bottom: 8,
                  left: 10,
                  right: 10,
                  child: senderAsync.when(
                    data: (sender) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sender?.displayUsername ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (photo?.createdAt != null)
                          Text(
                            DateFormatter.timeAgo(photo!.createdAt!),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 10),
                          ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

              // Lagket badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Lagket',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final _widgetSenderProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.watch(firestoreServiceProvider).getUser(userId);
});
