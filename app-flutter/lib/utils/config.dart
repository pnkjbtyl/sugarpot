import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Get API base URL from environment variable
  // Throws an error if not set (no fallback to hardcoded values)
  static String get apiBaseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'API_BASE_URL is not set in .env file. Please configure it before running the app.'
      );
    }
    return url;
  }
  
  // Helper to build full image URL
  static String buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    // If already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return '$apiBaseUrl$imagePath';
  }
}
