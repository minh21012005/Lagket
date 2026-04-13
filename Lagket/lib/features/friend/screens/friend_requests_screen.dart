import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/friend_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/models/friend_request_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/app_button.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);

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
        title: Text('Friend Requests', style: AppTextStyles.headlineMedium),
      ),
      body: requestsAsync.when(
        data: (requests) => requests.isEmpty
            ? _Empty()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (_, i) =>
                    _RequestTile(request: requests[i]),
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final FriendRequestModel request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderAsync =
        ref.watch(_requestSenderProvider(request.fromUserId));
    final friendState = ref.watch(friendNotifierProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: senderAsync.when(
        data: (sender) => Row(
          children: [
            UserAvatar(
              avatarUrl: sender?.avatarUrl,
              username: sender?.displayUsername ?? '?',
              size: 50,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sender?.displayUsername ?? 'Unknown',
                      style: AppTextStyles.bodyLarge),
                  Text('@${sender?.username ?? ''}',
                      style: AppTextStyles.bodySmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Accept
                      Expanded(
                        child: AppButton(
                          label: 'Accept',
                          height: 36,
                          borderRadius: 10,
                          isLoading: friendState.isLoading,
                          onPressed: () => ref
                              .read(friendNotifierProvider.notifier)
                              .acceptRequest(request),
                          icon: Icons.check_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Decline
                      Expanded(
                        child: AppButton(
                          label: 'Decline',
                          height: 36,
                          borderRadius: 10,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => ref
                              .read(friendNotifierProvider.notifier)
                              .rejectRequest(request),
                          icon: Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 60,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

final _requestSenderProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.watch(firestoreServiceProvider).getUser(userId);
});

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded,
              color: AppColors.textHint, size: 64),
          const SizedBox(height: 16),
          Text('No pending requests',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text('When someone sends you a request,\nit will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
