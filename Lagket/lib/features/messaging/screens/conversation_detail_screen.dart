import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/services/firestore_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/messaging/providers/messaging_provider.dart';
import '../../../shared/models/message_model.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../notification/services/fcm_service.dart';

// ─── Conversation Detail Screen ───────────────────────────────────────────────

class ConversationDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ConversationDetailScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState
    extends ConsumerState<ConversationDetailScreen> {
  final _msgController = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _msgController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String currentUserId) async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(firestoreServiceProvider).sendTextMessage(
            conversationId: widget.conversationId,
            senderId: currentUserId,
            content: text,
          );
      _msgController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final currentUserId = currentUser?.id ?? '';
    final messagesAsync =
        ref.watch(conversationDetailProvider(widget.conversationId));

    // Listen for new messages from others to show notification
    ref.listen(conversationDetailProvider(widget.conversationId), (previous, next) {
      if (next is AsyncData<List<MessageModel>> && 
          previous is AsyncData<List<MessageModel>>) {
        final newMessages = next.value;
        final oldMessages = previous.value;
        
        if (newMessages.length > oldMessages.length) {
          final latestMsg = newMessages.last;
          if (latestMsg.senderId != currentUserId) {
            FCMService().showLocalNotification(
              title: 'New message',
              body: latestMsg.content,
            );
          }
        }
      }
    });

    final convAsync = ref.watch(conversationListProvider);
    final conv = convAsync.value?.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: () => throw StateError('not found'),
    );
    final otherId = conv?.otherParticipant(currentUserId) ?? '';
    final otherUserAsync = ref.watch(conversationUserProvider(otherId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(otherUserAsync.value),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
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
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyChat(
                    otherUsername:
                        otherUserAsync.value?.displayUsername ?? '...',
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == currentUserId;
                    final showDate = i == 0 ||
                        _shouldShowDate(messages[i - 1], msg);
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.createdAt),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          senderUser: isMe ? currentUser : otherUserAsync.value,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _msgController,
            sending: _sending,
            onSend: () => _send(currentUserId),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDate(MessageModel prev, MessageModel curr) {
    if (prev.createdAt == null || curr.createdAt == null) return false;
    return curr.createdAt!.difference(prev.createdAt!).inMinutes > 30;
  }

  PreferredSizeWidget _buildAppBar(UserModel? otherUser) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          UserAvatar(
            avatarUrl: otherUser?.avatarUrl,
            username: otherUser?.displayUsername ?? '?',
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherUser?.displayUsername ?? '...',
                  style: AppTextStyles.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${otherUser?.username ?? ''}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final UserModel? senderUser;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.senderUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(
              avatarUrl: senderUser?.avatarUrl,
              username: senderUser?.displayUsername ?? '?',
              size: 28,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: _buildMessageContent(context),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.reaction:
        return _ReactionBubble(message: message, isMe: isMe);
      case MessageType.photo_reply:
        return _PhotoReplyBubble(message: message, isMe: isMe);
      default:
        return _TextBubble(message: message, isMe: isMe);
    }
  }
}

// ─── Photo Reply bubble ──────────────────────────────────────────────────────

class _PhotoReplyBubble extends ConsumerWidget {
  final MessageModel message;
  final bool isMe;

  const _PhotoReplyBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoAsync = ref.watch(_messagePhotoProvider(message.photoId ?? ''));

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMe ? null : AppColors.surfaceElevated,
            gradient: isMe ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.photoId != null)
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14), bottom: Radius.circular(4)),
                    child: photoAsync.when(
                      data: (photo) => photo != null
                          ? CachedNetworkImage(
                              imageUrl: photo.imageUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(height: 100),
                      loading: () => Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.black12,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox(height: 100),
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        if (message.createdAt != null)
          Text(
            DateFormatter.formatTime(message.createdAt!),
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textHint, fontSize: 10),
          ),
      ],
    );
  }
}

// ─── Text bubble ─────────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _TextBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe ? AppColors.primaryGradient : null,
            color: isMe ? null : AppColors.surfaceElevated,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe
                  ? const Radius.circular(18)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(18),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (message.createdAt != null)
          Text(
            DateFormatter.formatTime(message.createdAt!),
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textHint, fontSize: 10),
          ),
      ],
    );
  }
}

// ─── Reaction bubble ──────────────────────────────────────────────────────────

class _ReactionBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _ReactionBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.content,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 6),
              Text(
                isMe ? 'You reacted to a photo' : 'Reacted to a photo',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        if (message.createdAt != null)
          Text(
            DateFormatter.formatTime(message.createdAt!),
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textHint, fontSize: 10),
          ),
      ],
    );
  }
}

// ─── Date divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime? date;
  const _DateDivider({this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              DateFormatter.formatDate(date!),
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textHint),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14.5),
                    decoration: const InputDecoration(
                      hintText: 'Say something…',
                      hintStyle: TextStyle(color: AppColors.textHint),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: sending ? null : onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: sending
                        ? null
                        : AppColors.primaryGradient,
                    color: sending ? AppColors.surfaceElevated : null,
                    shape: BoxShape.circle,
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        )
                      : const Icon(Iconsax.send_1,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty chat state ─────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String otherUsername;
  const _EmptyChat({required this.otherUsername});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.message_add,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Start the conversation',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Say hello to $otherUsername!\nType a message below.',
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

// ─── Providers ────────────────────────────────────────────────────────────────

final _messagePhotoProvider =
    FutureProvider.family<PhotoModel?, String>((ref, photoId) async {
  if (photoId.isEmpty) return null;
  return ref.watch(firestoreServiceProvider).getPhoto(photoId);
});
