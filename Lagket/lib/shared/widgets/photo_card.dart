import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../models/photo_model.dart';
import '../models/user_model.dart';
import 'user_avatar.dart';

class PhotoCard extends StatelessWidget {
  final PhotoModel photo;
  final UserModel? sender;
  final VoidCallback? onTap;

  const PhotoCard({
    super.key,
    required this.photo,
    this.sender,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            photo.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photo.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: AppColors.surface,
                      highlightColor: AppColors.surfaceElevated,
                      child: Container(color: AppColors.surface),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surface,
                      child: const Icon(Iconsax.gallery_slash,
                          color: AppColors.textHint),
                    ),
                  )
                : Container(
                    color: AppColors.surface,
                    child: const Icon(Iconsax.gallery, color: AppColors.textHint),
                  ),

            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.photoOverlay,
              ),
            ),

            // Bottom info
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: sender?.avatarUrl,
                    username: sender?.displayUsername ?? '?',
                    size: 28,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sender?.displayUsername ?? 'Unknown',
                          style: AppTextStyles.labelLarge.copyWith(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          photo.createdAt != null
                              ? DateFormatter.timeAgo(photo.createdAt!)
                              : '',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
