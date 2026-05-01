import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/connectivity_service.dart';
import '../data/local/database_helper.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();
  final _db = DatabaseHelper.instance;

  UserModel? _currentUser;  // Currently logged in user
  bool _isLoading = false;  // Show loading spinner or not

  // Getters — other files can read these but not change them directly
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  // =====================
  // SIGN UP
  // =====================
  Future<String?> signUp(String name, String email, String password) async {
    _setLoading(true);
    final online = await _connectivity.isOnline();

    if (online) {
      try {
        // Create user in Firebase Auth
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Create user model
        final user = UserModel(
          id: credential.user!.uid,
          name: name,
          email: email,
          password: password,
        );

        // Save to Firestore (no password)
        await _firestore
            .collection('users')
            .doc(user.id)
            .set(user.toFirestoreMap());

        // Save to local database (with password for offline login)
        await _db.insertUser(user);

        _currentUser = user;
        _setLoading(false);
        notifyListeners();
        return null; // null means success

      } on FirebaseAuthException catch (e) {
        _setLoading(false);
        return _handleFirebaseError(e.code);
      }
    } else {
      // Offline signup — save locally only
      final user = UserModel(
        id: const Uuid().v4(), // Generate a random ID
        name: name,
        email: email,
        password: password,
      );
      await _db.insertUser(user);
      _currentUser = user;
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  // =====================
  // LOGIN
  // =====================
  Future<String?> login(String email, String password) async {
    _setLoading(true);
    final online = await _connectivity.isOnline();

    if (online) {
      try {
        // Login with Firebase Auth
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Get user details from Firestore
        final doc = await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        final user = UserModel(
          id: credential.user!.uid,
          name: doc.data()?['name'] ?? 'User',
          email: email,
          password: password,
        );

        // Update local database with latest info
        await _db.insertUser(user);

        _currentUser = user;
        _setLoading(false);
        notifyListeners();
        return null; // null means success

      } on FirebaseAuthException catch (e) {
        _setLoading(false);
        return _handleFirebaseError(e.code);
      }
    } else {
      // Offline login — check local database
      final user = await _db.getUser(email, password);
      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        notifyListeners();
        return null;
      } else {
        _setLoading(false);
        return 'No internet connection and user not found locally.';
      }
    }
  }

  // =====================
  // LOGOUT
  // =====================
  Future<void> logout() async {
    final online = await _connectivity.isOnline();
    if (online) await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // =====================
  // AUTO LOGIN
  // (check if user is already logged in when app starts)
  // =====================
  Future<void> checkCurrentUser() async {
    final online = await _connectivity.isOnline();
    if (online) {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: doc.data()?['name'] ?? 'User',
          email: firebaseUser.email ?? '',
          password: '',
        );
        notifyListeners();
      }
    }
  }

  // =====================
  // HELPERS
  // =====================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Convert Firebase error codes to readable messages
  String _handleFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}