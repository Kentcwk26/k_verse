import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:k_verse/models/user.dart';

import 'user_repository.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ADD THIS METHOD - This was missing
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  Future<User?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<User?> register(String email, String password, Users userData) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData.copyWith(userId: user.uid).toMap());
    }

    return user;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<User?> loginWithGoogle() async {
    try {
      return await _signInWithGoogle(isRegister: false);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> registerWithGoogle() async {
    try {
      return await _signInWithGoogle(isRegister: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) await _googleSignIn.signOut();
  }

  Future<User?> _signInWithGoogle({required bool isRegister}) async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final userCredential = await _auth.signInWithPopup(googleProvider);

      if (isRegister && userCredential.additionalUserInfo?.isNewUser == false) {
        throw FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message: 'This Google account is already registered. Please log in instead.',
        );
      }

      return userCredential.user;
    } else {
      await _googleSignIn.signOut();
      await _googleSignIn.initialize();

      final GoogleSignInAccount? account = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      if (account == null) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google sign-in cancelled by user.',
        );
      }

      final googleAuth = account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await UserRepository().getOrCreateUserOnLogin(userCredential.user!);

      if (isRegister && userCredential.additionalUserInfo?.isNewUser == false) {
        throw FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message: 'This Google account is already registered. Please log in instead.',
        );
      }

      return userCredential.user;
    }
  }

  Future<User?> getGoogleUserWithoutRegistration() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        await _auth.signOut();
        return userCredential.user;
      } else {
        await _googleSignIn.signOut();
        await _googleSignIn.initialize();

        final GoogleSignInAccount? account = await _googleSignIn.attemptLightweightAuthentication() ?? await _googleSignIn.authenticate(scopeHint: ['email', 'profile']);

        if (account == null) return null;

        final googleAuth = account.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;

        await _auth.signOut();
        await _googleSignIn.signOut();

        return user;
      }
    } catch (e) {
      rethrow;
    }
  }
}