import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final double size;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.username,
    this.size = 44,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: AppColors.primary, width: 2.5)
            : null,
        gradient: avatarUrl == null || avatarUrl!.isEmpty
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.accentPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initials,
                errorWidget: (_, __, ___) => _initials,
              )
            : _initials,
      ),
    );
  }

  Widget get _initials => Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: AppTextStyles.labelLarge.copyWith(
            color: Colors.white,
            fontSize: size * 0.4,
          ),
        ),
      );
}
