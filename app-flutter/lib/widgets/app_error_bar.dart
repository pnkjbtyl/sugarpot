import 'dart:async';
import 'package:flutter/material.dart';

import 'bar_text_style.dart';

/// Global error bar shown below the top of the screen (like "No Internet").
/// Call [show] to display a message; it auto-vanishes after 2 seconds.
class AppErrorBar extends StatefulWidget {
  const AppErrorBar({super.key});

  static final ValueNotifier<String?> _message = ValueNotifier<String?>(null);

  /// Show a message in the bar. It will vanish after 2 seconds.
  static void show(String message) {
    _message.value = message;
  }

  @override
  State<AppErrorBar> createState() => _AppErrorBarState();
}

class _AppErrorBarState extends State<AppErrorBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AppErrorBar._message.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    AppErrorBar._message.removeListener(_onMessageChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onMessageChanged() {
    final msg = AppErrorBar._message.value;
    _timer?.cancel();
    if (msg != null && msg.isNotEmpty) {
      _timer = Timer(const Duration(seconds: 2), () {
        AppErrorBar._message.value = null;
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final message = AppErrorBar._message.value;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }
    // Attach to bottom edge of top header (status bar + app bar)
    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: ColoredBox(
        color: const Color.fromARGB(255, 255, 102, 117),
        child: SafeArea(
          top: false,
          bottom: false,
          minimum: EdgeInsets.zero,
          child: SizedBox(
            height: 32,
            width: double.infinity,
            child: Center(
              child: Text(
                message,
                style: barMessageTextStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
