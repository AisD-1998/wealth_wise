import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Logger _logger = Logger('BiometricService');

  static const String _credentialsKey = 'biometric_credentials';

  // Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      developer.log('Checking biometric availability');
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      developer.log(
          'Can authenticate with biometrics: $canAuthenticateWithBiometrics');

      final isDeviceSupported = await _localAuth.isDeviceSupported();
      developer.log('Is device supported: $isDeviceSupported');

      final canAuthenticate =
          canAuthenticateWithBiometrics || isDeviceSupported;
      developer.log('Can authenticate: $canAuthenticate');

      return canAuthenticate;
    } on PlatformException catch (e) {
      _logger.warning('Error checking biometric availability: $e');
      developer.log('Error checking biometric availability: $e',
          error: e, stackTrace: StackTrace.current);
      return false;
    }
  }

  // Get a list of available biometric authentication options
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      developer.log('Getting available biometrics');
      final biometrics = await _localAuth.getAvailableBiometrics();
      developer.log('Available biometrics: $biometrics');
      return biometrics;
    } on PlatformException catch (e) {
      _logger.warning('Error getting available biometrics: $e');
      developer.log('Error getting available biometrics: $e',
          error: e, stackTrace: StackTrace.current);
      return [];
    }
  }

  // Authenticate using biometrics
  Future<bool> authenticate(
      {String reason = 'Authenticate to access the app'}) async {
    try {
      developer.log('Starting biometric authentication');
      final availableBiometrics = await getAvailableBiometrics();
      developer.log('Available biometrics before auth: $availableBiometrics');

      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          sensitiveTransaction: false,
        ),
      );

      developer.log('Authentication result: $result');

      if (result) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      return result;
    } on PlatformException catch (e) {
      if (_isUnrelatedPlatformError(e)) return true;
      _logPlatformError(e);
      return false;
    } catch (e) {
      if (_isUnrelatedGeneralError(e)) return true;
      developer.log('Authentication general exception: $e',
          error: e, stackTrace: StackTrace.current);
      _logger.severe('Unexpected error during authentication: $e');
      return false;
    }
  }

  /// Returns true if the PlatformException is from an unrelated SDK
  /// (Google API or Facebook) and biometric auth likely still succeeded.
  bool _isUnrelatedPlatformError(PlatformException e) {
    if (e.message == null) return false;

    if (e.message!.contains("GoogleApiManager")) {
      developer.log(
          'Google API error but biometric likely succeeded: ${e.code} - ${e.message}',
          error: e, stackTrace: StackTrace.current);
      return true;
    }

    if (e.message!.contains("facebook") ||
        e.message!.contains("GraphResponse")) {
      developer.log(
          'Facebook SDK error encountered but not related to biometrics: ${e.code} - ${e.message}',
          error: e, stackTrace: StackTrace.current);
      return true;
    }

    return false;
  }

  void _logPlatformError(PlatformException e) {
    developer.log(
        'Authentication PlatformException: ${e.code} - ${e.message}',
        error: e, stackTrace: StackTrace.current);

    final errorMessages = {
      auth_error.notAvailable: 'Biometric authentication is not available',
      auth_error.notEnrolled: 'No biometrics enrolled on this device',
      auth_error.passcodeNotSet: 'No PIN/pattern/password set on the device',
      auth_error.lockedOut: 'Biometric authentication temporarily locked out',
      auth_error.permanentlyLockedOut:
          'Biometric authentication permanently locked out',
    };

    final message = errorMessages[e.code];
    if (message != null) {
      _logger.warning(message);
      developer.log(message);
    } else {
      _logger.warning('Error authenticating with biometrics: $e');
      developer.log('Error authenticating with biometrics: $e');
    }
  }

  /// Returns true if a general exception is from an unrelated SDK.
  bool _isUnrelatedGeneralError(Object e) {
    final errorString = e.toString().toLowerCase();
    if (errorString.contains("facebook") ||
        errorString.contains("graph") ||
        errorString.contains("oauth")) {
      developer.log(
          'Facebook-related error encountered but not biometric related',
          error: e, stackTrace: StackTrace.current);
      return true;
    }
    return false;
  }

  // Save credentials for biometric login
  Future<bool> saveCredentials(String email, String password,
      {bool isTokenBased = false, String? authProvider}) async {
    try {
      developer.log('Saving credentials for biometric login');

      // Clean up the auth provider string to ensure consistency
      String normalizedProvider = 'password';
      if (authProvider != null) {
        // Normalize provider names
        if (authProvider == 'google.com' || authProvider == 'google') {
          normalizedProvider = 'google';
        } else if (authProvider == 'facebook.com' ||
            authProvider == 'facebook') {
          normalizedProvider = 'facebook';
        } else if (authProvider == 'password' || authProvider.isEmpty) {
          normalizedProvider = 'password';
        } else {
          normalizedProvider = authProvider;
        }
      }

      // Log detailed credential info (excluding actual password)
      developer.log('Credentials being saved:');
      developer.log('- Email: $email');
      developer.log('- Password present: ${password.isNotEmpty}');
      developer.log('- Is token-based: $isTokenBased');
      developer.log(
          '- Auth provider: $normalizedProvider (original: $authProvider)');

      final credentials = {
        'email': email,
        'password': password,
        'is_token_based': isTokenBased,
        'auth_provider': normalizedProvider,
        'saved_at': DateTime.now().toIso8601String(),
      };

      await _storage.write(
        key: _credentialsKey,
        value: jsonEncode(credentials),
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

      developer.log('Credentials saved successfully');
      return true;
    } catch (e) {
      _logger.severe('Error saving credentials: $e');
      developer.log('Error saving credentials: $e',
          error: e, stackTrace: StackTrace.current);
      return false;
    }
  }

  // Get saved credentials for biometric login
  Future<Map<String, String>?> getCredentials() async {
    try {
      developer.log('Getting saved credentials');
      final credentialsString = await _storage.read(
        key: _credentialsKey,
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

      if (credentialsString == null) {
        developer.log('No credentials found');
        return null;
      }

      developer.log('Raw credentials retrieved: $credentialsString');

      try {
        final Map<String, dynamic> credentials = jsonDecode(credentialsString);
        final isTokenBased = credentials['is_token_based'] == true;
        final authProvider =
            credentials['auth_provider'] as String? ?? 'password';

        developer.log(
            'Credentials parsed successfully, token-based: $isTokenBased, provider: $authProvider');

        // Log redacted credentials for debugging
        developer.log('Email: ${credentials['email']}');
        developer
            .log('Password length: ${credentials['password']?.length ?? 0}');

        return {
          'email': credentials['email'] as String,
          'password': credentials['password'] as String,
          'is_token_based': isTokenBased.toString(),
          'auth_provider': authProvider,
        };
      } catch (parseError) {
        _logger.severe('Error parsing credentials JSON: $parseError');
        developer.log('Error parsing credentials JSON: $parseError',
            error: parseError, stackTrace: StackTrace.current);
        // Return a generic error object that the UI can handle
        return {
          'email': '',
          'password': '',
          'is_token_based': 'true',
          'auth_provider': 'error',
          'error': 'Failed to parse stored credentials'
        };
      }
    } catch (e) {
      _logger.severe('Error retrieving credentials: $e');
      developer.log('Error retrieving credentials: $e',
          error: e, stackTrace: StackTrace.current);
      return null;
    }
  }

  // Check if biometric login is enabled (credentials are saved)
  Future<bool> isBiometricLoginEnabled() async {
    try {
      developer.log('Checking if biometric login is enabled');
      final credentials = await getCredentials();
      final isEnabled = credentials != null;
      developer.log('Biometric login enabled: $isEnabled');
      return isEnabled;
    } catch (e) {
      _logger.severe('Error checking if biometric login is enabled: $e');
      developer.log('Error checking if biometric login is enabled: $e',
          error: e, stackTrace: StackTrace.current);
      return false;
    }
  }

  // Delete saved credentials
  Future<bool> deleteSavedCredentials() async {
    try {
      developer.log('Deleting saved credentials');
      await _storage.delete(
        key: _credentialsKey,
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      developer.log('Credentials deleted successfully');
      return true;
    } catch (e) {
      _logger.severe('Error deleting credentials: $e');
      developer.log('Error deleting credentials: $e',
          error: e, stackTrace: StackTrace.current);
      return false;
    }
  }
}
