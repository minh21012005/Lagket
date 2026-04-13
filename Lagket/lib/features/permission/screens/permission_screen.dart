import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _cameraGranted = false;
  bool _notifGranted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatuses();
  }

  Future<void> _checkCurrentStatuses() async {
    final cam = await Permission.camera.status;
    final notif = await Permission.notification.status;
    setState(() {
      _cameraGranted = cam.isGranted;
      _notifGranted = notif.isGranted;
    });
  }

  Future<void> _requestAll() async {
    setState(() => _isLoading = true);
    final statuses = await [
      Permission.camera,
      Permission.notification,
    ].request();

    setState(() {
      _cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      _notifGranted = statuses[Permission.notification]?.isGranted ?? false;
      _isLoading = false;
    });
  }

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyPermissionsDone, true);
    if (mounted) context.go('/camera');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 28),
              Text('Allow Permissions', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 10),
              Text(
                'Lagket needs these to work properly.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              _PermissionTile(
                icon: Icons.camera_alt_rounded,
                title: 'Camera',
                description: 'To capture and share photos with friends.',
                isGranted: _cameraGranted,
              ),
              const SizedBox(height: 16),
              _PermissionTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                description: "So you're notified when a friend sends you a photo.",
                isGranted: _notifGranted,
              ),

              const Spacer(),

              if (!_cameraGranted || !_notifGranted) ...[
                AppButton(
                  label: 'Allow Permissions',
                  onPressed: _requestAll,
                  isLoading: _isLoading,
                  icon: Icons.lock_open_rounded,
                ),
                const SizedBox(height: 12),
              ],
              AppButton(
                label: _cameraGranted ? 'Continue' : 'Skip for now',
                onPressed: _proceed,
                variant: _cameraGranted
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? AppColors.success.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGranted
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: isGranted ? AppColors.success : AppColors.primary,
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headlineSmall),
                const SizedBox(height: 2),
                Text(description,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (isGranted)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}
