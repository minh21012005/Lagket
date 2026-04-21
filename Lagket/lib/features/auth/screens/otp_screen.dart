import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  bool _isLoading = false;
  bool _resending = false;
  String? _message;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);
    try {
      await _user?.reload();
      if (_user?.emailVerified == true) {
        if (mounted) context.go('/permissions');
      } else {
        setState(() => _message = 'Email not yet verified. Check your inbox.');
      }
    } catch (e) {
      setState(() => _message = 'An error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _resending = true);
    try {
      await _user?.sendEmailVerification();
      setState(() => _message = 'Verification email sent!');
    } catch (e) {
      setState(() => _message = 'Failed to send email. Please try again.');
    } finally {
      setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 28),

              Text('Verify your email', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 12),
              Text(
                'We sent a verification email to\n${_user?.email ?? 'your email'}.\n\nOpen it and tap the link, then come back here.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),

              if (_message != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 36),
              AppButton(
                label: 'I verified my email',
                onPressed: _checkVerification,
                isLoading: _isLoading,
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Resend email',
                onPressed: _resendEmail,
                isLoading: _resending,
                variant: AppButtonVariant.secondary,
                icon: Icons.refresh_rounded,
              ),
              const SizedBox(height: 28),
              TextButton(
                onPressed: () async {
                  await ref.read(firebaseAuthServiceProvider).signOut();
                  if (mounted) context.go('/login');
                },
                child: Text(
                  'Back to login',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
