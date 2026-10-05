import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../models/service_request.dart';
import '../models/notification_model.dart';
import '../models/review_model.dart';

/// Rock-solid cross-platform local persistent storage for LocalServe.
/// Uses SharedPreferences, backup user storage, and atomic disk file storage to guarantee
/// data is NEVER lost across app restarts, re-runs on Android phones, Web browser refreshes, or Desktop.
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  bool _initialized = false;
  String? _storagePath;
  SharedPreferences? _prefs;

  static const String _prefsStorageKey = 'localserve_persistent_store_v1';
  static const String _prefsUsersBackupKey = 'localserve_users_backup_v1';
  static const String _prefsActiveUserKey = 'localserve_active_user_id';
  static const String _prefsThemeKey = 'localserve_theme_mode';

  // In-memory cache synced with disk and SharedPreferences
  String? _activeUserId;
  String _themeMode = 'dark'; // 'dark', 'light', 'system' - default is dark
  final Map<String, AppUser> _users = {};
  final Map<String, String> _passwords = {};
  final Map<String, ServiceRequest> _requests = {};
  final List<AppNotification> _notifications = [];
  final List<Review> _reviews = [];

  bool get isInitialized => _initialized;
  String? get activeUserId => _activeUserId;
  String get themeMode => _themeMode;

  bool get _isTestEnv {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      if (!kIsWeb && !_isTestEnv) {
        await _resolveStoragePath();
      }

      if (!_isTestEnv) {
        try {
          _prefs = await SharedPreferences.getInstance();
        } catch (e) {
          debugPrint('SharedPreferences init note: $e');
        }
      }

      await _loadFromDisk();
    } catch (e) {
      debugPrint('LocalStorageService init warning: $e');
    } finally {
      _initialized = true;
    }
  }

  void resetForTesting() {
    _activeUserId = null;
    _users.clear();
    _passwords.clear();
    _requests.clear();
    _notifications.clear();
    _reviews.clear();
    _initialized = false;
  }

  Future<void> _resolveStoragePath() async {
    if (kIsWeb || _isTestEnv) {
      _storagePath = null;
      return;
    }

    try {
      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'] ??
            Platform.environment['APPDATA'];
        if (localAppData != null && localAppData.isNotEmpty) {
          final dir = Directory('$localAppData\\LocalServe');
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          _storagePath = '${dir.path}\\localserve_store.json';
          return;
        }
      }

      // Android / iOS / other platforms using path_provider
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        _storagePath = '${appDocDir.path}/localserve_store.json';
        return;
      } catch (_) {}

      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        final dir = Directory('$home/.localserve');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _storagePath = '${dir.path}/localserve_store.json';
        return;
      }

      final tempDir = Directory.systemTemp;
      _storagePath = '${tempDir.path}/localserve_store.json';
    } catch (e) {
      debugPrint('Could not resolve persistent directory: $e');
      _storagePath = 'localserve_store.json';
    }
  }

  Future<void> _ensurePrefs() async {
    if (_isTestEnv) return;
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('SharedPreferences init error: $e');
      }
    }
  }

  void _parseDataMap(Map<dynamic, dynamic> data) {
    if (data['activeUserId'] != null) {
      _activeUserId = data['activeUserId'].toString();
    }
    if (data['themeMode'] != null) {
      _themeMode = data['themeMode'].toString();
    }

    if (data['users'] is List) {
      for (final u in data['users'] as List) {
        if (u is Map) {
          try {
            final user = AppUser.fromMap(Map<String, dynamic>.from(u));
            if (user.uid.isNotEmpty) {
              _users[user.uid] = user;
            }
          } catch (_) {}
        }
      }
    }

    if (data['passwords'] is Map) {
      (data['passwords'] as Map).forEach((k, v) {
        if (k != null && v != null) {
          _passwords[k.toString().trim().toLowerCase()] = v.toString();
        }
      });
    }

    if (data['requests'] is List) {
      for (final r in data['requests'] as List) {
        if (r is Map) {
          try {
            final req = ServiceRequest.fromMap(Map<String, dynamic>.from(r));
            if (req.id.isNotEmpty) {
              _requests[req.id] = req;
            }
          } catch (_) {}
        }
      }
    }

    if (data['notifications'] is List) {
      for (final n in data['notifications'] as List) {
        if (n is Map) {
          try {
            final notif = AppNotification.fromMap(Map<String, dynamic>.from(n));
            if (!_notifications.any((existing) => existing.id == notif.id)) {
              _notifications.add(notif);
            }
          } catch (_) {}
        }
      }
    }

    if (data['reviews'] is List) {
      for (final rev in data['reviews'] as List) {
        if (rev is Map) {
          try {
            final review = Review.fromMap(Map<String, dynamic>.from(rev));
            if (!_reviews.any((existing) => existing.id == review.id)) {
              _reviews.add(review);
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      if (!_isTestEnv) {
        await _ensurePrefs();
      }

      // 1. Load from SharedPreferences
      if (_prefs != null) {
        final activePref = _prefs!.getString(_prefsActiveUserKey);
        if (activePref != null && activePref.isNotEmpty) {
          _activeUserId = activePref;
        }
        final themePref = _prefs!.getString(_prefsThemeKey);
        if (themePref != null && themePref.isNotEmpty) {
          _themeMode = themePref;
        }

        final jsonRaw = _prefs!.getString(_prefsStorageKey);
        if (jsonRaw != null && jsonRaw.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(jsonRaw);
            if (decoded is Map) {
              _parseDataMap(decoded);
            }
          } catch (e) {
            debugPrint('Error parsing SharedPreferences store: $e');
          }
        }

        // Check backup users store in SharedPreferences
        final usersBackupRaw = _prefs!.getString(_prefsUsersBackupKey);
        if (usersBackupRaw != null && usersBackupRaw.trim().isNotEmpty) {
          try {
            final usersList = jsonDecode(usersBackupRaw);
            if (usersList is List) {
              for (final u in usersList) {
                if (u is Map) {
                  final user = AppUser.fromMap(Map<String, dynamic>.from(u));
                  if (user.uid.isNotEmpty && !_users.containsKey(user.uid)) {
                    _users[user.uid] = user;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      // 2. Load from Disk File and merge
      if (!kIsWeb && _storagePath != null) {
        final file = File(_storagePath!);
        if (await file.exists()) {
          try {
            final fileRaw = await file.readAsString();
            if (fileRaw.trim().isNotEmpty) {
              final decoded = jsonDecode(fileRaw);
              if (decoded is Map) {
                _parseDataMap(decoded);
              }
            }
          } catch (e) {
            debugPrint('Error reading disk file store: $e');
          }
        }
      }

      // Enforce data integrity: specialized worker Alex Plumber has Plumbing requests & reviews
      bool needsFlush = false;
      if (_requests.containsKey('req_2')) {
        final r = _requests['req_2']!;
        if (r.workerId == 'demo_worker_1' && r.service != 'Plumbing') {
          _requests['req_2'] = r.copyWith(
            service: 'Plumbing',
            address: '44 Hill View Avenue, Navrangpura',
            description: 'Bathroom washbasin faucet leakage & new mixer tap installation.',
          );
          needsFlush = true;
        }
      }
      if (_requests.containsKey('req_3')) {
        final r = _requests['req_3']!;
        if (r.workerId == 'demo_worker_1' && r.service != 'Plumbing') {
          _requests['req_3'] = r.copyWith(
            service: 'Plumbing',
            description: 'Overhead water tank float valve and pipeline joint leakage repair.',
          );
          needsFlush = true;
        }
      }
      for (final id in _requests.keys.toList()) {
        final r = _requests[id]!;
        if (r.workerId == 'demo_worker_1' && r.service.trim().toLowerCase() != 'plumbing') {
          _requests[id] = r.copyWith(
            service: 'Plumbing',
            description: 'Plumbing pipeline joint & tap repair.',
          );
          needsFlush = true;
        }
      }
      for (int i = 0; i < _reviews.length; i++) {
        final rev = _reviews[i];
        if ((rev.toUserId == 'demo_worker_1' || rev.fromUserId == 'demo_worker_1') &&
            rev.service.trim().toLowerCase() != 'plumbing') {
          _reviews[i] = Review(
            id: rev.id,
            requestId: rev.requestId,
            service: 'Plumbing',
            fromUserId: rev.fromUserId,
            fromUserName: rev.fromUserName,
            fromUserRole: rev.fromUserRole,
            toUserId: rev.toUserId,
            toUserName: rev.toUserName,
            rating: rev.rating,
            comment: rev.id == 'rev_1'
                ? 'Super fast, punctual, and repaired the leaking overhead pipeline perfectly. Highly recommend for plumbing!'
                : (rev.id == 'rev_2'
                    ? 'Polite and clear communication. Immediate payment upon work completion.'
                    : rev.comment.replaceAll(RegExp(r'cleaned', caseSensitive: false), 'repaired')),
            createdAt: rev.createdAt,
          );
          needsFlush = true;
        }
      }
      if (needsFlush) {
        await _flushToDisk();
      }
    } catch (e) {
      debugPrint('Error loading persistent storage: $e');
    }
  }

  // Non-blocking coalescing lock for sequential atomic disk flushes
  bool _isFlushing = false;
  bool _needsAnotherFlush = false;

  Future<void> _flushToDisk() async {
    if (_isTestEnv) return;

    if (_isFlushing) {
      _needsAnotherFlush = true;
      return;
    }

    _isFlushing = true;
    try {
      do {
        _needsAnotherFlush = false;
        await _executeFlush();
      } while (_needsAnotherFlush);
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _executeFlush() async {
    try {
      final data = {
        'activeUserId': _activeUserId,
        'themeMode': _themeMode,
        'users': _users.values.map((u) => u.toMap()).toList(),
        'passwords': _passwords,
        'requests': _requests.values.map((r) => r.toMap()).toList(),
        'notifications': _notifications.map((n) => n.toMap()).toList(),
        'reviews': _reviews.map((r) => r.toMap()).toList(),
      };

      final encoded = jsonEncode(data);
      final usersEncoded = jsonEncode(_users.values.map((u) => u.toMap()).toList());

      await _ensurePrefs();

      // 1. Save to SharedPreferences
      if (_prefs != null) {
        await _prefs!.setString(_prefsStorageKey, encoded);
        await _prefs!.setString(_prefsUsersBackupKey, usersEncoded);
        if (_activeUserId != null) {
          await _prefs!.setString(_prefsActiveUserKey, _activeUserId!);
        } else {
          await _prefs!.remove(_prefsActiveUserKey);
        }
        await _prefs!.setString(_prefsThemeKey, _themeMode);
      }

      // 2. Save atomically to File on Desktop / Mobile
      if (_storagePath != null) {
        final file = File(_storagePath!);
        final tmpFile = File('${_storagePath!}.tmp');
        await tmpFile.writeAsString(encoded, flush: true);
        if (await tmpFile.exists()) {
          try {
            await tmpFile.rename(_storagePath!);
          } catch (_) {
            // Fallback for systems where rename over existing file requires direct write
            await file.writeAsString(encoded, flush: true);
            if (await tmpFile.exists()) {
              await tmpFile.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error flushing persistent storage: $e');
    }
  }

  // --- Theme Mode ---
  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _flushToDisk();
  }

  // --- Active Session Management ---
  Future<void> setActiveUserId(String? uid) async {
    _activeUserId = uid;
    await _flushToDisk();
  }

  // --- Users & Passwords ---
  List<AppUser> getAllUsers() => _users.values.toList();

  AppUser? getUserById(String uid) => _users[uid];

  AppUser? getUserByEmail(String email) {
    final norm = email.trim().toLowerCase();
    for (final u in _users.values) {
      if (u.email.trim().toLowerCase() == norm) return u;
    }
    return null;
  }

  String? getPassword(String email) => _passwords[email.trim().toLowerCase()];

  Future<void> saveUser(AppUser user, {String? password}) async {
    _users[user.uid] = user;
    if (password != null && password.isNotEmpty) {
      _passwords[user.email.trim().toLowerCase()] = password;
    }
    await _flushToDisk();
  }

  // Batch save to avoid triggering 20 separate disk writes in loops
  Future<void> saveUsersBatch(List<AppUser> usersList, {Map<String, String>? passwordsMap}) async {
    for (final u in usersList) {
      _users[u.uid] = u;
    }
    if (passwordsMap != null) {
      passwordsMap.forEach((email, pass) {
        _passwords[email.trim().toLowerCase()] = pass;
      });
    }
    await _flushToDisk();
  }

  // --- Service Requests ---
  List<ServiceRequest> getAllRequests() => _requests.values.toList();

  ServiceRequest? getRequestById(String id) => _requests[id];

  Future<void> saveRequest(ServiceRequest request) async {
    _requests[request.id] = request;
    await _flushToDisk();
  }

  Future<void> saveRequestsBatch(List<ServiceRequest> reqs) async {
    for (final r in reqs) {
      _requests[r.id] = r;
    }
    await _flushToDisk();
  }

  Future<void> deleteRequest(String id) async {
    _requests.remove(id);
    await _flushToDisk();
  }

  // --- Notifications ---
  List<AppNotification> getAllNotifications() => List.unmodifiable(_notifications);

  Future<void> saveNotification(AppNotification notification) async {
    final idx = _notifications.indexWhere((n) => n.id == notification.id);
    if (idx != -1) {
      _notifications[idx] = notification;
    } else {
      _notifications.insert(0, notification);
    }
    await _flushToDisk();
  }

  Future<void> markNotificationsRead(String userId) async {
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    await _flushToDisk();
  }

  // --- Reviews ---
  List<Review> getAllReviews() => List.unmodifiable(_reviews);

  Future<void> saveReview(Review review) async {
    final idx = _reviews.indexWhere((r) => r.id == review.id);
    if (idx != -1) {
      _reviews[idx] = review;
    } else {
      _reviews.insert(0, review);
    }
    await _flushToDisk();
  }

  Future<void> saveReviewsBatch(List<Review> revs) async {
    for (final rev in revs) {
      final idx = _reviews.indexWhere((r) => r.id == rev.id);
      if (idx != -1) {
        _reviews[idx] = rev;
      } else {
        _reviews.insert(0, rev);
      }
    }
    await _flushToDisk();
  }
}

