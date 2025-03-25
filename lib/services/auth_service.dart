import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wealth_wise/models/user.dart' as app_user;
import 'package:logging/logging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FacebookAuth _facebookAuth = FacebookAuth.instance;
  final Logger _logger = Logger('AuthService');

  // Get the current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get the current user
  Future<app_user.User?> getCurrentUser() async {
    User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    // Get user data from Firestore
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (doc.exists) {
        return app_user.User.fromMap(
            doc.data() as Map<String, dynamic>, firebaseUser.uid);
      } else {
        // Create a new user if not exists in Firestore
        app_user.User newUser = app_user.User(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName,
          photoUrl: firebaseUser.photoURL,
          balance: 0.0,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        // Save the new user to Firestore
        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(newUser.toMap());

        return newUser;
      }
    } catch (e) {
      _logger.severe('Error getting user data: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<app_user.User?> signInWithEmailPassword(
      String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await getCurrentUser();
    } catch (e) {
      _logger.severe('Error signing in with email and password: $e');
      rethrow;
    }
  }

  // Register with email and password
  Future<app_user.User?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      // Update the Firebase Auth user display name
      await user?.updateDisplayName(displayName);

      // Create a new user document in Firestore
      if (user != null) {
        app_user.User newUser = app_user.User(
          uid: user.uid,
          email: email,
          displayName: displayName,
          photoUrl: null,
          balance: 0.0,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());

        return newUser;
      }
      return null;
    } catch (e) {
      _logger.severe('Error registering with email and password: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      _logger.info('Starting Google sign in process');

      // Check if Google Play Services are available (on Android)
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _logger.warning('Google sign in was cancelled by the user');
        throw Exception('Google sign in was cancelled by the user');
      }

      _logger.info('Google user selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        _logger.severe('Missing Google Auth Token');
        throw Exception('Missing Google Auth Token');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      _logger.info('Signing in to Firebase with Google credential');
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        _logger.info(
            'New user signed in with Google, creating Firestore document');
        // Create user document in Firestore
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
          'photoUrl': userCredential.user?.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
          'balance': 0.0,
        });
      }

      _logger.info('Google sign in successful');
      return userCredential;
    } catch (e) {
      _logger.severe('Error signing in with Google: $e');
      throw Exception('Google sign in failed: $e');
    }
  }

  // Sign in with Facebook
  Future<UserCredential> signInWithFacebook() async {
    try {
      _logger.info('Starting Facebook sign in process');

      // Attempt to log in
      final LoginResult result = await _facebookAuth.login();

      _logger.info('Facebook login result: ${result.status}');

      if (result.status != LoginStatus.success) {
        if (result.status == LoginStatus.cancelled) {
          _logger.warning('Facebook sign in was cancelled by the user');
          throw Exception('Facebook sign in was cancelled by the user');
        } else {
          _logger
              .severe('Facebook sign in failed with status: ${result.status}');
          throw Exception(
              'Facebook sign in failed with status: ${result.status}');
        }
      }

      final AccessToken? accessToken = result.accessToken;

      if (accessToken == null || accessToken.token.isEmpty) {
        _logger.severe('No Facebook access token available');
        throw Exception('No Facebook access token available');
      }

      _logger.info('Got Facebook access token, signing in to Firebase');

      final credential = FacebookAuthProvider.credential(accessToken.token);

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        _logger.info(
            'New user signed in with Facebook, creating Firestore document');
        // Create user document in Firestore
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
          'photoUrl': userCredential.user?.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'facebook',
          'balance': 0.0,
        });
      }

      _logger.info('Facebook sign in successful');
      return userCredential;
    } catch (e) {
      _logger.severe('Error signing in with Facebook: $e');
      throw Exception('Facebook sign in failed: $e');
    }
  }

  // Update user profile - renamed to match AuthProvider
  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
    String? currency,
    bool? useBiometrics,
    bool? usePin,
    String? pin,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('User not found');
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore document
      await _firestore.collection('users').doc(userId).update({
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (currency != null) 'currency': currency,
        if (useBiometrics != null) 'useBiometrics': useBiometrics,
        if (usePin != null) 'usePin': usePin,
        if (pin != null) 'pin': pin,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.warning('Error updating profile: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await _facebookAuth.logOut();
    } catch (e) {
      _logger.severe('Error signing out: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      _logger.warning('Error sending password reset email: $e');
      rethrow;
    }
  }
}
