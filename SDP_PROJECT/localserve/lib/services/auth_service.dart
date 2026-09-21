import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isFirebaseInitialized = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isFirebaseInitialized => _isFirebaseInitialized;

  // Predefined mock users for quick 1-click testing & demo
  static final List<AppUser> demoUsers = [
    const AppUser(
      uid: 'demo_customer_1',
      email: 'customer@localserve.com',
      name: 'John Customer',
      mobile: '9876543210',
      role: UserRole.customer,
    ),
    const AppUser(
      uid: 'demo_worker_1',
      email: 'worker@localserve.com',
      name: 'Alex Plumber',
      mobile: '9123456780',
      role: UserRole.worker,
      workerSkill: 'Plumbing',
    ),
    const AppUser(
      uid: 'demo_admin_1',
      email: 'admin@localserve.com',
      name: 'Admin Supervisor',
      mobile: '9998887776',
      role: UserRole.admin,
    ),
  ];

  AuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
        // Listen to Firebase Auth state
        fb_auth.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
          if (fbUser != null) {
            await _fetchUserProfile(fbUser.uid);
          } else {
            _currentUser = null;
            _isLoading = false;
            notifyListeners();
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('Firebase not configured or initialized yet: $e');
    }

    // Default to demo mode if Firebase is not linked
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _currentUser = AppUser.fromMap(doc.data()!, uid: uid);
      } else {
        // Fallback default customer profile if doc does not exist
        final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
        _currentUser = AppUser(
          uid: uid,
          email: fbUser?.email ?? '',
          name: fbUser?.displayName ?? 'User',
          mobile: fbUser?.phoneNumber ?? '',
          role: UserRole.customer,
        );
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // SIGN IN
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseInitialized) {
        final credential = await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        if (credential.user != null) {
          await _fetchUserProfile(credential.user!.uid);
        }
      } else {
        // Mock fallback check
        await Future.delayed(const Duration(milliseconds: 600));
        final matched = demoUsers.firstWhere(
          (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
          orElse: () => AppUser(
            uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
            email: email.trim(),
            name: email.split('@').first,
            mobile: '9876543210',
            role: email.toLowerCase().contains('admin')
                ? UserRole.admin
                : (email.toLowerCase().contains('worker')
                    ? UserRole.worker
                    : UserRole.customer),
          ),
        );
        _currentUser = matched;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // SIGN UP
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String mobile,
    required UserRole role,
    String? workerSkill,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseInitialized) {
        final credential = await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        if (credential.user != null) {
          final newUser = AppUser(
            uid: credential.user!.uid,
            email: email.trim(),
            name: name.trim(),
            mobile: mobile.trim(),
            role: role,
            workerSkill: workerSkill,
            createdAt: DateTime.now(),
          );

          // Save user in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(newUser.uid)
              .set(newUser.toMap());

          _currentUser = newUser;
        }
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 600));
        _currentUser = AppUser(
          uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
          email: email.trim(),
          name: name.trim(),
          mobile: mobile.trim(),
          role: role,
          workerSkill: workerSkill,
          createdAt: DateTime.now(),
        );
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // QUICK DEMO SIGN IN
  void signInWithDemoUser(AppUser demoUser) {
    _currentUser = demoUser;
    _isLoading = false;
    notifyListeners();
  }

  // SIGN OUT
  Future<void> signOut() async {
    if (_isFirebaseInitialized) {
      await fb_auth.FirebaseAuth.instance.signOut();
    }
    _currentUser = null;
    notifyListeners();
  }
}
