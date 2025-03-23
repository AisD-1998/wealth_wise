import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/screens/auth/register_screen.dart';
import 'package:wealth_wise/screens/auth/reset_password_screen.dart';
import 'package:wealth_wise/screens/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _signInWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _signInWithFacebook() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithFacebook();

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _navigateToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RegisterScreen()));
  }

  void _navigateToResetPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and Title
                Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: theme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'WealthWise',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Simple Finance Tracking, Simplified',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Forgot Password Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _navigateToResetPassword,
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      ElevatedButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : _signInWithEmailPassword,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: authProvider.isLoading
                              ? const CircularProgressIndicator()
                              : const Text(
                                  'Login',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),

                      // Error Message
                      if (authProvider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            authProvider.error!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 24),

                      // OR Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Social Login Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Google Login
                          ElevatedButton.icon(
                            onPressed: authProvider.isLoading
                                ? null
                                : _signInWithGoogle,
                            icon: const Icon(Icons.g_mobiledata),
                            label: const Text('Google'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),

                          // Facebook Login
                          ElevatedButton.icon(
                            onPressed: authProvider.isLoading
                                ? null
                                : _signInWithFacebook,
                            icon: const Icon(Icons.facebook),
                            label: const Text('Facebook'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1877F2),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account?"),
                          TextButton(
                            onPressed: _navigateToRegister,
                            child: const Text('Register'),
                          ),
                        ],
                      ),
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
}
