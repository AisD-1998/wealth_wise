import 'package:flutter/material.dart';
import 'package:wealth_wise/services/biometric_service.dart';
import 'dart:developer' as developer;

class BiometricAuthProvider with ChangeNotifier {
  final BiometricService _biometricService = BiometricService();

  bool _isAvailable = false;
  bool _isEnabled = false;
  bool _isLoading = true;
  String? _error;
  String? _detailedErrorMessage;
  bool _isAuthenticating =
      false; // Flag to prevent multiple authentication calls

  // Getters
  bool get isAvailable => _isAvailable;
  bool get isEnabled => _isEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get detailedErrorMessage => _detailedErrorMessage;
  bool get isAuthenticating => _isAuthenticating;

  BiometricAuthProvider() {
    developer.log('BiometricAuthProvider initialized');
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _detailedErrorMessage = null;
    developer.log('BiometricAuthProvider: Starting initialization');
    notifyListeners();

    try {
      // Check if biometric authentication is available
      developer.log('BiometricAuthProvider: Checking biometric availability');
      _isAvailable = await _biometricService.isBiometricAvailable();
      developer.log('BiometricAuthProvider: isAvailable = $_isAvailable');

      // Check if biometric login is enabled
      developer
          .log('BiometricAuthProvider: Checking if biometric login is enabled');
      _isEnabled = await _biometricService.isBiometricLoginEnabled();
      developer.log('BiometricAuthProvider: isEnabled = $_isEnabled');

      _error = null;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isAvailable = false;
      _isEnabled = false;
      _detailedErrorMessage = 'Error during initialization: $e\n$stackTrace';
      developer.log('BiometricAuthProvider: Error during initialization',
          error: e, stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      developer.log('BiometricAuthProvider: Initialization complete');
      notifyListeners();
    }
  }

  // Force refresh the biometric state
  Future<void> refreshState() async {
    developer.log('BiometricAuthProvider: Refreshing state');
    _isAuthenticating = false; // Reset authentication flag
    _error = null; // Clear any errors
    _detailedErrorMessage = null; // Clear detailed error message
    await _init(); // Re-initialize completely
  }

  // Enable biometric login by saving credentials
  Future<bool> enableBiometricLogin(String email, String password,
      {String? authProvider}) async {
    _isLoading = true;
    _detailedErrorMessage = null;
    developer.log('BiometricAuthProvider: Enabling biometric login');
    notifyListeners();

    try {
      // If password is empty, we're using token-based authentication
      // In this case, we still need to store the email, but we'll use
      // a special marker for password to indicate token-based auth
      final credentialsToSave = {
        'email': email,
        'password': password.isEmpty ? '##TOKEN_BASED_AUTH##' : password,
        'is_token_based': password.isEmpty,
        'auth_provider': authProvider ?? 'password',
      };

      developer.log(
          'BiometricAuthProvider: Saving credentials for provider: ${authProvider ?? "password"}');
      final result = await _biometricService.saveCredentials(
        credentialsToSave['email'] as String,
        credentialsToSave['password'] as String,
        isTokenBased: password.isEmpty,
        authProvider: authProvider,
      );

      if (result) {
        _isEnabled = true;
        _error = null;
        developer
            .log('BiometricAuthProvider: Biometric login enabled successfully');
      } else {
        _error = 'Failed to save credentials';
        developer.log('BiometricAuthProvider: Failed to save credentials');
      }
      notifyListeners();
      return result;
    } catch (e, stackTrace) {
      _error = e.toString();
      _detailedErrorMessage = 'Error enabling biometric login: $e\n$stackTrace';
      developer.log('BiometricAuthProvider: Error enabling biometric login',
          error: e, stackTrace: stackTrace);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Disable biometric login by deleting credentials
  Future<bool> disableBiometricLogin() async {
    _isLoading = true;
    _detailedErrorMessage = null;
    developer.log('BiometricAuthProvider: Disabling biometric login');
    notifyListeners();

    try {
      developer.log('BiometricAuthProvider: Deleting credentials');
      final result = await _biometricService.deleteSavedCredentials();
      if (result) {
        _isEnabled = false;
        _error = null;
        developer.log(
            'BiometricAuthProvider: Biometric login disabled successfully');
      } else {
        _error = 'Failed to delete credentials';
        developer.log('BiometricAuthProvider: Failed to delete credentials');
      }
      notifyListeners();
      return result;
    } catch (e, stackTrace) {
      _error = e.toString();
      _detailedErrorMessage =
          'Error disabling biometric login: $e\n$stackTrace';
      developer.log('BiometricAuthProvider: Error disabling biometric login',
          error: e, stackTrace: stackTrace);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Authenticate with biometrics and get stored credentials
  Future<Map<String, String>?> authenticateAndGetCredentials() async {
    if (_isAuthenticating) {
      developer.log(
          'BiometricAuthProvider: Authentication already in progress, ignoring request');
      return null;
    }

    _isAuthenticating = true;
    _isLoading = true;
    _detailedErrorMessage = null;
    developer
        .log('BiometricAuthProvider: Starting biometric authentication flow');
    notifyListeners();

    try {
      // First authenticate using biometrics directly
      developer.log('BiometricAuthProvider: Starting biometric authentication');
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to log in to your account',
      );
      developer
          .log('BiometricAuthProvider: Authentication result: $authenticated');

      // Add a small delay to let the UI thread settle after biometric authentication
      await Future.delayed(const Duration(milliseconds: 300));

      if (authenticated) {
        // If authenticated, get stored credentials
        developer.log(
            'BiometricAuthProvider: Authentication successful, retrieving credentials');

        try {
          // Try to get credentials
          final credentials = await _biometricService.getCredentials();

          if (credentials == null) {
            developer.log(
                'BiometricAuthProvider: No credentials found after successful auth');
            _error = 'No saved credentials found';
            _isLoading = false;
            _isAuthenticating = false;
            notifyListeners();
            return null;
          }

          // Log detailed credential info (without revealing password)
          developer
              .log('BiometricAuthProvider: Credentials retrieved successfully');
          developer.log('- Email: ${credentials['email']}');
          developer.log(
              '- Password present: ${credentials['password']?.isNotEmpty == true}');
          developer.log('- Auth provider: ${credentials['auth_provider']}');
          developer.log('- Token-based: ${credentials['is_token_based']}');

          // Make sure we have all required fields
          if (credentials['email']?.isEmpty == true) {
            developer
                .log('BiometricAuthProvider: Email is missing in credentials');
            _error = 'Invalid credentials format: email missing';
            _isLoading = false;
            _isAuthenticating = false;
            notifyListeners();
            return null;
          }

          _error = null;
          _isLoading = false;
          _isAuthenticating = false;
          notifyListeners();
          return credentials;
        } catch (credError) {
          developer.log(
              'BiometricAuthProvider: Error getting credentials after successful auth: $credError');

          _error = 'Failed to retrieve saved credentials';
          _isLoading = false;
          _isAuthenticating = false;
          notifyListeners();
          return null;
        }
      } else {
        _error = 'Authentication failed';
        developer.log('BiometricAuthProvider: Authentication failed');
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return null;
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      _detailedErrorMessage =
          'Error during biometric authentication: $e\n$stackTrace';
      developer.log(
          'BiometricAuthProvider: Error during biometric authentication',
          error: e,
          stackTrace: stackTrace);
      _isLoading = false;
      _isAuthenticating = false;
      notifyListeners();
      return null;
    }
  }
}
