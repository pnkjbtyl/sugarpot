import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import '../theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _professionController;
  DateTime? _dateOfBirth;
  String? _gender;
  String? _eatingHabits;
  String? _smoking;
  String? _drinking;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    _nameController = TextEditingController(text: user?['name'] ?? '');
    _bioController = TextEditingController(text: user?['bio'] ?? '');
    _professionController = TextEditingController(text: user?['profession'] ?? '');
    
    if (user?['dateOfBirth'] != null) {
      _dateOfBirth = DateTime.parse(user!['dateOfBirth']);
    }
    _gender = user?['gender'];
    _eatingHabits = user?['eatingHabits'];
    _smoking = user?['smoking'];
    _drinking = user?['drinking'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
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

  bool _isAtLeast18YearsOld() {
    if (_dateOfBirth == null) return false;
    final today = DateTime.now();
    final age = today.year - _dateOfBirth!.year;
    final monthDiff = today.month - _dateOfBirth!.month;
    final dayDiff = today.day - _dateOfBirth!.day;
    
    if (monthDiff < 0 || (monthDiff == 0 && dayDiff < 0)) {
      return age - 1 >= 18;
    }
    return age >= 18;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isAtLeast18YearsOld()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 18 years old'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final updates = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'dateOfBirth': _dateOfBirth!.toIso8601String(),
        'gender': _gender,
        if (_professionController.text.trim().isNotEmpty)
          'profession': _professionController.text.trim(),
        if (_eatingHabits != null) 'eatingHabits': _eatingHabits,
        if (_smoking != null) 'smoking': _smoking,
        if (_drinking != null) 'drinking': _drinking,
      };

      final response = await authProvider.updateProfile(updates);

      if (mounted) {
        if (response) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Failed to update profile'),
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
        title: const Text('Edit Profile'),
        backgroundColor: context.appPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    errorText: _dateOfBirth == null
                        ? 'Date of birth is required'
                        : (!_isAtLeast18YearsOld()
                            ? 'You must be at least 18 years old'
                            : null),
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
              const SizedBox(height: 24),
              const Text(
                'Gender *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildGenderOption('male', 'Male', Icons.male),
              const SizedBox(height: 16),
              _buildGenderOption('female', 'Female', Icons.female),
              const SizedBox(height: 16),
              _buildGenderOption('other', 'Other', Icons.transgender),
              const SizedBox(height: 32),
              TextFormField(
                controller: _professionController,
                decoration: const InputDecoration(
                  labelText: 'What do you do?',
                  hintText: 'E.g., Software Engineer, Teacher, Doctor...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work_outline),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'About you',
                  hintText: 'Tell us about yourself...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
                maxLength: 120,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty && value.length > 120) {
                    return 'About you must be 120 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'What are your eating habits?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildEatingHabitsOption('vegetarian', 'Vegetarian', Icons.eco),
              const SizedBox(height: 8),
              _buildEatingHabitsOption('non-vegetarian', 'Non-vegetarian', Icons.restaurant),
              const SizedBox(height: 8),
              _buildEatingHabitsOption('vegan', 'Vegan', Icons.eco_outlined),
              const SizedBox(height: 24),
              const Text(
                'Do you smoke?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildSmokingOption('yes', 'Yes', Icons.smoking_rooms),
              const SizedBox(height: 8),
              _buildSmokingOption('no', 'No', Icons.smoke_free),
              const SizedBox(height: 8),
              _buildSmokingOption('occasionally', 'Occasionally', Icons.smoking_rooms_outlined),
              const SizedBox(height: 24),
              const Text(
                'Do you drink?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildDrinkingOption('yes', 'Yes', Icons.wine_bar),
              const SizedBox(height: 8),
              _buildDrinkingOption('no', 'No', Icons.no_drinks),
              const SizedBox(height: 8),
              _buildDrinkingOption('occasionally', 'Occasionally', Icons.local_drink_outlined),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.appPrimaryColor,
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
                          'Save Changes',
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

  Widget _buildEatingHabitsOption(String value, String label, IconData icon) {
    final isSelected = _eatingHabits == value;
    return InkWell(
      onTap: () => setState(() => _eatingHabits = isSelected ? null : value),
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

  Widget _buildSmokingOption(String value, String label, IconData icon) {
    final isSelected = _smoking == value;
    return InkWell(
      onTap: () => setState(() => _smoking = isSelected ? null : value),
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

  Widget _buildDrinkingOption(String value, String label, IconData icon) {
    final isSelected = _drinking == value;
    return InkWell(
      onTap: () => setState(() => _drinking = isSelected ? null : value),
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
}
