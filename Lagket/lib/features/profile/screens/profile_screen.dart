import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../friend/providers/friend_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/widgets/user_avatar.dart';

// ─── Providers ─────────────────────────────────────────────────────────────────

final _sentPhotoCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return 0;
  return ref.watch(firestoreServiceProvider).getSentPhotoCount(user.id);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final friendsAsync = ref.watch(friendUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Iconsax.arrow_left,
                      color: AppColors.textPrimary),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Iconsax.setting_2,
                        color: AppColors.textPrimary),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.darkGradient,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Stack(
                            children: [
                              UserAvatar(
                                avatarUrl: user.avatarUrl,
                                username: user.displayUsername,
                                size: 90,
                                showBorder: true,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Iconsax.edit,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user.displayUsername,
                            style: AppTextStyles.headlineLarge),
                        Text('@${user.username}',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),

              // Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Friends',
                          value:
                              '${friendsAsync.value?.length ?? 0}',
                          icon: Iconsax.people,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Photos Sent',
                          value: ref
                                  .watch(_sentPhotoCountProvider)
                                  .value
                                  ?.toString() ??
                              '—',
                          icon: Iconsax.send_1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Joined',
                          value: user.createdAt != null
                              ? '${user.createdAt!.month}/${user.createdAt!.year}'
                              : '—',
                          icon: Iconsax.calendar_1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Iconsax.edit,
                        label: 'Edit Profile',
                        onTap: () => context.push('/profile/edit'),
                      ),
                      _ActionTile(
                        icon: Iconsax.people,
                        label: 'My Friends',
                        onTap: () => context.push('/friends'),
                        showBadge: ref.watch(incomingRequestsProvider).value?.isNotEmpty ?? false,
                      ),
                      _ActionTile(
                        icon: Iconsax.category,
                        label: 'Widget Preview',
                        onTap: () => context.push('/widget'),
                      ),
                      _ActionTile(
                        icon: Iconsax.setting_2,
                        label: 'Settings',
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.headlineLarge
                  .copyWith(color: AppColors.primary)),
          Text(label, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showBadge;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                if (showBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: AppTextStyles.bodyLarge),
            ),
            const Icon(Iconsax.arrow_right_3,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
