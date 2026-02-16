import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class MatchProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _potentialMatches = [];
  List<dynamic> _myMatches = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> _receivedHearts = [];
  int _receivedHeartsPage = 1;
  bool _hasMoreReceivedHearts = true;
  bool _isLoadingMoreReceivedHearts = false;

  List<dynamic> get potentialMatches => _potentialMatches;
  List<dynamic> get myMatches => _myMatches;
  List<dynamic> get receivedHearts => _receivedHearts;
  bool get isLoading => _isLoading;
  bool get isLoadingMoreReceivedHearts => _isLoadingMoreReceivedHearts;
  bool get hasMoreReceivedHearts => _hasMoreReceivedHearts;
  String? get error => _error;

  Future<void> loadPotentialMatches() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _potentialMatches = await _apiService.getPotentialMatches();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> swipeRight(String targetUserId, {String? locationId}) async {
    try {
      final response = await _apiService.swipeRight(targetUserId, locationId: locationId);
      if (response['match'] == true) {
        await loadMyMatches();
      }
      return response;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> swipeLeft(String targetUserId) async {
    try {
      await _apiService.swipeLeft(targetUserId);
      // Remove from potential matches
      _potentialMatches.removeWhere((user) => user['id'] == targetUserId || user['_id'] == targetUserId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadMyMatches() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _myMatches = await _apiService.getMyMatches();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMatchLocation(String matchId, String locationId) async {
    try {
      await _apiService.updateMatchLocation(matchId, locationId);
      await loadMyMatches();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendHeartRequest(String targetUserId) async {
    try {
      final response = await _apiService.sendHeartRequest(targetUserId);
      if (response['match'] == true) {
        await loadMyMatches();
        // Remove from received hearts if it was there (user accepted a heart request)
        _receivedHearts.removeWhere((request) {
          final user = request['user'];
          return (user['id'] ?? user['_id']) == targetUserId;
        });
      }
      // Remove from potential matches
      _potentialMatches.removeWhere((user) => user['id'] == targetUserId || user['_id'] == targetUserId);
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadReceivedHearts({bool reset = false}) async {
    if (reset) {
      _receivedHeartsPage = 1;
      _hasMoreReceivedHearts = true;
      _receivedHearts = [];
    }

    if (!_hasMoreReceivedHearts && !reset) {
      return; // No more data to load
    }

    _isLoading = reset;
    _isLoadingMoreReceivedHearts = !reset;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getReceivedHearts(
        page: _receivedHeartsPage,
        limit: 10,
      );
      
      debugPrint('[MATCH_PROVIDER] Received hearts response: $response');
      
      final requests = response['requests'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      
      debugPrint('[MATCH_PROVIDER] Requests count: ${requests.length}');
      debugPrint('[MATCH_PROVIDER] Pagination: $pagination');
      
      if (reset) {
        _receivedHearts = requests;
      } else {
        _receivedHearts.addAll(requests);
      }
      
      _hasMoreReceivedHearts = pagination['hasMore'] as bool? ?? false;
      _receivedHeartsPage++;
      
      debugPrint('[MATCH_PROVIDER] Total received hearts: ${_receivedHearts.length}');
      debugPrint('[MATCH_PROVIDER] Has more: $_hasMoreReceivedHearts');
    } catch (e, stackTrace) {
      debugPrint('[MATCH_PROVIDER] Error loading received hearts: $e');
      debugPrint('[MATCH_PROVIDER] Stack trace: $stackTrace');
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMoreReceivedHearts = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreReceivedHearts() async {
    if (_isLoadingMoreReceivedHearts || !_hasMoreReceivedHearts) {
      return;
    }
    await loadReceivedHearts();
  }

  Future<void> declineHeart(String matchId) async {
    try {
      await _apiService.declineHeart(matchId);
      // Remove from local list
      _receivedHearts.removeWhere((request) => request['matchId'] == matchId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
