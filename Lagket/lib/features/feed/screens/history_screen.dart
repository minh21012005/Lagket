import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
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
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/user_avatar.dart';

// ─── History Screen ───────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerStatefulWidget {
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

  // ─── Filter modal ──────────────────────────────────────────────────────────

  Future<void> _showFilterSheet() async {
    final friends = ref.read(historyFriendListProvider).value ?? [];
    final currentFilter = ref.read(historyFilterProvider);

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FilterSheet(
        currentFilter: currentFilter,
        friends: friends,
        onSelected: (f) {
          ref.read(historyFilterProvider.notifier).state = f;
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  // ─── Filter label ──────────────────────────────────────────────────────────

  String _filterLabel(HistoryFilter f) {
    return switch (f) {
      AllPhotosFilter() => 'All Photos',
      MyPhotosFilter() => 'My Photos',
      FriendPhotosFilter(:final friendName) => friendName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(historyViewModeProvider);
    final filteredAsync = ref.watch(filteredHistoryProvider);
    final filter = ref.watch(historyFilterProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.arrow_left,
                        color: Colors.white),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.primaryGradient.createShader(b),
                    child: Text(
                      'History',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // View mode toggle
                  _IconBtn(
                    icon: viewMode == HistoryViewMode.grid
                        ? Iconsax.row_vertical
                        : Iconsax.grid_1,
                    tooltip: viewMode == HistoryViewMode.grid
                        ? 'Single view'
                        : 'Grid view',
                    onTap: () {
                      ref.read(historyViewModeProvider.notifier).state =
                          viewMode == HistoryViewMode.grid
                              ? HistoryViewMode.single
                              : HistoryViewMode.grid;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Filter pill button ────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _showFilterSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: filter is AllPhotosFilter
                        ? null
                        : AppColors.primaryGradient,
                    color: filter is AllPhotosFilter
                        ? AppColors.surface
                        : null,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: filter is AllPhotosFilter
                          ? AppColors.border
                          : Colors.transparent,
                    ),
                    boxShadow: filter is! AllPhotosFilter
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.filter,
                        size: 14,
                        color: filter is AllPhotosFilter
                            ? AppColors.textSecondary
                            : Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _filterLabel(filter),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: filter is AllPhotosFilter
                              ? AppColors.textSecondary
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Iconsax.arrow_down_1,
                        size: 12,
                        color: filter is AllPhotosFilter
                            ? AppColors.textHint
                            : Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

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
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.primary)),
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
      ),
    );
  }
}

// ─── Filter bottom sheet ──────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final HistoryFilter currentFilter;
  final List<UserModel> friends;
  final ValueChanged<HistoryFilter> onSelected;
  const _FilterSheet(
      {required this.currentFilter,
      required this.friends,
      required this.onSelected});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  bool _showFriendPicker = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              if (_showFriendPicker)
                GestureDetector(
                  onTap: () => setState(() => _showFriendPicker = false),
                  child: const Icon(Iconsax.arrow_left,
                      size: 20, color: AppColors.textPrimary),
                ),
              if (_showFriendPicker) const SizedBox(width: 8),
              Text(
                _showFriendPicker ? 'Select a Friend' : 'Filter Photos',
                style: AppTextStyles.headlineMedium,
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppColors.border),

        if (!_showFriendPicker) ...[
          _OptionTile(
            icon: Iconsax.gallery,
            label: 'All Photos',
            selected: widget.currentFilter is AllPhotosFilter,
            onTap: () => widget.onSelected(const AllPhotosFilter()),
          ),
          _OptionTile(
            icon: Iconsax.user,
            label: 'My Photos',
            selected: widget.currentFilter is MyPhotosFilter,
            onTap: () => widget.onSelected(const MyPhotosFilter()),
          ),
          _OptionTile(
            icon: Iconsax.people,
            label: 'Specific Friend',
            selected: widget.currentFilter is FriendPhotosFilter,
            onTap: () {
              if (widget.friends.isEmpty) return;
              setState(() => _showFriendPicker = true);
            },
            trailing: Icon(Iconsax.arrow_right_3,
                size: 16, color: AppColors.textHint),
          ),
        ] else ...[
          // Friend list (scrollable up to 300 px)
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: widget.friends.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No friends yet.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.friends.length,
                    itemBuilder: (_, i) {
                      final f = widget.friends[i];
                      final sel = widget.currentFilter is FriendPhotosFilter &&
                          (widget.currentFilter as FriendPhotosFilter)
                                  .friendId ==
                              f.id;
                      return ListTile(
                        leading: UserAvatar(
                          avatarUrl: f.avatarUrl,
                          username: f.displayUsername,
                          size: 40,
                        ),
                        title: Text(f.displayUsername,
                            style: AppTextStyles.bodyLarge),
                        subtitle: Text('@${f.username}',
                            style: AppTextStyles.bodySmall),
                        trailing: sel
                            ? const Icon(Iconsax.tick_circle,
                                color: AppColors.primary)
                            : null,
                        onTap: () => widget.onSelected(
                          FriendPhotosFilter(
                              friendId: f.id, friendName: f.displayUsername),
                        ),
                      );
                    },
                  ),
          ),
        ],

        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  const _OptionTile(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 20,
            color: selected ? AppColors.primary : AppColors.textSecondary),
      ),
      title: Text(label,
          style: AppTextStyles.bodyLarge.copyWith(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          )),
      trailing:
          trailing ?? (selected ? const Icon(Iconsax.tick_circle, color: AppColors.primary) : null),
      onTap: onTap,
    );
  }
}

// ─── Small icon button ────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
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
  const _SinglePhotoView(
      {super.key,
      required this.photos,
      required this.pageController,
      required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageView.builder(
      controller: pageController,
      itemCount: photos.length,
      onPageChanged: (i) =>
          ref.read(historyPageIndexProvider.notifier).state = i,
      itemBuilder: (context, index) {
        return _HistoryPhotoPage(
          photo: photos[index],
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
  ConsumerState<_HistoryPhotoPage> createState() =>
      _HistoryPhotoPageState();
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

    // Do not message oneself
    final otherId = widget.photo.senderId;
    if (otherId.isEmpty || otherId == widget.currentUserId) return;

    setState(() => _sendingMsg = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final convId =
          await fs.getOrCreateConversation(widget.currentUserId, otherId);
      await fs.sendTextMessage(
        conversationId: convId,
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
    final reactionsAsync = ref.watch(reactionsProvider(widget.photo.id));
    final myReaction = ref
        .watch(myReactionProvider((widget.photo.id, widget.currentUserId)));
    final messagesAsync = ref.watch(messagesProvider(widget.photo.id));

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fullscreen image
        CachedNetworkImage(
          imageUrl: widget.photo.imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          memCacheHeight: 800,
          filterQuality: FilterQuality.medium,
          placeholder: (_, __) => Container(color: AppColors.surface),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.surface,
            child: const Icon(Iconsax.gallery_slash,
                color: AppColors.textHint, size: 60),
          ),
        ),

        // Dark gradient
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.photoOverlay),
          ),
        ),

        // Sender info
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
                    Text(sender?.displayUsername ?? 'Unknown',
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: Colors.white)),
                    if (widget.photo.createdAt != null)
                      Text(DateFormatter.formatDate(widget.photo.createdAt!),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        // Reaction summary
        Positioned(
          bottom: 174,
          left: 16,
          right: 16,
          child: reactionsAsync.when(
            data: (reactions) {
              if (reactions.isEmpty) return const SizedBox.shrink();
              final counts = <ReactionType, int>{};
              for (final r in reactions) {
                counts[r.type] = (counts[r.type] ?? 0) + 1;
              }
              return Wrap(
                spacing: 6,
                children: counts.entries.map((e) {
                  return Container(
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

        // Reaction buttons
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

        // Message panel
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                                    margin:
                                        const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppColors.primary
                                              .withValues(alpha: 0.85)
                                          : Colors.white
                                              .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(14),
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
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showMessages = !_showMessages),
                      child: Icon(
                        _showMessages
                            ? Iconsax.message5
                            : Iconsax.message,
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
                          fillColor:
                              Colors.white.withValues(alpha: 0.12),
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
                            : const Icon(Iconsax.send_1,
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
          child:
              Text(widget.type.emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

// ─── Grid view ────────────────────────────────────────────────────────────────

class _GridPhotoView extends ConsumerWidget {
  final List<PhotoModel> photos;
  final ValueChanged<int> onTap;
  const _GridPhotoView(
      {super.key, required this.photos, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final photo = photos[i];
        final senderAsync =
            ref.watch(historySenderProvider(photo.senderId));
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
                  memCacheWidth: 800,
                  memCacheHeight: 800,
                  filterQuality: FilterQuality.medium,
                  placeholder: (_, __) =>
                      Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surface,
                    child: const Icon(Iconsax.gallery_slash,
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
              child: const Icon(Iconsax.gallery,
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
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary, height: 1.5),
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
