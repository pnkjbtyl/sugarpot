import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';
import '../utils/config.dart';
import 'swipe_screen.dart' show SwipeScreen, swipeScreenKey;
import 'matches_screen.dart';
import 'get_started_screen.dart';
import 'edit_profile_screen.dart';
import 'photos_media_screen.dart';
import 'dating_preferences_screen.dart';
import 'account_settings_screen.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  final int? initialIndex;
  
  const HomeScreen({super.key, this.initialIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  bool _permissionsRequested = false;

  String _formatLocation(Map<String, dynamic>? user) {
    if (user == null) return '';
    
    final location = user['location'] as Map<String, dynamic>?;
    if (location == null) return '';
    
    final List<String> parts = [];
    if (location['city'] != null && location['city'].toString().isNotEmpty) {
      parts.add(location['city']);
    }
    if (location['state'] != null && location['state'].toString().isNotEmpty) {
      parts.add(location['state']);
    }
    
    String locationStr = parts.join(', ');
    
    if (location['countryCode'] != null && location['countryCode'].toString().isNotEmpty) {
      if (locationStr.isNotEmpty) {
        locationStr += ' (${location['countryCode']})';
      } else {
        locationStr = '(${location['countryCode']})';
      }
    }
    
    return locationStr;
  }

  @override
  void initState() {
    super.initState();
    // Default to People (middle tab) or use provided initialIndex
    _currentIndex = widget.initialIndex ?? 1;
    // Request permissions when Home Screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Widget _buildProfileScreen() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: 0.0,
                child: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (user?['profileImage'] != null)
                            CircleAvatar(
                            radius: 60,
                            backgroundImage: NetworkImage(
                              AppConfig.getProfileThumbnailUrl(user!['profileImage']),
                            ),
                          )
                        else
                          const CircleAvatar(
                            radius: 60,
                            child: Icon(Icons.person, size: 60),
                          ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.appPrimaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              onPressed: () => _replaceProfileImage(context, authProvider),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              iconSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?['name'] ?? 'No name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user?['email'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          user!['email'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    if (user?['location'] != null && 
                        (user!['location']?['city'] != null || 
                         user['location']?['state'] != null || 
                         user['location']?['countryCode'] != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatLocation(user),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.edit, color: context.appPrimaryColor),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.favorite, color: context.appPrimaryColor),
                      title: const Text('Dating Preferences'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DatingPreferencesScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.photo_library, color: context.appPrimaryColor),
                      title: const Text('Photos & Media'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PhotosMediaScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.settings, color: context.appPrimaryColor),
                      title: const Text('Account Settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AccountSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.logout, color: context.appPrimaryColor),
                      title: const Text('Logout'),
                      onTap: () async {
                        await authProvider.logout();
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const GetStartedScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _replaceProfileImage(BuildContext context, AuthProvider authProvider) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Compress image to max 800px width with 85% quality
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          image.path,
          '${image.path}_compressed.jpg',
          minWidth: 800,
          minHeight: 800,
          quality: 85,
          keepExif: false,
        );

        File? fileToUpload;
        if (compressedFile != null) {
          fileToUpload = File(compressedFile.path);
        } else {
          // Fallback to original if compression fails
          fileToUpload = File(image.path);
        }

        // Upload the image
        final apiService = ApiService();
        final uploadResponse = await apiService.uploadProfileImage(fileToUpload);

        if (uploadResponse['imageUrl'] != null) {
          // Update profile with new image URL
          final updates = {
            'profileImage': uploadResponse['imageUrl'],
          };

          await authProvider.updateProfile(updates);

          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile image updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update profile image'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error uploading profile image: $e');
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    // Request notification permissions
    try {
      final notificationGranted = await FirebaseService.requestPermission();
      if (notificationGranted) {
        // Get and update FCM token
        final token = await FirebaseService.getToken();
        if (token != null) {
          // Update Firebase token to backend
          try {
            final apiService = ApiService();
            await apiService.updateFirebaseToken(token);
            debugPrint('Firebase token updated successfully');
          } catch (e) {
            debugPrint('Error updating Firebase token: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // Request location permissions
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable them in your device settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are required for the app to work properly. Please grant location access.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in your device settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prevent back from Profile/Explore/Matches from returning to login when user has valid token
    return PopScope(
      canPop: false,
      child: Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/SugarPot-logo-light.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        backgroundColor: context.appPrimaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildProfileScreen(),
          SwipeScreen(key: swipeScreenKey),
          const MatchesScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Capture location when user switches to People tab (index 1)
          if (index == 1) {
            debugPrint('People tab selected - attempting to capture location');
            if (swipeScreenKey.currentState != null) {
              swipeScreenKey.currentState!.captureLocation();
            } else {
              debugPrint('WARNING: SwipeScreen state is null, cannot capture location');
            }
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: context.appSecondaryColor,
        selectedItemColor: context.appPrimaryColor,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.thumbs_up_down),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            label: 'Matches',
          ),
        ],
      ),
    ),
    );
  }
}
