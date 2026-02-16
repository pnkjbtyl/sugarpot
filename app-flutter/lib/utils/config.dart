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
  
  // Convert profile image URL to thumbnail URL
  // Profile images: /uploads/user-images/userId_timestamp.jpg
  // Thumbnails: /uploads/user-images/thumbnails/userId_timestamp_thumb.jpg
  static String getProfileThumbnailUrl(String profileImageUrl) {
    if (profileImageUrl.isEmpty) {
      return '';
    }
    
    // If already a full URL, extract the path
    String imagePath = profileImageUrl;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // Extract path after domain
      final uri = Uri.parse(imagePath);
      imagePath = uri.path;
    }
    
    // Check if it's a profile image path (not already a thumbnail)
    if (imagePath.contains('/uploads/user-images/') && 
        !imagePath.contains('/thumbnails/') &&
        imagePath.endsWith('.jpg')) {
      // Convert to thumbnail path
      // Pattern: /uploads/user-images/userId_timestamp.jpg
      // Result: /uploads/user-images/thumbnails/userId_timestamp_thumb.jpg
      final filename = imagePath.split('/').last;
      final thumbnailFilename = filename.replaceAll(RegExp(r'\.jpg$'), '_thumb.jpg');
      final thumbnailPath = imagePath.replaceAll('/uploads/user-images/', '/uploads/user-images/thumbnails/')
                                     .replaceAll(filename, thumbnailFilename);
      return buildImageUrl(thumbnailPath);
    }
    
    // If not a profile image or already a thumbnail, return original
    return buildImageUrl(profileImageUrl);
  }
}
