import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:wealth_wise/models/user.dart' as app_user;
import 'package:wealth_wise/services/database_service.dart';

import 'package:wealth_wise/services/auth_service.dart';

// Flag to use demo mode (this should match the flag in main.dart)
const bool useDemo = false;

class AuthProvider with ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();
  app_user.User? _user;
  bool _isLoading = false;
  String? _error;

  // Getters
  app_user.User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  firebase_auth.User? get firebaseUser => _auth.currentUser;

  AuthProvider() {
    _initUser();
  }

  void _initUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if there's already a logged-in user
      firebase_auth.User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get user data from Firestore
        final userData = await _databaseService.getUserData(currentUser.uid);
        if (userData != null) {
          _user = userData;
        }
      }

      // Listen for auth state changes
      _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) async {
        _isLoading = true; // Start loading on state change
        notifyListeners();

        if (firebaseUser != null) {
          // Get user data from Firestore
          final userData = await _databaseService.getUserData(firebaseUser.uid);
          if (userData != null) {
            _user = userData;
          } else {
            // Create new user in Firestore if doesn't exist
            final newUser = app_user.User(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              displayName: firebaseUser.displayName,
              photoUrl: firebaseUser.photoURL,
              phoneNumber: firebaseUser.phoneNumber,
              balance: 0.0,
              createdAt: DateTime.now(),
              lastLoginAt: DateTime.now(),
            );

            await _databaseService.updateUserData(newUser);
            _user = newUser;
          }

          // Initialize default categories if needed
          await _databaseService.initializeDefaultCategories(firebaseUser.uid);
        } else {
          _user = null;
        }

        _isLoading = false;
        _error = null;
        notifyListeners();
      });
    } catch (e) {
      _handleError(e);
    }
  }

  // Set user data manually (used when getting current user in other providers)
  void setUser(app_user.User user) {
    _user = user;
    _error = null;
    notifyListeners();
  }

  // Clear user data (used for sign out)
  void clearUser() {
    _user = null;
    _error = null;
    notifyListeners();
  }

  // Sign up with email and password
  Future<bool> signUp(
      {required String email,
      required String password,
      String? displayName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Update displayName if provided
        if (displayName != null && displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }

        // Initialize default categories
        await _databaseService
            .initializeDefaultCategories(userCredential.user!.uid);

        // User is created in Firestore via the authStateChanges listener
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Update last login time
        if (_user != null) {
          await _databaseService
              .updateUserData(_user!.copyWith(lastLoginAt: DateTime.now()));
        }

        // Initialize default categories if needed
        await _databaseService
            .initializeDefaultCategories(userCredential.user!.uid);

        _isLoading = false;
        notifyListeners();

        // Return success and saved credentials for potential biometric setup
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Sign in with email and password (alias method for login_screen.dart)
  Future<bool> signInWithEmailPassword(String email, String password) async {
    return signIn(email: email, password: password);
  }

  // Sign in with Google
  Future<bool> signInWithGoogle({bool silent = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create an instance of AuthService to handle the Google sign-in
      final authService = AuthService();

      // First attempt to sign in with Google
      final userCredential = await authService.signInWithGoogle(silent: silent);

      if (userCredential.user != null) {
        // Update user's last login time
        if (_user != null) {
          await _databaseService
              .updateUserData(_user!.copyWith(lastLoginAt: DateTime.now()));
        }

        // Initialize default categories if needed
        await _databaseService
            .initializeDefaultCategories(userCredential.user!.uid);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Sign in with Facebook
  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create an instance of AuthService to handle the Facebook sign-in
      final authService = AuthService();
      final userCredential = await authService.signInWithFacebook();

      if (userCredential.user != null) {
        // User data will be loaded via authStateChanges listener
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Register with email and password (for register_screen.dart)
  Future<bool> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    return signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signOut();
      _user = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Update Firebase Auth profile
      if (displayName != null && displayName.isNotEmpty) {
        await _auth.currentUser?.updateDisplayName(displayName);
      }

      if (photoUrl != null && photoUrl.isNotEmpty) {
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }

      // Update user in Firestore
      final updatedUser = _user!.copyWith(
        displayName: displayName ?? _user!.displayName,
        photoUrl: photoUrl ?? _user!.photoUrl,
        phoneNumber: phoneNumber ?? _user!.phoneNumber,
      );

      await _databaseService.updateUserData(updatedUser);
      _user = updatedUser;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Update user balance
  Future<bool> updateBalance(double newBalance) async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = _user!.copyWith(balance: newBalance);
      await _databaseService.updateUserData(updatedUser);
      _user = updatedUser;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Get the last successful email and password for biometric login setup
  String getLastSuccessfulEmail() {
    return _user?.email ?? '';
  }

  // Sign in with token (for biometric authentication)
  Future<bool> signInWithToken(
      {required String email, String? password, String? authProvider}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Normalize the auth provider string
      String normalizedProvider = 'password';
      if (authProvider != null) {
        if (authProvider == 'google.com' || authProvider == 'google') {
          normalizedProvider = 'google';
        } else if (authProvider == 'facebook.com' ||
            authProvider == 'facebook') {
          normalizedProvider = 'facebook';
        } else {
          normalizedProvider = authProvider;
        }
      }

      debugPrint(
          "Auth provider normalized from '$authProvider' to '$normalizedProvider'");

      // Check if the user is already authenticated
      if (_auth.currentUser != null && _auth.currentUser!.email == email) {
        debugPrint("User already signed in with correct account");
        _isLoading = false;
        notifyListeners();
        return true;
      }

      debugPrint(
          "Attempting to sign in with biometric auth: $email (provider: $normalizedProvider)");

      // APPROACH 1: If we have a password for email/password, use it
      if (normalizedProvider == 'password' &&
          password != null &&
          password.isNotEmpty &&
          password != '##TOKEN_BASED_AUTH##') {
        debugPrint("Using stored password for email/password authentication");
        try {
          final userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (userCredential.user != null) {
            debugPrint("Successfully signed in with stored email/password");
            _isLoading = false;
            notifyListeners();
            return true;
          }
        } catch (credentialError) {
          debugPrint(
              "Error signing in with stored credentials: $credentialError");
          _error =
              "Invalid email or password. Please try again with your regular login.";
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // APPROACH 2: Try provider-specific authentication
      if (normalizedProvider == 'google') {
        debugPrint("Attempting Google authentication for biometric login");
        try {
          // First try silent mode
          final success = await signInWithGoogle(silent: true);
          if (success) {
            debugPrint("Successfully signed in with Google silently");
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            // If silent mode failed, try regular sign-in
            debugPrint(
                "Silent Google sign-in failed, trying regular Google sign-in");
            final regularSuccess = await signInWithGoogle(silent: false);
            if (regularSuccess) {
              debugPrint("Successfully signed in with regular Google sign-in");
              _isLoading = false;
              notifyListeners();
              return true;
            }
          }
        } catch (providerError) {
          debugPrint("Error with Google authentication: $providerError");
          _error =
              "Google authentication failed. Please try again with your regular login.";
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else if (normalizedProvider == 'facebook') {
        debugPrint("Attempting Facebook authentication for biometric login");
        try {
          final success = await signInWithFacebook();
          if (success) {
            debugPrint("Successfully signed in with Facebook");
            _isLoading = false;
            notifyListeners();
            return true;
          }
        } catch (providerError) {
          debugPrint("Error with Facebook authentication: $providerError");
          _error =
              "Facebook authentication failed. Please try again with your regular login.";
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // APPROACH 3: For demo purposes only
      if (useDemo) {
        debugPrint("Using demo mode for biometric login");
        try {
          await _auth.signInAnonymously();
          debugPrint("Demo auth successful (anonymous)");
          _isLoading = false;
          notifyListeners();
          return true;
        } catch (demoError) {
          debugPrint("Demo auth failed: $demoError");
        }
      }

      // All authentication methods failed
      _error =
          "Biometric login failed. Please sign in with your regular method.";
      debugPrint(
          "All authentication methods failed for provider: $normalizedProvider");
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Sign up with Google (check if account exists first)
  Future<bool> signUpWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create an instance of AuthService to handle the Google sign-in
      final authService = AuthService();

      // First check if there's an existing account by attempting sign-in
      try {
        final userCredential = await authService.signInWithGoogle(silent: true);

        // If we get here without errors, the account exists and we're signed in
        if (userCredential.user != null) {
          // Set error message to notify caller that the account exists
          _error = 'This email is already registered. Please sign in instead.';
          _isLoading = false;
          notifyListeners();

          // Sign out immediately since this is a sign-up attempt
          await _auth.signOut();
          return false;
        }
      } catch (e) {
        // Ignore errors here as they likely mean the account doesn't exist
        // or the user canceled the Google sign-in flow
      }

      // Proceed with normal Google sign-in for new registration
      final userCredential = await authService.signInWithGoogle();

      // Check if this is actually a new user or an existing one
      debugPrint(
          "Google auth - isNewUser: ${userCredential.additionalUserInfo?.isNewUser}");
      if (userCredential.additionalUserInfo?.isNewUser == false) {
        // This is an existing account, not a new user
        debugPrint("Google auth - Existing account detected, signing out");
        _error = 'This email is already registered. Please sign in instead.';
        _isLoading = false;
        notifyListeners();

        // Sign out immediately since this is a sign-up attempt
        await _auth.signOut();
        return false;
      }

      if (userCredential.user != null) {
        // Update user's last login time
        if (_user != null) {
          await _databaseService
              .updateUserData(_user!.copyWith(lastLoginAt: DateTime.now()));
        }

        // Initialize default categories if needed
        await _databaseService
            .initializeDefaultCategories(userCredential.user!.uid);

        // Force refresh user data
        final userData =
            await _databaseService.getUserData(userCredential.user!.uid);
        if (userData != null) {
          _user = userData;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Sign up with Facebook (check if account exists first)
  Future<bool> signUpWithFacebook() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create an instance of AuthService to handle the Facebook sign-in
      final authService = AuthService();

      // First check if there's an existing account by attempting sign-in
      try {
        final userCredential = await authService.signInWithFacebook();

        // If we get here without errors, the account exists and we're signed in
        if (userCredential.user != null) {
          // Set error message to notify caller that the account exists
          _error = 'This email is already registered. Please sign in instead.';
          _isLoading = false;
          notifyListeners();

          // Sign out immediately since this is a sign-up attempt
          await _auth.signOut();
          return false;
        }
      } catch (e) {
        // Silently catch errors here as it means the account doesn't exist
        // or the user canceled the Facebook sign-in flow
      }

      // Proceed with normal Facebook sign-in for new registration
      final userCredential = await authService.signInWithFacebook();

      // Check if this is actually a new user or an existing one
      debugPrint(
          "Facebook auth - isNewUser: ${userCredential.additionalUserInfo?.isNewUser}");
      if (userCredential.additionalUserInfo?.isNewUser == false) {
        // This is an existing account, not a new user
        debugPrint("Facebook auth - Existing account detected, signing out");
        _error = 'This email is already registered. Please sign in instead.';
        _isLoading = false;
        notifyListeners();

        // Sign out immediately since this is a sign-up attempt
        await _auth.signOut();
        return false;
      }

      if (userCredential.user != null) {
        // User data will be loaded via authStateChanges listener
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  void _handleError(dynamic e) {
    _isLoading = false;
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          _error = 'The email address is badly formatted.';
          break;
        case 'user-disabled':
          _error = 'This user has been disabled. Please contact support.';
          break;
        case 'user-not-found':
          _error = 'No user found with this email.';
          break;
        case 'wrong-password':
          _error = 'Incorrect password. Please try again.';
          break;
        case 'email-already-in-use':
          _error = 'This email is already registered. Please sign in instead.';
          break;
        case 'weak-password':
          _error = 'The password is too weak.';
          break;
        case 'operation-not-allowed':
          _error = 'This sign-in method is not enabled.';
          break;
        case 'account-exists-with-different-credential':
          _error =
              'An account already exists with this email. Please sign in using the method you originally registered with (email/password, Google, or Facebook).';
          break;
        case 'invalid-credential':
          _error = 'The credential is malformed or has expired.';
          break;
        default:
          _error = e.message ?? 'Authentication error occurred';
      }
    } else if (e.toString().contains('MissingPluginException')) {
      _error = 'Plugin not configured correctly. Please check the setup.';
    } else if (e.toString().contains('ApiException: 10')) {
      _error =
          'Google Sign-In requires proper SHA1 fingerprint in Firebase console.';
    } else {
      _error = e.toString();
    }
    debugPrint('Auth error: $_error');
    notifyListeners();
  }
}
