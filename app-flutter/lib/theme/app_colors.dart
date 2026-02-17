import 'package:flutter/material.dart';
import '../main.dart';

/// Gender-based color scheme for the app.
/// Default (no user / no gender): purple shades from main.dart.
/// Male: navy blue shades.
/// Female: pink shades.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  /// Default scheme (not logged in or no gender) - purple from main.dart
  static const AppColors defaultScheme = AppColors(
    primary: Color(0xFFab76e3),
    secondary: Color.fromARGB(255, 238, 222, 255),
    tertiary: Color.fromARGB(255, 245, 236, 255),
  );

  /// Male - navy blue shades
  static const AppColors maleScheme = AppColors(
    primary: Color.fromARGB(255, 71, 138, 224),
    secondary: Color.fromARGB(255, 204, 227, 255),
    tertiary: Color(0xFFebf4ff),
  );

  /// Female - pink shades
  static const AppColors femaleScheme = AppColors(
    primary: Color.fromARGB(255, 223, 82, 145),
    secondary: Color.fromARGB(255, 255, 203, 230),
    tertiary: Color.fromARGB(255, 255, 232, 245),
  );

  /// Build scheme from user's gender. [gender] can be null, 'male', 'female', etc.
  static AppColors fromGender(dynamic gender) {
    if (gender == null) return defaultScheme;
    final g = gender.toString().toLowerCase();
    if (g == 'male' || g == 'm') return maleScheme;
    if (g == 'female' || g == 'f') return femaleScheme;
    return defaultScheme;
  }

  @override
  AppColors copyWith({
    Color? primary,
    Color? secondary,
    Color? tertiary,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
    );
  }
}

/// Convenience getters for current theme colors (with fallback to main.dart constants).
extension AppColorsContext on BuildContext {
  Color get appPrimaryColor =>
      Theme.of(this).extension<AppColors>()?.primary ?? primaryColor;
  Color get appSecondaryColor =>
      Theme.of(this).extension<AppColors>()?.secondary ?? secondaryColor;
  Color get appTertiaryColor =>
      Theme.of(this).extension<AppColors>()?.tertiary ?? tertiaryColor;
}
