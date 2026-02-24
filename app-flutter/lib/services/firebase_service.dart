import 'dart:async';

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../app_navigator.dart';
import '../providers/auth_provider.dart';
import '../providers/match_provider.dart';
import '../screens/chat_screen.dart';

class FirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Match ID of the chat screen currently open, or null. Used to avoid showing a notification when user is already in that chat.
  static String? currentChatMatchId;

  /// True when user is on Matches tab (HomeScreen, index 2) with no ChatScreen on top. Set by HomeScreen/ChatScreen.
  static bool _isOnMatchesScreen = false;
  static void setOnMatchesScreen(bool value) {
    _isOnMatchesScreen = value;
  }
  static bool get isOnMatchesScreen => _isOnMatchesScreen;

  /// Callback to refresh the current chat. Set by ChatScreen when it mounts, cleared when it disposes.
  static String? _refreshChatMatchId;
  static void Function()? _onRefreshChat;

  static void setCurrentChatMatchId(String? matchId) {
    currentChatMatchId = matchId;
  }

  static void registerChatRefresh(String matchId, void Function() onRefresh) {
    _refreshChatMatchId = matchId;
    _onRefreshChat = onRefresh;
  }

  static void unregisterChatRefresh(String matchId) {
    if (_refreshChatMatchId == matchId) {
      _refreshChatMatchId = null;
      _onRefreshChat = null;
    }
  }

  /// If the open chat is for [matchId], trigger refresh and return true. Otherwise return false.
  static bool tryRefreshChatIfSame(String matchId) {
    if (currentChatMatchId == matchId && _refreshChatMatchId == matchId && _onRefreshChat != null) {
      _onRefreshChat!();
      return true;
    }
    return false;
  }

  /// Ensures AuthProvider has loaded user, then runs [callback]. Use async callback to land on Matches, fetch matches, then open chat.
  static Future<void> _ensureUserLoadedThen(Future<void> Function() callback) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await Provider.of<AuthProvider>(context, listen: false).loadUser();
    if (!context.mounted) return;
    await callback();
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
            _ensureUserLoadedThen(() async => _openReceivedHearts());
          } else if (type == 'heart_accepted') {
            _ensureUserLoadedThen(() => _openChatFromHeartAcceptedPayload(response.payload!));
          } else {
            _ensureUserLoadedThen(() => _openChatFromPayload(response.payload!));
          }
        } catch (_) {
          _ensureUserLoadedThen(() => _openChatFromPayload(response.payload!));
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

  static Future<void> _openChatFromPayload(String payloadStr) async {
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final matchId = data['matchId'] as String?;
      final senderId = data['senderId'] as String?;
      final senderName = data['senderName'] as String?;
      if (matchId == null || senderId == null) return;

      final nav = navigatorKey.currentState;
      if (nav == null || !nav.mounted) return;

      // 1. Same chat already open: just refresh and return
      if (tryRefreshChatIfSame(matchId)) return;

      // 2. Already on Matches screen: skip navigate and fetch, just push chat
      if (isOnMatchesScreen) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              matchId: matchId,
              otherUser: {'id': senderId, 'name': senderName ?? 'Unknown'},
            ),
          ),
        );
        return;
      }

      // 3. Land on Matches tab first, fetch matches, then open chat
      nav.pushNamedAndRemoveUntil('/home', (route) => false, arguments: 2);

      final frameDone = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => frameDone.complete());
      await frameDone.future;

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await Provider.of<MatchProvider>(context, listen: false).loadMyMatches();
      if (!context.mounted) return;

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
  static Future<void> _openChatFromHeartAcceptedPayload(String payloadStr) async {
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final matchId = data['matchId'] as String?;
      final accepterId = data['accepterId'] as String?;
      final accepterName = data['accepterName'] as String?;
      if (matchId == null || accepterId == null) return;

      final nav = navigatorKey.currentState;
      if (nav == null || !nav.mounted) return;

      if (tryRefreshChatIfSame(matchId)) return;

      if (isOnMatchesScreen) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              matchId: matchId,
              otherUser: {'id': accepterId, 'name': accepterName ?? 'Unknown'},
            ),
          ),
        );
        return;
      }

      nav.pushNamedAndRemoveUntil('/home', (route) => false, arguments: 2);

      final frameDone = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => frameDone.complete());
      await frameDone.future;

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await Provider.of<MatchProvider>(context, listen: false).loadMyMatches();
      if (!context.mounted) return;

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
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _ensureUserLoadedThen(() => _openChatFromPayload(payload));
        });
      } else if (type == 'heart_request') {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _ensureUserLoadedThen(() async => _openReceivedHearts());
        });
      } else if (type == 'heart_accepted') {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _ensureUserLoadedThen(() => _openChatFromHeartAcceptedPayload(jsonEncode(message.data)));
        });
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final type = message.data['type'] as String?;
      if (type == 'chat') {
        _ensureUserLoadedThen(() => _openChatFromPayload(jsonEncode(message.data)));
      } else if (type == 'heart_request') {
        _ensureUserLoadedThen(() async => _openReceivedHearts());
      } else if (type == 'heart_accepted') {
        _ensureUserLoadedThen(() => _openChatFromHeartAcceptedPayload(jsonEncode(message.data)));
      }
    });
  }
}
