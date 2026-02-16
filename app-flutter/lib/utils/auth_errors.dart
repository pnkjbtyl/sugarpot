/// Authentication error codes returned by the backend
class AuthErrorCodes {
  static const String tokenRequired = 'TOKEN_REQUIRED';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String tokenInvalid = 'TOKEN_INVALID';
  static const String userNotFound = 'USER_NOT_FOUND';
  
  /// Check if an error is an authentication error that requires re-login
  static bool requiresReLogin(dynamic error) {
    if (error is Exception) {
      final code = (error as dynamic).code as String?;
      if (code != null) {
        return code == tokenRequired ||
               code == tokenExpired ||
               code == tokenInvalid ||
               code == userNotFound;
      }
    }
    
    // Fallback: check if error response has a code
    if (error is Map<String, dynamic>) {
      final code = error['code'] as String?;
      if (code != null) {
        return code == tokenRequired ||
               code == tokenExpired ||
               code == tokenInvalid ||
               code == userNotFound;
      }
    }
    
    return false;
  }
  
  /// Get error code from exception or response
  static String? getErrorCode(dynamic error) {
    if (error is Exception) {
      return (error as dynamic).code as String?;
    }
    if (error is Map<String, dynamic>) {
      return error['code'] as String?;
    }
    return null;
  }
}
