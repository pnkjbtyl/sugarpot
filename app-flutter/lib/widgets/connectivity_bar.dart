import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'bar_text_style.dart';

/// Red bar with white text shown below the app bar when there's no connectivity.
/// With [onlyWhenOffline] true, shows only when offline (no slow-network check).
class ConnectivityBar extends StatefulWidget {
  const ConnectivityBar({super.key, this.onlyWhenOffline = false});

  final bool onlyWhenOffline;

  @override
  State<ConnectivityBar> createState() => _ConnectivityBarState();
}

class _ConnectivityBarState extends State<ConnectivityBar> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool? _hasConnectivity;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((_) => _checkConnectivity());
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    final connected = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _hasConnectivity = connected);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _showBar => _hasConnectivity == false;

  @override
  Widget build(BuildContext context) {
    if (!_showBar) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: const Color.fromARGB(255, 255, 102, 117),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 32,
          width: double.infinity,
          child: Center(
            child: Text(
              'No Internet',
              style: barMessageTextStyle,
            ),
          ),
        ),
      ),
    );
  }
}
