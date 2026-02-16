import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class ApiService {
  // Get base URL from environment variable
  static String get baseUrl {
    return '${AppConfig.apiBaseUrl}/api';
  }
  
  // Get auth token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  // Expose getToken for AuthProvider
  Future<String?> getToken() => _getToken();

  // Save auth token to shared preferences
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear auth token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Make authenticated request
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Send OTP to email
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  // Verify OTP only (without logging in, for email change)
  Future<Map<String, dynamic>> verifyOtpOnly(String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/verify-otp-only'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
      }),
    );
    return jsonDecode(response.body);
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      await _saveToken(data['token']);
    }
    return data;
  }

  // Refresh token
  Future<Map<String, dynamic>> refreshToken() async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/refresh-token'),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token is invalid or expired - clear it
      await clearToken();
      // Preserve error code if available
      final error = Exception(data['message'] ?? 'Token expired. Please log in again.');
      if (data['code'] != null) {
        (error as dynamic).code = data['code'];
      }
      throw error;
    }
    if (response.statusCode == 200 && data['token'] != null) {
      await _saveToken(data['token']);
    } else if (response.statusCode != 200) {
      final error = Exception(data['message'] ?? 'Failed to refresh token');
      if (data['code'] != null) {
        (error as dynamic).code = data['code'];
      }
      throw error;
    }
    return data;
  }

  // Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token expired or invalid - clear it
      await clearToken();
      // Preserve error code if available
      final error = Exception(data['message'] ?? 'Authentication failed. Please log in again.');
      if (data['code'] != null) {
        (error as dynamic).code = data['code'];
      }
      throw error;
    }
    if (response.statusCode != 200) {
      final error = Exception(data['message'] ?? 'Failed to load profile');
      if (data['code'] != null) {
        (error as dynamic).code = data['code'];
      }
      throw error;
    }
    return data;
  }

  // Upload profile image
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/upload-image'),
    );
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Determine content type from file extension
    String contentTypeString = 'image/jpeg'; // default
    final extension = imageFile.path.toLowerCase();
    if (extension.endsWith('.png')) {
      contentTypeString = 'image/png';
    } else if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
      contentTypeString = 'image/jpeg';
    } else if (extension.endsWith('.webp')) {
      contentTypeString = 'image/webp';
    } else if (extension.endsWith('.heic') || extension.endsWith('.heif')) {
      contentTypeString = 'image/heic';
    }
    
    // Reject GIFs explicitly
    if (extension.endsWith('.gif')) {
      throw Exception('GIF images are not allowed. Please use JPEG or PNG.');
    }
    
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType.parse(contentTypeString),
      ),
    );
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: await _getHeaders(),
      body: jsonEncode(updates),
    );
    
    final data = jsonDecode(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token expired or invalid - clear it
      await clearToken();
      // Preserve error code if available
      final error = Exception(data['message'] ?? 'Authentication failed. Please log in again.');
      if (data['code'] != null) {
        (error as dynamic).code = data['code'];
      }
      throw error;
    }
    if (response.statusCode != 200) {
      final error = Exception(data['message'] ?? 'Failed to update profile');
      if (data['code'] != null) {
        (error as dynamic).code = data['code'];
      }
      throw error;
    }
    
    return data;
  }

  // Update Firebase token
  Future<Map<String, dynamic>> updateFirebaseToken(String token) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/firebase-token'),
      headers: await _getHeaders(),
      body: jsonEncode({'firebaseToken': token}),
    );
    return jsonDecode(response.body);
  }

  // Get potential matches
  Future<List<dynamic>> getPotentialMatches() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/potential-matches'),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to load potential matches');
    }
    
    return jsonDecode(response.body);
  }

  // Get locations between two users
  Future<List<dynamic>> getLocationsBetweenUsers(String otherUserId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/locations/nearby-between-users'),
      headers: await _getHeaders(),
      body: jsonEncode({'otherUserId': otherUserId}),
    );
    return jsonDecode(response.body);
  }

  // Swipe right
  Future<Map<String, dynamic>> swipeRight(String targetUserId, {String? locationId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/matches/swipe'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'targetUserId': targetUserId,
        if (locationId != null) 'locationId': locationId,
      }),
    );
    return jsonDecode(response.body);
  }

  // Swipe left
  Future<Map<String, dynamic>> swipeLeft(String targetUserId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/matches/pass'),
      headers: await _getHeaders(),
      body: jsonEncode({'targetUserId': targetUserId}),
    );
    return jsonDecode(response.body);
  }

  // Get my matches
  Future<List<dynamic>> getMyMatches() async {
    final response = await http.get(
      Uri.parse('$baseUrl/matches/my-matches'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  // Send heart request to a user
  Future<Map<String, dynamic>> sendHeartRequest(String targetUserId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/matches/heart-request'),
      headers: await _getHeaders(),
      body: jsonEncode({'targetUserId': targetUserId}),
    );
    return jsonDecode(response.body);
  }

  // Get received heart requests (paginated)
  Future<Map<String, dynamic>> getReceivedHearts({int page = 1, int limit = 10}) async {
    final url = '$baseUrl/matches/received-hearts?page=$page&limit=$limit';
    debugPrint('[API_SERVICE] Fetching received hearts from: $url');
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    
    debugPrint('[API_SERVICE] Response status: ${response.statusCode}');
    debugPrint('[API_SERVICE] Response body: ${response.body}');
    
    if (response.statusCode != 200) {
      throw Exception('Failed to load received hearts: ${response.statusCode} - ${response.body}');
    }
    
    return jsonDecode(response.body);
  }

  // Decline a heart request
  Future<Map<String, dynamic>> declineHeart(String matchId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/matches/decline-heart/$matchId'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  // Update match location
  Future<Map<String, dynamic>> updateMatchLocation(String matchId, String locationId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/matches/$matchId/location'),
      headers: await _getHeaders(),
      body: jsonEncode({'locationId': locationId}),
    );
    return jsonDecode(response.body);
  }

  // Change email
  Future<Map<String, dynamic>> changeEmail({
    required String currentEmailOtp,
    required String newEmail,
    required String newEmailOtp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/change-email'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'currentEmailOtp': currentEmailOtp,
        'newEmail': newEmail,
        'newEmailOtp': newEmailOtp,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to change email');
    }
    return data;
  }

  // Toggle profile visibility
  Future<Map<String, dynamic>> toggleProfileVisibility() async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/toggle-profile-visibility'),
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to toggle profile visibility');
    }
    return data;
  }

  // Delete profile
  Future<Map<String, dynamic>> deleteProfile() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/delete-profile'),
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to delete profile');
    }
    return data;
  }

  // Upload gallery media (image or video)
  Future<Map<String, dynamic>> uploadGalleryMedia(File mediaFile, String galleryType, {File? thumbnailFile}) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/upload-gallery-media'),
    );
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Determine content type from file extension
    String contentTypeString = 'image/jpeg'; // default
    final extension = mediaFile.path.toLowerCase();
    if (extension.endsWith('.png')) {
      contentTypeString = 'image/png';
    } else if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
      contentTypeString = 'image/jpeg';
    } else if (extension.endsWith('.webp')) {
      contentTypeString = 'image/webp';
    } else if (extension.endsWith('.heic') || extension.endsWith('.heif')) {
      contentTypeString = 'image/heic';
    } else if (extension.endsWith('.mp4')) {
      contentTypeString = 'video/mp4';
    } else if (extension.endsWith('.mov')) {
      contentTypeString = 'video/quicktime';
    }
    
    request.fields['galleryType'] = galleryType;
    request.files.add(
      await http.MultipartFile.fromPath(
        'media',
        mediaFile.path,
        contentType: MediaType.parse(contentTypeString),
      ),
    );
    
    // Add thumbnail if provided (for videos)
    if (thumbnailFile != null) {
      try {
        final thumbnailSize = await thumbnailFile.length();
        debugPrint('Uploading thumbnail: ${thumbnailFile.path}, size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB');
        request.files.add(
          await http.MultipartFile.fromPath(
            'thumbnail',
            thumbnailFile.path,
            contentType: MediaType.parse('image/jpeg'),
          ),
        );
        debugPrint('Thumbnail added to multipart request');
      } catch (e) {
        debugPrint('Error adding thumbnail to request: $e');
      }
    } else {
      debugPrint('No thumbnail file provided for upload');
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);
    
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to upload media');
    }
    
    return data;
  }

  // Get user gallery
  Future<Map<String, dynamic>> getGallery() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/gallery'),
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to get gallery');
    }
    return data;
  }

  // Unmatch a user
  Future<Map<String, dynamic>> unmatchUser(String matchId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/matches/$matchId/unmatch'),
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to unmatch user');
    }
    return data;
  }

  // Report a user
  Future<Map<String, dynamic>> reportUser(String reportedUserId, String reason, {String? description}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reports'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'reportedUserId': reportedUserId,
        'reason': reason,
        'description': description ?? '',
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to report user');
    }
    return data;
  }

  // Delete gallery media
  Future<Map<String, dynamic>> deleteGalleryMedia(String galleryType, int index) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/gallery-media/$galleryType/$index'),
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to delete media');
    }
    return data;
  }

  // Upload chat media (image, video, or audio)
  Future<Map<String, dynamic>> uploadChatMedia(File mediaFile) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/chat-media/upload'),
    );
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Determine content type based on file extension
    final extension = mediaFile.path.toLowerCase();
    String contentTypeString = 'application/octet-stream';
    
    if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
      contentTypeString = 'image/jpeg';
    } else if (extension.endsWith('.png')) {
      contentTypeString = 'image/png';
    } else if (extension.endsWith('.gif')) {
      contentTypeString = 'image/gif';
    } else if (extension.endsWith('.webp')) {
      contentTypeString = 'image/webp';
    } else if (extension.endsWith('.mp4')) {
      contentTypeString = 'video/mp4';
    } else if (extension.endsWith('.mov')) {
      contentTypeString = 'video/quicktime';
    } else if (extension.endsWith('.avi')) {
      contentTypeString = 'video/x-msvideo';
    } else if (extension.endsWith('.mp3')) {
      contentTypeString = 'audio/mpeg';
    } else if (extension.endsWith('.wav')) {
      contentTypeString = 'audio/wav';
    } else if (extension.endsWith('.aac')) {
      contentTypeString = 'audio/aac';
    } else if (extension.endsWith('.ogg')) {
      contentTypeString = 'audio/ogg';
    }
    
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        mediaFile.path,
        contentType: MediaType.parse(contentTypeString),
      ),
    );
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);
    
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to upload file');
    }
    
    return data;
  }
}
