import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/screens/home/home_screen.dart';
import 'package:wealth_wise/widgets/loading_indicator.dart';
import 'package:wealth_wise/widgets/custom_action_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _kAlreadyRegistered = 'already registered';
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  Future<void> _registerWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.registerWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (mounted && authProvider.error != null) {
        // Check if the error is about existing account
        if (authProvider.error!.contains(_kAlreadyRegistered)) {
          // Show a specific dialog for already registered users
          _showAccountExistsDialog();
        } else {
          // Show regular error message
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(authProvider.error!)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signUpWithGoogle();

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (mounted) {
        // Check if there's an error about existing account
        if (authProvider.error != null &&
            authProvider.error!.contains(_kAlreadyRegistered)) {
          _showAccountExistsDialog();
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Failed to sign up with Google')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithFacebook() async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signUpWithFacebook();

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (mounted) {
        // Check if there's an error about existing account
        if (authProvider.error != null &&
            authProvider.error!.contains(_kAlreadyRegistered)) {
          _showAccountExistsDialog();
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Failed to sign up with Facebook')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    // Login screen is already on the stack — just pop back to it
    Navigator.of(context).pop();
  }

  // Helper method to show account exists dialog
  void _showAccountExistsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Already Exists'),
        content: const Text(
            'An account with this email already exists. Would you like to sign in instead?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              _navigateToLogin(); // Navigate to login screen
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDisabled = _isLoading || authProvider.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRegisterHeader(theme),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildRegisterEmailField(),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 16),
                      _buildConfirmPasswordField(),
                      const SizedBox(height: 24),
                      _buildRegisterButton(isDisabled),
                      if (authProvider.error != null)
                        _buildErrorMessage(authProvider.error!, theme),
                      const SizedBox(height: 20),
                      _buildOrDivider(theme),
                      const SizedBox(height: 20),
                      _buildSocialSignUpButtons(isDisabled),
                      const SizedBox(height: 24),
                      _buildLoginLink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterHeader(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.account_balance_wallet,
          size: 60,
          color: theme.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          'Join WealthWise',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Start your journey to financial freedom',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Full Name',
        hintText: 'Enter your full name',
        prefixIcon: Icon(Icons.person),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        prefixIcon: Icon(Icons.email),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!value.contains('@') || !value.contains('.')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: _togglePasswordVisibility,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a password';
        if (value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        hintText: 'Confirm your password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: _toggleConfirmPasswordVisibility,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please confirm your password';
        if (value != _passwordController.text) return 'Passwords do not match';
        return null;
      },
    );
  }

  Widget _buildRegisterButton(bool isDisabled) {
    return ElevatedButton(
      onPressed: isDisabled ? null : _registerWithEmailPassword,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: isDisabled
            ? const LoadingIndicator(size: 24, message: '')
            : const Text('Create Account', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildErrorMessage(String error, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        error,
        style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOrDivider(ThemeData theme) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildSocialSignUpButtons(bool isDisabled) {
    return Row(
      children: [
        Expanded(
          child: CustomActionButton(
            onPressed: isDisabled ? null : _signUpWithGoogle,
            label: 'Google',
            icon: Icons.g_mobiledata,
            isSmall: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomActionButton(
            onPressed: isDisabled ? null : _signUpWithFacebook,
            label: 'Facebook',
            icon: Icons.facebook,
            isSmall: true,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account?'),
        TextButton(
          onPressed: _navigateToLogin,
          child: const Text('Login'),
        ),
      ],
    );
  }
}
