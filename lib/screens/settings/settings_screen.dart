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
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            subtitle: Text(authProvider.user?.displayName ?? 'User'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to profile screen
            },
          ),
          const Divider(),

          // Theme switch
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),
          const Divider(),

          // Currency settings
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Currency'),
            subtitle: const Text('USD'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to currency selection
            },
          ),
          const Divider(),

          // Notification settings (placeholder)
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Coming soon'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Will be implemented in the future
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Notifications will be available in a future update'),
                ),
              );
            },
          ),
          const Divider(),

          // Help & Support
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to help screen
            },
          ),
          const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to about screen
            },
          ),
          const Divider(),

          // Sign out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),

          // App version
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
