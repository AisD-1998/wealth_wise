import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/widgets/loading_indicator.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _resetEmailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resetPassword(
      _emailController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _resetEmailSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _resetEmailSent
              ? _buildSuccessScreen(theme)
              : _buildResetForm(authProvider, theme),
        ),
      ),
    );
  }

  Widget _buildResetForm(AuthProvider authProvider, ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 70, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            'Forgot Your Password?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: authProvider.isLoading ? null : _resetPassword,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: authProvider.isLoading
                  ? const LoadingIndicator(size: 24, message: '')
                  : const Text(
                      'Reset Password',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
          if (authProvider.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                authProvider.error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 24),
        Text(
          'Reset Email Sent!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent an email to ${_emailController.text} with instructions to reset your password.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text('Back to Login', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
