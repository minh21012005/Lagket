import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email + password and create Firestore user doc
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(credential.user!.uid)
        .set({
      'id': credential.user!.uid,
      'email': email,
      'username': username.toLowerCase().trim(),
      'displayUsername': username.trim(),
      'avatarUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send email verification
    await credential.user!.sendEmailVerification();

    return credential;
  }

  /// Sign in with email + password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Reload current user
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final query = await _firestore
        .collection(AppConstants.usersCollection)
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }
}
