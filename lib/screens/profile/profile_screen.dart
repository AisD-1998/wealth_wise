import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/services/auth_service.dart';
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
      ),
      body: user == null
          ? _buildSignInPrompt(context)
          : _buildProfileContent(context, user),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile picture and name
          CircleAvatar(
            radius: 60,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 26),
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.displayName != null && user.displayName!.isNotEmpty
                        ? user.displayName![0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName ?? 'User',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),

          const SizedBox(height: 32),

          // Account options
          _buildSectionTitle(context, 'Account'),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.edit,
            title: 'Edit Profile',
            onTap: () {
              // Navigate to edit profile
            },
          ),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.lock,
            title: 'Change Password',
            onTap: () {
              // Navigate to change password
            },
          ),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {
              // Navigate to notifications settings
            },
          ),

          const SizedBox(height: 16),

          // Preferences
          _buildSectionTitle(context, 'Preferences'),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            onTap: () {
              // Navigate to language settings
            },
          ),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.attach_money,
            title: 'Currency',
            subtitle: 'USD',
            onTap: () {
              // Navigate to currency settings
            },
          ),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.dark_mode,
            title: 'Theme',
            subtitle: 'Light',
            onTap: () {
              // Navigate to theme settings
            },
          ),

          const SizedBox(height: 16),

          // About and Support
          _buildSectionTitle(context, 'About & Support'),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {
              // Navigate to help and support
            },
          ),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.info,
            title: 'About',
            onTap: () {
              // Navigate to about
            },
          ),
          _buildProfileMenuItem(
            context: context,
            icon: Icons.policy,
            title: 'Privacy Policy',
            onTap: () {
              // Navigate to privacy policy
            },
          ),

          const SizedBox(height: 32),

          // Sign out button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Store the navigation route before async operation
                final navigator = Navigator.of(context);
                final provider =
                    Provider.of<AuthProvider>(context, listen: false);

                // Sign out
                await AuthService().signOut();
                if (mounted) {
                  provider.clearUser();
                  navigator.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Sign Out'),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 26),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
