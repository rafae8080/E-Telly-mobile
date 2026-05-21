import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'navigation_service.dart';
import 'api_service.dart';

// Must be a top-level function — Firebase runs background messages in a separate isolate
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM Background] Received: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stored so we can cancel on logout to prevent stale token re-registration
  static StreamSubscription<String>? _tokenRefreshSub;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'etelly_alerts',
    'E-Telly Alerts',
    description: 'Emergency alerts and hazard notifications from E-Telly CDRRMO',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      _handleNotificationTap(initialMessage);
    }
  }

  static Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  static Future<String?> getToken() async {
    final token = await _messaging.getToken();
    print('[FCM] Device token: $token');
    return token;
  }

  // Call after login — listens for token rotation and re-registers automatically
  static Future<void> setupTokenRefresh(String platform) async {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _registerToken(newToken, platform);
    });
  }

  // Call before logout — prevents stale listener from re-registering under wrong session
  static void cancelTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  static Future<void> _registerToken(String token, String platform) async {
    try {
      await ApiService().authenticatedPost('/api/push/fcm-subscribe', {
        'token': token,
        'platform': platform,
      });
      print('[FCM] Token re-registered after refresh');
    } catch (e) {
      print('[FCM] Token refresh registration failed: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'],
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'] ?? 'home';
    NavigationService.navigateTo(route);
  }

  static void _onNotificationTap(NotificationResponse response) {
    final route = response.payload ?? 'home';
    NavigationService.navigateTo(route);
  }
}
