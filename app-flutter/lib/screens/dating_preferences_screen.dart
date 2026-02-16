import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';

class DatingPreferencesScreen extends StatefulWidget {
  const DatingPreferencesScreen({super.key});

  @override
  State<DatingPreferencesScreen> createState() => _DatingPreferencesScreenState();
}

class _DatingPreferencesScreenState extends State<DatingPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _minAgeController;
  late TextEditingController _maxAgeController;
  late TextEditingController _maxDistanceController;
  late TextEditingController _pickupLineController;
  final Set<String> _interestedIn = <String>{};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final preferences = user?['preferences'] as Map<String, dynamic>?;
    
    _minAgeController = TextEditingController(
      text: preferences?['minAge']?.toString() ?? '18',
    );
    _maxAgeController = TextEditingController(
      text: preferences?['maxAge']?.toString() ?? '100',
    );
    _maxDistanceController = TextEditingController(
      text: preferences?['maxDistance']?.toString() ?? '50',
    );
    _pickupLineController = TextEditingController(
      text: user?['pickupLine'] ?? '',
    );
    
    // Load interestedIn preferences
    if (preferences?['interestedIn'] != null) {
      final interestedInList = preferences!['interestedIn'] as List<dynamic>?;
      if (interestedInList != null) {
        _interestedIn.addAll(interestedInList.map((e) => e.toString()));
      }
    }
    
    // If no preferences set, default to all genders
    if (_interestedIn.isEmpty) {
      _interestedIn.addAll(['male', 'female', 'other']);
    }
  }

  @override
  void dispose() {
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _maxDistanceController.dispose();
    _pickupLineController.dispose();
    super.dispose();
  }

  Future<void> _savePreferences() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final minAge = int.parse(_minAgeController.text.trim());
      final maxAge = int.parse(_maxAgeController.text.trim());
      final maxDistance = int.parse(_maxDistanceController.text.trim());

      // Validate age range
      if (minAge < 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimum age must be at least 18'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (maxAge < minAge) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum age must be greater than or equal to minimum age'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (maxDistance < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum distance must be at least 1 km'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Validate at least one gender is selected
      if (_interestedIn.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one gender preference'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Validate pickup line
      final pickupLine = _pickupLineController.text.trim();
      if (pickupLine.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup line is required'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      if (pickupLine.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup line must be at least 10 characters'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      if (pickupLine.length > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup line must be at most 50 characters'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final updates = {
        'preferences': {
          'minAge': minAge,
          'maxAge': maxAge,
          'maxDistance': maxDistance,
          'interestedIn': _interestedIn.toList(),
        },
        'pickupLine': pickupLine,
      };

      final response = await authProvider.updateProfile(updates);

      if (mounted) {
        if (response) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferences updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Failed to update preferences'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dating Preferences'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Age Range',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set the age range for potential matches',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minAgeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Age *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                        errorMaxLines: 3,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Minimum age is required';
                        }
                        final age = int.tryParse(value.trim());
                        if (age == null) {
                          return 'Please enter a valid number';
                        }
                        if (age < 18) {
                          return 'Minimum age must be atleast 18 years';
                        }
                        if (age > 99) {
                          return 'Minimum age must be less than or equal to 99 years';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxAgeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Age *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        errorMaxLines: 3,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Maximum age is required';
                        }
                        final age = int.tryParse(value.trim());
                        if (age == null) {
                          return 'Please enter a valid number';
                        }
                        final minAge = int.tryParse(_minAgeController.text.trim()) ?? 18;
                        if (age <= minAge) {
                          return 'Maximum age must be more than minimum age';
                        }
                        if (age > 100) {
                          return 'Maximum age must be less than or equal to 100 years';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Interested In',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the genders you\'re interested in',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              _buildGenderOption('male', 'Male', Icons.male),
              const SizedBox(height: 16),
              _buildGenderOption('female', 'Female', Icons.female),
              const SizedBox(height: 16),
              _buildGenderOption('other', 'Other', Icons.person),
              const SizedBox(height: 32),
              const Text(
                'Maximum Distance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set the maximum distance (in kilometers) for potential matches',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxDistanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Distance (km) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  suffixText: 'km',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Maximum distance is required';
                  }
                  final distance = int.tryParse(value.trim());
                  if (distance == null) {
                    return 'Please enter a valid number';
                  }
                  if (distance < 1) {
                    return 'Distance must be at least 1 km';
                  }
                  if (distance > 20000) {
                    return 'Distance must be less than or equal to 20000 km';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Pickup Line',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Write something that can be sent as an opening message to your matches',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
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
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Preferences',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon) {
    final isSelected = _interestedIn.contains(value);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _interestedIn.remove(value);
          } else {
            _interestedIn.add(value);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryColor : Colors.grey),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.black,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor),
          ],
        ),
      ),
    );
  }
}
