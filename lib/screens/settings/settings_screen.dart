import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/theme_provider.dart';
import 'package:wealth_wise/screens/auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            subtitle: Text(authProvider.user?.displayName ?? 'User'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/profile');
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
            subtitle: const Text('USD'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Currency selection dialog
              showDialog(
                context: context,
                builder: (context) => const AlertDialog(
                  title: Text('Currency'),
                  content: Text(
                      'Currency selection will be available in a future update'),
                ),
              );
            },
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
              Navigator.pushNamed(context, '/categories');
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
            subtitle: const Text('Coming soon'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Notifications will be available in a future update'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          const Divider(indent: 72, endIndent: 0),

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
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const AlertDialog(
                  title: Text('Help & Support'),
                  content: Text(
                      'Support options will be available in a future update'),
                ),
              );
            },
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
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'WealthWise',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.primary,
                  size: 48,
                ),
                applicationLegalese: '© 2023 WealthWise',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                      'A finance tracking application that helps you manage your expenses, income, and savings.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
