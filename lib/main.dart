import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

import 'package:wealth_wise/screens/auth/login_screen.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/constants/theme.dart';
import 'package:wealth_wise/screens/settings/settings_screen.dart';
import 'package:wealth_wise/screens/onboarding/onboarding_screen.dart';
import 'package:wealth_wise/screens/home/home_screen.dart';
import 'package:wealth_wise/services/shared_prefs.dart';

// Flag to enable/disable Firebase (for testing)
// This should match useDemo in auth_provider.dart
const bool useFirebase = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('Main');

  logger.info('Initializing Firebase...');
  await Firebase.initializeApp();
  logger.info('Firebase initialized successfully');

  logger.info('Initializing SharedPrefs...');
  await SharedPrefs.init();
  logger.info('SharedPrefs initialized successfully');

  // Debug check for onboarding flag
  final hasCompletedOnboarding = SharedPrefs.getBool('hasCompletedOnboarding');
  logger.info('hasCompletedOnboarding: $hasCompletedOnboarding');

  runApp(const MyApp());
}

// Error App to display when Firebase fails to initialize
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WealthWise - Error',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Firebase Initialization Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please make sure you have added the google-services.json file to the android/app directory and properly set up Firebase.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Force close the app
                    // This will restart the app and attempt to initialize Firebase again
                    // This is better than having the app hang in an error state
                    // ignore: avoid_print
                    // User requested app restart - would use proper logging in production
                  },
                  child: const Text('Restart App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FinanceProvider>(
          create: (_) => FinanceProvider(),
          update: (_, authProvider, financeProvider) {
            if (authProvider.isLoggedIn && authProvider.firebaseUser != null) {
              financeProvider!
                  .initializeFinanceData(authProvider.firebaseUser!.uid);
            }
            return financeProvider!;
          },
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'WealthWise',
            theme: AppTheme.lightTheme(),
            debugShowCheckedModeBanner: false,
            home: _buildHomeScreen(authProvider),
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen(AuthProvider authProvider) {
    // If loading, show loading screen
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If user is not logged in, show login screen
    if (!authProvider.isLoggedIn) {
      // Check if onboarding has been shown
      final hasCompletedOnboarding =
          SharedPrefs.getBool('hasCompletedOnboarding') ?? false;

      if (!hasCompletedOnboarding) {
        return const OnboardingScreen();
      }

      return const LoginScreen();
    }

    // If user is logged in, show home screen
    return const HomeScreen();
  }
}

// Demo home screen when running without Firebase
class DemoHomeScreen extends StatelessWidget {
  const DemoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WealthWise Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'WealthWise Demo Mode',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Running without Firebase for testing purposes',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // Use ElevatedButton instead while we sort out the shadcn_ui integration
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()));
              },
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple version of settings screen for demo mode not used anymore since we're using the real SettingsScreen
