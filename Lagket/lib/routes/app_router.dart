import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/permission/screens/permission_screen.dart';
import '../features/camera/screens/camera_screen.dart';
import '../features/camera/screens/preview_screen.dart';
import '../features/camera/screens/send_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/feed/screens/history_screen.dart';
import '../features/feed/screens/photo_detail_screen.dart';
import '../features/feed/screens/widget_preview_screen.dart';
import '../features/friend/screens/add_friend_screen.dart';
import '../features/friend/screens/friend_requests_screen.dart';
import '../features/friend/screens/friends_list_screen.dart';
import '../features/messaging/screens/message_list_screen.dart';
import '../features/notification/screens/notification_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,

    // Redirect unauthenticated users
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.value != null;
      final location = state.matchedLocation;

      final publicRoutes = ['/login', '/signup', '/verify', '/'];
      final isPublic = publicRoutes.contains(location);

      if (!isLoggedIn && !isPublic) return '/login';
      if (isLoggedIn && (location == '/login' || location == '/signup')) {
        return '/camera';
      }
      return null;
    },

    routes: [
      // ─── Auth ───────────────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (_, __) => const OtpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const _ForgotPasswordScreen(),
      ),

      // ─── Onboarding ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/permissions',
        builder: (_, __) => const PermissionScreen(),
      ),

      // ─── Persistent shell (Camera / Calendar / Messages) ────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          // ── Tab 0: Calendar ──────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, __) => const CalendarScreen(),
              ),
            ],
          ),

          // ── Tab 1: Camera (default / home) ───────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/camera',
                builder: (_, __) => const CameraScreen(),
              ),
            ],
          ),

          // ── Tab 2: Messages ──────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (_, __) => const MessageListScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─── Camera sub-screens (outside shell) ─────────────────────────────────
      GoRoute(
        path: '/preview',
        builder: (_, __) => const PreviewScreen(),
      ),
      GoRoute(
        path: '/send',
        builder: (_, __) => const SendScreen(),
      ),

      // ─── Feed / History ──────────────────────────────────────────────────────
      GoRoute(
        path: '/feed',
        builder: (_, __) => const FeedScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/photo/:id',
        builder: (_, state) =>
            PhotoDetailScreen(photoId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/widget',
        builder: (_, __) => const WidgetPreviewScreen(),
      ),

      // ─── Friends ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/friends',
        builder: (_, __) => const FriendsListScreen(),
      ),
      GoRoute(
        path: '/friends/add',
        builder: (_, __) => const AddFriendScreen(),
      ),
      GoRoute(
        path: '/friends/requests',
        builder: (_, __) => const FriendRequestsScreen(),
      ),

      // ─── Notifications ──────────────────────────────────────────────────────
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationScreen(),
      ),

      // ─── Profile ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.info_circle,
                color: Color(0xFFEF476F), size: 56),
            const SizedBox(height: 16),
            Text('Page not found',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(state.error?.message ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home',
                  style: TextStyle(color: Color(0xFFFF6B35))),
            ),
          ],
        ),
      ),
    ),
  );
});

// ─── Simple forgot password screen ────────────────────────────────────────────

class _ForgotPasswordScreen extends ConsumerStatefulWidget {
  const _ForgotPasswordScreen();

  @override
  ConsumerState<_ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<_ForgotPasswordScreen> {
  final _ctrl = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(firebaseAuthServiceProvider)
          .sendPasswordResetEmail(_ctrl.text.trim());
      setState(() => _sent = true);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left,
              color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reset Password',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!_sent) ...[
              const Icon(Iconsax.password_check,
                  color: Color(0xFFFF6B35), size: 60),
              const SizedBox(height: 24),
              const Text(
                'Enter your email and we will send you a link to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white))
                      : const Text('Send Reset Email',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              const Icon(Iconsax.tick_circle,
                  color: Color(0xFF06D6A0), size: 64),
              const SizedBox(height: 20),
              const Text('Email sent!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Check your inbox at ${_ctrl.text}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to login',
                    style: TextStyle(color: Color(0xFFFF6B35))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
