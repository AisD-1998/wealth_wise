import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wealth_wise/firebase_options.dart';
import 'package:wealth_wise/screens/auth/login_screen.dart';

import 'package:wealth_wise/screens/home/home_screen.dart';
import 'package:wealth_wise/screens/onboarding/onboarding_screen.dart';
import 'package:wealth_wise/screens/settings/settings_screen.dart';

import 'package:wealth_wise/screens/transactions/transactions_screen.dart';
import 'package:wealth_wise/screens/settings/categories_screen.dart';

import 'package:wealth_wise/services/auth_service.dart';
import 'package:wealth_wise/services/database_service.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/providers/category_provider.dart';
import 'package:wealth_wise/providers/expense_provider.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/providers/currency_provider.dart';
import 'package:wealth_wise/providers/notification_provider.dart';
import 'package:wealth_wise/providers/user_preferences_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:wealth_wise/widgets/loading_indicator.dart';
import 'package:wealth_wise/providers/theme_provider.dart';
import 'package:wealth_wise/services/billing_service.dart';
import 'package:wealth_wise/providers/biometric_auth_provider.dart';

// Flag to toggle Firebase auth (set to false for demo mode)
const bool useFirebase = true;

// SharedPrefs implementation
class SharedPrefs {
  static final Map<String, dynamic> _prefs = {};

  static Future<void> init() async {
    // Mock initialization for now
    _prefs['hasCompletedOnboarding'] = false;
  }

  static bool? getBool(String key) {
    return _prefs[key] as bool?;
  }

  static Future<void> setBool(String key, bool value) async {
    _prefs[key] = value;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPrefs
  await SharedPrefs.init();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Configure logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    }
  });

  // Initialize MobileAds with test app ID
  await MobileAds.instance.initialize();

  // Initialize billing service
  final billingService = BillingService();
  await billingService.initialize();

  // Ensure in_app_purchase is initialized
  final inAppPurchase = InAppPurchase.instance;
  final isAvailable = await inAppPurchase.isAvailable();
  final logger = Logger('Main');
  if (!isAvailable) {
    logger.warning('In-app purchase is not available on this device');
  } else {
    logger.info('In-app purchase is available on this device');
  }

  // Create providers
  final authService = AuthService();
  final databaseService = DatabaseService();

  // Run the app
  runApp(MyApp(
    prefs: prefs,
    authService: authService,
    databaseService: databaseService,
    billingService: billingService,
  ));
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  final AuthService authService;
  final DatabaseService databaseService;
  final BillingService billingService;

  const MyApp({
    super.key,
    required this.prefs,
    required this.authService,
    required this.databaseService,
    required this.billingService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
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
                    print('User requested app restart');
                    // In a real app, we would use proper platform channel to restart the app
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

class MyNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _refreshDataIfNeeded(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _refreshDataIfNeeded(previousRoute);
    super.didPop(route, previousRoute);
  }

  void _refreshDataIfNeeded(Route<dynamic>? route) {
    if (route == null) return;

    // Get the route widget type
    final routeWidget = route is MaterialPageRoute
        ? route.builder(route.navigator!.context)
        : null;
    if (routeWidget is CategoriesScreen || routeWidget is TransactionsScreen) {
      // Get the navigator context
      final navigatorContext = route.navigator?.context;
      if (navigatorContext == null) return;

      // Get the user ID synchronously before the async operation
      final authProvider =
          Provider.of<AuthProvider>(navigatorContext, listen: false);
      final userId = authProvider.user?.uid;
      if (userId == null) return;

      // Get category provider synchronously
      final categoryProvider =
          Provider.of<CategoryProvider>(navigatorContext, listen: false);

      // Now run the async operation without directly using BuildContext
      // after the async gap
      Future.delayed(const Duration(milliseconds: 100), () {
        categoryProvider.loadCategoriesByUser(userId);
      });
    }
  }
}

class _MyAppState extends State<MyApp> {
  final MyNavigatorObserver _navigatorObserver = MyNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. First provide services that don't depend on other providers
        Provider<DatabaseService>.value(value: widget.databaseService),
        Provider<AuthService>.value(value: widget.authService),
        Provider<BillingService>.value(value: widget.billingService),

        // 2. Auth provider must be initialized first
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // 3. Category provider (no constructor parameters needed, uses default DatabaseService)
        ChangeNotifierProvider(create: (_) => CategoryProvider()),

        // 4. Finance provider
        ChangeNotifierProvider(create: (_) => FinanceProvider()),

        // 5. Expense provider
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),

        // 6. Subscription provider
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),

        // 7. Theme provider
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // 8. Currency provider
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),

        // 9. Notification provider
        ChangeNotifierProvider(create: (_) => NotificationProvider()),

        // 10. User Preferences provider
        ChangeNotifierProvider(create: (_) => UserPreferencesProvider()),

        // 11. Biometric Auth provider
        ChangeNotifierProvider(create: (_) => BiometricAuthProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          if (authProvider.isLoading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: themeProvider.themeMode,
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      LoadingIndicator(
                        size: 80.0,
                        message: 'Welcome to WealthWise',
                        useDollarSpinner: true,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Setting up your financial dashboard...',
                        style: TextStyle(
                          color: AppTheme.neutralGray,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // If user is logged in, initialize the providers with user data
          if (authProvider.user != null) {
            // Get all needed data before the async gap
            final userId = authProvider.user!.uid;
            final categoryProvider =
                Provider.of<CategoryProvider>(context, listen: false);
            final financeProvider =
                Provider.of<FinanceProvider>(context, listen: false);
            final userPreferencesProvider =
                Provider.of<UserPreferencesProvider>(context, listen: false);

            // Run this only once when the user logs in
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Use the pre-fetched providers and userId without directly using context
              categoryProvider.loadCategoriesByUser(userId);
              financeProvider.setTimeframe(TimeFrame.month);
              financeProvider.fetchTransactions();

              // Load user preferences
              userPreferencesProvider.loadUserPreferences(userId);
            });
          }

          return MaterialApp(
            title: 'WealthWise',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            navigatorObservers: [_navigatorObserver],
            localizationsDelegates: const [
              // Add Material localization delegates
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('es', ''),
              Locale('fr', ''),
            ],
            home: _buildHomeScreen(authProvider),
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen(AuthProvider authProvider) {
    // If loading, show loading screen
    if (authProvider.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              LoadingIndicator(
                size: 80.0,
                message: 'Welcome to WealthWise',
                useDollarSpinner: true,
              ),
              SizedBox(height: 30),
              Text(
                'Managing your finances',
                style: TextStyle(
                  color: AppTheme.neutralGray,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If user is not logged in, show login screen
    if (!authProvider.isLoggedIn) {
      // Check if onboarding has been shown
      final hasCompletedOnboarding =
          widget.prefs.getBool('hasCompletedOnboarding') ?? false;

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
