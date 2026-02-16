import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class LocationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _locations = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadLocationsBetweenUsers(String otherUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _locations = await _apiService.getLocationsBetweenUsers(otherUserId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearLocations() {
    _locations = [];
    notifyListeners();
  }
}
