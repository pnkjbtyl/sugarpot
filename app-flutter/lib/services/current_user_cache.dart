import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/config.dart';

/// Caches current user's profile data and profile image locally.
/// Refreshed whenever user logs in, loads profile, or updates profile.
class CurrentUserCache {
  static const String _keyUserId = 'current_user_id';
  static const String _keyName = 'current_user_name';
  static const String _keyEmail = 'current_user_email';
  static const String _keyGender = 'current_user_gender';
  static const String _keyProfileImageUrl = 'current_user_profile_image_url';
  static const String _profileImageFileName = 'profile.jpg';

  static String? _cachedProfileImagePath;

  /// Save user to local cache and download profile image to local file.
  /// Call after login, loadUser, updateProfile, or completeOnboarding.
  static Future<void> saveUser(
    Map<String, dynamic> user, {
    String? authToken,
  }) async {
    if (user.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final id = user['id']?.toString() ?? user['_id']?.toString();
    final name = user['name']?.toString();
    final email = user['email']?.toString();
    final gender = user['gender']?.toString();
    final profileImageUrl = user['profileImage']?.toString().trim();

    if (id != null) await prefs.setString(_keyUserId, id);
    if (name != null) await prefs.setString(_keyName, name);
    if (email != null) await prefs.setString(_keyEmail, email);
    if (gender != null) await prefs.setString(_keyGender, gender);
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      await prefs.setString(_keyProfileImageUrl, profileImageUrl);
      await _downloadAndSaveProfileImage(profileImageUrl, authToken: authToken);
    } else {
      await prefs.remove(_keyProfileImageUrl);
      await _deleteProfileImageFile();
      _cachedProfileImagePath = null;
    }
  }

  /// Returns cached user map with id, _id, name, email, gender, profileImage (or null if not cached).
  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyUserId);
    if (id == null) return null;

    return {
      'id': id,
      '_id': id,
      'name': prefs.getString(_keyName),
      'email': prefs.getString(_keyEmail),
      'gender': prefs.getString(_keyGender),
      'profileImage': prefs.getString(_keyProfileImageUrl),
    };
  }

  /// Returns the local file path for the cached profile image, or null if not cached.
  /// Use with Image.file(File(path)) to show from cache.
  static Future<String?> getCachedProfileImagePath() async {
    if (_cachedProfileImagePath != null) {
      if (await File(_cachedProfileImagePath!).exists()) return _cachedProfileImagePath;
      _cachedProfileImagePath = null;
    }
    final dir = await _getCacheDirectory();
    if (dir == null) return null;
    final file = File('${dir.path}/$_profileImageFileName');
    if (await file.exists()) {
      _cachedProfileImagePath = file.path;
      return file.path;
    }
    return null;
  }

  /// Clear all cached user data and delete the local profile image file.
  /// Call on logout.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyProfileImageUrl);
    await _deleteProfileImageFile();
    _cachedProfileImagePath = null;
  }

  static Future<Directory?> _getCacheDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/current_user');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (e) {
      debugPrint('CurrentUserCache: failed to get cache dir: $e');
      return null;
    }
  }

  static Future<void> _downloadAndSaveProfileImage(
    String profileImagePath, {
    String? authToken,
  }) async {
    final dir = await _getCacheDirectory();
    if (dir == null) return;

    final url = AppConfig.buildImageUrl(profileImagePath);
    if (url.isEmpty) return;

    try {
      final headers = <String, String>{};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      final response = await http.get(Uri.parse(url), headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Profile image download timeout'),
      );
      if (response.statusCode != 200) return;

      final file = File('${dir.path}/$_profileImageFileName');
      await file.writeAsBytes(response.bodyBytes);
      _cachedProfileImagePath = file.path;
    } catch (e) {
      debugPrint('CurrentUserCache: failed to download profile image: $e');
    }
  }

  static Future<void> _deleteProfileImageFile() async {
    final dir = await _getCacheDirectory();
    if (dir == null) return;
    final file = File('${dir.path}/$_profileImageFileName');
    if (await file.exists()) await file.delete();
    _cachedProfileImagePath = null;
  }
}
