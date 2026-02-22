import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_navigator.dart';
import '../screens/chat_screen.dart';

class FirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Match ID of the chat screen currently open, or null. Used to avoid showing a notification when user is already in that chat.
  static String? currentChatMatchId;

  static void setCurrentChatMatchId(String? matchId) {
    currentChatMatchId = matchId;
  }

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidChannel = AndroidNotificationDetails(
    'chat',
    'Chat messages',
    channelDescription: 'Notifications for new chat messages',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == null || response.payload!.isEmpty) return;
        try {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          final type = data['type'] as String?;
          if (type == 'heart_request') {
            _openReceivedHearts();
          } else if (type == 'heart_accepted') {
            _openChatFromHeartAcceptedPayload(response.payload!);
          } else {
            _openChatFromPayload(response.payload!);
          }
        } catch (_) {
          _openChatFromPayload(response.payload!);
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'chat',
          'Chat messages',
          description: 'Notifications for new chat messages',
          importance: Importance.high,
        ));
  }

  static void _openChatFromPayload(String payloadStr) {
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final matchId = data['matchId'] as String?;
      final senderId = data['senderId'] as String?;
      final senderName = data['senderName'] as String?;
      if (matchId == null || senderId == null) return;

      final nav = navigatorKey.currentState;
      if (nav == null || !nav.mounted) return;

      // So Back from chat goes to Chat index (Matches tab = index 2): put Home(Matches) under Chat via named route (keeps theme).
      nav.pushNamedAndRemoveUntil('/home', (route) => false, arguments: 2);
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            matchId: matchId,
            otherUser: {'id': senderId, 'name': senderName ?? 'Unknown'},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat from notification: $e');
    }
  }

  /// Navigate to Matches >> Received Hearts tab.
  static void _openReceivedHearts() {
    final nav = navigatorKey.currentState;
    if (nav == null || !nav.mounted) return;
    nav.pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: {'tab': 2, 'matchesTab': 1},
    );
  }

  /// Open chat with the user who accepted the heart (heart_accepted notification tap).
  static void _openChatFromHeartAcceptedPayload(String payloadStr) {
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final matchId = data['matchId'] as String?;
      final accepterId = data['accepterId'] as String?;
      final accepterName = data['accepterName'] as String?;
      if (matchId == null || accepterId == null) return;

      final nav = navigatorKey.currentState;
      if (nav == null || !nav.mounted) return;

      nav.pushNamedAndRemoveUntil('/home', (route) => false, arguments: 2);
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            matchId: matchId,
            otherUser: {'id': accepterId, 'name': accepterName ?? 'Unknown'},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat from heart_accepted notification: $e');
    }
  }

  static Future<void> init() async {
    await _initLocalNotifications();
  }

  // Request notification permissions
  static Future<bool> requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Get FCM token
  static Future<String?> getToken() async {
    try {
      String? token = await _messaging.getToken();
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  // Setup foreground message handler
  static void setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      final data = message.data;
      final type = data['type'] as String?;

      if (type == 'chat') {
        final matchId = data['matchId'] as String?;
        if (matchId == null) return;
        if (currentChatMatchId == matchId) return;

        final title = data['senderName'] as String? ?? message.notification?.title ?? 'New message';
        final body = message.notification?.body ?? data['messageText'] as String? ?? 'New message';
        final payload = jsonEncode({
          'matchId': matchId,
          'senderId': data['senderId'] ?? '',
          'senderName': data['senderName'] ?? title,
        });
        _localNotifications.show(
          message.hashCode.abs(),
          title,
          body,
          NotificationDetails(android: _androidChannel),
          payload: payload,
        );
      } else if (type == 'heart_request') {
        final title = message.notification?.title ?? 'New heart!';
        final body = message.notification?.body ?? 'Someone sent you a heart!';
        final payload = jsonEncode({'type': 'heart_request'});
        _localNotifications.show(
          'heart_${data['matchId'] ?? message.messageId}'.hashCode.abs(),
          title,
          body,
          NotificationDetails(android: _androidChannel),
          payload: payload,
        );
      } else if (type == 'heart_accepted') {
        final title = message.notification?.title ?? 'Heart accepted!';
        final body = message.notification?.body ?? 'Someone accepted your heart!';
        final payload = jsonEncode({
          'type': 'heart_accepted',
          'matchId': data['matchId'] ?? '',
          'accepterId': data['accepterId'] ?? '',
          'accepterName': data['accepterName'] ?? '',
        });
        _localNotifications.show(
          'heart_accepted_${data['matchId'] ?? message.messageId}'.hashCode.abs(),
          title,
          body,
          NotificationDetails(android: _androidChannel),
          payload: payload,
        );
      }
    });
  }

  // Setup background message handler (must be top-level function)
  static Future<void> backgroundMessageHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    debugPrint('Handling a background message: ${message.messageId}');
  }

  // Setup notification handlers (tap: open chat or Received Hearts)
  static void setupNotificationHandlers() {
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message == null) return;
      final type = message.data['type'] as String?;
      if (type == 'chat') {
        final data = message.data;
        final payload = jsonEncode({
          'matchId': data['matchId'],
          'senderId': data['senderId'],
          'senderName': data['senderName'],
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openChatFromPayload(payload);
        });
      } else if (type == 'heart_request') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openReceivedHearts();
        });
      } else if (type == 'heart_accepted') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openChatFromHeartAcceptedPayload(jsonEncode(message.data));
        });
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final type = message.data['type'] as String?;
      if (type == 'chat') {
        _openChatFromPayload(jsonEncode(message.data));
      } else if (type == 'heart_request') {
        _openReceivedHearts();
      } else if (type == 'heart_accepted') {
        _openChatFromHeartAcceptedPayload(jsonEncode(message.data));
      }
    });
  }
}
