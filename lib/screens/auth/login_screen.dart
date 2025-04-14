import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/biometric_auth_provider.dart';
import 'package:wealth_wise/screens/auth/register_screen.dart';
import 'package:wealth_wise/screens/auth/reset_password_screen.dart';
import 'package:wealth_wise/screens/home/home_screen.dart';

import 'package:wealth_wise/widgets/custom_action_button.dart';
import 'package:wealth_wise/providers/user_preferences_provider.dart';
import 'package:wealth_wise/utils/logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final bool _rememberMe = false;
  final _logger = Logger('LoginScreen');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await context.read<AuthProvider>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (mounted && success) {
        // Store variables that need context here, before async gap
        final authProvider = context.read<AuthProvider>();
        final userPreferencesProvider =
            Provider.of<UserPreferencesProvider>(context, listen: false);
        final userId = authProvider.user?.uid;

        // Offer biometric login setup if available
        final biometricAuthProvider =
            Provider.of<BiometricAuthProvider>(context, listen: false);

        if (biometricAuthProvider.isAvailable &&
            !biometricAuthProvider.isEnabled) {
          _offerBiometricSetup();
        }

        // Save any temporary user preferences to Firestore if available
        if (userId != null) {
          // Try to save any temporary preferences if we have them
          try {
            await userPreferencesProvider.loadTempPreferencesFromLocal();

            if (userPreferencesProvider.tempPrimaryGoal != null &&
                userPreferencesProvider.tempIncomeRange != null &&
                userPreferencesProvider.tempExpertise != null) {
              await userPreferencesProvider.saveUserPreferences(userId);
            }

            // try to load the user's existing preferences
            await userPreferencesProvider.loadUserPreferences(userId);
          } catch (e) {
            // Silently handle errors with preferences - don't block login
            _logger
                .warning('Failed to handle user preferences: ${e.toString()}');
          }
        }

        // Check if mounted before using context after async gap
        if (!mounted) return;

        // Force navigation to home screen after successful login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );

        if (_rememberMe) {
          _saveCredentials(
              _emailController.text.trim(), _passwordController.text.trim());
        }
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final biometricAuthProvider = Provider.of<BiometricAuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                // Logo and welcome text
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome Back',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(179),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email field
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 24),

                // Login button
                CustomActionButton(
                  onPressed: _isLoading ? null : _signIn,
                  label: _isLoading ? 'Signing in...' : 'Sign In',
                  icon: _isLoading ? Icons.hourglass_empty : Icons.login,
                  isSmall: false,
                ),

                // Fingerprint login button - show whenever biometrics is available on the device
                if (biometricAuthProvider.isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _handleFingerprintButtonPress(
                              biometricAuthProvider),
                      icon: Icon(
                        Icons.fingerprint,
                        color: biometricAuthProvider.isEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 128),
                        size: 28,
                      ),
                      label: Text(
                        biometricAuthProvider.isEnabled
                            ? 'Sign In with Fingerprint'
                            : 'Use Fingerprint Login',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Use different styles depending on whether fingerprint is enabled
                        backgroundColor: biometricAuthProvider.isEnabled
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: biometricAuthProvider.isEnabled
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // OR divider
                Row(
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
                ),
                const SizedBox(height: 24),

                // Social login buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomActionButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                // Capture ScaffoldMessenger before async operation
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                // Capture Navigator before async operation
                                final navigator = Navigator.of(context);

                                try {
                                  final success =
                                      await authProvider.signInWithGoogle();

                                  if (mounted) {
                                    if (!success) {
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Failed to sign in with Google')),
                                      );
                                    } else {
                                      // Use MaterialPageRoute instead of named routes
                                      navigator.pushReplacement(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const HomeScreen(),
                                        ),
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
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              },
                        label: 'Google',
                        icon: Icons.g_mobiledata,
                        isSmall: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomActionButton(
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          // Capture Navigator before async operation
                          final navigator = Navigator.of(context);

                          try {
                            final success =
                                await authProvider.signInWithFacebook();

                            if (mounted) {
                              if (!success) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Failed to sign in with Facebook')),
                                );
                              } else {
                                // Use MaterialPageRoute instead of named routes
                                navigator.pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const HomeScreen(),
                                  ),
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
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                        label: 'Facebook',
                        icon: Icons.facebook,
                        isSmall: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Forgot password and sign up links
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ResetPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this method for biometric authentication
  Future<void> _signInWithBiometrics() async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final biometricAuthProvider =
        Provider.of<BiometricAuthProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      debugPrint("Starting biometric login process...");

      // Authenticate with biometrics and get stored credentials
      final credentials =
          await biometricAuthProvider.authenticateAndGetCredentials();

      if (credentials == null) {
        final error = biometricAuthProvider.error ?? "Authentication failed";
        debugPrint("Biometric authentication failed: $error");
        throw Exception(error);
      }

      final String email = credentials['email']!;
      final String? password = credentials['password'];
      final String? provider = credentials['auth_provider'];

      debugPrint("Credentials retrieved, email: $email, provider: $provider");

      // Sign in with token-based authentication
      final success = await authProvider.signInWithToken(
        email: email,
        password: password,
        authProvider: provider,
      );

      if (!mounted) return;

      if (success) {
        debugPrint("Sign in successful!");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else {
        final error = authProvider.error ?? "Failed to sign in";
        debugPrint("Sign in failed: $error");

        // Try manual sign-in as fallback
        if (password?.isNotEmpty == true &&
            password != '##TOKEN_BASED_AUTH##' &&
            provider == 'password') {
          debugPrint("Attempting traditional sign-in as fallback");
          final manualSuccess = await authProvider.signIn(
            email: email,
            password: password!,
          );

          if (manualSuccess && mounted) {
            debugPrint("Traditional sign-in successful");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
            return;
          }
        }

        // If we reach here, all sign-in attempts failed
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error during biometric login: $e");
      if (mounted) {
        final message = e.toString().contains("Exception:")
            ? e.toString().split("Exception:").last.trim()
            : "Fingerprint login failed. Please use your password.";

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Method to offer biometric login setup
  Future<void> _offerBiometricSetup() async {
    final biometricAuthProvider =
        Provider.of<BiometricAuthProvider>(context, listen: false);

    // Check if biometric authentication is available
    if (!biometricAuthProvider.isAvailable || biometricAuthProvider.isEnabled) {
      return;
    }

    if (!mounted) return;

    // Show dialog to ask user if they want to enable biometric login
    bool? enableBiometrics = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable Fingerprint Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to enable fingerprint login for faster access next time?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will allow you to securely sign in with just your fingerprint!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    // If user declined or dialog was dismissed
    if (enableBiometrics != true || !mounted) return;

    // Show a progress dialog and handle the setup process
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressContext) => AlertDialog(
        title: const Text('Setting Up Fingerprint Login'),
        content: FutureBuilder<bool>(
          future: _setupBiometrics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up fingerprint login...')
                ],
              );
            } else {
              // Process completed
              final success = snapshot.data == true;
              if (success) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(height: 16),
                    Text('Fingerprint login enabled successfully!'),
                    SizedBox(height: 8),
                    Text(
                      'You can now sign in quickly with your fingerprint.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text('Failed to enable fingerprint login'),
                    if (biometricAuthProvider.error?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          biometricAuthProvider.error ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                );
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(progressContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper method to setup biometrics
  Future<bool> _setupBiometrics() async {
    final biometricAuthProvider =
        Provider.of<BiometricAuthProvider>(context, listen: false);

    try {
      // Save credentials for future biometric login
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get the auth provider information if available
      final userProvider =
          authProvider.firebaseUser?.providerData.isNotEmpty == true
              ? authProvider.firebaseUser!.providerData.first.providerId
              : 'password';

      // Save the credentials with the correct provider information
      return await biometricAuthProvider.enableBiometricLogin(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        authProvider: userProvider,
      );
    } catch (e) {
      debugPrint("Error during biometric setup: $e");
      return false;
    }
  }

  // Add this method to handle fingerprint button press differently based on whether it's enabled
  void _handleFingerprintButtonPress(
      BiometricAuthProvider biometricAuthProvider) {
    if (biometricAuthProvider.isEnabled) {
      // If fingerprint is already enabled, proceed with biometric authentication
      _signInWithBiometrics();
    } else {
      // If fingerprint is not enabled yet, show an explanation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fingerprint Login Setup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fingerprint,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Fingerprint login lets you sign in quickly and securely.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'To enable this feature:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  '1. Sign in with your email/password or social accounts'),
              const Text('2. Go to Settings > Fingerprint Login'),
              const Text('3. Toggle the switch to enable'),
              const SizedBox(height: 12),
              const Text(
                'You can use any sign-in method (Google, Facebook, or Email) to activate fingerprint login!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                // Focus the email field to encourage the user to sign in
                FocusScope.of(context).requestFocus(
                  _emailController.text.isEmpty
                      ? _emailFocusNode
                      : _passwordFocusNode,
                );
              },
              child: const Text('Got It'),
            ),
          ],
        ),
      );
    }
  }

  void _saveCredentials(String email, String password) {
    // For security reasons, we'll only implement this if we add secure storage
    // This is a placeholder method
    _logger.info('Credentials would be saved here if implemented');
  }
}
