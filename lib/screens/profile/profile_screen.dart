import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: user == null
          ? _buildSignInPrompt(context)
          : SafeArea(
              child: _buildProfileContent(context, user),
            ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            'You need to sign in',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in to access your profile',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Navigate to login screen
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, User user) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile picture and name
          Card(
            elevation: 0,
            color: theme.colorScheme.surface.withValues(alpha: 240),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 26),
                    backgroundImage: user.photoUrl != null
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null
                        ? Text(
                            user.displayName != null &&
                                    user.displayName!.isNotEmpty
                                ? user.displayName![0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName ?? 'User',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 153),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      // Navigate to edit profile
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Account options
          _buildSectionTitle(context, 'Account'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              children: [
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: () {
                    // Navigate to change password
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    // Navigate to notifications settings
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {
                    // Navigate to language settings
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Preferences
          _buildSectionTitle(context, 'Preferences'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              children: [
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.nightlight_outlined,
                  title: 'Theme',
                  subtitle: 'System default',
                  onTap: () {
                    // Theme settings
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.attach_money_outlined,
                  title: 'Currency',
                  subtitle: 'USD',
                  onTap: () {
                    // Currency settings
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Support & Logout
          _buildSectionTitle(context, 'Support'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              children: [
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    // Navigate to help
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'About',
                  onTap: () {
                    // Show about dialog
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () => _handleSignOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  // Helper method to show logout confirmation dialog
  Future<bool> showLogoutConfirmation(BuildContext context) async {
    return await showDialog<bool>(
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
  }

  // Add this new method to handle sign out process
  Future<void> _handleSignOut(BuildContext context) async {
    // Store context related objects before async gap
    final navigator = Navigator.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Show confirmation dialog
    final shouldLogout = await showLogoutConfirmation(context);

    // Check if still mounted after dialog
    if (!mounted) return;

    // Process the logout if confirmed
    if (shouldLogout) {
      // Sign out
      await authProvider.signOut();

      // Check if still mounted after sign out
      if (!mounted) return;

      // Navigate to login
      navigator.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }
}
