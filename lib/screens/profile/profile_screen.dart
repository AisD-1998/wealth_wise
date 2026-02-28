import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/achievement.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/models/user.dart';
import 'package:wealth_wise/screens/settings/settings_screen.dart';
import 'package:wealth_wise/screens/auth/login_screen.dart';
import 'package:wealth_wise/screens/profile/edit_profile_screen.dart';
import 'package:wealth_wise/screens/profile/change_password_screen.dart';
import 'package:wealth_wise/screens/profile/delete_account_screen.dart';
import 'package:wealth_wise/constants/app_strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userInitial(User user) {
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName![0].toUpperCase();
    }
    return 'U';
  }

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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
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
                            _userInitial(user),
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
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(user: user),
                        ),
                      );

                      // Refresh the profile if changes were made
                      if (result == true) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Achievements Section
          _buildAchievementsSection(context),

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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Remove all your data permanently',
                  titleColor: theme.colorScheme.error,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeleteAccountScreen(),
                      ),
                    );
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.attach_money_outlined,
                  title: 'Currency',
                  subtitle: 'USD',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildProfileMenuItem(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'About',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'WealthWise',
                      applicationVersion: '1.0.0',
                      applicationIcon: Icon(
                        Icons.account_balance_wallet,
                        color: theme.colorScheme.primary,
                        size: 48,
                      ),
                      applicationLegalese: '© ${DateTime.now().year} WealthWise',
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'A finance tracking application that helps you manage your expenses, income, and savings.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () => _handleSignOut(context),
            icon: const Icon(Icons.logout),
            label: const Text(AppStrings.kSignOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),

          const SizedBox(height: 40),

          // Account info footer
          Card(
            elevation: 0,
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Info',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAccountInfoRow(
                    context,
                    title: 'Account Type',
                    value: 'Free',
                  ),
                  const SizedBox(height: 4),
                  _buildAccountInfoRow(
                    context,
                    title: 'Member Since',
                    value: _formatDate(user.createdAt),
                  ),
                  const SizedBox(height: 4),
                  _buildAccountInfoRow(
                    context,
                    title: 'Last Login',
                    value: _formatDate(user.lastLoginAt),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context) {
    final theme = Theme.of(context);
    final financeProvider = Provider.of<FinanceProvider>(context);
    final subProvider = Provider.of<SubscriptionProvider>(context);
    final isPremium = subProvider.isSubscribed;
    final achievements = financeProvider.achievements;
    final streak = financeProvider.currentStreak;

    // Filter: free users see only non-premium achievements
    final visibleAchievements = isPremium
        ? achievements
        : achievements.where((a) => !a.isPremium).toList();
    final unlockedCount =
        visibleAchievements.where((a) => a.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Achievements'),
        // Streak display
        if (streak > 0)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.orange.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      color: Colors.orange, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streak-day streak',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'Keep logging daily!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Achievement count
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$unlockedCount / ${visibleAchievements.length} unlocked',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // Achievement badges grid
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleAchievements
                  .map((a) => _buildAchievementBadge(context, a))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(BuildContext context, Achievement achievement) {
    final theme = Theme.of(context);
    final isUnlocked = achievement.isUnlocked;

    return Tooltip(
      message: '${achievement.title}: ${achievement.description}',
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isUnlocked
              ? theme.colorScheme.primaryContainer.withValues(alpha: 80)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 80),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getAchievementIcon(achievement.iconName),
              size: 28,
              color: isUnlocked
                  ? theme.colorScheme.primary
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              achievement.title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isUnlocked
                    ? theme.colorScheme.onSurface
                    : Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'shield':
        return Icons.shield;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'military_tech':
        return Icons.military_tech;
      case 'savings':
        return Icons.savings;
      case 'category':
        return Icons.category;
      case 'hundred_mp':
        return Icons.looks_one;
      case 'flag':
        return Icons.flag;
      case 'account_balance':
        return Icons.account_balance;
      case 'whatshot':
        return Icons.whatshot;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.emoji_events;
    }
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
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: titleColor != null ? TextStyle(color: titleColor) : null,
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildAccountInfoRow(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Helper method to show logout confirmation dialog
  Future<bool> showLogoutConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(AppStrings.kSignOut),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(AppStrings.kSignOut),
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
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
