import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _photoNotifications = true;
  bool _requestNotifications = true;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log out?', style: AppTextStyles.headlineSmall),
        content: Text(
          'Are you sure you want to log out?',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log out',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

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
        title: Text('Settings', style: AppTextStyles.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          _SectionHeader(title: 'Account'),
          _InfoTile(
            icon: Iconsax.user,
            label: 'Username',
            value: '@${user?.username ?? '—'}',
          ),
          _InfoTile(
            icon: Iconsax.sms,
            label: 'Email',
            value: user?.email ?? '—',
          ),

          const SizedBox(height: 16),
          _SectionHeader(title: 'Notifications'),

          _SwitchTile(
            icon: Iconsax.notification,
            label: 'All notifications',
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          _SwitchTile(
            icon: Iconsax.camera,
            label: 'New photo received',
            value: _photoNotifications,
            onChanged: _notifications
                ? (v) => setState(() => _photoNotifications = v)
                : null,
          ),
          _SwitchTile(
            icon: Iconsax.user_add,
            label: 'Friend requests',
            value: _requestNotifications,
            onChanged: _notifications
                ? (v) => setState(() => _requestNotifications = v)
                : null,
          ),

          const SizedBox(height: 16),
          _SectionHeader(title: 'Privacy'),
          _NavTile(
            icon: Iconsax.shield_tick,
            label: 'Privacy Policy',
            onTap: () {},
          ),
          _NavTile(
            icon: Iconsax.document_text,
            label: 'Terms of Service',
            onTap: () {},
          ),

          const SizedBox(height: 16),
          _SectionHeader(title: 'App'),
          _InfoTile(
            icon: Iconsax.info_circle,
            label: 'Version',
            value: '1.0.0',
          ),

          const SizedBox(height: 24),
          // Logout
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.logout,
                      color: AppColors.error, size: 22),
                  const SizedBox(width: 12),
                  Text('Log out',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title,
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Text(label, style: AppTextStyles.bodyLarge),
          const Spacer(),
          Text(value,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
            const Icon(Iconsax.arrow_right_3,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
