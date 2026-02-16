import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class SocketService {
  static IO.Socket? _socket;

  static Future<IO.Socket> getSocket() async {
    if (_socket != null && _socket!.connected) {
      return _socket!;
    }

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
        .enableAutoConnect()
        .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

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
