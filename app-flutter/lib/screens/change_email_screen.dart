import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import 'otp_verification_screen.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();
  bool _isLoading = false;
  String? _currentEmailOtp;
  String? _newEmailOtp;
  bool _currentEmailVerified = false;
  bool _newEmailVerified = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    // Store current email for reference (not editable)
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  Future<void> _sendCurrentEmailOtp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final currentEmail = user?['email'];

    if (currentEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await authProvider.sendOtp(currentEmail);
      if (mounted) {
        if (success) {
          // Navigate to OTP verification for current email
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: currentEmail,
                returnOtpCode: true,
              ),
            ),
          );

          if (result != null && result.length == 6) {
            setState(() {
              _currentEmailVerified = true;
              _currentEmailOtp = result;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Current email verified'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Failed to send OTP'),
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

  Future<void> _sendNewEmailOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newEmail = _newEmailController.text.trim();

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.sendOtp(newEmail);
      if (mounted) {
        if (success) {
          // Navigate to OTP verification for new email
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: newEmail,
                returnOtpCode: true,
              ),
            ),
          );

          if (result != null && result.length == 6) {
            setState(() {
              _newEmailVerified = true;
              _newEmailOtp = result;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('New email verified'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Failed to send OTP'),
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

  Future<void> _changeEmail() async {
    if (!_currentEmailVerified || !_newEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify both email addresses first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final currentEmail = user?['email'];
    final newEmail = _newEmailController.text.trim();

    if (currentEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = authProvider.apiService;
      final response = await apiService.changeEmail(
        currentEmailOtp: _currentEmailOtp!,
        newEmail: newEmail,
        newEmailOtp: _newEmailOtp!,
      );

      if (mounted) {
        if (response['user'] != null) {
          // Reload user to get updated email
          await authProvider.loadUser();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email changed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to change email'),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final currentEmail = user?['email'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Email'),
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
              const Text(
                'Current Email',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentEmail,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (_currentEmailVerified)
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!_currentEmailVerified)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendCurrentEmailOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Verify Current Email'),
                  ),
                ),
              const SizedBox(height: 32),
              const Text(
                'New Email',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newEmailController,
                keyboardType: TextInputType.emailAddress,
                enabled: _currentEmailVerified,
                decoration: InputDecoration(
                  labelText: 'New Email Address *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: _newEmailVerified
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'New email is required';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  if (value.trim().toLowerCase() == currentEmail.toLowerCase()) {
                    return 'New email must be different from current email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_currentEmailVerified && !_newEmailVerified)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendNewEmailOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Verify New Email'),
                  ),
                ),
              if (_currentEmailVerified && _newEmailVerified) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changeEmail,
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
                            'Change Email',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
