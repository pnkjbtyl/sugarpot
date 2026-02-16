import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../utils/auth_errors.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  // Expose apiService for screens that need direct access
  ApiService get apiService => _apiService;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isOnboardingComplete => _user?['isOnboardingComplete'] == true;

  // Check which onboarding page should be shown based on missing fields
  // Returns -1 if all fields are complete, otherwise returns the page index (0-3)
  int getMissingOnboardingPage() {
    if (_user == null) return 0;
    
    // Page 0: Name and Date of Birth
    if (_user!['name'] == null || _user!['name'].toString().trim().isEmpty ||
        _user!['dateOfBirth'] == null) {
      return 0;
    }
    
    // Page 1: Gender
    if (_user!['gender'] == null) {
      return 1;
    }
    
    // Page 2: Profile Image
    if (_user!['profileImage'] == null || _user!['profileImage'].toString().trim().isEmpty) {
      return 2;
    }
    
    // Page 3: Pickup Line
    if (_user!['pickupLine'] == null || _user!['pickupLine'].toString().trim().isEmpty) {
      return 3;
    }
    
    // All fields are complete
    return -1;
  }

  // Send OTP to email
  Future<bool> sendOtp(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.sendOtp(email);
      _isLoading = false;
      notifyListeners();
      return response['message'] != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Verify OTP
  Future<bool> verifyOtp(String email, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.verifyOtp(email, code);

      if (response['user'] != null) {
        _user = response['user'];
        
        // Request notification permission and update Firebase token
        await _updateFirebaseToken();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'OTP verification failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Complete onboarding
  Future<bool> completeOnboarding({
    required String name,
    required DateTime dateOfBirth,
    required String gender,
    required File profileImage,
    required String pickupLine,
    required double latitude,
    required double longitude,
    String? city,
    String? state,
    String? countryCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload profile image first
      String? imageUrl;
      try {
        final uploadResponse = await _apiService.uploadProfileImage(profileImage);
        if (uploadResponse['imageUrl'] != null) {
          imageUrl = uploadResponse['imageUrl'];
        }
      } catch (e) {
        debugPrint('Error uploading image: $e');
        // Continue without image URL for now
      }

      // Update profile
      final Map<String, dynamic> locationData = {
        'latitude': latitude,
        'longitude': longitude,
      };
      
      // Add address components inside location if available
      if (city != null && city.isNotEmpty) {
        locationData['city'] = city;
      }
      if (state != null && state.isNotEmpty) {
        locationData['state'] = state;
      }
      if (countryCode != null && countryCode.isNotEmpty) {
        locationData['countryCode'] = countryCode.toUpperCase();
      }
      
      final Map<String, dynamic> updates = {
        'name': name,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender,
        'pickupLine': pickupLine,
        'location': locationData,
      };

      if (imageUrl != null) {
        updates['profileImage'] = imageUrl;
      }
      
      debugPrint('Onboarding update data: $updates');

      // Check if token exists before making request
      final token = await _apiService.getToken();
      if (token == null) {
        _error = 'You are not logged in. Please log in again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await _apiService.updateProfile(updates);

      if (response['_id'] != null) {
        _user = response;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Check if user not found - need to re-authenticate
        if (AuthErrorCodes.requiresReLogin(response)) {
          _error = 'Your session has expired. Please log in again.';
          // Clear token and user data
          await _apiService.clearToken();
          _user = null;
        } else {
          _error = response['message'] ?? 'Failed to complete onboarding';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      // If authentication failed, clear token and user
      if (AuthErrorCodes.requiresReLogin(e)) {
        await _apiService.clearToken();
        _user = null;
        _error = 'Your session has expired. Please log in again.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _apiService.getToken();
      if (token == null) {
        _user = null;
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final user = await _apiService.getProfile();
      _user = user;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _user = null;
      // If authentication failed, clear token
      if (AuthErrorCodes.requiresReLogin(e)) {
        await _apiService.clearToken();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateProfile(updates);

      if (response['_id'] != null) {
        _user = response;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Check if user not found - need to re-authenticate
        if (AuthErrorCodes.requiresReLogin(response)) {
          _error = 'Your session has expired. Please log in again.';
          await _apiService.clearToken();
          _user = null;
        } else {
          _error = response['message'] ?? 'Failed to update profile';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Refresh token if needed (called periodically)
  Future<void> refreshTokenIfNeeded() async {
    try {
      final token = await _apiService.getToken();
      if (token != null) {
        await _apiService.refreshToken();
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    _user = null;
    _error = null;
    notifyListeners();
  }

  // Update Firebase token to backend
  Future<void> _updateFirebaseToken() async {
    try {
      // Request notification permission
      await FirebaseService.requestPermission();
      
      // Get FCM token
      String? token = await FirebaseService.getToken();
      
      if (token != null) {
        // Update token in backend
        await _apiService.updateFirebaseToken(token);
      }
    } catch (e) {
      debugPrint('Error updating Firebase token: $e');
    }
  }
}
