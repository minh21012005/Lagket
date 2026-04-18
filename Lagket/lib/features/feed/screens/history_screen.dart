import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/history_provider.dart';
import '../providers/reaction_provider.dart';
import '../providers/message_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/models/reaction_model.dart';
import '../../../shared/widgets/user_avatar.dart';

// ─── History Screen ───────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerStatefulWidget {
  /// When non-null the PageView will jump to this index on first build.
  final int initialIndex;
  const HistoryScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final startIndex = ref.read(historyPageIndexProvider);
    _pageController = PageController(initialPage: startIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToIndex(int index) {
    ref.read(historyPageIndexProvider.notifier).state = index;
    ref.read(historyViewModeProvider.notifier).state = HistoryViewMode.single;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(historyViewModeProvider);
    final filteredAsync = ref.watch(filteredHistoryProvider);
    final friends = ref.watch(historyFriendListProvider).value ?? [];
    final filter = ref.watch(historyFilterProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: ShaderMask(
          shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
          child: Text('History',
              style: AppTextStyles.headlineMedium.copyWith(color: Colors.white)),
        ),
        actions: [
          // Toggle between grid and single view
          IconButton(
            icon: Icon(
              viewMode == HistoryViewMode.grid
                  ? Icons.view_carousel_rounded
                  : Icons.grid_view_rounded,
              color: Colors.white,
            ),
            tooltip: viewMode == HistoryViewMode.grid ? 'Single view' : 'Grid view',
            onPressed: () {
              ref.read(historyViewModeProvider.notifier).state =
                  viewMode == HistoryViewMode.grid
                      ? HistoryViewMode.single
                      : HistoryViewMode.grid;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────────────────────
          _FilterChipsRow(
            currentFilter: filter,
            friends: friends,
            onFilterChanged: (f) =>
                ref.read(historyFilterProvider.notifier).state = f,
          ),

          // ── Content area ──────────────────────────────────────────────────
          Expanded(
            child: filteredAsync.when(
              data: (photos) {
                if (photos.isEmpty) {
                  return _EmptyHistory(
                    isFiltered: filter is! AllPhotosFilter,
                    onClear: () => ref
                        .read(historyFilterProvider.notifier)
                        .state = const AllPhotosFilter(),
                  );
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: viewMode == HistoryViewMode.single
                      ? _SinglePhotoView(
                          key: const ValueKey('single'),
                          photos: photos,
                          pageController: _pageController,
                          currentUser: currentUser,
                        )
                      : _GridPhotoView(
                          key: const ValueKey('grid'),
                          photos: photos,
                          onTap: _jumpToIndex,
                        ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary)),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chips row ─────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  final HistoryFilter currentFilter;
  final List<dynamic> friends;
  final ValueChanged<HistoryFilter> onFilterChanged;

  const _FilterChipsRow({
    required this.currentFilter,
    required this.friends,
    required this.onFilterChanged,
  });

  bool _isActive(HistoryFilter f) {
    if (currentFilter.runtimeType != f.runtimeType) return false;
    if (f is FriendPhotosFilter && currentFilter is FriendPhotosFilter) {
      return (currentFilter as FriendPhotosFilter).friendId ==
          f.friendId;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
      color: Colors.black54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: 'All',
            active: _isActive(const AllPhotosFilter()),
            onTap: () => onFilterChanged(const AllPhotosFilter()),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'My Photos',
            active: _isActive(const MyPhotosFilter()),
            onTap: () => onFilterChanged(const MyPhotosFilter()),
          ),
          ...friends.map((f) {
            final filt = FriendPhotosFilter(
                friendId: f.id, friendName: f.displayUsername);
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Chip(
                label: f.displayUsername as String,
                active: _isActive(filt),
                onTap: () => onFilterChanged(filt),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          color: active ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Single photo PageView ────────────────────────────────────────────────────

class _SinglePhotoView extends ConsumerWidget {
  final List<PhotoModel> photos;
  final PageController pageController;
  final dynamic currentUser;

  const _SinglePhotoView({
    super.key,
    required this.photos,
    required this.pageController,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageView.builder(
      controller: pageController,
      itemCount: photos.length,
      onPageChanged: (i) =>
          ref.read(historyPageIndexProvider.notifier).state = i,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return _HistoryPhotoPage(
          photo: photo,
          currentUserId: currentUser?.id ?? '',
        );
      },
    );
  }
}

// ─── Full-screen single photo page ───────────────────────────────────────────

class _HistoryPhotoPage extends ConsumerStatefulWidget {
  final PhotoModel photo;
  final String currentUserId;
  const _HistoryPhotoPage(
      {required this.photo, required this.currentUserId});

  @override
  ConsumerState<_HistoryPhotoPage> createState() => _HistoryPhotoPageState();
}

class _HistoryPhotoPageState extends ConsumerState<_HistoryPhotoPage> {
  final _msgController = TextEditingController();
  bool _sendingMsg = false;
  bool _showMessages = false;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingMsg = true);
    try {
      await ref.read(firestoreServiceProvider).addMessage(
            photoId: widget.photo.id,
            senderId: widget.currentUserId,
            content: text,
          );
      _msgController.clear();
    } finally {
      if (mounted) setState(() => _sendingMsg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderAsync =
        ref.watch(historySenderProvider(widget.photo.senderId));
    final reactionsAsync =
        ref.watch(reactionsProvider(widget.photo.id));
    final myReaction = ref.watch(
        myReactionProvider((widget.photo.id, widget.currentUserId)));
    final messagesAsync =
        ref.watch(messagesProvider(widget.photo.id));

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Fullscreen image ────────────────────────────────────────────────
        CachedNetworkImage(
          imageUrl: widget.photo.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.surface),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.surface,
            child: const Icon(Icons.broken_image,
                color: AppColors.textHint, size: 60),
          ),
        ),

        // ── Dark gradient bottom ────────────────────────────────────────────
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.photoOverlay),
          ),
        ),

        // ── Sender info ─────────────────────────────────────────────────────
        Positioned(
          bottom: 220,
          left: 16,
          right: 16,
          child: senderAsync.when(
            data: (sender) => Row(
              children: [
                UserAvatar(
                  avatarUrl: sender?.avatarUrl,
                  username: sender?.displayUsername ?? '?',
                  size: 40,
                  showBorder: true,
                ),
                const SizedBox(width: 10),
                Column(
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
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        // ── Reaction summary bar ────────────────────────────────────────────
        Positioned(
          bottom: 174,
          left: 16,
          right: 16,
          child: reactionsAsync.when(
            data: (reactions) {
              if (reactions.isEmpty) return const SizedBox.shrink();
              // Group by type
              final counts = <ReactionType, int>{};
              for (final r in reactions) {
                counts[r.type] = (counts[r.type] ?? 0) + 1;
              }
              return Row(
                children: counts.entries.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

        // ── Reaction buttons ────────────────────────────────────────────────
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ReactionType.values.map((type) {
              final isActive = myReaction?.type == type;
              return _AnimatedReactionBtn(
                type: type,
                isActive: isActive,
                onTap: () async {
                  final fs = ref.read(firestoreServiceProvider);
                  if (isActive) {
                    await fs.removeReaction(
                        photoId: widget.photo.id,
                        userId: widget.currentUserId);
                  } else {
                    await fs.upsertReaction(
                        photoId: widget.photo.id,
                        userId: widget.currentUserId,
                        type: type);
                  }
                },
              );
            }).toList(),
          ),
        ),

        // ── Messages toggle + input ─────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Message list (collapsible)
                if (_showMessages)
                  messagesAsync.when(
                    data: (msgs) => msgs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('No messages yet',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: Colors.white54)),
                          )
                        : Container(
                            constraints:
                                const BoxConstraints(maxHeight: 160),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListView.builder(
                              shrinkWrap: true,
                              reverse: true,
                              itemCount: msgs.length,
                              itemBuilder: (_, i) {
                                final m = msgs[msgs.length - 1 - i];
                                final isMe =
                                    m.senderId == widget.currentUserId;
                                return Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppColors.primary
                                              .withValues(alpha: 0.85)
                                          : Colors.white
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(m.content,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13)),
                                  ),
                                );
                              },
                            ),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                // Input row
                Row(
                  children: [
                    // Show/hide messages toggle
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showMessages = !_showMessages),
                      child: Icon(
                        _showMessages
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Say something…',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendingMsg ? null : _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
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
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Animated reaction button ─────────────────────────────────────────────────

class _AnimatedReactionBtn extends StatefulWidget {
  final ReactionType type;
  final bool isActive;
  final VoidCallback onTap;
  const _AnimatedReactionBtn(
      {required this.type, required this.isActive, required this.onTap});

  @override
  State<_AnimatedReactionBtn> createState() => _AnimatedReactionBtnState();
}

class _AnimatedReactionBtnState extends State<_AnimatedReactionBtn>
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
          margin: const EdgeInsets.symmetric(horizontal: 5),
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
          child: Text(widget.type.emoji,
              style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

// ─── Grid view ────────────────────────────────────────────────────────────────

class _GridPhotoView extends ConsumerWidget {
  final List<PhotoModel> photos;
  final ValueChanged<int> onTap;
  const _GridPhotoView({super.key, required this.photos, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final photo = photos[i];
        final senderAsync = ref.watch(historySenderProvider(photo.senderId));
        return GestureDetector(
          onTap: () => onTap(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: photo.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surface,
                    child: const Icon(Icons.broken_image,
                        color: AppColors.textHint),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: AppColors.photoOverlay),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarUrl: senderAsync.value?.avatarUrl,
                        username:
                            senderAsync.value?.displayUsername ?? '?',
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          senderAsync.value?.displayUsername ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  final bool isFiltered;
  final VoidCallback onClear;
  const _EmptyHistory({required this.isFiltered, required this.onClear});

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
              child: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltered ? 'No photos match this filter' : 'No photos yet',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try a different filter.'
                  : 'Send a photo to your friends\nand it will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: onClear,
                child: Text('Show all photos',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
