import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// AuthService maps a plain username to a synthetic email
/// using the pattern: username@periodapp.local
/// and uses Firebase email/password auth under the hood.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String _syntheticEmailFor(String username) => '$username@periodapp.local';

  Future<UserCredential> signUpWithUsername({
    required String username,
    required String password,
  }) async {
    final email = _syntheticEmailFor(username);
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // Optionally set displayName
    await cred.user?.updateDisplayName(username);
    notifyListeners();
    return cred;
  }

  Future<UserCredential> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final email = _syntheticEmailFor(username);
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    notifyListeners();
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}
