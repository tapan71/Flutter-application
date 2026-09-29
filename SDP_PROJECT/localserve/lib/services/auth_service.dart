import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'local_storage_service.dart';

class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isFirebaseInitialized = false;
  bool _isRegistering = false;
  final LocalStorageService _storage = LocalStorageService();

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
      address: '102 Green Heights, 5th Main Road',
      latitude: 23.0225,
      longitude: 72.5714,
      role: UserRole.customer,
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      rating: 5.0,
      ratingCount: 6,
      completedJobsCount: 8,
    ),
    const AppUser(
      uid: 'demo_worker_1',
      email: 'worker@localserve.com',
      name: 'Alex Plumber',
      mobile: '9123456780',
      address: 'Shop 12, Market Complex, West Side',
      latitude: 23.0260,
      longitude: 72.5760,
      role: UserRole.worker,
      workerSkill: 'Plumbing',
      avatarUrl: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=150',
      bio: 'Certified Master Plumber with 9 years of residential & commercial experience in Ahmedabad. Quick response, transparent pricing, and leak repair specialist.',
      rating: 4.9,
      ratingCount: 18,
      completedJobsCount: 24,
    ),
    const AppUser(
      uid: 'demo_worker_2',
      email: 'david.plumber@localserve.com',
      name: 'David Mehta',
      mobile: '9811223399',
      address: 'Paldi Cross Road, Ahmedabad',
      latitude: 23.0130,
      longitude: 72.5620,
      role: UserRole.worker,
      workerSkill: 'Plumbing',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      bio: 'Expert plumbing & sanitary technician. Specializing in pipeline fitting, bathroom fixtures, and emergency blockages.',
      rating: 4.7,
      ratingCount: 12,
      completedJobsCount: 15,
    ),
  ];

  final List<AppUser> _registeredUsers = [];

  AuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Initialize persistent storage
    await _storage.init();

    // 2. Load registered users from disk
    final savedUsers = _storage.getAllUsers();
    if (savedUsers.isEmpty) {
      // Seed default demo users
      for (final demo in demoUsers) {
        _registeredUsers.add(demo);
        await _storage.saveUser(demo, password: 'password');
      }
    } else {
      _registeredUsers.addAll(savedUsers);
      // Ensure demo users are present
      for (final demo in demoUsers) {
        if (!_registeredUsers.any((u) => u.uid == demo.uid)) {
          _registeredUsers.add(demo);
          await _storage.saveUser(demo, password: 'password');
        }
      }
    }

    // 3. Restore active session if available
    final activeId = _storage.activeUserId;
    if (activeId != null) {
      final savedUser = _storage.getUserById(activeId);
      if (savedUser != null) {
        _currentUser = savedUser;
      }
    }

    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
        fb_auth.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
          if (_isRegistering) return;

          if (fbUser != null) {
            await _fetchUserProfile(fbUser.uid);
          } else if (!_storage.isInitialized || _storage.activeUserId == null) {
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

      if (!doc.exists) {
        await Future.delayed(const Duration(milliseconds: 500));
        doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      }

      if (doc.exists && doc.data() != null) {
        _currentUser = AppUser.fromMap(doc.data()!, uid: uid);
        await _storage.saveUser(_currentUser!);
        await _storage.setActiveUserId(_currentUser!.uid);
      } else {
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
        await _storage.saveUser(cached);
        await _storage.setActiveUserId(cached.uid);
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
        // Mock / Offline persistent mode
        await Future.delayed(const Duration(milliseconds: 250));
        final normalizedEmail = email.trim().toLowerCase();

        // 1. Look up in registered users or storage
        var user = _storage.getUserByEmail(normalizedEmail);
        user ??= _registeredUsers.cast<AppUser?>().firstWhere(
              (u) => u?.email.toLowerCase() == normalizedEmail,
              orElse: () => null,
            );

        if (user != null) {
          final savedPassword = _storage.getPassword(normalizedEmail);
          if (savedPassword != null && savedPassword != password) {
            throw Exception('Invalid password. Please try again.');
          }
          _currentUser = user;
          await _storage.setActiveUserId(user.uid);
        } else {
          // If trying demo emails
          if (normalizedEmail == 'customer@localserve.com') {
            _currentUser = demoUsers[0];
            await _storage.setActiveUserId(_currentUser!.uid);
          } else if (normalizedEmail == 'worker@localserve.com') {
            _currentUser = demoUsers[1];
            await _storage.setActiveUserId(_currentUser!.uid);
          } else {
            throw Exception('No account found for "$email". Please register first to set up your mobile number and address.');
          }
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
    String? address,
    double? latitude,
    double? longitude,
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
            address: address?.trim(),
            latitude: latitude,
            longitude: longitude,
            role: role,
            workerSkill: workerSkill,
            createdAt: DateTime.now(),
          );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(newUser.uid)
              .set(newUser.toMap());

          _currentUser = newUser;
          _registeredUsers.add(newUser);
          await _storage.saveUser(newUser, password: password);
          await _storage.setActiveUserId(newUser.uid);
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 250));
        final normalizedEmail = email.trim().toLowerCase();

        if (_registeredUsers.any((u) => u.email.toLowerCase() == normalizedEmail)) {
          throw Exception('An account with this email already exists.');
        }

        final newUser = AppUser(
          uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
          email: email.trim(),
          name: name.trim(),
          mobile: mobile.trim(),
          address: address?.trim(),
          latitude: latitude,
          longitude: longitude,
          role: role,
          workerSkill: workerSkill,
          createdAt: DateTime.now(),
        );

        _registeredUsers.add(newUser);
        _currentUser = newUser;
        await _storage.saveUser(newUser, password: password);
        await _storage.setActiveUserId(newUser.uid);
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
  Future<void> signInWithDemoUser(AppUser demoUser) async {
    _currentUser = demoUser;
    _isLoading = false;
    await _storage.saveUser(demoUser);
    await _storage.setActiveUserId(demoUser.uid);
    notifyListeners();
  }

  // SIGN OUT
  Future<void> signOut() async {
    if (_isFirebaseInitialized) {
      await fb_auth.FirebaseAuth.instance.signOut();
    }
    _currentUser = null;
    await _storage.setActiveUserId(null);
    notifyListeners();
  }

  // UPDATE FULL USER PROFILE (NAME, MOBILE, ADDRESS, COORDINATES, BIO, SKILL)
  Future<void> updateUserProfile({
    required String name,
    required String mobile,
    required String address,
    double? latitude,
    double? longitude,
    String? workerSkill,
    String? bio,
  }) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      name: name.trim(),
      mobile: mobile.trim(),
      address: address.trim(),
      latitude: latitude ?? _currentUser!.latitude,
      longitude: longitude ?? _currentUser!.longitude,
      workerSkill: workerSkill ?? _currentUser!.workerSkill,
      bio: bio ?? _currentUser!.bio,
    );

    _currentUser = updated;

    // Update in memory registry
    final idx = _registeredUsers.indexWhere((u) => u.uid == updated.uid);
    if (idx != -1) {
      _registeredUsers[idx] = updated;
    } else {
      _registeredUsers.add(updated);
    }

    // Persist to disk
    await _storage.saveUser(updated);

    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(updated.uid).update({
          'name': updated.name,
          'mobile': updated.mobile,
          'address': updated.address,
          'latitude': updated.latitude,
          'longitude': updated.longitude,
          'workerSkill': updated.workerSkill,
          'bio': updated.bio,
        });
      } catch (e) {
        debugPrint('Error updating user profile in Firestore: $e');
      }
    }

    notifyListeners();
  }

  // UPDATE LOCATION
  Future<void> updateCurrentUserLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );

    _currentUser = updated;

    final idx = _registeredUsers.indexWhere((u) => u.uid == updated.uid);
    if (idx != -1) {
      _registeredUsers[idx] = updated;
    } else {
      _registeredUsers.add(updated);
    }

    await _storage.saveUser(updated);

    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(updated.uid).update({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        });
      } catch (e) {
        debugPrint('Error updating user location in Firestore: $e');
      }
    }

    notifyListeners();
  }
}
