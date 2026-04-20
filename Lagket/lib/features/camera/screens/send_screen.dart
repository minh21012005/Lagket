import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../providers/camera_provider.dart';
import '../../friend/providers/friend_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../notification/services/fcm_service.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final Set<String> _selectedIds = {};
  bool _sendToAll = true;
  bool _isSending = false;

  Future<void> _send() async {
    final file = ref.read(capturedFileProvider);
    final currentUser = ref.read(currentUserProvider).value;
    if (file == null || currentUser == null) return;

    setState(() => _isSending = true);

    try {
      final friends = ref.read(friendUsersProvider).value ?? [];
      final receiverIds = _sendToAll
          ? friends.map((f) => f.id).toList()
          : _selectedIds.toList();

      if (receiverIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one friend to send to.')),
        );
        setState(() => _isSending = false);
        return;
      }

      // Upload image
      final storageService = StorageService();
      final imageUrl = await storageService.uploadPhoto(
        file: file,
        senderId: currentUser.id,
      );

      final caption = ref.read(captionProvider);

      // Save to Firestore
      final photo = PhotoModel(
        id: '',
        senderId: currentUser.id,
        receiverIds: receiverIds,
        imageUrl: imageUrl,
        caption: caption.isNotEmpty ? caption : null,
      );
      await ref.read(firestoreServiceProvider).createPhoto(photo);

      // Trigger upload success notification
      FCMService().showLocalNotification(
        title: 'Moment Shared! 📸',
        body: 'Your photo has been uploaded and shared with your friends.',
      );

      // Clear state
      ref.read(capturedFileProvider.notifier).state = null;
      ref.read(cameraNotifierProvider.notifier).clearCapture();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Photo sent!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/camera');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(capturedFileProvider);
    final friendsAsync = ref.watch(friendUsersProvider);

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
        title: Text('Send to', style: AppTextStyles.headlineMedium),
      ),
      body: Column(
        children: [
          // Thumbnail
          if (file != null)
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: FileImage(file),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Send to all toggle
          _SwitchTile(
            title: 'Send to all friends',
            value: _sendToAll,
            onChanged: (v) => setState(() => _sendToAll = v),
          ),

          if (!_sendToAll) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Select friends',
                  style: AppTextStyles.headlineSmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: friendsAsync.when(
                data: (friends) => friends.isEmpty
                    ? Center(
                        child: Text(
                          'No friends yet.\nAdd some friends first!',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: friends.length,
                        itemBuilder: (_, i) {
                          final friend = friends[i];
                          final selected = _selectedIds.contains(friend.id);
                          return _FriendSelectTile(
                            friend: friend,
                            selected: selected,
                            onToggle: () => setState(() {
                              if (selected) {
                                _selectedIds.remove(friend.id);
                              } else {
                                _selectedIds.add(friend.id);
                              }
                            }),
                          );
                        },
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.primary)),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ] else
            const Spacer(),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: AppButton(
              label: 'Send Photo 🚀',
              onPressed: _send,
              isLoading: _isSending,
              icon: Iconsax.send_1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile(
      {required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.bodyLarge),
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

class _FriendSelectTile extends StatelessWidget {
  final UserModel friend;
  final bool selected;
  final VoidCallback onToggle;

  const _FriendSelectTile(
      {required this.friend, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            UserAvatar(
                avatarUrl: friend.avatarUrl,
                username: friend.displayUsername),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.displayUsername,
                      style: AppTextStyles.bodyLarge),
                  Text('@${friend.username}',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (selected)
              const Icon(Iconsax.tick_circle,
                  color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
