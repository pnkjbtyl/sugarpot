import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import 'change_email_screen.dart';
import 'get_started_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: context.appPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final user = authProvider.user;
              final isHidden = user?['isProfileHidden'] == true;
              
              return ListTile(
                leading: Icon(
                  isHidden ? Icons.visibility_off : Icons.visibility,
                  color: context.appPrimaryColor,
                ),
                title: const Text('Hide Profile'),
                subtitle: Text(
                  isHidden
                      ? 'Your profile is currently hidden'
                      : 'Hide your profile from other users',
                ),
                trailing: Switch(
                  value: isHidden,
                  onChanged: (value) {
                    _showHideProfileDialog(context, authProvider, value);
                  },
                  activeColor: context.appPrimaryColor,
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.email, color: context.appPrimaryColor),
            title: const Text('Change Email'),
            subtitle: const Text('Update your email address'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChangeEmailScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete Profile',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Permanently delete your account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showDeleteProfileDialog(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.help, color: context.appPrimaryColor),
            title: const Text('Help'),
            subtitle: const Text('Contact support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final Uri emailUri = Uri.parse('mailto:sugarpot-assistance@shree.systems');
                final launched = await launchUrl(
                  emailUri,
                  mode: LaunchMode.externalApplication,
                );
                if (!launched && context.mounted) {
                  throw Exception('Failed to launch email client');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Could not open email client. Please send an email to sugarpot-assistance@shree.systems'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showHideProfileDialog(
    BuildContext context,
    AuthProvider authProvider,
    bool hide,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(hide ? 'Hide Profile' : 'Show Profile'),
          content: Text(
            hide
                ? 'Your profile will be hidden from other users. You can still login and browse profiles, but others won\'t see you in their feed.'
                : 'Your profile will be visible to other users again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _toggleProfileVisibility(context, authProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleProfileVisibility(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    try {
      final apiService = authProvider.apiService;
      final response = await apiService.toggleProfileVisibility();

      if (context.mounted) {
        if (response['isProfileHidden'] != null) {
          // Reload user to get updated profile status
          await authProvider.loadUser();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Profile visibility updated'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to update profile visibility'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Profile',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'Are you sure you want to delete your profile? This action cannot be undone and all your data will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showDeleteConfirmationDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Final Confirmation',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'This is your last chance to cancel. Deleting your profile will permanently remove all your data. This action CANNOT be undone.\n\nAre you absolutely sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteProfile(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Delete Forever'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProfile(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final apiService = authProvider.apiService;
      final response = await apiService.deleteProfile();

      if (context.mounted) {
        if (response['message'] != null) {
          // Logout and clear data
          await authProvider.logout();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to login screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const GetStartedScreen()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to delete profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
