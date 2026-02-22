import 'package:flutter/material.dart';

/// Global navigator key so we can push routes from notification handlers (outside BuildContext).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
