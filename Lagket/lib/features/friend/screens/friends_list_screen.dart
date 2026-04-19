import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/friend_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: Text('Friends', style: AppTextStyles.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.user_add,
                color: AppColors.primary),
            onPressed: () => context.push('/friends/add'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined,
                color: AppColors.textPrimary),
            onPressed: () => context.push('/friends/requests'),
          ),
        ],
      ),
      body: friendsAsync.when(
        data: (friends) => friends.isEmpty ? _Empty() : _FriendList(friends: friends),
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _FriendList extends ConsumerWidget {
  final List<UserModel> friends;
  const _FriendList({required this.friends});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      itemBuilder: (_, i) => _FriendTile(
        friend: friends[i],
        onRemove: () => _confirmRemove(context, ref, friends[i]),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, UserModel friend) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove friend?', style: AppTextStyles.headlineSmall),
        content: Text(
          'Are you sure you want to remove ${friend.displayUsername} from your friends?',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(friendNotifierProvider.notifier)
                  .removeFriend(friend.id);
            },
            child: Text('Remove',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final UserModel friend;
  final VoidCallback onRemove;
  const _FriendTile({required this.friend, required this.onRemove});

  @override
  Widget build(BuildContext context) {
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
            avatarUrl: friend.avatarUrl,
            username: friend.displayUsername,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.displayUsername, style: AppTextStyles.bodyLarge),
                Text('@${friend.username}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove friend',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error)),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.people,
              color: AppColors.textHint, size: 64),
          const SizedBox(height: 16),
          Text('No friends yet', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text('Add friends to start sharing moments!',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => context.push('/friends/add'),
            icon: const Icon(Iconsax.user_add,
                color: AppColors.primary),
            label: Text('Add friends',
                style:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
