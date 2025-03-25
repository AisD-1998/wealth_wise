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
      // Listen for auth state changes
      _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) async {
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
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create an instance of AuthService to handle the Google sign-in
      final authService = AuthService();
      final userCredential = await authService.signInWithGoogle();

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
          _error = 'This email is already in use by another account.';
          break;
        case 'weak-password':
          _error = 'The password is too weak.';
          break;
        case 'operation-not-allowed':
          _error = 'This sign-in method is not enabled.';
          break;
        case 'account-exists-with-different-credential':
          _error =
              'An account already exists with the same email but different sign-in credentials.';
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
