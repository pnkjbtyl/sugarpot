import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import 'get_started_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Try to refresh token if exists
    try {
      await authProvider.refreshTokenIfNeeded();
    } catch (e) {
      debugPrint('Token refresh error: $e');
    }
    
    await authProvider.loadUser();

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      // Check which onboarding page should be shown
      final missingPage = authProvider.getMissingOnboardingPage();
      
      if (missingPage == -1) {
        // All fields are complete, go to People screen (index 1). Clear stack so back won't return to login.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 1)),
          (route) => false,
        );
      } else {
        // Navigate to the first missing field page. Clear stack so back won't return to login.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OnboardingScreen(initialPage: missingPage),
          ),
          (route) => false,
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite,
              size: 100,
              color: context.appPrimaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'SugarPot',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: context.appPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
