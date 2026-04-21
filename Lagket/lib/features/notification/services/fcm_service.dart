import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initializeSilent() async {
    // Initialize local notifications silently without requesting permissions initially
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSettings);

    // Create notification channel (Android)
    const channel = AndroidNotificationChannel(
      'lagket_channel',
      'Lagket Notifications',
      description: 'Notifications for new photos and friend requests',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Background message handler is registered at top-level (main.dart)
  }

  Future<void> requestPermissionsAndToken() async {
    // Request permission (may prompt user via OS)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await _messaging.getToken();
    // TODO: save token to Firestore for this user
    // ignore: avoid_print
    print('FCM Token: \$token');
  }

  void _handleForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    String body = notification.body ?? '';

    // Transform image URL to readable text in notification
    if (body.startsWith('http') &&
        (body.contains('cloudinary') || body.contains('firebasestorage'))) {
      body = 'sent you a photo';
    }

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lagket_channel',
          'Lagket Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<String?> getToken() => _messaging.getToken();

  // Show a local notification programmatically
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'lagket_channel',
      'Lagket Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}

/// Top-level background handler — must be outside any class
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message (Firebase already handles display)
}
