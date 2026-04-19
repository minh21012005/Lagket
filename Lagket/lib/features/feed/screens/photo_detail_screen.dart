import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/reaction_provider.dart';
import '../providers/message_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/reaction_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';

class PhotoDetailScreen extends ConsumerWidget {
  final String photoId;
  const PhotoDetailScreen({super.key, required this.photoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoAsync = ref.watch(_photoDetailProvider(photoId));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: photoAsync.when(
        data: (photo) {
          if (photo == null) {
            return const Center(
                child: Text('Photo not found.',
                    style: TextStyle(color: Colors.white)));
          }
          return _PhotoDetailContent(photo: photo);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

class _PhotoDetailContent extends ConsumerStatefulWidget {
  final PhotoModel photo;
  const _PhotoDetailContent({required this.photo});

  @override
  ConsumerState<_PhotoDetailContent> createState() =>
      _PhotoDetailContentState();
}

class _PhotoDetailContentState extends ConsumerState<_PhotoDetailContent> {
  final _msgController = TextEditingController();
  bool _sendingMsg = false;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  /// Resolves (or creates) a conversation with the photo sender, then sends
  /// a text message into that conversation.
  Future<void> _sendMessage(String currentUserId) async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // Don't message yourself (sender is the same user)
    final otherId = widget.photo.senderId;
    if (otherId.isEmpty || otherId == currentUserId) return;

    setState(() => _sendingMsg = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final convId =
          await fs.getOrCreateConversation(currentUserId, otherId);
      await fs.sendTextMessage(
        conversationId: convId,
        senderId: currentUserId,
        content: text,
      );
      _msgController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingMsg = false);
    }
  }

  /// Handles a reaction tap: upsert/remove the reaction in Firestore, and
  /// – on a new reaction – also write a reaction-message to the conversation.
  Future<void> _handleReaction({
    required String currentUserId,
    required ReactionType type,
    required bool isActive,
  }) async {
    final fs = ref.read(firestoreServiceProvider);
    if (isActive) {
      await fs.removeReaction(
          photoId: widget.photo.id, userId: currentUserId);
    } else {
      await fs.upsertReaction(
          photoId: widget.photo.id,
          userId: currentUserId,
          type: type);

      // Create/update conversation and add reaction message.
      final otherId = widget.photo.senderId;
      if (otherId.isNotEmpty && otherId != currentUserId) {
        try {
          final convId =
              await fs.getOrCreateConversation(currentUserId, otherId);
          await fs.sendReactionMessage(
            conversationId: convId,
            senderId: currentUserId,
            reactionEmoji: type.emoji,
            photoId: widget.photo.id,
          );
        } catch (_) {
          // Reaction was saved – conversation failure is non-fatal.
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final currentUserId = currentUser?.id ?? '';
    final senderAsync =
        ref.watch(_photoSenderProvider(widget.photo.senderId));
    final reactionsAsync = ref.watch(reactionsProvider(widget.photo.id));
    final myReaction =
        ref.watch(myReactionProvider((widget.photo.id, currentUserId)));

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Zoomable image ────────────────────────────────────────────────────
        PhotoView(
          imageProvider: CachedNetworkImageProvider(widget.photo.imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2.5,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          loadingBuilder: (_, __) => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary)),
          ),
        ),

        // ── Sender info overlay ───────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 48),
            decoration: const BoxDecoration(
              gradient: AppColors.photoOverlay,
            ),
            child: senderAsync.when(
              data: (sender) => Row(
                children: [
                  // Tapping the avatar opens the conversation
                  GestureDetector(
                    onTap: currentUserId.isNotEmpty &&
                            widget.photo.senderId != currentUserId
                        ? () async {
                            final fs = ref.read(firestoreServiceProvider);
                            final convId =
                                await fs.getOrCreateConversation(
                                    currentUserId, widget.photo.senderId);
                            if (context.mounted) {
                              context.push('/conversation/$convId');
                            }
                          }
                        : null,
                    child: UserAvatar(
                      avatarUrl: sender?.avatarUrl,
                      username: sender?.displayUsername ?? '?',
                      size: 48,
                      showBorder: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sender?.displayUsername ?? 'Unknown',
                          style: AppTextStyles.headlineSmall
                              .copyWith(color: Colors.white),
                        ),
                        if (widget.photo.createdAt != null)
                          Text(
                            DateFormatter.formatDate(widget.photo.createdAt!),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),

        // ── Reaction summary ──────────────────────────────────────────────────
        Positioned(
          bottom: 160,
          left: 16,
          right: 16,
          child: reactionsAsync.when(
            data: (reactions) {
              if (reactions.isEmpty) return const SizedBox.shrink();
              final counts = <ReactionType, int>{};
              for (final r in reactions) {
                counts[r.type] = (counts[r.type] ?? 0) + 1;
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: counts.entries.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${e.key.emoji} ${e.value}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        // ── Reaction row ──────────────────────────────────────────────────────
        Positioned(
          bottom: 108,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ReactionType.values.map((type) {
              final isActive = myReaction?.type == type;
              return _ReactionButton(
                type: type,
                isActive: isActive,
                onTap: () => _handleReaction(
                  currentUserId: currentUserId,
                  type: type,
                  isActive: isActive,
                ),
              );
            }).toList(),
          ),
        ),

        // ── Message input bar ─────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 52),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                // ── Text input ──────────────────────────────────────
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(currentUserId),
                    decoration: InputDecoration(
                      hintText: 'Say something…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ── Send button ─────────────────────────────────────
                GestureDetector(
                  onTap: _sendingMsg
                      ? null
                      : () => _sendMessage(currentUserId),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: _sendingMsg
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white)),
                          )
                        : const Icon(Iconsax.send_1,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reaction button widget ───────────────────────────────────────────────────

class _ReactionButton extends StatefulWidget {
  final ReactionType type;
  final bool isActive;
  final VoidCallback onTap;
  const _ReactionButton(
      {required this.type, required this.isActive, required this.onTap});

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1, end: 1.4)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: widget.isActive
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child:
              Text(widget.type.emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

// ─── Local providers ──────────────────────────────────────────────────────────

final _photoDetailProvider =
    FutureProvider.family<PhotoModel?, String>((ref, photoId) async {
  return ref.watch(firestoreServiceProvider).getPhoto(photoId);
});

final _photoSenderProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.watch(firestoreServiceProvider).getUser(userId);
});
