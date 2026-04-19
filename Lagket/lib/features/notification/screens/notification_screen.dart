import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Mock notifications for demo
  static final List<_NotifItem> _mockItems = [
    _NotifItem(
      icon: Iconsax.camera,
      iconColor: AppColors.primary,
      title: 'New photo from alex_dev',
      subtitle: 'Tap to view the photo',
      time: '2 min ago',
    ),
    _NotifItem(
      icon: Iconsax.user_add,
      iconColor: AppColors.success,
      title: 'sarah_j accepted your friend request',
      subtitle: 'You are now friends!',
      time: '1 hr ago',
    ),
    _NotifItem(
      icon: Iconsax.notification_bing,
      iconColor: AppColors.warning,
      title: 'Friend request from mike_w',
      subtitle: 'Accept or decline',
      time: '3 hr ago',
    ),
    _NotifItem(
      icon: Iconsax.camera,
      iconColor: AppColors.primary,
      title: 'New photo from sarah_j',
      subtitle: 'Tap to view the photo',
      time: 'Yesterday',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Notifications', style: AppTextStyles.headlineMedium),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Mark all read',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: _mockItems.isEmpty
          ? _Empty()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _mockItems.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.divider, height: 1),
              itemBuilder: (_, i) => _NotifTile(item: _mockItems[i]),
            ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final _NotifItem item;
  const _NotifTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: item.iconColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(item.icon, color: item.iconColor, size: 22),
      ),
      title: Text(item.title, style: AppTextStyles.bodyLarge),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.subtitle,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(item.time, style: AppTextStyles.caption),
        ],
      ),
      onTap: () {},
    );
  }
}

class _NotifItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  const _NotifItem(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.subtitle,
      required this.time});
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.notification,
              color: AppColors.textHint, size: 64),
          const SizedBox(height: 16),
          Text('No notifications', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text("You're all caught up!",
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
