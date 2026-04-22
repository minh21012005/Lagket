import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/user_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  File? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _usernameCtrl.text = user?.displayUsername ?? '';
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _selectedAvatar = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final success = await ref.read(profileNotifierProvider.notifier).updateProfile(
      username: _usernameCtrl.text.trim(),
      avatarFile: _selectedAvatar,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final profileState = ref.watch(profileNotifierProvider);

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
        title: Text('Edit Profile', style: AppTextStyles.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar picker
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    _selectedAvatar != null
                        ? CircleAvatar(
                            radius: 52,
                            backgroundImage: FileImage(_selectedAvatar!),
                          )
                        : UserAvatar(
                            avatarUrl: user?.avatarUrl,
                            username: user?.displayUsername ?? '',
                            size: 104,
                          ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.camera,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Tap to change photo',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),

              const SizedBox(height: 32),

              // Error
              if (profileState.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(profileState.error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
                const SizedBox(height: 16),
              ],

              AppTextField(
                label: 'Username',
                controller: _usernameCtrl,
                validator: Validators.validateUsername,
                prefixIcon: Iconsax.sms,
                maxLength: 20,
              ),

              const SizedBox(height: 12),
              Text(
                'Email: ${user?.email ?? '—'}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 32),
              AppButton(
                label: 'Save Changes',
                onPressed: _save,
                isLoading: profileState.isLoading,
                icon: Iconsax.document_download,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
