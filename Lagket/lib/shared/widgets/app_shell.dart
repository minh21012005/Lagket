import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/messaging/providers/messaging_provider.dart';
import '../../features/feed/providers/feed_provider.dart';
import '../../features/feed/providers/history_provider.dart';
import '../../features/feed/providers/reaction_provider.dart';
import '../../features/friend/providers/friend_provider.dart';
import '../../features/notification/services/fcm_service.dart';
import '../../shared/models/message_model.dart';
import '../../shared/models/reaction_model.dart';
import '../../shared/models/photo_model.dart';
import '../../shared/models/user_model.dart';

// ─── Tab index provider ───────────────────────────────────────────────────────

final shellTabIndexProvider = StateProvider<int>((ref) => 1); // camera = center

// ─── App Shell ────────────────────────────────────────────────────────────────

/// Persistent scaffold that wraps the three main tabs: Calendar / Camera / Messages.
/// Rendered by [StatefulShellRoute]. History and photo-detail screens push
/// *outside* this widget so the bottom nav auto-disappears.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  static const _tabs = [
    _TabItem(
      label: 'Calendar',
      icon: Iconsax.calendar_1,
      activeIcon: Iconsax.calendar,
    ),
    _TabItem(
      label: 'Home',
      icon: Iconsax.camera,
      activeIcon: Iconsax.camera5,
    ),
    _TabItem(
      label: 'Messages',
      icon: Iconsax.message,
      activeIcon: Iconsax.message5,
    ),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = navigationShell.currentIndex;
    final currentUser = ref.watch(currentUserProvider).value;
    final currentUserId = currentUser?.id ?? '';

    // ─── Global Message / Comment Listener ───────────────────────────────────
    ref.listen(conversationListProvider, (previous, next) {
      if (next.hasValue && previous?.hasValue == true) {
        for (final conv in next.value!) {
          final prevConv = previous!.value!.firstWhere(
            (c) => c.id == conv.id,
            orElse: () => conv,
          );

          if (conv.lastMessage.isNotEmpty &&
              conv.lastMessage != prevConv.lastMessage &&
              conv.lastMessageSenderId != null &&
              conv.lastMessageSenderId != currentUserId) {
            
            ref.read(conversationUserProvider(conv.lastMessageSenderId!))
                .whenData((sender) {
              FCMService().showLocalNotification(
                title: sender?.displayUsername ?? 'New message',
                body: conv.lastMessage,
              );
            });
          }
        }
      }
    });

    // ─── Global Friend Request Listener ──────────────────────────────────────
    ref.listen(incomingRequestsProvider, (previous, next) {
      if (next.hasValue && previous?.hasValue == true) {
        final newRequests = next.value!;
        final oldRequests = previous!.value!;
        if (newRequests.length > oldRequests.length) {
          final latest = newRequests.first;
          ref.read(conversationUserProvider(latest.fromUserId)).whenData((sender) {
            FCMService().showLocalNotification(
              title: 'New Friend Request',
              body: '${sender?.displayUsername ?? 'Someone'} wants to be your friend!',
            );
          });
        }
      }
    });

    // ─── Global Friend Accepted Listener ─────────────────────────────────────
    ref.listen(friendshipsProvider, (previous, next) {
      if (next.hasValue) {
        final newFriends = next.value ?? [];
        final oldFriends = previous?.value ?? [];

        if (newFriends.length > oldFriends.length) {
          // Find all IDs that are in new list but not in old list
          final oldIds = oldFriends.map((f) => f.friendId).toSet();
          final newlyAdded = newFriends.where((f) => !oldIds.contains(f.friendId));

          for (final friendObj in newlyAdded) {
            ref.read(conversationUserProvider(friendObj.friendId)).whenData((friend) {
              if (friend != null) {
                FCMService().showLocalNotification(
                  title: 'New Friend!',
                  body: 'You and ${friend.displayUsername} are now friends!',
                );
              }
            });
          }
        }
      }
    });

    // ─── Global Reaction Listener ───────────────────────────────────────────
    // We listen to all photos sent by the user to detect new reactions.
    final myPhotos = ref.watch(historyPhotosProvider).value ?? [];
    for (final photo in myPhotos.where((p) => p.senderId == currentUserId)) {
      ref.listen(reactionsProvider(photo.id), (previous, next) {
        if (next is AsyncData<List<ReactionModel>> &&
            previous is AsyncData<List<ReactionModel>>) {
          final newReactions = next.value!;
          final oldReactions = previous.value!;

          // Kiểm tra xem có react mới hoặc react thay đổi không
          // So sánh dựa trên sự khác biệt về số lượng hoặc thay đổi react của người dùng gần nhất
          bool hasNewOrUpdated = newReactions.length > oldReactions.length;
          
          ReactionModel? latest;
          if (newReactions.isNotEmpty) {
             latest = newReactions.last;
             // Nếu số lượng bằng nhau nhưng reaction mới nhất khác loại với cái cũ nhất trong danh sách
             // thì coi như có cập nhật.
             if (oldReactions.isNotEmpty && latest.type != oldReactions.last.type) {
               hasNewOrUpdated = true;
             }
          }

          if (hasNewOrUpdated && latest != null && latest.userId != currentUserId) {
            ref.read(conversationUserProvider(latest.userId)).whenData((sender) {
              FCMService().showLocalNotification(
                title: '${sender?.displayUsername ?? 'Someone'} reacted ${latest!.type.emoji}',
                body: 'to your photo',
              );
            });
          }
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        current: current,
        tabs: _tabs,
        onTap: _onTap,
      ),
    );
  }
}

// ─── Floating nav bar ─────────────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int current;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;
  const _FloatingNavBar(
      {required this.current, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, bottom + 12),
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == current;
          final tab = tabs[i];
          final isCenter = i == 1;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: EdgeInsets.symmetric(
                  horizontal: isCenter ? 4 : 6,
                  vertical: 8,
                ),
                decoration: selected
                    ? BoxDecoration(
                        gradient: isCenter
                            ? AppColors.primaryGradient
                            : LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.18),
                                  AppColors.accentPink.withValues(alpha: 0.10),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(24),
                        border: isCenter
                            ? null
                            : Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                      )
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        selected ? tab.activeIcon : tab.icon,
                        key: ValueKey(selected),
                        size: isCenter ? 26 : 22,
                        color: selected
                            ? (isCenter ? Colors.white : AppColors.primary)
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Label
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: selected
                            ? (isCenter ? Colors.white : AppColors.primary)
                            : AppColors.textHint,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: Text(tab.label),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem(
      {required this.label, required this.icon, required this.activeIcon});
}
