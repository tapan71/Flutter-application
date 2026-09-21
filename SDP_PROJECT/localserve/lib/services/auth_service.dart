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
  bool _isRegistering = false;

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
  ];

  // In-memory registry of all registered users (demo users + newly registered)
  static final List<AppUser> _registeredUsers = [
    ...demoUsers,
  ];

  static final Map<String, String> _mockPasswords = {
    'customer@localserve.com': 'password',
    'worker@localserve.com': 'password',
  };

  AuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
        fb_auth.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
          // If we are in the middle of a registration call, wait for the Firestore doc to write
          if (_isRegistering) return;

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

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchUserProfile(String uid) async {
    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      // If document does not exist yet (e.g. slight write delay), wait and retry once
      if (!doc.exists) {
        await Future.delayed(const Duration(milliseconds: 500));
        doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      }

      if (doc.exists && doc.data() != null) {
        _currentUser = AppUser.fromMap(doc.data()!, uid: uid);
      } else {
        // Look up in local registered users cache before falling back
        final cached = _registeredUsers.firstWhere(
          (u) => u.uid == uid,
          orElse: () {
            final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
            return AppUser(
              uid: uid,
              email: fbUser?.email ?? '',
              name: fbUser?.displayName ?? 'User',
              mobile: fbUser?.phoneNumber ?? '',
              role: UserRole.customer,
            );
          },
        );
        _currentUser = cached;
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
        // Mock fallback mode: Look up in registered users
        await Future.delayed(const Duration(milliseconds: 400));
        final normalizedEmail = email.trim().toLowerCase();

        final matchIndex = _registeredUsers.indexWhere(
          (u) => u.email.toLowerCase() == normalizedEmail,
        );

        if (matchIndex != -1) {
          // Verify password if one was set during registration
          final savedPassword = _mockPasswords[normalizedEmail];
          if (savedPassword != null && savedPassword != password) {
            throw Exception('Invalid password. Please try again.');
          }
          _currentUser = _registeredUsers[matchIndex];
        } else {
          // If the user was not registered yet, create and remember them
          final inferredRole = email.toLowerCase().contains('worker')
              ? UserRole.worker
              : UserRole.customer;

          final newUser = AppUser(
            uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
            email: email.trim(),
            name: email.split('@').first,
            mobile: '9876543210',
            role: inferredRole,
            workerSkill: inferredRole == UserRole.worker ? 'General Service' : null,
          );

          _registeredUsers.add(newUser);
          _mockPasswords[normalizedEmail] = password;
          _currentUser = newUser;
        }

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
    _isRegistering = true;
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
          _registeredUsers.add(newUser);
        }
      } else {
        // Mock fallback mode: Save into _registeredUsers
        await Future.delayed(const Duration(milliseconds: 400));
        final normalizedEmail = email.trim().toLowerCase();

        // Check if already registered
        if (_registeredUsers.any((u) => u.email.toLowerCase() == normalizedEmail)) {
          throw Exception('An account with this email already exists.');
        }

        final newUser = AppUser(
          uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
          email: email.trim(),
          name: name.trim(),
          mobile: mobile.trim(),
          role: role,
          workerSkill: workerSkill,
          createdAt: DateTime.now(),
        );

        _registeredUsers.add(newUser);
        _mockPasswords[normalizedEmail] = password;
        _currentUser = newUser;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isRegistering = false;
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
