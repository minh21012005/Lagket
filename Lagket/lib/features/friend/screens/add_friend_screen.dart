import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/friend_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/user_avatar.dart';

class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(userSearchQueryProvider);
    final searchAsync = ref.watch(userSearchProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final friendState = ref.watch(friendNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Add Friends', style: AppTextStyles.headlineMedium),
        actions: [
          TextButton(
            onPressed: () => context.push('/friends/requests'),
            child: Text('Requests',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _ctrl.clear();
                          ref
                              .read(userSearchQueryProvider.notifier)
                              .state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) =>
                  ref.read(userSearchQueryProvider.notifier).state = v,
            ),
          ),

          // Invite via link
          _InviteTile(),

          const Divider(color: AppColors.divider, height: 1),

          // Results
          Expanded(
            child: query.trim().length < 2
                ? _SearchHint()
                : searchAsync.when(
                    data: (users) {
                      // Filter out self
                      final filtered = users
                          .where((u) => u.id != (currentUser?.id ?? ''))
                          .toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'No users found for "$query"',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _UserSearchTile(
                          user: filtered[i],
                          currentUserId: currentUser?.id ?? '',
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.primary)),
                    ),
                    error: (e, _) =>
                        Center(child: Text('Error: $e')),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserSearchTile extends ConsumerStatefulWidget {
  final UserModel user;
  final String currentUserId;
  const _UserSearchTile(
      {required this.user, required this.currentUserId});

  @override
  ConsumerState<_UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends ConsumerState<_UserSearchTile> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendNotifierProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: widget.user.avatarUrl,
            username: widget.user.displayUsername,
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.displayUsername,
                    style: AppTextStyles.bodyLarge),
                Text('@${widget.user.username}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          _sent
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 24)
              : SizedBox(
                  height: 36,
                  width: 90,
                  child: AppButton(
                    label: 'Add',
                    height: 36,
                    borderRadius: 10,
                    isLoading: friendState.isLoading,
                    onPressed: () async {
                      final ok = await ref
                          .read(friendNotifierProvider.notifier)
                          .sendRequest(widget.user.id);
                      if (ok && mounted) setState(() => _sent = true);
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.link_rounded, color: Colors.white, size: 22),
      ),
      title:
          Text('Invite via link', style: AppTextStyles.bodyLarge),
      subtitle: Text('Share your invite link with friends',
          style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('📎 Link copied: lagket.app/invite/you')),
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_rounded,
              color: AppColors.textHint, size: 56),
          const SizedBox(height: 12),
          Text('Search for a username',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          Text('Type at least 2 characters',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
