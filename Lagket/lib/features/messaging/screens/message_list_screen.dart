import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/messaging/providers/messaging_provider.dart';
import '../../../shared/models/conversation_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';

// ─── Message List Screen ──────────────────────────────────────────────────────

class MessageListScreen extends ConsumerWidget {
  const MessageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationListProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.primaryGradient.createShader(b),
                          child: Text(
                            'Messages',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: Colors.white,
                              fontSize: 26,
                            ),
                          ),
                        ),
                        Text(
                          'Your conversations',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: UserAvatar(
                      avatarUrl: currentUser?.avatarUrl,
                      username: currentUser?.displayUsername ?? '?',
                      size: 38,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Conversation list ───────────────────────────────────────────
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.error)),
                ),
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: conversations.length,
                    itemBuilder: (_, i) => _ConversationTile(
                      conversation: conversations[i],
                      myId: currentUser?.id ?? '',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Conversation tile ────────────────────────────────────────────────────────

class _ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;
  final String myId;

  const _ConversationTile({
    required this.conversation,
    required this.myId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherId = conversation.otherParticipant(myId);
    final otherUserAsync = ref.watch(conversationUserProvider(otherId));

    return otherUserAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (otherUser) {
        return GestureDetector(
          onTap: () => context.push('/conversation/${conversation.id}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // ── Avatar ────────────────────────────────────────────
                UserAvatar(
                  avatarUrl: otherUser?.avatarUrl,
                  username: otherUser?.displayUsername ?? '?',
                  size: 50,
                ),
                const SizedBox(width: 12),

                // ── Text info ─────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherId == myId
                                  ? 'You'
                                  : (otherUser?.displayUsername ?? 'Unknown'),
                              style: AppTextStyles.labelLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.updatedAt != null)
                            Text(
                              DateFormatter.timeAgo(conversation.updatedAt!),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Iconsax.message_text,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatLastMessage(
                                conversation.lastMessage,
                                conversation.lastMessageSenderId == myId,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: conversation.readBy.contains(myId)
                                    ? AppColors.textSecondary
                                    : Colors.white,
                                fontWeight: conversation.readBy.contains(myId)
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                shadows: !conversation.readBy.contains(myId)
                                    ? [
                                        Shadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Iconsax.arrow_right_3,
                    size: 16, color: AppColors.textHint),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatLastMessage(String msg, bool isMe) {
    if (msg.isEmpty) return 'No messages yet';

    String prefix = isMe ? 'You: ' : '';
    String content = msg;

    if (msg.startsWith('http') &&
        (msg.contains('cloudinary') || msg.contains('firebasestorage'))) {
      content = isMe ? 'sent a photo' : 'sent you a photo';
    }

    return '$prefix$content';
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.message,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 20),
            Text('No conversations yet',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'React or send a message to a photo\nand your conversation will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
