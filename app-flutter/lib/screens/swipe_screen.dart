import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/match_provider.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';
import '../main.dart';
import '../utils/config.dart';
import 'location_selection_dialog.dart';
import 'user_profile_details_screen.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

// Global key to access SwipeScreen state from HomeScreen
final GlobalKey<_SwipeScreenState> swipeScreenKey = GlobalKey<_SwipeScreenState>();

class _SwipeScreenState extends State<SwipeScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('SwipeScreen initState - will capture location');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MatchProvider>(context, listen: false).loadPotentialMatches();
      debugPrint('SwipeScreen postFrameCallback - capturing location now');
      _captureAndSaveLocation();
    });
  }

  // Public method to capture location (called from HomeScreen when tab changes)
  void captureLocation() {
    debugPrint('SwipeScreen captureLocation() called from HomeScreen');
    _captureAndSaveLocation();
  }

  Future<void> _captureAndSaveLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Reverse geocode to get address components
      String? city;
      String? state;
      String? countryCode;
      
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          city = place.locality ?? place.subAdministrativeArea;
          state = place.administrativeArea;
          countryCode = place.isoCountryCode;
          
          debugPrint('Reverse geocoding successful:');
          debugPrint('  City: $city');
          debugPrint('  State: $state');
          debugPrint('  Country Code: $countryCode');
          debugPrint('  Full placemark: ${place.toString()}');
        } else {
          debugPrint('No placemarks found for coordinates: ${position.latitude}, ${position.longitude}');
        }
      } catch (e) {
        debugPrint('Error reverse geocoding: $e');
        // Continue without address components if reverse geocoding fails
      }

      // Update location in backend
      final apiService = ApiService();
      final Map<String, dynamic> locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
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
      
      final Map<String, dynamic> updateData = {
        'location': locationData,
        'lastSeenAt': DateTime.now().toIso8601String(), // Update last seen timestamp
      };
      
      debugPrint('Sending location update to backend:');
      debugPrint('  Update data: $updateData');
      
      try {
        final response = await apiService.updateProfile(updateData);
        
        debugPrint('Location update response: $response');
        debugPrint('Location updated successfully: ${position.latitude}, ${position.longitude}');
        debugPrint('lastSeenAt: ${updateData['lastSeenAt']}');
        
        if (city != null || state != null || countryCode != null) {
          debugPrint('Address saved: $city, $state, $countryCode');
        } else {
          debugPrint('WARNING: No address components were captured');
        }
        
        // Verify the response contains the saved data
        if (response['city'] != null || response['state'] != null || response['countryCode'] != null) {
          debugPrint('✓ Location fields confirmed in response:');
          debugPrint('  city: ${response['city']}');
          debugPrint('  state: ${response['state']}');
          debugPrint('  countryCode: ${response['countryCode']}');
          debugPrint('  lastSeenAt: ${response['lastSeenAt']}');
        } else {
          debugPrint('⚠ WARNING: Location fields not found in response');
        }
      } catch (e) {
        debugPrint('ERROR updating location in backend: $e');
        debugPrint('  Update data that failed: $updateData');
        rethrow; // Re-throw to be caught by outer catch
      }
    } catch (e) {
      debugPrint('ERROR capturing location: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      // Silently fail - don't show error to user as this is a background operation
    }
  }

  void _showLocationDialog(BuildContext context, Map<String, dynamic> user) async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.loadLocationsBetweenUsers(user['id'] ?? user['_id']);

    if (!mounted) return;

    final selectedLocation = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => LocationSelectionDialog(
        locations: locationProvider.locations,
        otherUserName: user['name'],
      ),
    );

    if (!mounted) return;
    if (selectedLocation != null) {
      final matchProvider = Provider.of<MatchProvider>(context, listen: false);
      final response = await matchProvider.swipeRight(
        user['id'] ?? user['_id'],
        locationId: selectedLocation['_id'] ?? selectedLocation['id'],
      );

      if (!mounted) return;
      if (response['match'] == true) {
        _showMatchDialog(context, user['name']);
      }
    }
  }

  void _showMatchDialog(BuildContext context, String userName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('It\'s a Match!'),
        content: Text('You and $userName liked each other!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchProvider>(
      builder: (context, matchProvider, _) {
        return RefreshIndicator(
          onRefresh: () async {
            await matchProvider.loadPotentialMatches();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: _buildContent(matchProvider, constraints.maxHeight),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildContent(MatchProvider matchProvider, double availableHeight) {
    if (matchProvider.isLoading && matchProvider.potentialMatches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (matchProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading matches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                matchProvider.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                matchProvider.loadPotentialMatches();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (matchProvider.potentialMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No more potential matches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later or adjust your preferences',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                matchProvider.loadPotentialMatches();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final currentUser = matchProvider.potentialMatches.first;
    final profileImageUrl = currentUser['profileImage'] != null 
        ? AppConfig.buildImageUrl(currentUser['profileImage'])
        : null;
    final gallery = currentUser['gallery'] as Map<String, dynamic>?;
    final publicGallery = gallery?['public'] as List<dynamic>? ?? [];
    final galleryImageUrl = publicGallery.isNotEmpty 
        ? AppConfig.buildImageUrl(publicGallery[0]['url'])
        : null;
    final displayImageUrl = profileImageUrl ?? galleryImageUrl;
    
    // Get location info
    final location = currentUser['location'] as Map<String, dynamic>?;
    String? locationText;
    if (location != null) {
      final parts = <String>[];
      if (location['city'] != null && location['city'].toString().isNotEmpty) {
        parts.add(location['city']);
      }
      if (location['state'] != null && location['state'].toString().isNotEmpty) {
        parts.add(location['state']);
      }
      if (location['countryCode'] != null && location['countryCode'].toString().isNotEmpty) {
        parts.add('(${location['countryCode']})');
      }
      if (parts.isNotEmpty) {
        locationText = parts.join(', ');
      }
    }

    return Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 0, bottom: 16.0),
          child: Center(
            child: SizedBox(
              height: availableHeight - 100, // 3:4 ratio (portrait)
              child: Stack(
                clipBehavior: Clip.none, // Allow buttons to extend outside
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileDetailsScreen(user: currentUser),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Blurred background image (fills entire container)
                            if (displayImageUrl != null)
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: CachedNetworkImage(
                                  imageUrl: displayImageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => _buildPlaceholder(currentUser),
                                  errorWidget: (context, url, error) => _buildPlaceholder(currentUser),
                                ),
                              )
                            else
                              _buildPlaceholder(currentUser),
                            
                            // Profile image (sharp, on top of blurred background)
                            displayImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: displayImageUrl,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => _buildPlaceholder(currentUser),
                                    errorWidget: (context, url, error) => _buildPlaceholder(currentUser),
                                  )
                                : _buildPlaceholder(currentUser),
                    
                            // Gradient overlay at top for text visibility
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.7),
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          
                            // Name, age, location overlay at top
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 20,
                              left: 20,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name with gender icon
                                  Row(
                                    children: [
                                      Text(
                                        currentUser['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black87,
                                            ),
                                            Shadow(
                                              offset: Offset(-1, -1),
                                              blurRadius: 3,
                                              color: Colors.black87,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (currentUser['gender'] != null) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          currentUser['gender'] == 'male'
                                              ? Icons.male
                                              : currentUser['gender'] == 'female'
                                                  ? Icons.female
                                                  : Icons.transgender,
                                          color: Colors.white,
                                          size: 28,
                                          shadows: const [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black87,
                                            ),
                                            Shadow(
                                              offset: Offset(-1, -1),
                                              blurRadius: 3,
                                              color: Colors.black87,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Location
                                  if (locationText != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            locationText!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Gradient overlay at bottom for button visibility
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.7),
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                         ],
                      ),
                    ),
                  ),
                  ),
                  
                  // Buttons at bottom border (50% inside, 50% outside)
                  Positioned(
                    bottom: -32, // Negative value to position at border: button height is 64, so -32 puts half inside and half outside
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cross button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                matchProvider.swipeLeft(currentUser['id'] ?? currentUser['_id']);
                              },
                              borderRadius: BorderRadius.circular(32),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        // Wink button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final matchProvider = Provider.of<MatchProvider>(context, listen: false);
                                try {
                                  final response = await matchProvider.sendHeartRequest(
                                    currentUser['id'] ?? currentUser['_id'],
                                  );
                                  
                                  if (mounted) {
                                    if (response['match'] == true) {
                                      _showMatchDialog(context, currentUser['name'] ?? 'User');
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Heart request sent! They\'ll see your request.'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error sending heart request: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(32),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildPlaceholder(Map<String, dynamic> user) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 100, color: Colors.grey[600]),
            const SizedBox(height: 10),
            Text(
              user['name'] ?? 'No photo',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
