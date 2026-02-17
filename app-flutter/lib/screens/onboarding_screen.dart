import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../utils/auth_errors.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';
import 'get_started_screen.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  final int? initialPage;
  
  const OnboardingScreen({super.key, this.initialPage});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pickupLineController = TextEditingController();
  late final PageController _pageController;
  
  DateTime? _dateOfBirth;
  String? _gender;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  late int _currentPage;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    // Set initial page
    _currentPage = widget.initialPage ?? 0;
    // Initialize PageController with initial page
    _pageController = PageController(initialPage: _currentPage);
    
    // Initialize with existing user data if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      if (user != null) {
        setState(() {
          if (user['name'] != null) {
            _nameController.text = user['name'];
          }
          if (user['dateOfBirth'] != null) {
            _dateOfBirth = DateTime.parse(user['dateOfBirth']);
          }
          if (user['gender'] != null) {
            _gender = user['gender'];
          }
          if (user['pickupLine'] != null) {
            _pickupLineController.text = user['pickupLine'];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pickupLineController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        // Compress image to max 800px width with 85% quality
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          image.path,
          '${image.path}_compressed.jpg',
          minWidth: 800,
          minHeight: 800,
          quality: 85,
          keepExif: false,
        );
        
        if (compressedFile != null) {
          setState(() {
            _profileImage = File(compressedFile.path);
          });
        } else {
          // Fallback to original if compression fails
          setState(() {
            _profileImage = File(image.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: 'Select your date of birth (Must be 18+)',
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  // Check if user is at least 18 years old
  bool _isAtLeast18YearsOld() {
    if (_dateOfBirth == null) return false;
    final today = DateTime.now();
    final age = today.year - _dateOfBirth!.year;
    final monthDiff = today.month - _dateOfBirth!.month;
    final dayDiff = today.day - _dateOfBirth!.day;
    
    // Check if birthday has passed this year
    if (monthDiff < 0 || (monthDiff == 0 && dayDiff < 0)) {
      return age - 1 >= 18;
    }
    return age >= 18;
  }

  // Check if current page is valid
  bool _isCurrentPageValid() {
    switch (_currentPage) {
      case 0: // Name and Date of Birth
        return _nameController.text.trim().isNotEmpty && 
               _dateOfBirth != null && 
               _isAtLeast18YearsOld();
      case 1: // Gender
        return _gender != null;
      case 2: // Profile Image
        return _profileImage != null;
      case 3: // Pickup Line
        final pickupLine = _pickupLineController.text.trim();
        return pickupLine.isNotEmpty && 
               pickupLine.length >= 10 &&
               pickupLine.length <= 50;
      default:
        return false;
    }
  }

  // Check if all fields are valid (for final submission)
  bool _isValid() {
    final pickupLine = _pickupLineController.text.trim();
    return _nameController.text.trim().isNotEmpty &&
        _dateOfBirth != null &&
        _isAtLeast18YearsOld() &&
        _gender != null &&
        _profileImage != null &&
        pickupLine.isNotEmpty &&
        pickupLine.length >= 10 &&
        pickupLine.length <= 50;
  }

  Future<void> _completeOnboarding() async {
    if (!_isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check and request location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them in your device settings.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
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
              content: Text('Location permissions are required to complete your profile. Please grant location access.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in your device settings.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Get current location
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

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
      }
    } catch (e) {
      debugPrint('Error reverse geocoding during onboarding: $e');
      // Continue without address components if reverse geocoding fails
    }

    final success = await authProvider.completeOnboarding(
      name: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      gender: _gender!,
      profileImage: _profileImage!,
      pickupLine: _pickupLineController.text.trim(),
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      state: state,
      countryCode: countryCode,
    );

    setState(() {
      _isCompleting = false;
    });

    if (mounted) {
      if (success) {
        // Navigate to People screen (index 1) after completing onboarding. Clear stack so back won't return to login.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 1)),
          (route) => false,
        );
      } else {
        final error = authProvider.error ?? 'Failed to complete onboarding';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // If authentication failed, redirect to login
        // Check error code from auth provider
        final authError = authProvider.error;
        if (AuthErrorCodes.requiresReLogin(authError) || 
            AuthErrorCodes.requiresReLogin(error)) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GetStartedScreen()),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: context.appPrimaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Disable swipe gestures
          onPageChanged: (index) => setState(() => _currentPage = index),
          children: [
            // Page 1: Name and Date of Birth
            _buildNameAndDobPage(),
            // Page 2: Gender
            _buildGenderPage(),
            // Page 3: Profile Image
            _buildProfileImagePage(),
            // Page 4: Pickup Line
            _buildPickupLinePage(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Next button - bigger and centered
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isCurrentPageValid() && !_isCompleting)
                    ? (_currentPage == 3 ? _completeOnboarding : () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      })
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isCurrentPageValid() ? context.appPrimaryColor : Colors.grey,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                ),
                child: (_isCompleting && _currentPage == 3)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _currentPage == 3 ? 'Complete' : 'Next',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Back button and dots row
            Stack(
              alignment: Alignment.center,
              children: [
                // Back button positioned on the left
                Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: _currentPage > 0 ? 1.0 : 0.0,
                    child: TextButton(
                      onPressed: _currentPage > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      child: const Text('Back'),
                    ),
                  ),
                ),
                // Dots centered horizontally
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? context.appPrimaryColor
                            : Colors.grey[300],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameAndDobPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We need some basic information to get started',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date of Birth * (Must be 18+)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
                suffixIcon: _dateOfBirth != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _dateOfBirth = null),
                      )
                    : null,
                errorText: _currentPage == 0
                    ? (_dateOfBirth == null
                        ? 'Date of birth is required'
                        : (!_isAtLeast18YearsOld()
                            ? 'You must be at least 18 years old to use this app'
                            : null))
                    : null,
              ),
              child: Text(
                _dateOfBirth != null
                    ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                    : 'Select your date of birth',
                style: TextStyle(
                  color: _dateOfBirth != null
                      ? Colors.black
                      : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s your gender?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your gender *',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_gender == null && _currentPage == 1)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Text(
                'Gender is required',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildGenderOption('male', 'Male', Icons.male),
          const SizedBox(height: 16),
          _buildGenderOption('female', 'Female', Icons.female),
          const SizedBox(height: 16),
          _buildGenderOption('other', 'Other', Icons.person),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? context.appPrimaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? context.appPrimaryColor.withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? context.appPrimaryColor : Colors.grey),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? context.appPrimaryColor : Colors.black,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: context.appPrimaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImagePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a profile photo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a clear photo of yourself',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _profileImage != null ? context.appPrimaryColor : Colors.grey[300]!,
                        width: 3,
                      ),
                      color: Colors.grey[200],
                    ),
                    child: _profileImage != null
                        ? ClipOval(
                            child: Image.file(
                              _profileImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 60, color: Colors.grey[600]),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add photo',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_profileImage == null && _currentPage == 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Profile image is required',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupLinePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your pickup line',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Write something that can be sent as an opening message to your matches',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _pickupLineController,
            maxLines: 1,
            maxLength: 50,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              labelText: 'Pickup Line *',
              hintText: 'E.g., Coffee enthusiast and adventure seeker...',
              border: OutlineInputBorder(),
              alignLabelWithHint: false,
              contentPadding: EdgeInsets.fromLTRB(12, 20, 12, 12),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Pickup line is required';
              }
              if (value.trim().length < 10) {
                return 'Pickup line must be at least 10 characters';
              }
              if (value.trim().length > 50) {
                return 'Pickup line must be at most 50 characters';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
