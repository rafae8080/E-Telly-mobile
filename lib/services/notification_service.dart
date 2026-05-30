import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'navigation_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'hive_service.dart';

// Broadcast stream — any screen can listen for incoming FCM route events
// Used to trigger data refreshes when a notification arrives while the app is open
final _incomingRouteController = StreamController<String>.broadcast();
Stream<String> get onFcmRouteReceived => _incomingRouteController.stream;

// Must be a top-level function — Firebase runs background messages in a separate isolate
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // System automatically shows the notification banner from the FCM payload
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

  // Call after login AND after auto-login — registers the FCM token with the backend
  static Future<void> postLoginSetup() async {
    try {
      await requestPermission();
      final fcmToken = await getToken();
      if (fcmToken == null) {
        print('[FCM] No token available — skipping registration');
        return;
      }
      final platform = Platform.isIOS ? 'ios' : 'android';
      final response = await ApiService().authenticatedPost('/api/push/fcm-subscribe', {
        'token': fcmToken,
        'platform': platform,
      });
      if (response.statusCode == 401) {
        print('[FCM] Stale JWT detected — clearing auth and redirecting to login');
        await AuthService().logout();
        await HiveService.setLoggedIn(false);
        NavigationService.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (route) => false);
        return;
      }
      if (response.statusCode != 200) {
        print('[FCM] Registration error body: ${response.body}');
      }
      await setupTokenRefresh(platform);
    } catch (e) {
      print('[FCM] postLoginSetup failed: $e');
    }
  }

  static Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  static Future<String?> getToken() async {
    return await _messaging.getToken();
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
    } catch (e) {
      print('[FCM] Token refresh registration failed: $e');
    }
  }

  // Fires a local notification from in-app code (e.g. a live socket event while the
  // user is mid-navigation). Reuses the already-created 'etelly_alerts' channel.
  static Future<void> showLocalAlert(String title, String body,
      {String? route}) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
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
      payload: route,
    );
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    _incomingRouteController.add(message.data['route'] ?? 'home');
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
