import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/theme_provider.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/providers/currency_provider.dart';
import 'package:wealth_wise/providers/notification_provider.dart';
import 'package:wealth_wise/providers/biometric_auth_provider.dart';
import 'package:wealth_wise/services/biometric_service.dart';
import 'package:wealth_wise/screens/auth/login_screen.dart';
import 'package:wealth_wise/screens/profile/profile_screen.dart';
import 'package:wealth_wise/screens/settings/categories_screen.dart';
import 'package:wealth_wise/screens/settings/subscription_screen.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:url_launcher/url_launcher_string.dart'
    show launchUrlString, LaunchMode;
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.0';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      _isLoading = false;
    });
  }

  // Method to handle sign out process
  Future<void> _handleSignOut(
      BuildContext context, AuthProvider authProvider) async {
    // Get navigator state before any async operations
    final navigatorState = Navigator.of(context);

    // Show confirmation dialog
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;

    if (confirm) {
      await authProvider.signOut();

      if (!mounted) return;

      navigatorState.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _openCurrencySelector(CurrencyProvider currencyProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Currency',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: currencyProvider.availableCurrencies.length,
                      itemBuilder: (context, index) {
                        final currency =
                            currencyProvider.availableCurrencies[index];
                        return RadioListTile<String>(
                          title: Text(currency),
                          subtitle:
                              Text(currencyProvider.getCurrencyName(currency)),
                          value: currency,
                          groupValue: currencyProvider.currencyCode,
                          onChanged: (value) {
                            if (value != null) {
                              currencyProvider.setCurrency(value);
                              Navigator.pop(context);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openNotificationSettings(NotificationProvider notificationProvider) {
    TimeOfDay selectedTime = notificationProvider.reminderTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Settings',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Daily Expense Reminders'),
                      subtitle: const Text(
                          'Get a daily reminder to track your expenses'),
                      value: notificationProvider.notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          notificationProvider.toggleNotifications(value);
                        });
                      },
                    ),
                    const Divider(),
                    if (notificationProvider.notificationsEnabled) ...[
                      ListTile(
                        title: const Text('Reminder Time'),
                        subtitle: Text(
                            '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (pickedTime != null) {
                            setState(() {
                              selectedTime = pickedTime;
                            });
                            notificationProvider.setReminderTime(pickedTime);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          notificationProvider.showNotification(
                            id: 0,
                            title: 'Notification Test',
                            body:
                                'This is a test notification from WealthWise!',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Test notification sent. Check your console logs.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text('Send Test Notification'),
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Enable notifications to set reminder times and schedule notifications.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrlString(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch the URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showHelpAndSupport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryGreen.withValues(alpha: 0.12),
                    child: const Icon(Icons.help_outline,
                        color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Frequently Asked Questions'),
                  onTap: () => _launchUrl('https://wealthwise.example.com/faq'),
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.secondaryBlue.withValues(alpha: 0.12),
                    child: const Icon(Icons.mail_outline,
                        color: AppTheme.secondaryBlue),
                  ),
                  title: const Text('Contact Support'),
                  onTap: () =>
                      _launchUrl('mailto:support@wealthwise.example.com'),
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.neutralGray.withValues(alpha: 0.12),
                    child: const Icon(Icons.description_outlined,
                        color: AppTheme.neutralGray),
                  ),
                  title: const Text('Terms of Service'),
                  onTap: () =>
                      _launchUrl('https://wealthwise.example.com/terms'),
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.neutralGray.withValues(alpha: 0.12),
                    child: const Icon(Icons.privacy_tip_outlined,
                        color: AppTheme.neutralGray),
                  ),
                  title: const Text('Privacy Policy'),
                  onTap: () =>
                      _launchUrl('https://wealthwise.example.com/privacy'),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAboutApp() {
    showAboutDialog(
      context: context,
      applicationName: 'WealthWise',
      applicationVersion: _appVersion,
      applicationIcon: CircleAvatar(
        radius: 30,
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
        child: Icon(
          Icons.account_balance_wallet,
          color: AppTheme.primaryGreen,
          size: 32,
        ),
      ),
      applicationLegalese: '© ${DateTime.now().year} WealthWise Finance',
      children: [
        const SizedBox(height: 24),
        const Text(
          'WealthWise is a comprehensive finance tracking application designed to help you manage your expenses, income, and savings with smart insights and beautiful visualizations.',
        ),
        const SizedBox(height: 16),
        const Text(
          'This app allows you to categorize expenses, set budgets, track financial goals, and get personalized recommendations to improve your financial health.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.star, size: 16),
              label: const Text('Rate App'),
              onPressed: () => _launchUrl(
                  'https://play.google.com/store/apps/details?id=com.example.wealthwise'),
            ),
            ActionChip(
              avatar: const Icon(Icons.share, size: 16),
              label: const Text('Share'),
              onPressed: () {
                // Share app functionality would go here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Share functionality coming soon!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final biometricAuthProvider = Provider.of<BiometricAuthProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Account',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Profile section
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            title: const Text('Profile'),
            subtitle: Text(authProvider.user?.displayName ??
                authProvider.user?.email ??
                'User'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),

          const Divider(indent: 72, endIndent: 0),

          // Subscription
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.card_membership,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            title: const Text('Subscription'),
            subtitle:
                Text(subscriptionProvider.isSubscribed ? 'Premium' : 'Free'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen()),
              );
            },
          ),

          const Divider(indent: 72, endIndent: 0),

          // Sign out
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.errorContainer,
              child: Icon(
                Icons.logout,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            title: const Text('Sign Out'),
            onTap: () => _handleSignOut(context, authProvider),
          ),

          // Appearance section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Appearance',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Theme switch
          SwitchListTile(
            secondary: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.dark_mode,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            title: const Text('Dark Mode'),
            subtitle: Text(themeProvider.isDarkMode ? 'On' : 'Off'),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),

          const Divider(indent: 72, endIndent: 0),

          // Currency settings
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.currency_exchange,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            title: const Text('Currency'),
            subtitle: Text(
                '${currencyProvider.currencySymbol} (${currencyProvider.currencyCode})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openCurrencySelector(currencyProvider),
          ),

          // Preferences section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Preferences',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Categories settings
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(
                Icons.category,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            title: const Text('Categories'),
            subtitle: const Text('Manage expense categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CategoriesScreen()),
              );
            },
          ),

          const Divider(indent: 72, endIndent: 0),

          // Notification settings
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(
                Icons.notifications,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            title: const Text('Notifications'),
            subtitle: Text(notificationProvider.notificationsEnabled
                ? 'Enabled'
                : 'Disabled'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openNotificationSettings(notificationProvider),
          ),

          // Only show biometric login option if the device supports it
          if (biometricAuthProvider.isAvailable) ...[
            const Divider(indent: 72, endIndent: 0),

            // Fingerprint login settings
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: Icon(
                Icons.fingerprint,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Fingerprint Login'),
              subtitle: Text(
                  biometricAuthProvider.isEnabled ? 'Enabled' : 'Disabled'),
              value: biometricAuthProvider.isEnabled,
              onChanged: (value) =>
                  _toggleBiometricLogin(biometricAuthProvider, authProvider),
            ),
          ],

          // About and Help section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'About & Help',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Help & Support
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(
                Icons.help,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showHelpAndSupport,
          ),

          const Divider(indent: 72, endIndent: 0),

          // About
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(
                Icons.info,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutApp,
          ),
        ],
      ),
    );
  }

  // Method to toggle biometric login
  Future<void> _toggleBiometricLogin(
      BiometricAuthProvider biometricAuthProvider,
      AuthProvider authProvider) async {
    // Store BuildContext reference before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // If biometric is already enabled, just disable it
    if (biometricAuthProvider.isEnabled) {
      await biometricAuthProvider.disableBiometricLogin();
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Fingerprint login disabled'),
        ),
      );
      return;
    }

    // Enable biometric login
    if (authProvider.user == null) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to enable fingerprint login'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Use the direct approach that works in the test button
    try {
      // Show authentication dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Authenticating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verify your fingerprint...'),
            ],
          ),
        ),
      );

      // Directly use the biometric service instead of going through provider
      final biometricService = BiometricService();
      final authenticated = await biometricService.authenticate(
        reason: 'Verify your identity to enable fingerprint login',
      );

      // Close the authentication dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      // If authentication failed, show error and return
      if (!authenticated) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Authentication succeeded, now directly save credentials
      final userEmail = authProvider.user!.email;

      // Get the auth provider information
      final userProvider =
          authProvider.firebaseUser?.providerData.isNotEmpty == true
              ? authProvider.firebaseUser!.providerData.first.providerId
              : 'password';

      debugPrint(
          "Setting up fingerprint login for user with provider: $userProvider");

      // Add a short delay before saving credentials
      await Future.delayed(const Duration(milliseconds: 300));

      // Check if widget is still mounted before showing dialog
      if (!mounted) return;

      // For email/password, we need to ask the user to enter their password once more
      String passwordForStorage = '';
      bool isTokenBased = true;

      if (userProvider == 'password') {
        // For email/password authentication, we need to store the actual password
        // Show a dialog to ask for the password
        final password = await _promptForPassword();

        if (password == null || password.isEmpty) {
          // User cancelled
          if (!mounted) return;

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Password required to set up fingerprint login'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        passwordForStorage = password;
        isTokenBased = false;
      }

      // First, perform the async operation to save credentials without showing dialog directly
      // Instead of using FutureBuilder inside a dialog, we'll wait for the future to complete
      // and then show a dialog with the result
      bool success = false;
      try {
        // Show a loading dialog first
        if (!mounted) return;
        _showLoadingDialog('Setting up fingerprint login...');

        // Wait for the operation to complete
        success = await biometricService.saveCredentials(
          userEmail,
          passwordForStorage,
          isTokenBased: isTokenBased,
          authProvider: userProvider,
        );

        // Close the loading dialog
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        // Check if widget is still mounted before showing result dialog
        if (!mounted) return;

        // Show success or error dialog
        _showResultDialog(success, biometricAuthProvider);
      } catch (e) {
        // Close the loading dialog if it's open
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        if (!mounted) return;

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close any open dialogs
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to show loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Setting Up Fingerprint Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  // Helper method to show result dialog
  void _showResultDialog(
      bool success, BiometricAuthProvider biometricAuthProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(success ? 'Success' : 'Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(success
                ? 'Fingerprint login enabled successfully!'
                : 'Failed to enable fingerprint login'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Manually refresh the provider state
              biometricAuthProvider.refreshState();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptForPassword() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Enter Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Please enter your password to enable fingerprint login.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, passwordController.text);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      }),
    );
  }
}
