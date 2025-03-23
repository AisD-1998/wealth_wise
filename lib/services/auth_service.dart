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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in was cancelled by the user');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        // Create user document in Firestore
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
        });
      }

      return userCredential;
    } catch (e) {
      _logger.warning('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign in with Facebook
  Future<UserCredential> signInWithFacebook() async {
    try {
      final LoginResult result = await _facebookAuth.login();

      if (result.status != LoginStatus.success) {
        throw Exception('Facebook sign in was not successful');
      }

      final AccessToken? accessToken = result.accessToken;

      final credential = FacebookAuthProvider.credential(accessToken!.token);

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        // Create user document in Firestore
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'facebook',
        });
      }

      return userCredential;
    } catch (e) {
      _logger.warning('Error signing in with Facebook: $e');
      rethrow;
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
