import 'dart:async';
import 'dart:io';

/// Returns a user-friendly message for errors shown to the end user.
/// Hides technical details (socket timeouts, connection errors) on mobile/slow networks.
String userFriendlyErrorMessage(Object e, {String? fallback}) {
  final s = e.toString().toLowerCase();
  final fallbackMsg = fallback ?? 'Something went wrong. Please try again.';

  // Network / connection / timeout errors — show a single friendly message
  if (e is TimeoutException) {
    return 'Connection timed out. Please check your internet and try again.';
  }
  if (e is SocketException) {
    return 'Unable to connect. Please check your internet and try again.';
  }
  if (e is HandshakeException) {
    return 'Connection failed. Please check your internet and try again.';
  }
  if (e is OSError && (e.message.toLowerCase().contains('connection') || e.message.toLowerCase().contains('timed out') || e.message.toLowerCase().contains('network'))) {
    return 'Connection problem. Please check your internet and try again.';
  }
  if (s.contains('socket') || s.contains('timeout') || s.contains('timed out') ||
      s.contains('connection refused') || s.contains('failed host lookup') ||
      s.contains('network is unreachable') || s.contains('connection reset') ||
      s.contains('handshake') || s.contains('connection closed')) {
    return 'Connection problem. Please check your internet and try again.';
  }

  // Prefer exception message if it looks like a server/user message (no stack trace, not technical)
  final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : s;
  if (msg.length < 120 && !msg.contains('#')) {
    return msg;
  }
  return fallbackMsg;
}
