import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../models/review_model.dart';
import '../models/notification_model.dart';
import 'local_storage_service.dart';
import 'email_service.dart';

class DatabaseService extends ChangeNotifier {
  bool _isFirebaseInitialized = false;
  final LocalStorageService _storage = LocalStorageService();

  /// Maximum allowed radius (in kilometers) for a worker to accept a customer service request
  static const double maxWorkerDistanceKm = 20.0;

  /// Calculate geodesic distance in kilometers between two points
  double? calculateDistanceKm({
    required double? lat1,
    required double? lon1,
    required double? lat2,
    required double? lon2,
  }) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
    const distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  /// Fixed condition assessment & inspection charge: ₹100
  static const double inspectionFee = 100.0;

  /// Extra service charge based on distance from worker's location to customer's location:
  /// Under 10 km: ₹250
  /// Under 20 km: ₹500
  static double calculateDistanceFee(double? distanceKm) {
    if (distanceKm == null || distanceKm <= 10.0) {
      return 250.0;
    } else {
      return 500.0;
    }
  }

  // Initial seed data
  static final List<ServiceRequest> _defaultRequests = [
    ServiceRequest(
      id: 'req_1',
      service: 'Plumbing',
      name: 'John Customer',
      email: 'customer@localserve.com',
      mobile: '9876543210',
      address: '102 Green Heights, 5th Main Road',
      latitude: 23.0225,
      longitude: 72.5714,
      priority: 'High',
      reminder: true,
      description: 'Leaking kitchen pipe under sink requires urgent repair.',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      status: 'pending',
      customerId: 'demo_customer_1',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      applicantWorkerIds: ['demo_worker_1', 'demo_worker_2'],
    ),
    ServiceRequest(
      id: 'req_2',
      service: 'Plumbing',
      name: 'Sarah Connor',
      email: 'sarah@example.com',
      mobile: '9811223344',
      address: '44 Hill View Avenue, Navrangpura',
      latitude: 23.0338,
      longitude: 72.5850,
      priority: 'Medium',
      reminder: false,
      description: 'Bathroom washbasin faucet leakage & new mixer tap installation.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      status: 'assigned',
      customerId: 'demo_customer_2',
      workerId: 'demo_worker_1',
      workerName: 'Alex Plumber',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    ServiceRequest(
      id: 'req_3',
      service: 'Plumbing',
      name: 'John Customer',
      email: 'customer@localserve.com',
      mobile: '9876543210',
      address: '102 Green Heights, 5th Main Road',
      latitude: 23.0225,
      longitude: 72.5714,
      priority: 'Low',
      reminder: false,
      description: 'Overhead water tank float valve and pipeline joint leakage repair.',
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
      status: 'completed',
      customerId: 'demo_customer_1',
      workerId: 'demo_worker_1',
      workerName: 'Alex Plumber',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      customerReviewed: true,
      workerReviewed: true,
    ),
    ServiceRequest(
      id: 'req_4',
      service: 'Painting',
      name: 'Ramesh Patel',
      email: 'ramesh.patel@example.com',
      mobile: '9822334455',
      address: 'Station Road, Sayajigunj, Vadodara (~100km away)',
      latitude: 22.3072,
      longitude: 73.1812,
      priority: 'Medium',
      reminder: false,
      description: 'Apartment interior wall painting (outside Ahmedabad 20km worker service area).',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      status: 'pending',
      customerId: 'demo_customer_3',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    ServiceRequest(
      id: 'req_5',
      service: 'Electrical',
      name: 'Pooja Shah',
      email: 'pooja.shah@example.com',
      mobile: '9899112233',
      address: 'Drive-in Road, Memnagar, Ahmedabad',
      latitude: 23.0450,
      longitude: 72.5300,
      priority: 'High',
      reminder: true,
      description: 'Living room short-circuit and main circuit breaker replacement.',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      status: 'pending',
      customerId: 'demo_customer_4',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ServiceRequest(
      id: 'req_clean_1',
      service: 'Cleaning',
      name: 'Kavita Patel',
      email: 'kavita@example.com',
      mobile: '9822446688',
      address: '302 Shivalik Residency, Bodakdev, Ahmedabad',
      latitude: 23.0390,
      longitude: 72.5120,
      priority: 'Low',
      reminder: false,
      description: 'Deep 3BHK apartment sanitization and balcony cleaning before family function.',
      dueDate: DateTime.now().subtract(const Duration(days: 5)),
      status: 'completed',
      customerId: 'demo_customer_1',
      workerId: 'demo_worker_5',
      workerName: 'Anita Verma',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      customerReviewed: true,
      workerReviewed: true,
    ),
    ServiceRequest(
      id: 'req_elec_1',
      service: 'Electrical',
      name: 'Sarah Connor',
      email: 'sarah@example.com',
      mobile: '9811223344',
      address: '44 Hill View Avenue, Navrangpura',
      latitude: 23.0338,
      longitude: 72.5850,
      priority: 'Medium',
      reminder: false,
      description: 'Living room ceiling fan regulator sparking & switchboard upgrade.',
      dueDate: DateTime.now().subtract(const Duration(days: 4)),
      status: 'completed',
      customerId: 'demo_customer_2',
      workerId: 'demo_worker_pro',
      workerName: 'Vikram Singh',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      customerReviewed: true,
      workerReviewed: true,
    ),
  ];

  static final List<AppUser> _defaultUsers = [
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
    const AppUser(
      uid: 'demo_worker_3',
      email: 'rajesh.electric@localserve.com',
      name: 'Rajesh Sharma',
      mobile: '9822334411',
      address: 'Near Commerce Six Road, Navrangpura, Ahmedabad',
      latitude: 23.0360,
      longitude: 72.5600,
      role: UserRole.worker,
      workerSkill: 'Electrical',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      bio: 'Licensed Senior Electrician with 12 years experience. Specializing in complete wiring, MCB circuit breakers, short-circuits & safe power installations.',
      rating: 4.8,
      ratingCount: 22,
      completedJobsCount: 35,
    ),
    const AppUser(
      uid: 'demo_worker_4',
      email: 'vikram.carpenter@localserve.com',
      name: 'Vikram Patel',
      mobile: '9898765432',
      address: 'Near Jodhpur Cross Road, Satellite, Ahmedabad',
      latitude: 23.0280,
      longitude: 72.5200,
      role: UserRole.worker,
      workerSkill: 'Carpentry',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
      bio: 'Artisan Carpenter specializing in modular kitchen fittings, door hinges, lock installations, and custom furniture repair.',
      rating: 4.9,
      ratingCount: 19,
      completedJobsCount: 28,
    ),
    const AppUser(
      uid: 'demo_worker_5',
      email: 'anita.cleaning@localserve.com',
      name: 'Anita Verma',
      mobile: '9877665544',
      address: 'Bodakdev Garden Road, Ahmedabad',
      latitude: 23.0400,
      longitude: 72.5100,
      role: UserRole.worker,
      workerSkill: 'Cleaning',
      avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
      bio: 'Professional deep cleaning specialist. Equipped with modern eco-friendly equipment for kitchen, sofa, carpet and full home sanitization.',
      rating: 5.0,
      ratingCount: 31,
      completedJobsCount: 45,
    ),
    const AppUser(
      uid: 'demo_worker_6',
      email: 'sunil.painter@localserve.com',
      name: 'Sunil Prajapati',
      mobile: '9811002233',
      address: 'Near Vastrapur Lake, Ahmedabad',
      latitude: 23.0350,
      longitude: 72.5350,
      role: UserRole.worker,
      workerSkill: 'Painting',
      avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
      bio: 'Professional wall painter and texture specialist. Clean, mess-free painting with premium waterproof emulsions and fast turnarounds.',
      rating: 4.7,
      ratingCount: 14,
      completedJobsCount: 20,
    ),
    const AppUser(
      uid: 'demo_worker_7',
      email: 'manoj.appliance@localserve.com',
      name: 'Manoj Kumar',
      mobile: '9833445566',
      address: 'Drive-in Road, Memnagar, Ahmedabad',
      latitude: 23.0470,
      longitude: 72.5280,
      role: UserRole.worker,
      workerSkill: 'Appliance Repair',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
      bio: 'Certified Home Appliance Technician. Expert in AC gas refill & servicing, refrigerator cooling, washing machine drum repair & microwave ovens.',
      rating: 4.8,
      ratingCount: 27,
      completedJobsCount: 39,
    ),
    const AppUser(
      uid: 'demo_worker_8',
      email: 'sanjay.general@localserve.com',
      name: 'Sanjay Rawat',
      mobile: '9844556677',
      address: 'CG Road, Ellisbridge, Ahmedabad',
      latitude: 23.0250,
      longitude: 72.5550,
      role: UserRole.worker,
      workerSkill: 'General Service',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
      bio: 'All-round experienced Handyman. Fast resolution for general household repairs, curtain rod installations, ceiling drillings, and fixture fixes.',
      rating: 4.9,
      ratingCount: 40,
      completedJobsCount: 52,
    ),
  ];

  static final List<Review> _defaultReviews = [
    Review(
      id: 'rev_1',
      requestId: 'req_3',
      service: 'Plumbing',
      fromUserId: 'demo_customer_1',
      fromUserName: 'John Customer',
      fromUserRole: 'customer',
      toUserId: 'demo_worker_1',
      toUserName: 'Alex Plumber',
      rating: 5.0,
      comment: 'Super fast, punctual, and repaired the leaking overhead pipeline perfectly. Highly recommend for plumbing!',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Review(
      id: 'rev_2',
      requestId: 'req_3',
      service: 'Plumbing',
      fromUserId: 'demo_worker_1',
      fromUserName: 'Alex Plumber',
      fromUserRole: 'worker',
      toUserId: 'demo_customer_1',
      toUserName: 'John Customer',
      rating: 5.0,
      comment: 'Polite and clear communication. Immediate payment upon work completion.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Review(
      id: 'rev_clean_1',
      requestId: 'req_clean_1',
      service: 'Cleaning',
      fromUserId: 'demo_customer_1',
      fromUserName: 'John Customer',
      fromUserRole: 'customer',
      toUserId: 'demo_worker_5',
      toUserName: 'Anita Verma',
      rating: 5.0,
      comment: 'Outstanding deep cleaning service! The kitchen and balcony were sparkling clean.',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Review(
      id: 'rev_elec_1',
      requestId: 'req_elec_1',
      service: 'Electrical',
      fromUserId: 'demo_customer_2',
      fromUserName: 'Sarah Connor',
      fromUserRole: 'customer',
      toUserId: 'demo_worker_pro',
      toUserName: 'Vikram Singh',
      rating: 5.0,
      comment: 'Expert electrician, quickly replaced faulty sparking switches and restored power safely.',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  static final List<AppNotification> _defaultNotifications = [
    AppNotification(
      id: 'notif_1',
      userId: 'demo_customer_1',
      title: 'Worker Applied!',
      message: 'Alex Plumber accepted your Plumbing request! Tap to view profile & reviews.',
      type: 'worker_applied',
      requestId: 'req_1',
      relatedUserId: 'demo_worker_1',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
  ];

  final List<ServiceRequest> _mockRequests = [];
  final List<AppUser> _mockUsers = [];
  final List<AppNotification> _mockNotifications = [];
  final List<Review> _mockReviews = [];

  static final StreamController<List<ServiceRequest>> _mockRequestsStreamController =
      StreamController<List<ServiceRequest>>.broadcast();
  static final StreamController<List<AppNotification>> _mockNotificationsStreamController =
      StreamController<List<AppNotification>>.broadcast();
  static final StreamController<List<Review>> _mockReviewsStreamController =
      StreamController<List<Review>>.broadcast();

  List<ServiceRequest> get allRequests => List.unmodifiable(_mockRequests);
  List<AppUser> get allUsers {
    final map = <String, AppUser>{};
    for (final u in _defaultUsers) {
      map[u.uid] = u;
    }
    for (final u in _mockUsers) {
      map[u.uid] = u;
    }
    for (final u in _storage.getAllUsers()) {
      map[u.uid] = u;
    }
    return map.values.toList();
  }
  List<AppUser> getAllUsers() => allUsers;
  List<Review> get allReviews => List.unmodifiable(_mockReviews);
  Stream<List<AppNotification>> streamUserNotifications(String userId) => streamNotifications(userId);

  DatabaseService() {
    _init();
  }

  Future<void> _init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      }
    } catch (_) {}

    await _storage.init();

    // 0. Check if initial mock data should be wiped as requested
    if (!_storage.isMockDataCleared) {
      await clearAllFirestoreData();
    }

    // 1. Load Requests
    final savedReqs = _storage.getAllRequests();
    if (_storage.isMockDataCleared) {
      _mockRequests.addAll(savedReqs);
    } else {
      if (savedReqs.isEmpty) {
        _mockRequests.addAll(_defaultRequests);
        await _storage.saveRequestsBatch(_defaultRequests);
      } else {
        _mockRequests.addAll(savedReqs);
        final missingReqs = <ServiceRequest>[];
        for (final def in _defaultRequests) {
          final idx = _mockRequests.indexWhere((r) => r.id == def.id);
          if (idx == -1) {
            _mockRequests.add(def);
            missingReqs.add(def);
          } else if (_mockRequests[idx].service != def.service && (def.id == 'req_2' || def.id == 'req_3')) {
            _mockRequests[idx] = def;
            missingReqs.add(def);
          }
        }
        if (missingReqs.isNotEmpty) {
          await _storage.saveRequestsBatch(missingReqs);
        }
      }
    }

    // 2. Load Users
    final savedUsers = _storage.getAllUsers();
    if (savedUsers.isEmpty) {
      _mockUsers.addAll(_defaultUsers);
      await _storage.saveUsersBatch(_defaultUsers);
    } else {
      _mockUsers.addAll(savedUsers);
      final missingUsers = <AppUser>[];
      for (final def in _defaultUsers) {
        if (!_mockUsers.any((u) => u.uid == def.uid)) {
          _mockUsers.add(def);
          missingUsers.add(def);
        }
      }
      if (missingUsers.isNotEmpty) {
        await _storage.saveUsersBatch(missingUsers);
      }
    }

    // 3. Load Notifications (Auto-purge older than 24 hours / 1 day)
    final savedNotifs = _storage.getAllNotifications();
    final cutoff24h = DateTime.now().subtract(const Duration(hours: 24));
    if (_storage.isMockDataCleared) {
      _mockNotifications.addAll(savedNotifs.where((n) => n.createdAt.isAfter(cutoff24h)));
    } else {
      if (savedNotifs.isEmpty) {
        _mockNotifications.addAll(_defaultNotifications);
        for (final n in _defaultNotifications) {
          await _storage.saveNotification(n);
        }
      } else {
        _mockNotifications.addAll(savedNotifs.where((n) => n.createdAt.isAfter(cutoff24h)));
      }
    }

    // 4. Load Reviews
    final savedRevs = _storage.getAllReviews();
    if (_storage.isMockDataCleared) {
      _mockReviews.addAll(savedRevs);
    } else {
      if (savedRevs.isEmpty) {
        _mockReviews.addAll(_defaultReviews);
        await _storage.saveReviewsBatch(_defaultReviews);
      } else {
        _mockReviews.addAll(savedRevs);
        final missingReviews = <Review>[];
        for (final def in _defaultReviews) {
          final idx = _mockReviews.indexWhere((r) => r.id == def.id);
          if (idx == -1) {
            _mockReviews.add(def);
            missingReviews.add(def);
          } else if (_mockReviews[idx].service != def.service && (def.id == 'rev_1' || def.id == 'rev_2')) {
            _mockReviews[idx] = def;
            missingReviews.add(def);
          }
        }
        if (missingReviews.isNotEmpty) {
          await _storage.saveReviewsBatch(missingReviews);
        }
      }
    }
    unawaited(cleanupExpiredNotifications());

    // 5. Enforce trade specialization integrity across demo workers:
    // A Plumber (demo_worker_1) must ONLY have Plumbing jobs and Plumbing reviews.
    for (int i = 0; i < _mockRequests.length; i++) {
      final req = _mockRequests[i];
      if (req.workerId == 'demo_worker_1' && req.service.toLowerCase() != 'plumbing') {
        final fixed = req.copyWith(
          service: 'Plumbing',
          description: req.id == 'req_2'
              ? 'Bathroom washbasin faucet leakage & new mixer tap installation.'
              : (req.id == 'req_3'
                  ? 'Overhead water tank float valve and pipeline joint leakage repair.'
                  : 'Plumbing repair and pipeline maintenance.'),
        );
        _mockRequests[i] = fixed;
        await _storage.saveRequest(fixed);
      }
    }

    for (int i = 0; i < _mockReviews.length; i++) {
      final rev = _mockReviews[i];
      if ((rev.toUserId == 'demo_worker_1' || rev.fromUserId == 'demo_worker_1') &&
          rev.service.toLowerCase() != 'plumbing') {
        final fixedRev = Review(
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
        _mockReviews[i] = fixedRev;
        await _storage.saveReview(fixedRev);
      }
    }

    _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
    _mockReviewsStreamController.add(List.unmodifiable(_mockReviews));
    notifyListeners();

    if (_isFirebaseInitialized) {
      unawaited(_syncFromFirebase());
    }
  }

  /// Background sync to fetch remote documents from Firebase server and populate local server
  Future<void> _syncFromFirebase() async {
    try {
      // 1. Sync users from Firestore to local server
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      final firestoreUsers = <AppUser>[];
      for (final doc in usersSnap.docs) {
        final u = AppUser.fromMap(doc.data(), uid: doc.id);
        firestoreUsers.add(u);
        final idx = _mockUsers.indexWhere((m) => m.uid == u.uid);
        if (idx != -1) {
          _mockUsers[idx] = u;
        } else {
          _mockUsers.add(u);
        }
      }
      if (firestoreUsers.isNotEmpty) {
        await _storage.saveUsersBatch(firestoreUsers);
      }

      // 2. Sync service requests from Firestore to local server
      final reqsSnap = await FirebaseFirestore.instance.collection('service_requests').get();
      final firestoreReqs = <ServiceRequest>[];
      for (final doc in reqsSnap.docs) {
        final r = ServiceRequest.fromMap(doc.data(), id: doc.id);
        firestoreReqs.add(r);
        final idx = _mockRequests.indexWhere((m) => m.id == r.id);
        if (idx != -1) {
          _mockRequests[idx] = r;
        } else {
          _mockRequests.add(r);
        }
      }
      if (firestoreReqs.isNotEmpty) {
        await _storage.saveRequestsBatch(firestoreReqs);
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      }

      // 3. Sync reviews from Firestore to local server
      final revsSnap = await FirebaseFirestore.instance.collection('reviews').get();
      final firestoreRevs = <Review>[];
      for (final doc in revsSnap.docs) {
        final rev = Review.fromMap(doc.data(), id: doc.id);
        firestoreRevs.add(rev);
        final idx = _mockReviews.indexWhere((m) => m.id == rev.id);
        if (idx != -1) {
          _mockReviews[idx] = rev;
        } else {
          _mockReviews.add(rev);
        }
      }
      if (firestoreRevs.isNotEmpty) {
        await _storage.saveReviewsBatch(firestoreRevs);
        _mockReviewsStreamController.add(List.unmodifiable(_mockReviews));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Firestore background sync notice: $e');
    }
  }

  // Look up user details by ID
  Future<AppUser?> getUserById(String uid) async {
    if (_isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          return AppUser.fromMap(doc.data()!, uid: doc.id);
        }
      } catch (_) {}
    }
    return _storage.getUserById(uid) ?? _mockUsers.where((u) => u.uid == uid).firstOrNull;
  }

  // Helper to query customer requests by customerId OR email
  List<ServiceRequest> getCustomerRequests(String customerId, {String? customerEmail}) {
    return _mockRequests.where((r) {
      if (r.customerId == customerId) return true;
      if (customerEmail != null &&
          customerEmail.isNotEmpty &&
          r.email.trim().toLowerCase() == customerEmail.trim().toLowerCase()) {
        return true;
      }
      return false;
    }).toList();
  }

  // --- QUERY STREAMS ---

  Stream<List<ServiceRequest>> streamCustomerRequests(String customerId, {String? customerEmail}) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('service_requests')
          .snapshots()
          .map((snapshot) {
            final firestoreList = snapshot.docs
                .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
                .where((r) =>
                    r.customerId == customerId ||
                    (customerEmail != null &&
                        customerEmail.isNotEmpty &&
                        r.email.trim().toLowerCase() ==
                            customerEmail.trim().toLowerCase()))
                .toList();

            final map = <String, ServiceRequest>{};
            for (final r in firestoreList) {
              map[r.id] = r;
            }
            for (final r in _mockRequests) {
              if (r.customerId == customerId ||
                  (customerEmail != null &&
                      customerEmail.isNotEmpty &&
                      r.email.trim().toLowerCase() ==
                          customerEmail.trim().toLowerCase())) {
                map.putIfAbsent(r.id, () => r);
              }
            }
            return map.values.toList();
          });
    } else {
      return Stream<List<ServiceRequest>>.multi((controller) {
        controller.add(getCustomerRequests(customerId, customerEmail: customerEmail));
        final sub = _mockRequestsStreamController.stream.listen((_) {
          controller.add(getCustomerRequests(customerId, customerEmail: customerEmail));
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  Stream<List<ServiceRequest>> streamAvailableRequests({String? skill, String? workerId}) {
    final skillFilter = (skill != null &&
            skill.trim().isNotEmpty &&
            skill.trim().toLowerCase() != 'general service' &&
            skill.trim().toLowerCase() != 'all')
        ? skill.trim().toLowerCase()
        : null;

    bool matchesSkill(String service) {
      if (skillFilter == null) return true;
      final reqService = service.trim().toLowerCase();
      if (reqService == 'general service' || reqService == 'general') return true;
      if (reqService == skillFilter) return true;
      if (reqService.contains(skillFilter) || skillFilter.contains(reqService)) return true;
      if (reqService.contains('plumb') && skillFilter.contains('plumb')) return true;
      if (reqService.contains('electr') && skillFilter.contains('electr')) return true;
      if (reqService.contains('carpent') && skillFilter.contains('carpent')) return true;
      if (reqService.contains('paint') && skillFilter.contains('paint')) return true;
      if (reqService.contains('clean') && skillFilter.contains('clean')) return true;
      if (reqService.contains('appliance') && skillFilter.contains('appliance')) return true;
      return false;
    }

    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('service_requests')
          .snapshots()
          .map((snapshot) {
            final firestoreList = snapshot.docs
                .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
                .where((r) {
                  if (workerId != null &&
                      workerId.isNotEmpty &&
                      r.targetWorkerId == workerId &&
                      (r.status == 'direct_pending' || r.status == 'pending')) {
                    return true;
                  }
                  final isAvailable = (r.status == 'pending' && (r.targetWorkerId == null || r.targetWorkerId!.isEmpty));
                  if (!isAvailable) return false;
                  return matchesSkill(r.service);
                })
                .toList();

            final map = <String, ServiceRequest>{};
            for (final r in firestoreList) {
              map[r.id] = r;
            }
            for (final r in _mockRequests) {
              final isTargeted = workerId != null &&
                  workerId.isNotEmpty &&
                  r.targetWorkerId == workerId &&
                  (r.status == 'direct_pending' || r.status == 'pending');
              final isAvailable = (r.status == 'pending' && (r.targetWorkerId == null || r.targetWorkerId!.isEmpty));
              if (isTargeted || (isAvailable && matchesSkill(r.service))) {
                map.putIfAbsent(r.id, () => r);
              }
            }
            return map.values.toList();
          });
    } else {
      return Stream<List<ServiceRequest>>.multi((controller) {
        List<ServiceRequest> filter(List<ServiceRequest> list) {
          return list.where((r) {
            if (workerId != null &&
                workerId.isNotEmpty &&
                r.targetWorkerId == workerId &&
                (r.status == 'direct_pending' || r.status == 'pending')) {
              return true;
            }
            final isAvailable = (r.status == 'pending' && (r.targetWorkerId == null || r.targetWorkerId!.isEmpty));
            if (!isAvailable) return false;
            return matchesSkill(r.service);
          }).toList();
        }

        controller.add(filter(_mockRequests));
        final sub = _mockRequestsStreamController.stream.listen((list) {
          controller.add(filter(list));
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  Stream<List<ServiceRequest>> streamWorkerJobs(String workerId) =>
      streamWorkerActiveJobs(workerId);

  Stream<List<ServiceRequest>> streamWorkerActiveJobs(String workerId) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('workerId', isEqualTo: workerId)
          .snapshots()
          .map((snapshot) {
            final firestoreList = snapshot.docs
                .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
                .where((r) {
                  final user = _mockUsers.cast<AppUser?>().firstWhere(
                        (u) => u?.uid == workerId,
                        orElse: () => _defaultUsers.cast<AppUser?>().firstWhere(
                              (u) => u?.uid == workerId,
                              orElse: () => null,
                            ),
                      );
                  final skill = user?.workerSkill?.trim().toLowerCase();
                  if (skill == null || skill.isEmpty || skill == 'general service' || skill == 'all') {
                    return true;
                  }
                  final reqService = r.service.trim().toLowerCase();
                  return reqService == skill || reqService == 'general service' || reqService == 'general';
                })
                .toList();

            final map = <String, ServiceRequest>{};
            for (final r in firestoreList) {
              map[r.id] = r;
            }
            for (final r in _mockRequests) {
              if (r.workerId == workerId) {
                map.putIfAbsent(r.id, () => r);
              }
            }
            return map.values.toList();
          });
    } else {
      return Stream<List<ServiceRequest>>.multi((controller) {
        List<ServiceRequest> filter(List<ServiceRequest> list) {
          final user = _mockUsers.cast<AppUser?>().firstWhere(
                (u) => u?.uid == workerId,
                orElse: () => _defaultUsers.cast<AppUser?>().firstWhere(
                      (u) => u?.uid == workerId,
                      orElse: () => null,
                    ),
              );
          final skill = user?.workerSkill?.trim().toLowerCase();
          return list.where((r) {
            if (r.workerId != workerId) return false;
            if (skill == null || skill.isEmpty || skill == 'general service' || skill == 'all') {
              return true;
            }
            final reqService = r.service.trim().toLowerCase();
            return reqService == skill || reqService == 'general service' || reqService == 'general';
          }).toList();
        }

        controller.add(filter(_mockRequests));
        final sub = _mockRequestsStreamController.stream.listen((list) {
          controller.add(filter(list));
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  Stream<ServiceRequest?> streamRequestById(String requestId) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return ServiceRequest.fromMap(snapshot.data()!, id: snapshot.id);
      });
    } else {
      return Stream<ServiceRequest?>.multi((controller) {
        ServiceRequest? find(List<ServiceRequest> list) {
          return list.where((r) => r.id == requestId).firstOrNull;
        }

        controller.add(find(_mockRequests));
        final sub = _mockRequestsStreamController.stream.listen((list) {
          controller.add(find(list));
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  // --- IN-APP NOTIFICATIONS (Auto-expires after 24 hours / 1 day) ---

  /// Auto-clean and delete notifications older than 24 hours across local and Firestore
  Future<void> cleanupExpiredNotifications() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final expiredIds = _mockNotifications
        .where((n) => n.createdAt.isBefore(cutoff))
        .map((n) => n.id)
        .toList();

    if (expiredIds.isNotEmpty) {
      _mockNotifications.removeWhere((n) => expiredIds.contains(n.id));
      await _storage.deleteExpiredNotifications(const Duration(hours: 24));
      _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
      notifyListeners();

      if (_isFirebaseInitialized) {
        try {
          for (final id in expiredIds) {
            await FirebaseFirestore.instance.collection('notifications').doc(id).delete();
          }
        } catch (e) {
          debugPrint('Expired notifications Firestore deletion warning: $e');
        }
      }
    }
  }

  List<AppNotification> getNotifications(String userId) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _mockNotifications
        .where((n) => n.userId == userId && n.createdAt.isAfter(cutoff))
        .toList();
  }

  Stream<List<AppNotification>> streamNotifications(String userId) =>
      streamNotificationsForUser(userId);

  Stream<List<AppNotification>> streamNotificationsForUser(String userId) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final firestoreList = snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), id: doc.id))
            .where((n) => n.createdAt.isAfter(cutoff))
            .toList();
        final map = <String, AppNotification>{};
        for (final n in firestoreList) {
          map[n.id] = n;
        }
        for (final n in _mockNotifications) {
          if (n.userId == userId && n.createdAt.isAfter(cutoff)) {
            map.putIfAbsent(n.id, () => n);
          }
        }
        final list = map.values.toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } else {
      return Stream<List<AppNotification>>.multi((controller) {
        List<AppNotification> filter(List<AppNotification> list) {
          final res = list
              .where((n) => n.userId == userId && n.createdAt.isAfter(cutoff))
              .toList();
          res.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return res;
        }

        controller.add(filter(_mockNotifications));
        final sub = _mockNotificationsStreamController.stream.listen((list) {
          controller.add(filter(list));
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? requestId,
    String? relatedUserId,
    String? customerEmail,
    String? workerEmail,
  }) async {
    // 0. Auto-clean notifications older than 24 hours
    unawaited(cleanupExpiredNotifications());

    final notif = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${_mockNotifications.length}',
      userId: userId,
      title: title,
      message: message,
      type: type,
      requestId: requestId,
      relatedUserId: relatedUserId,
      createdAt: DateTime.now(),
    );

    // 1. Write to local storage & in-memory state
    _mockNotifications.insert(0, notif);
    await _storage.saveNotification(notif);
    _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
    notifyListeners();

    // 2. Write to Firebase server
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notif.id)
            .set(notif.toMap());
      } catch (e) {
        debugPrint('Error saving notification in Firestore: $e');
      }
    }

    // 3. Dispatch notification email to BOTH Customer and Worker
    unawaited(_dispatchNotificationEmails(
      userId: userId,
      relatedUserId: relatedUserId,
      requestId: requestId,
      title: title,
      message: message,
      overrideCustomerEmail: customerEmail,
      overrideWorkerEmail: workerEmail,
    ));
  }

  Future<void> _dispatchNotificationEmails({
    required String userId,
    String? relatedUserId,
    String? requestId,
    required String title,
    required String message,
    String? overrideCustomerEmail,
    String? overrideWorkerEmail,
  }) async {
    String? cEmail = overrideCustomerEmail;
    String? wEmail = overrideWorkerEmail;
    String? serviceName;
    String? reqOtp;

    if (requestId != null) {
      final req = _mockRequests.where((r) => r.id == requestId).firstOrNull ??
          _storage.getRequestById(requestId);
      if (req != null) {
        serviceName = req.service;
        reqOtp = req.otp;
        if (req.email.isNotEmpty && cEmail == null) {
          cEmail = req.email;
        }
        if (req.customerId != null && req.customerId!.isNotEmpty && cEmail == null) {
          final cust = await getUserById(req.customerId!);
          if (cust != null && cust.email.isNotEmpty) cEmail = cust.email;
        }
        if (req.workerId != null && req.workerId!.isNotEmpty && wEmail == null) {
          final wrk = await getUserById(req.workerId!);
          if (wrk != null && wrk.email.isNotEmpty) wEmail = wrk.email;
        }
      }
    }

    if (cEmail == null || wEmail == null) {
      final user1 = await getUserById(userId);
      if (user1 != null) {
        if (user1.isWorker) {
          wEmail ??= user1.email;
        } else {
          cEmail ??= user1.email;
        }
      }
      if (relatedUserId != null) {
        final user2 = await getUserById(relatedUserId);
        if (user2 != null) {
          if (user2.isWorker) {
            wEmail ??= user2.email;
          } else {
            cEmail ??= user2.email;
          }
        }
      }
    }

    try {
      await EmailService().sendDualPartyNotificationEmail(
        customerEmail: cEmail,
        workerEmail: wEmail,
        title: title,
        message: message,
        serviceType: serviceName,
        requestId: requestId,
        otp: reqOtp,
      );
    } catch (e) {
      debugPrint('[DatabaseService] Email notification dispatch notice: $e');
    }
  }

  /// Completely wipe all requests, notifications, and reviews from Firestore collections and local storage
  /// Ensures only newly created data will be stored moving forward.
  Future<void> clearAllFirestoreData({bool clearUsers = false}) async {
    debugPrint('[DatabaseService] Clearing all data from Firestore & Local Storage...');

    // 1. Clear local memory and storage
    _mockRequests.clear();
    _mockNotifications.clear();
    _mockReviews.clear();
    await _storage.clearAllRequests();
    await _storage.clearAllNotifications();
    await _storage.clearAllReviews();
    await _storage.setMockDataCleared(true);

    // 2. Delete all Firestore collection documents
    if (_isFirebaseInitialized) {
      try {
        final reqDocs = await FirebaseFirestore.instance.collection('service_requests').get();
        for (final doc in reqDocs.docs) {
          await doc.reference.delete();
        }

        final notifDocs = await FirebaseFirestore.instance.collection('notifications').get();
        for (final doc in notifDocs.docs) {
          await doc.reference.delete();
        }

        final revDocs = await FirebaseFirestore.instance.collection('reviews').get();
        for (final doc in revDocs.docs) {
          await doc.reference.delete();
        }

        if (clearUsers) {
          final userDocs = await FirebaseFirestore.instance.collection('users').get();
          for (final doc in userDocs.docs) {
            await doc.reference.delete();
          }
        }
        debugPrint('[DatabaseService] Firestore collections successfully wiped.');
      } catch (e) {
        debugPrint('[DatabaseService] Firestore wipe warning: $e');
      }
    }

    _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
    _mockReviewsStreamController.add(List.unmodifiable(_mockReviews));
    notifyListeners();
  }

  Future<void> markNotificationsAsRead(String userId) async {
    // 1. Update local storage & in-memory
    for (int i = 0; i < _mockNotifications.length; i++) {
      if (_mockNotifications[i].userId == userId) {
        _mockNotifications[i] = _mockNotifications[i].copyWith(isRead: true);
      }
    }
    await _storage.markNotificationsRead(userId);
    _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
    notifyListeners();

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final docs = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

        for (final doc in docs.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Error marking notifications read in Firestore: $e');
      }
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) =>
      markNotificationsAsRead(userId);

  Future<void> markNotificationAsRead(String notificationId) async {
    // 1. Update local storage & in-memory
    final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _mockNotifications[idx] = _mockNotifications[idx].copyWith(isRead: true);
      await _storage.saveNotification(_mockNotifications[idx]);
      _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
      notifyListeners();
    }

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true});
      } catch (e) {
        debugPrint('Error marking notification read in Firestore: $e');
      }
    }
  }

  // --- REVIEWS & RATINGS ---

  List<Review> getReviewsForUser(String userId) {
    final list = _mockReviews.where((r) => r.toUserId == userId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<List<Review>> streamReviewsForUser(String userId) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('reviews')
          .where('toUserId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final firestoreList = snapshot.docs
            .map((doc) => Review.fromMap(doc.data(), id: doc.id))
            .toList();
        final map = <String, Review>{};
        for (final rev in firestoreList) {
          map[rev.id] = rev;
        }
        for (final rev in _mockReviews) {
          if (rev.toUserId == userId) {
            map.putIfAbsent(rev.id, () => rev);
          }
        }
        final list = map.values.toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } else {
      return Stream<List<Review>>.multi((controller) {
        List<Review> filter(List<Review> list) {
          final res = list.where((r) => r.toUserId == userId).toList();
          res.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return res;
        }

        controller.add(filter(_mockReviews));
        final sub = _mockReviewsStreamController.stream.listen((list) {
          controller.add(filter(list));
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  Future<void> submitReview(Review review) async {
    // 1. Write to local storage & in-memory state
    _mockReviews.insert(0, review);
    await _storage.saveReview(review);
    _mockReviewsStreamController.add(List.unmodifiable(_mockReviews));

    // Update Service Request review flag locally
    final reqIdx = _mockRequests.indexWhere((r) => r.id == review.requestId);
    if (reqIdx != -1) {
      final updated = review.fromUserRole == 'customer'
          ? _mockRequests[reqIdx].copyWith(customerReviewed: true)
          : _mockRequests[reqIdx].copyWith(workerReviewed: true);
      _mockRequests[reqIdx] = updated;
      await _storage.saveRequest(updated);
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    }

    // Update recipient user rating metrics locally
    final userIdx = _mockUsers.indexWhere((u) => u.uid == review.toUserId);
    if (userIdx != -1) {
      final existing = _mockReviews.where((r) => r.toUserId == review.toUserId).toList();
      final double avg = existing.fold<double>(0.0, (acc, r) => acc + r.rating) / existing.length;
      final updatedUser = _mockUsers[userIdx].copyWith(
        rating: double.parse(avg.toStringAsFixed(1)),
        ratingCount: existing.length,
        completedJobsCount: _mockUsers[userIdx].completedJobsCount + 1,
      );
      _mockUsers[userIdx] = updatedUser;
      await _storage.saveUser(updatedUser);
    }
    notifyListeners();

    // 2. Write to Firebase server
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('reviews')
            .doc(review.id)
            .set(review.toMap());

        final fieldToUpdate = review.fromUserRole == 'customer'
            ? {'customerReviewed': true}
            : {'workerReviewed': true};

        await FirebaseFirestore.instance
            .collection('service_requests')
            .doc(review.requestId)
            .update(fieldToUpdate);

        final allRevs = await FirebaseFirestore.instance
            .collection('reviews')
            .where('toUserId', isEqualTo: review.toUserId)
            .get();

        if (allRevs.docs.isNotEmpty) {
          final ratings = allRevs.docs
              .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 5.0)
              .toList();
          final double avg = ratings.reduce((a, b) => a + b) / ratings.length;

          await FirebaseFirestore.instance.collection('users').doc(review.toUserId).update({
            'rating': double.parse(avg.toStringAsFixed(1)),
            'ratingCount': ratings.length,
            'completedJobsCount': FieldValue.increment(1),
          });
        }
      } catch (e) {
        debugPrint('Error saving review to Firestore: $e');
      }
    }

    // Send Notification to recipient
    await sendNotification(
      userId: review.toUserId,
      title: 'New ${review.rating.toStringAsFixed(1)}★ Review!',
      message: '${review.fromUserName} left you a review: "${review.comment}"',
      type: 'review_received',
      requestId: review.requestId,
      relatedUserId: review.fromUserId,
    );
  }

  // --- CRUD ACTIONS ---

  Future<void> addRequest(ServiceRequest request) async {
    // Generate secure 6-digit verification OTP if not provided
    final String generatedOtp = (request.otp != null && request.otp!.trim().isNotEmpty)
        ? request.otp!.trim()
        : (100000 + Random().nextInt(900000)).toString();

    final newReq = request.copyWith(
      status: request.status.isEmpty ? 'pending' : request.status,
      otp: generatedOtp,
    );
    _mockRequests.removeWhere((r) => r.id == newReq.id);
    _mockRequests.insert(0, newReq);
    await _storage.saveRequest(newReq);
    _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    notifyListeners();

    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('service_requests')
            .doc(newReq.id)
            .set(newReq.toMap());
      } catch (e) {
        debugPrint('Error saving request to Firestore: $e');
      }
    }

    // Dispatch genuine verification email from system sender moditapan0@gmail.com
    unawaited(EmailService().sendJobVerificationOtpEmail(
      customerEmail: newReq.email,
      customerName: newReq.name,
      otp: generatedOtp,
      serviceName: newReq.service,
      requestId: newReq.id,
      workerName: newReq.workerName,
    ));

    // Send in-app notification to customer
    if (newReq.customerId != null && newReq.customerId!.isNotEmpty) {
      unawaited(sendNotification(
        userId: newReq.customerId!,
        title: 'Service Booked: ${newReq.service}',
        message: 'Your service request has been booked! Your Completion OTP is $generatedOtp.',
        type: 'request_created',
        requestId: newReq.id,
        customerEmail: newReq.email,
      ));
    }

    // If general service request (not targeted to a single worker), notify all nearby workers matching category
    if (!newReq.isDirectRequest) {
      double? custLat = newReq.latitude;
      double? custLon = newReq.longitude;
      if ((custLat == null || custLon == null) && newReq.customerId != null) {
        final cust = _mockUsers.where((u) => u.uid == newReq.customerId).firstOrNull;
        if (cust != null) {
          custLat = cust.latitude;
          custLon = cust.longitude;
        }
      }

      final nearbyWorkers = getWorkersForCategory(
        newReq.service,
        customerLat: custLat,
        customerLon: custLon,
        maxDistanceKm: maxWorkerDistanceKm,
        strictWithinRadius: (custLat != null && custLon != null),
      );

      for (final worker in nearbyWorkers) {
        if (worker.uid != newReq.customerId && worker.email.isNotEmpty) {
          final dist = calculateDistanceKm(
            lat1: custLat,
            lon1: custLon,
            lat2: worker.latitude,
            lon2: worker.longitude,
          );

          unawaited(EmailService().sendNearbyJobAlertEmail(
            request: newReq,
            worker: worker,
            distanceKm: dist,
          ));

          unawaited(sendNotification(
            userId: worker.uid,
            title: 'New ${newReq.service} Job Nearby! 📍',
            message: 'Customer ${newReq.name} requested ${newReq.service} nearby at ${newReq.address}. Tap to apply.',
            type: 'nearby_job_available',
            requestId: newReq.id,
            relatedUserId: newReq.customerId,
          ));
        }
      }
    }
  }

  Future<void> updateRequest(ServiceRequest request) async {
    final index = _mockRequests.indexWhere((r) => r.id == request.id);
    if (index != -1) {
      _mockRequests[index] = request;
    } else {
      _mockRequests.insert(0, request);
    }
    await _storage.saveRequest(request);
    _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    notifyListeners();

    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('service_requests')
            .doc(request.id)
            .set(request.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating request in Firestore: $e');
      }
    }
  }

  Future<void> deleteRequest(String requestId) async {
    _mockRequests.removeWhere((r) => r.id == requestId);
    await _storage.deleteRequest(requestId);
    _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    notifyListeners();

    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('service_requests')
            .doc(requestId)
            .delete();
      } catch (e) {
        debugPrint('Error deleting request in Firestore: $e');
      }
    }
  }

  /// Cancels a customer service request and notifies any workers involved.
  Future<void> cancelRequest({
    required String requestId,
    String? reason,
  }) async {
    ServiceRequest? targetReq;

    // 1. Update local storage & in-memory state
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      targetReq = _mockRequests[index];
      final updated = _mockRequests[index].copyWith(
        status: 'cancelled',
        completed: false,
      );
      _mockRequests[index] = updated;
      await _storage.saveRequest(updated);
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
    }

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        if (targetReq == null) {
          final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
          if (doc.exists && doc.data() != null) {
            targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
            final updated = targetReq.copyWith(status: 'cancelled', completed: false);
            _mockRequests.removeWhere((r) => r.id == requestId);
            _mockRequests.insert(0, updated);
            await _storage.saveRequest(updated);
            _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
            notifyListeners();
          }
        }
        await FirebaseFirestore.instance
            .collection('service_requests')
            .doc(requestId)
            .update({
          'status': 'cancelled',
          'completed': false,
        });
      } catch (e) {
        debugPrint('Error cancelling request in Firestore: $e');
      }
    }

    // Notify assigned worker or applicants about cancellation
    if (targetReq != null) {
      final workersToNotify = <String>{};
      if (targetReq.workerId != null && targetReq.workerId!.isNotEmpty) {
        workersToNotify.add(targetReq.workerId!);
      }
      workersToNotify.addAll(targetReq.applicantWorkerIds);

      for (final workerId in workersToNotify) {
        await sendNotification(
          userId: workerId,
          title: 'Request Cancelled',
          message: 'The customer cancelled the ${targetReq.service} request.',
          type: 'request_cancelled',
          requestId: requestId,
        );
      }
    }
  }

  /// Worker accepts/applies for a request.
  Future<void> acceptJob({
    required String requestId,
    required String workerId,
    required String workerName,
    AppUser? worker,
    bool autoConfirm = false,
  }) async {
    if (worker != null) {
      if (!_mockUsers.any((u) => u.uid == worker.uid)) {
        _mockUsers.add(worker);
        await _storage.saveUser(worker);
      }
      if (!worker.hasLocation) {
        throw Exception(
          'Please set your base location on OpenStreetMap first to verify you are within 20 km of this request.',
        );
      }

      ServiceRequest? targetReq;
      if (_isFirebaseInitialized) {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } else {
        targetReq = _mockRequests.where((r) => r.id == requestId).firstOrNull;
      }

      if (targetReq != null && targetReq.hasLocation) {
        final dist = calculateDistanceKm(
          lat1: worker.latitude,
          lon1: worker.longitude,
          lat2: targetReq.latitude,
          lon2: targetReq.longitude,
        );

        if (dist != null && dist > maxWorkerDistanceKm) {
          throw Exception(
            'This request is ${dist.toStringAsFixed(1)} km away. Workers can only accept jobs within 20 km.',
          );
        }
      }

      if (worker.workerSkill != null && worker.workerSkill!.isNotEmpty && targetReq != null) {
        final isDirect = targetReq.targetWorkerId == worker.uid;
        if (!isDirect) {
          final workerSkill = worker.workerSkill!.trim().toLowerCase();
          final reqService = targetReq.service.trim().toLowerCase();
          if (workerSkill != 'general service' && workerSkill != 'all') {
            final matches = reqService.isEmpty ||
                reqService == 'general service' ||
                reqService == 'general' ||
                reqService == workerSkill ||
                reqService.contains(workerSkill) ||
                workerSkill.contains(reqService) ||
                (reqService.contains('plumb') && workerSkill.contains('plumb')) ||
                (reqService.contains('electr') && workerSkill.contains('electr')) ||
                (reqService.contains('carpent') && workerSkill.contains('carpent')) ||
                (reqService.contains('paint') && workerSkill.contains('paint')) ||
                (reqService.contains('clean') && workerSkill.contains('clean')) ||
                (reqService.contains('appliance') && workerSkill.contains('appliance'));

            if (!matches) {
              throw Exception(
                'Specialization mismatch: Your profile is registered as ${worker.workerSkill} and cannot accept $reqService requests.',
              );
            }
          }
        }
      }
    }

    ServiceRequest? target = _mockRequests.where((r) => r.id == requestId).firstOrNull;
    if (target == null && _isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          target = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } catch (_) {}
    }

    if (target == null) throw Exception('Request not found.');

    final isDirectForThisWorker = target.status == 'direct_pending' && target.targetWorkerId == workerId;
    if (target.status != 'pending' && !isDirectForThisWorker) {
      throw Exception('This job has already been confirmed and assigned to another worker.');
    }

    // 1. Update local storage & in-memory state
    final ServiceRequest updatedReq;
    if (autoConfirm || isDirectForThisWorker) {
      updatedReq = target.copyWith(
        workerId: workerId,
        workerName: workerName,
        status: 'assigned',
      );
    } else {
      final updatedApplicants = List<String>.from(target.applicantWorkerIds);
      if (!updatedApplicants.contains(workerId)) {
        updatedApplicants.add(workerId);
      }
      updatedReq = target.copyWith(applicantWorkerIds: updatedApplicants);
    }

    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _mockRequests[index] = updatedReq;
    } else {
      _mockRequests.insert(0, updatedReq);
    }
    await _storage.saveRequest(updatedReq);
    _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    notifyListeners();

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        if (autoConfirm || isDirectForThisWorker) {
          await FirebaseFirestore.instance
              .collection('service_requests')
              .doc(requestId)
              .update({
            'workerId': workerId,
            'workerName': workerName,
            'status': 'assigned',
          });
        } else {
          await FirebaseFirestore.instance
              .collection('service_requests')
              .doc(requestId)
              .update({
            'applicantWorkerIds': FieldValue.arrayUnion([workerId]),
          });
        }
      } catch (e) {
        debugPrint('Error updating accepted job in Firestore: $e');
      }
    }

    final isDirectAccepted = target.status == 'direct_pending' && target.targetWorkerId == workerId;
    if (autoConfirm || isDirectAccepted) {
      final wrk = await getUserById(workerId);
      final cust = (target.customerId != null) ? await getUserById(target.customerId!) : null;
      final cEmail = target.email.isNotEmpty ? target.email : (cust?.email ?? '');
      final cName = target.name.isNotEmpty ? target.name : (cust?.name ?? 'Customer');

      unawaited(EmailService().sendJobAcceptedEmail(
        request: updatedReq,
        workerName: workerName,
        workerEmail: wrk?.email,
        customerName: cName,
        customerEmail: cEmail,
        isDirectRequest: isDirectAccepted,
      ));
    }

    if (target.customerId != null && target.customerId!.isNotEmpty) {
      await sendNotification(
        userId: target.customerId!,
        title: isDirectAccepted ? 'Direct Request Accepted! 🎉' : 'Worker Applied!',
        message: isDirectAccepted
            ? '$workerName accepted your direct request for ${target.service}! Work is scheduled.'
            : '$workerName wants to do your ${target.service} job! Review their profile and confirm.',
        type: isDirectAccepted ? 'direct_request_accepted' : 'worker_applied',
        requestId: requestId,
        relatedUserId: workerId,
      );
    }

    await sendNotification(
      userId: workerId,
      title: isDirectAccepted ? 'Job Confirmed! 🎉' : 'Application Sent!',
      message: isDirectAccepted
          ? 'You accepted the direct request for ${target.name}\'s ${target.service}. Work is scheduled.'
          : 'You applied for ${target.name}\'s ${target.service} request. Waiting for customer confirmation.',
      type: isDirectAccepted ? 'job_assigned' : 'worker_applied',
      requestId: requestId,
      relatedUserId: target.customerId,
    );
  }

  /// Customer confirms an applicant worker.
  Future<void> confirmWorker({
    required String requestId,
    required String workerId,
    required String workerName,
    String? customerId,
  }) async {
    ServiceRequest? targetReq = _mockRequests.where((r) => r.id == requestId).firstOrNull;
    if (targetReq == null && _isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } catch (_) {}
    }

    // 1. Update local storage & in-memory state
    if (targetReq != null) {
      final updated = targetReq.copyWith(
        workerId: workerId,
        workerName: workerName,
        status: 'assigned',
      );
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _mockRequests[index] = updated;
      } else {
        _mockRequests.insert(0, updated);
      }
      await _storage.saveRequest(updated);
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
    }

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({
          'workerId': workerId,
          'workerName': workerName,
          'status': 'assigned',
        });
      } catch (e) {
        debugPrint('Error confirming worker in Firestore: $e');
      }
    }

    if (targetReq != null) {
      final wrk = await getUserById(workerId);
      final otpToUse = targetReq.otp ?? (100000 + Random().nextInt(900000)).toString();

      // Dispatch real job accepted confirmation email to both customer and worker
      unawaited(EmailService().sendJobAcceptedEmail(
        request: targetReq.copyWith(workerId: workerId, workerName: workerName, status: 'assigned'),
        workerName: workerName,
        workerEmail: wrk?.email,
        customerName: targetReq.name,
        customerEmail: targetReq.email,
        isDirectRequest: false,
      ));

      // Dispatch real email from moditapan0@gmail.com with OTP instructions
      unawaited(EmailService().sendJobVerificationOtpEmail(
        customerEmail: targetReq.email,
        customerName: targetReq.name,
        otp: otpToUse,
        serviceName: targetReq.service,
        requestId: targetReq.id,
        workerName: workerName,
        workerEmail: wrk?.email,
      ));

      await sendNotification(
        userId: workerId,
        title: 'Job Confirmed! 🎉',
        message: '${targetReq.name} accepted your application for ${targetReq.service}! Verification OTP will be provided by customer upon job completion.',
        type: 'customer_accepted',
        requestId: requestId,
        relatedUserId: targetReq.customerId,
      );

      if (targetReq.customerId != null && targetReq.customerId!.isNotEmpty) {
        await sendNotification(
          userId: targetReq.customerId!,
          title: 'Worker Confirmed! 🛠️',
          message: 'You have confirmed $workerName for ${targetReq.service}. Your completion OTP is $otpToUse.',
          type: 'worker_confirmed',
          requestId: requestId,
          relatedUserId: workerId,
        );
      }

      final otherApplicants = targetReq.applicantWorkerIds.where((id) => id != workerId).toList();
      for (final otherId in otherApplicants) {
        await sendNotification(
          userId: otherId,
          title: 'Application Update',
          message: 'Another worker was chosen for ${targetReq.name}\'s ${targetReq.service} job.',
          type: 'worker_rejected',
          requestId: requestId,
        );
      }
    }
  }

  /// Customer declines an applicant worker.
  Future<void> declineWorker({
    required String requestId,
    required String workerId,
  }) async {
    ServiceRequest? targetReq = _mockRequests.where((r) => r.id == requestId).firstOrNull;
    if (targetReq == null && _isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } catch (_) {}
    }

    // 1. Update local storage & in-memory state
    if (targetReq != null) {
      final applicants = List<String>.from(targetReq.applicantWorkerIds)..remove(workerId);
      final declined = List<String>.from(targetReq.declinedWorkerIds);
      if (!declined.contains(workerId)) declined.add(workerId);

      final updated = targetReq.copyWith(
        applicantWorkerIds: applicants,
        declinedWorkerIds: declined,
      );
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _mockRequests[index] = updated;
      } else {
        _mockRequests.insert(0, updated);
      }
      await _storage.saveRequest(updated);
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
    }

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({
          'applicantWorkerIds': FieldValue.arrayRemove([workerId]),
          'declinedWorkerIds': FieldValue.arrayUnion([workerId]),
        });
      } catch (e) {
        debugPrint('Error declining worker in Firestore: $e');
      }
    }

    if (targetReq != null) {
      await sendNotification(
        userId: workerId,
        title: 'Application Update',
        message: '${targetReq.name} opted for another worker for ${targetReq.service}.',
        type: 'worker_rejected',
        requestId: requestId,
      );
    }
  }

  Future<void> updateStatus({
    required String requestId,
    required String newStatus,
  }) async {
    ServiceRequest? targetReq = _mockRequests.where((r) => r.id == requestId).firstOrNull;
    if (targetReq == null && _isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } catch (_) {}
    }

    // 1. Update local storage & in-memory state
    if (targetReq != null) {
      final updated = targetReq.copyWith(
        status: newStatus,
        completed: newStatus == 'completed',
      );
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _mockRequests[index] = updated;
      } else {
        _mockRequests.insert(0, updated);
      }
      await _storage.saveRequest(updated);
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
    }

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('service_requests')
            .doc(requestId)
            .update({
          'status': newStatus,
          'completed': newStatus == 'completed',
        });
      } catch (e) {
        debugPrint('Error updating status in Firestore: $e');
      }
    }

    if (newStatus == 'completed' && targetReq != null) {
      final cust = (targetReq.customerId != null) ? await getUserById(targetReq.customerId!) : null;
      final wrk = (targetReq.workerId != null) ? await getUserById(targetReq.workerId!) : null;
      final cEmail = targetReq.email.isNotEmpty ? targetReq.email : (cust?.email ?? '');

      // Dispatch real completion email from moditapan0@gmail.com to both customer & worker
      unawaited(EmailService().sendJobCompletedEmail(
        request: targetReq.copyWith(status: 'completed', completed: true),
        customerEmail: cEmail,
        workerEmail: wrk?.email,
      ));

      if (targetReq.customerId != null && targetReq.customerId!.isNotEmpty) {
        await sendNotification(
          userId: targetReq.customerId!,
          title: 'Job Completed! 🎉',
          message: 'Your ${targetReq.service} job is complete. Please leave a review for ${targetReq.workerName ?? "your worker"}!',
          type: 'job_completed',
          requestId: requestId,
          relatedUserId: targetReq.workerId,
        );
      }
      if (targetReq.workerId != null && targetReq.workerId!.isNotEmpty) {
        await sendNotification(
          userId: targetReq.workerId!,
          title: 'Job Completed! 🎉',
          message: 'The ${targetReq.service} job for ${targetReq.name} is complete. Please leave a review for the customer!',
          type: 'job_completed',
          requestId: requestId,
          relatedUserId: targetReq.customerId,
        );
      }
    }
  }

  /// Verify the 6-digit customer OTP and mark the job completed
  Future<bool> verifyAndCompleteJob({
    required String requestId,
    required String enteredOtp,
  }) async {
    final cleanOtp = enteredOtp.trim();
    ServiceRequest? target = _mockRequests.where((r) => r.id == requestId).firstOrNull;
    if (target == null && _isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          target = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } catch (_) {}
    }

    if (target == null) {
      throw Exception('Service request not found.');
    }

    // Verify OTP matches expected code
    final expectedOtp = target.otp?.trim();
    if (expectedOtp != null && expectedOtp.isNotEmpty) {
      if (cleanOtp != expectedOtp) {
        return false;
      }
    }

    await updateStatus(requestId: requestId, newStatus: 'completed');
    return true;
  }

  /// Worker submits finalized bill after inspecting the work on-site.
  /// Distance fee: ₹250 (<10km) or ₹500 (<20km)
  /// Fixed condition fee: ₹100
  Future<ServiceRequest> submitBill({
    required String requestId,
    required double baseAmount,
    required AppUser worker,
    double? customerLat,
    double? customerLng,
  }) async {
    ServiceRequest? targetReq;
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      targetReq = _mockRequests[index];
    }

    if (_isFirebaseInitialized && targetReq == null) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }
    }

    if (targetReq == null) {
      throw Exception('Service request not found');
    }

    // Geodesic distance calculation
    final double? distanceKm = calculateDistanceKm(
      lat1: worker.latitude,
      lon1: worker.longitude,
      lat2: customerLat ?? targetReq.latitude,
      lon2: customerLng ?? targetReq.longitude,
    );

    final double distanceFee = calculateDistanceFee(distanceKm);
    const double inspection = inspectionFee;
    final double total = baseAmount + inspection + distanceFee;

    final updated = targetReq.copyWith(
      baseAmount: baseAmount,
      inspectionFee: inspection,
      distanceFee: distanceFee,
      distanceKm: distanceKm,
      totalAmount: total,
      paymentStatus: 'pending',
    );

    await updateRequest(updated);

    // Send notification to customer
    final customerUserId = updated.customerId ??
        _mockUsers.where((u) => u.email.toLowerCase() == updated.email.toLowerCase()).firstOrNull?.uid;

    if (customerUserId != null && customerUserId.isNotEmpty) {
      await sendNotification(
        userId: customerUserId,
        title: 'Invoice: ₹${total.toStringAsFixed(0)} for ${updated.service}',
        message: '${worker.name} evaluated the work condition and generated your bill of ₹${total.toStringAsFixed(0)} (Work: ₹${baseAmount.toStringAsFixed(0)}, Inspection: ₹100, Distance: ₹${distanceFee.toStringAsFixed(0)}). Tap to pay with Razorpay.',
        type: 'payment_request',
        requestId: updated.id,
        relatedUserId: worker.uid,
      );
    }

    return updated;
  }

  /// Mark payment as completed via Razorpay
  Future<ServiceRequest> completePayment({
    required String requestId,
    required String paymentId,
    required double amount,
    String paymentMethod = 'Razorpay',
  }) async {
    ServiceRequest? targetReq;
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      targetReq = _mockRequests[index];
    }

    if (_isFirebaseInitialized && targetReq == null) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }
    }

    if (targetReq == null) {
      throw Exception('Service request not found');
    }

    final updated = targetReq.copyWith(
      paymentStatus: 'paid',
      paymentId: paymentId,
      paymentMethod: paymentMethod,
      paidAt: DateTime.now(),
    );

    await updateRequest(updated);

    final wrk = (updated.workerId != null) ? await getUserById(updated.workerId!) : null;
    final cust = (updated.customerId != null) ? await getUserById(updated.customerId!) : null;
    final cEmail = updated.email.isNotEmpty ? updated.email : (cust?.email ?? '');

    // Dispatch real payment receipt email to customer & payment credit email to worker
    unawaited(EmailService().sendPaymentReceiptEmail(
      request: updated,
      amount: amount,
      paymentId: paymentId,
      paymentMethod: paymentMethod,
      customerEmail: cEmail,
      workerEmail: wrk?.email,
    ));

    // Notify worker
    if (updated.workerId != null && updated.workerId!.isNotEmpty) {
      await sendNotification(
        userId: updated.workerId!,
        title: 'Payment Received: ₹${amount.toStringAsFixed(0)}',
        message: 'Customer ${updated.name} paid ₹${amount.toStringAsFixed(0)} for ${updated.service} via Razorpay (Payment ID: $paymentId).',
        type: 'payment_received',
        requestId: updated.id,
        relatedUserId: updated.customerId,
      );
    }

    // Notify customer
    final customerUserId = updated.customerId ??
        _mockUsers.where((u) => u.email.toLowerCase() == updated.email.toLowerCase()).firstOrNull?.uid;

    if (customerUserId != null && customerUserId.isNotEmpty) {
      await sendNotification(
        userId: customerUserId,
        title: 'Payment Successful!',
        message: 'Your payment of ₹${amount.toStringAsFixed(0)} for ${updated.service} was successfully received via Razorpay (Payment ID: $paymentId).',
        type: 'payment_success',
        requestId: updated.id,
        relatedUserId: updated.workerId,
      );
    }

    return updated;
  }

  /// Record payment failure / incomplete payment and notify customer to retry payment
  Future<ServiceRequest> recordPaymentFailure({
    required String requestId,
    required String reason,
    String? errorCode,
  }) async {
    ServiceRequest? targetReq;
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      targetReq = _mockRequests[index];
    }

    if (_isFirebaseInitialized && targetReq == null) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }
    }

    if (targetReq == null) {
      throw Exception('Service request not found');
    }

    final updated = targetReq.copyWith(
      paymentStatus: 'failed',
    );

    await updateRequest(updated);

    // Notify customer to retry payment
    final customerUserId = updated.customerId ??
        _mockUsers.where((u) => u.email.toLowerCase() == updated.email.toLowerCase()).firstOrNull?.uid;

    if (customerUserId != null && customerUserId.isNotEmpty) {
      final amountStr = (updated.totalAmount ?? 0.0).toStringAsFixed(0);
      await sendNotification(
        userId: customerUserId,
        title: 'Payment Incomplete - Retry Required',
        message: 'Your Razorpay payment of ₹$amountStr for ${updated.service} was not completed ($reason). Please tap here to retry your payment.',
        type: 'payment_failed',
        requestId: updated.id,
        relatedUserId: updated.workerId,
      );
    }

    return updated;
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String mobile,
    required String address,
    double? latitude,
    double? longitude,
    String? workerSkill,
    String? bio,
    String? avatarUrl,
  }) async {
    // 1. Update local storage & in-memory
    final index = _mockUsers.indexWhere((u) => u.uid == uid);
    final AppUser updated;
    if (index != -1) {
      updated = _mockUsers[index].copyWith(
        name: name,
        mobile: mobile,
        address: address,
        latitude: latitude,
        longitude: longitude,
        workerSkill: workerSkill,
        bio: bio,
        avatarUrl: avatarUrl ?? _mockUsers[index].avatarUrl,
      );
      _mockUsers[index] = updated;
    } else {
      final stored = _storage.getUserById(uid);
      updated = (stored != null)
          ? stored.copyWith(
              name: name,
              mobile: mobile,
              address: address,
              latitude: latitude,
              longitude: longitude,
              workerSkill: workerSkill,
              bio: bio,
              avatarUrl: avatarUrl ?? stored.avatarUrl,
            )
          : AppUser(
              uid: uid,
              email: '',
              name: name,
              mobile: mobile,
              address: address,
              latitude: latitude,
              longitude: longitude,
              workerSkill: workerSkill,
              bio: bio,
              avatarUrl: avatarUrl,
              role: UserRole.customer,
            );
      _mockUsers.add(updated);
    }
    await _storage.saveUser(updated);
    notifyListeners();

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        final Map<String, dynamic> firestoreMap = {
          'name': name,
          'mobile': mobile,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'workerSkill': workerSkill,
          'bio': bio,
        };
        if (avatarUrl != null) {
          firestoreMap['avatarUrl'] = avatarUrl;
        }
        await FirebaseFirestore.instance.collection('users').doc(uid).set(firestoreMap, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating user profile in Firestore: $e');
      }
    }
  }

  Future<void> updateUserLocation({
    required String uid,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    // 1. Update local storage & in-memory
    final index = _mockUsers.indexWhere((u) => u.uid == uid);
    final AppUser updated;
    if (index != -1) {
      updated = _mockUsers[index].copyWith(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      _mockUsers[index] = updated;
    } else {
      final stored = _storage.getUserById(uid);
      updated = (stored != null)
          ? stored.copyWith(latitude: latitude, longitude: longitude, address: address)
          : AppUser(
              uid: uid,
              email: '',
              name: 'User',
              mobile: '',
              address: address,
              latitude: latitude,
              longitude: longitude,
              role: UserRole.customer,
            );
      _mockUsers.add(updated);
    }
    await _storage.saveUser(updated);
    notifyListeners();

    // 2. Update Firebase server
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating user location in Firestore: $e');
      }
    }
  }

  // --- CATEGORY WORKER DISCOVERY & DIRECT BOOKING (1-HOUR EXPIRY) ---

  /// Finds all verified workers for a given category, sorted with PRO workers first, then distance & rating
  List<AppUser> getWorkersForCategory(
    String category, {
    double? customerLat,
    double? customerLon,
    double maxDistanceKm = 20.0,
    bool strictWithinRadius = false,
  }) {
    final catNorm = category.trim().toLowerCase();
    var workers = allUsers.where((u) {
      if (u.role != UserRole.worker) return false;
      final skill = (u.workerSkill ?? '').trim().toLowerCase();
      if (skill.isEmpty || skill == 'general service' || skill == 'all') return true;
      if (catNorm == 'general service' || catNorm == 'all') return true;
      if (skill == catNorm || skill.contains(catNorm) || catNorm.contains(skill)) return true;
      if (skill.contains('plumb') && catNorm.contains('plumb')) return true;
      if (skill.contains('electr') && catNorm.contains('electr')) return true;
      if (skill.contains('carpent') && catNorm.contains('carpent')) return true;
      if (skill.contains('paint') && catNorm.contains('paint')) return true;
      if (skill.contains('clean') && catNorm.contains('clean')) return true;
      if (skill.contains('appliance') && catNorm.contains('appliance')) return true;
      return false;
    }).toList();

    // Sort: 1) Distance (Nearest First), 2) Highest Rating
    workers.sort((a, b) {
      if (customerLat != null && customerLon != null) {
        final distA = calculateDistanceKm(
              lat1: customerLat,
              lon1: customerLon,
              lat2: a.latitude,
              lon2: a.longitude,
            ) ??
            9999.0;
        final distB = calculateDistanceKm(
              lat1: customerLat,
              lon1: customerLon,
              lat2: b.latitude,
              lon2: b.longitude,
            ) ??
            9999.0;
        final comp = distA.compareTo(distB);
        if (comp != 0) return comp;
      }

      return b.rating.compareTo(a.rating);
    });

    if (customerLat != null && customerLon != null && strictWithinRadius) {
      workers = workers.where((w) {
        final dist = calculateDistanceKm(
          lat1: customerLat,
          lon1: customerLon,
          lat2: w.latitude,
          lon2: w.longitude,
        );
        return dist == null || dist <= maxDistanceKm;
      }).toList();
    }

    return workers;
  }

  /// Customer books a specific worker directly.
  /// Worker has 1 hour to respond, after which the request automatically expires/rejects.
  Future<void> createDirectRequest({
    required ServiceRequest request,
    required AppUser targetWorker,
    required AppUser customer,
  }) async {
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    final directReq = request.copyWith(
      status: 'direct_pending',
      targetWorkerId: targetWorker.uid,
      targetWorkerName: targetWorker.name,
      directRequestExpiresAt: expiresAt,
      customerId: customer.uid,
      name: customer.name,
      email: customer.email,
      mobile: customer.mobile,
      address: request.address.isNotEmpty ? request.address : (customer.address ?? ''),
      latitude: request.latitude ?? customer.latitude,
      longitude: request.longitude ?? customer.longitude,
    );

    await addRequest(directReq);

    // 1. Notify targeted worker
    await sendNotification(
      userId: targetWorker.uid,
      title: 'Direct Job Request! ⏳',
      message: '${customer.name} sent you a direct request for ${directReq.service}! Please review their profile & accept within 1 hour.',
      type: 'direct_request',
      requestId: directReq.id,
      relatedUserId: customer.uid,
    );

    // 2. Notify customer
    await sendNotification(
      userId: customer.uid,
      title: 'Direct Request Sent',
      message: 'Your request for ${directReq.service} was sent directly to ${targetWorker.name}. They have 1 hour to respond.',
      type: 'direct_request_sent',
      requestId: directReq.id,
      relatedUserId: targetWorker.uid,
    );

    // 3. Dispatch real email to targeted worker & customer confirmation from moditapan0@gmail.com
    unawaited(EmailService().sendDirectRequestEmail(
      request: directReq,
      customer: customer,
      targetWorker: targetWorker,
    ));
  }

  /// Worker accepts a direct request within the 1-hour window
  Future<void> acceptDirectRequest({
    required String requestId,
    required String workerId,
    required String workerName,
  }) async {
    await checkAndExpireDirectRequests();

    ServiceRequest? target = _mockRequests.where((r) => r.id == requestId).firstOrNull;
    if (target == null && _isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          target = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } catch (_) {}
    }
    if (target == null) throw Exception('Request not found.');

    if (target.isDirectExpired || target.status == 'rejected') {
      throw Exception('This direct request has expired (1 hour limit exceeded) or was declined.');
    }

    if (target.status == 'assigned') {
      throw Exception('This request has already been assigned.');
    }

    final updated = target.copyWith(
      status: 'assigned',
      workerId: workerId,
      workerName: workerName,
    );
    await updateRequest(updated);

    final wrk = await getUserById(workerId);
    final cust = (target.customerId != null) ? await getUserById(target.customerId!) : null;
    final cEmail = target.email.isNotEmpty ? target.email : (cust?.email ?? '');
    final cName = target.name.isNotEmpty ? target.name : (cust?.name ?? 'Customer');

    // 1. App notification to Customer
    if (target.customerId != null && target.customerId!.isNotEmpty) {
      await sendNotification(
        userId: target.customerId!,
        title: 'Direct Request Accepted! 🎉',
        message: '$workerName accepted your direct request for ${target.service}! Work is scheduled.',
        type: 'direct_request_accepted',
        requestId: requestId,
        relatedUserId: workerId,
      );
    }

    // 2. App notification to Worker
    await sendNotification(
      userId: workerId,
      title: 'Job Accepted! 🛠️',
      message: 'You have accepted $cName\'s direct request for ${target.service}! Work is scheduled at ${target.address}.',
      type: 'direct_request_accepted_worker',
      requestId: requestId,
      relatedUserId: target.customerId,
    );

    // 3. Real email notification from moditapan0@gmail.com to both customer and worker
    unawaited(EmailService().sendJobAcceptedEmail(
      request: updated,
      workerName: workerName,
      workerEmail: wrk?.email,
      customerName: cName,
      customerEmail: cEmail,
      isDirectRequest: true,
    ));
  }

  /// Worker declines a direct request
  Future<void> declineDirectRequest({
    required String requestId,
    required String workerId,
    required String workerName,
    String? reason,
  }) async {
    ServiceRequest? target = _mockRequests.where((r) => r.id == requestId).firstOrNull;
    if (target == null && _isFirebaseInitialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          target = ServiceRequest.fromMap(doc.data()!, id: doc.id);
        }
      } catch (_) {}
    }
    if (target == null) return;

    final updated = target.copyWith(status: 'rejected');
    await updateRequest(updated);

    if (target.customerId != null && target.customerId!.isNotEmpty) {
      await sendNotification(
        userId: target.customerId!,
        title: 'Direct Request Declined',
        message: '$workerName was unable to take your ${target.service} request at this time. You can request another worker or post a public request.',
        type: 'direct_request_declined',
        requestId: requestId,
        relatedUserId: workerId,
      );
    }
  }

  /// Automatically check and expire direct requests that have passed the 1-hour window
  Future<void> checkAndExpireDirectRequests() async {
    final now = DateTime.now();
    final expired = _mockRequests
        .where((r) =>
            r.isDirectPending &&
            r.directRequestExpiresAt != null &&
            now.isAfter(r.directRequestExpiresAt!))
        .toList();

    for (final req in expired) {
      final updated = req.copyWith(status: 'rejected');
      await updateRequest(updated);

      if (req.customerId != null && req.customerId!.isNotEmpty) {
        await sendNotification(
          userId: req.customerId!,
          title: 'Direct Request Expired ⏰',
          message:
              'Your direct request to ${req.targetWorkerName ?? "worker"} expired because they did not respond within 1 hour. You can choose another nearby worker or post a request.',
          type: 'direct_request_expired',
          requestId: req.id,
          relatedUserId: req.targetWorkerId,
        );
      }
    }

    if (_isFirebaseInitialized) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('service_requests')
            .where('status', isEqualTo: 'direct_pending')
            .get();
        for (final doc in snapshot.docs) {
          final req = ServiceRequest.fromMap(doc.data(), id: doc.id);
          if (req.directRequestExpiresAt != null && now.isAfter(req.directRequestExpiresAt!)) {
            final updated = req.copyWith(status: 'rejected');
            await updateRequest(updated);

            if (req.customerId != null && req.customerId!.isNotEmpty) {
              await sendNotification(
                userId: req.customerId!,
                title: 'Direct Request Expired ⏰',
                message:
                    'Your direct request to ${req.targetWorkerName ?? "worker"} expired because they did not respond within 1 hour. You can choose another nearby worker or post a request.',
                type: 'direct_request_expired',
                requestId: req.id,
                relatedUserId: req.targetWorkerId,
              );
            }
          }
        }
      } catch (_) {}
    }
  }

  /// Stream direct invitations targeted specifically to this worker
  Stream<List<ServiceRequest>> streamWorkerDirectInvitations(String workerId) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('service_requests')
          .snapshots()
          .map((snapshot) {
            final now = DateTime.now();
            final firestoreList = snapshot.docs
                .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
                .where((r) {
                  if (r.targetWorkerId != workerId) return false;
                  if (r.status != 'direct_pending') return false;
                  if (r.directRequestExpiresAt != null && now.isAfter(r.directRequestExpiresAt!)) {
                    return false;
                  }
                  return true;
                }).toList();

            final map = <String, ServiceRequest>{};
            for (final r in firestoreList) {
              map[r.id] = r;
            }
            for (final r in _mockRequests) {
              if (r.targetWorkerId == workerId &&
                  r.status == 'direct_pending' &&
                  (r.directRequestExpiresAt == null || !now.isAfter(r.directRequestExpiresAt!))) {
                map.putIfAbsent(r.id, () => r);
              }
            }
            return map.values.toList();
          });
    } else {
      return Stream<List<ServiceRequest>>.multi((controller) {
        List<ServiceRequest> filter(List<ServiceRequest> list) {
          final now = DateTime.now();
          return list.where((r) {
            if (r.targetWorkerId != workerId) return false;
            if (r.status != 'direct_pending') return false;
            if (r.directRequestExpiresAt != null && now.isAfter(r.directRequestExpiresAt!)) {
              return false;
            }
            return true;
          }).toList();
        }

        controller.add(filter(_mockRequests));
        final sub = _mockRequestsStreamController.stream.listen((list) {
          controller.add(filter(list));
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  /// Upgrade / Activate user's membership in database and dispatch celebratory notification
  Future<void> upgradeMembership({
    required String userId,
    required String planId,
    required String tierName,
    required int durationDays,
    required double price,
  }) async {
    final expiresAt = DateTime.now().add(Duration(days: durationDays));

    AppUser? user;
    final idx = _mockUsers.indexWhere((u) => u.uid == userId);
    if (idx != -1) {
      user = _mockUsers[idx];
    } else {
      user = _storage.getUserById(userId);
      if (user == null && _isFirebaseInitialized) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (doc.exists && doc.data() != null) {
            user = AppUser.fromMap(doc.data()!, uid: doc.id);
          }
        } catch (_) {}
      }
    }

    if (user != null) {
      final isPro = user.isWorker;
      final updated = user.copyWith(
        membershipPlan: planId,
        membershipTier: tierName,
        membershipExpiresAt: expiresAt,
        isProMember: isPro,
      );
      if (idx != -1) {
        _mockUsers[idx] = updated;
      } else {
        _mockUsers.add(updated);
      }
      await _storage.saveUser(updated);

      if (_isFirebaseInitialized) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'membershipPlan': planId,
            'membershipTier': tierName,
            'membershipExpiresAt': expiresAt.toIso8601String(),
            'isProMember': isPro,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error updating membership in Firestore: $e');
        }
      }

      // Dispatch congratulations notification
      final isWorker = user.isWorker;
      await sendNotification(
        userId: userId,
        title: isWorker ? 'Worker Pro Active! 🌟' : 'LocalServe Plus Active! 👑',
        message: isWorker
            ? 'Congratulations! You are now a $tierName member with #1 Category Rank & Verified Pro Badge.'
            : 'Welcome to $tierName! Enjoy ₹0 inspection fees on all bookings and exclusive discounts.',
        type: 'membership_activated',
      );

      notifyListeners();
    }
  }
}
