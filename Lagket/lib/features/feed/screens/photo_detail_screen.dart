import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';

class PhotoDetailScreen extends ConsumerWidget {
  final String photoId;
  const PhotoDetailScreen({super.key, required this.photoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoAsync =
        ref.watch(_photoDetailProvider(photoId));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: photoAsync.when(
        data: (photo) {
          if (photo == null) {
            return const Center(
                child: Text('Photo not found.',
                    style: TextStyle(color: Colors.white)));
          }
          return _PhotoDetailContent(photo: photo, ref: ref);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

class _PhotoDetailContent extends StatelessWidget {
  final PhotoModel photo;
  final WidgetRef ref;
  const _PhotoDetailContent({required this.photo, required this.ref});

  @override
  Widget build(BuildContext context) {
    final senderAsync = ref.watch(_photoSenderProvider(photo.senderId));

    return Stack(
      fit: StackFit.expand,
      children: [
        // Zoomable image
        PhotoView(
          imageProvider:
              CachedNetworkImageProvider(photo.imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2.5,
          backgroundDecoration:
              const BoxDecoration(color: Colors.black),
          loadingBuilder: (_, __) => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary)),
          ),
        ),

        // Sender info overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 48),
            decoration: const BoxDecoration(
              gradient: AppColors.photoOverlay,
            ),
            child: senderAsync.when(
              data: (sender) => Row(
                children: [
                  UserAvatar(
                    avatarUrl: sender?.avatarUrl,
                    username: sender?.displayUsername ?? '?',
                    size: 48,
                    showBorder: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sender?.displayUsername ?? 'Unknown',
                          style: AppTextStyles.headlineSmall
                              .copyWith(color: Colors.white),
                        ),
                        if (photo.createdAt != null)
                          Text(
                            DateFormatter.formatDate(photo.createdAt!),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),

        // Reaction row
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['❤️', '😂', '😮', '🔥', '👏']
                .map((emoji) => _ReactionButton(emoji: emoji))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  const _ReactionButton({required this.emoji});

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1, end: 1.4)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _photoDetailProvider =
    FutureProvider.family<PhotoModel?, String>((ref, photoId) async {
  return ref.watch(firestoreServiceProvider).getPhoto(photoId);
});

final _photoSenderProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.watch(firestoreServiceProvider).getUser(userId);
});
