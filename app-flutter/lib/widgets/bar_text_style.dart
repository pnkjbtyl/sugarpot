import 'package:flutter/material.dart';

/// Shared text style for connectivity bar and app error bar so they match.
/// Uses inherit: false and explicit font so theme/app font does not override.
const TextStyle barMessageTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
  inherit: false,
  fontFamily: 'Roboto',
);
