import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';
import 'screens/get_started_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/match_provider.dart';
import 'providers/location_provider.dart';
import 'services/firebase_service.dart';
import 'theme/app_colors.dart';

// Default color constants (used when theme extension is not available, e.g. fallback)
const Color primaryColor = Color(0xFFab76e3);
const Color secondaryColor = Color.fromARGB(255, 238, 222, 255);
const Color tertiaryColor = Color.fromARGB(255, 245, 236, 255);

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await FirebaseService.backgroundMessageHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp();
  
  // Setup Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  FirebaseService.setupForegroundHandler();
  FirebaseService.setupNotificationHandlers();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static ThemeData _buildTheme(AppColors colors) {
    return ThemeData(
      primaryColor: colors.primary,
      extensions: [colors],
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        primary: colors.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final colors = AppColors.fromGender(auth.user?['gender']);
          return MaterialApp(
            title: 'SugarPot',
            theme: _buildTheme(colors),
            home: const SplashScreen(),
            routes: {
              '/get-started': (context) => const GetStartedScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/home': (context) => const HomeScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
