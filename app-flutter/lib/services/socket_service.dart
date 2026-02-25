import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class SocketService {
  static IO.Socket? _socket;

  static Future<IO.Socket> getSocket() async {
    if (_socket != null && _socket!.connected) {
      return _socket!;
    }

    // Clear any disconnected socket so we create a single new one
    _socket?.disconnect();
    _socket = null;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    final baseUrl = AppConfig.apiBaseUrl;

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .setExtraHeaders({'authorization': 'Bearer $token'})
        .disableAutoConnect()
        .disableReconnection()
        .build(),
    );

    final completer = Completer<void>();
    final thisSocket = _socket!;
    bool errorHandled = false;
    thisSocket.onConnect((_) {
      if (!completer.isCompleted) completer.complete();
    });
    thisSocket.onDisconnect((_) {
      // Only clear if this is still the active socket (avoids old socket's callback killing a new one after Retry)
      if (_socket == thisSocket) {
        _socket?.disconnect();
        _socket = null;
      }
    });
    thisSocket.onError((error) {
      // Socket.io can fire onError repeatedly when disconnected (e.g. every few seconds); handle only once and stop the socket
      if (errorHandled) return;
      errorHandled = true;
      // Disconnect immediately so the library stops any internal retries and stops emitting further errors
      try {
        thisSocket.disconnect();
      } catch (_) {}
      if (_socket == thisSocket) {
        _socket = null;
      }
      if (!completer.isCompleted) completer.completeError(error);
    });

    thisSocket.connect();

    try {
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (_socket == thisSocket) {
            _socket?.disconnect();
            _socket = null;
          }
          throw TimeoutException('Socket connection timed out');
        },
      );
    } catch (e) {
      if (_socket == thisSocket) {
        _socket?.disconnect();
        _socket = null;
      }
      rethrow;
    }
    return _socket!;
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static bool isConnected() {
    return _socket != null && _socket!.connected;
  }
}
