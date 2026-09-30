import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../models/review_model.dart';
import '../models/notification_model.dart';
import 'local_storage_service.dart';

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
      service: 'Electrical',
      name: 'Sarah Connor',
      email: 'sarah@example.com',
      mobile: '9811223344',
      address: '44 Hill View Avenue',
      latitude: 23.0338,
      longitude: 72.5850,
      priority: 'Medium',
      reminder: false,
      description: 'Living room ceiling fan regulator sparking.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      status: 'assigned',
      customerId: 'demo_customer_2',
      workerId: 'demo_worker_1',
      workerName: 'Alex Plumber',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    ServiceRequest(
      id: 'req_3',
      service: 'Cleaning',
      name: 'John Customer',
      email: 'customer@localserve.com',
      mobile: '9876543210',
      address: '102 Green Heights, 5th Main Road',
      latitude: 23.0225,
      longitude: 72.5714,
      priority: 'Low',
      reminder: false,
      description: 'Deep bathroom and balcony cleaning before weekend.',
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
      service: 'Cleaning',
      fromUserId: 'demo_customer_1',
      fromUserName: 'John Customer',
      fromUserRole: 'customer',
      toUserId: 'demo_worker_1',
      toUserName: 'Alex Plumber',
      rating: 5.0,
      comment: 'Super fast, punctual, and thoroughly cleaned the apartment. Highly recommend!',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Review(
      id: 'rev_2',
      requestId: 'req_3',
      service: 'Cleaning',
      fromUserId: 'demo_worker_1',
      fromUserName: 'Alex Plumber',
      fromUserRole: 'worker',
      toUserId: 'demo_customer_1',
      toUserName: 'John Customer',
      rating: 5.0,
      comment: 'Polite and clear communication. Immediate payment upon work completion.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
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
  List<AppUser> get allUsers => List.unmodifiable(_mockUsers);

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

    // 1. Load Requests
    final savedReqs = _storage.getAllRequests();
    if (savedReqs.isEmpty) {
      _mockRequests.addAll(_defaultRequests);
      for (final r in _defaultRequests) {
        await _storage.saveRequest(r);
      }
    } else {
      _mockRequests.addAll(savedReqs);
    }

    // 2. Load Users
    final savedUsers = _storage.getAllUsers();
    if (savedUsers.isEmpty) {
      _mockUsers.addAll(_defaultUsers);
      for (final u in _defaultUsers) {
        await _storage.saveUser(u);
      }
    } else {
      _mockUsers.addAll(savedUsers);
      for (final def in _defaultUsers) {
        if (!_mockUsers.any((u) => u.uid == def.uid)) {
          _mockUsers.add(def);
        }
      }
    }

    // 3. Load Notifications
    final savedNotifs = _storage.getAllNotifications();
    if (savedNotifs.isEmpty) {
      _mockNotifications.addAll(_defaultNotifications);
      for (final n in _defaultNotifications) {
        await _storage.saveNotification(n);
      }
    } else {
      _mockNotifications.addAll(savedNotifs);
    }

    // 4. Load Reviews
    final savedRevs = _storage.getAllReviews();
    if (savedRevs.isEmpty) {
      _mockReviews.addAll(_defaultReviews);
      for (final rev in _defaultReviews) {
        await _storage.saveReview(rev);
      }
    } else {
      _mockReviews.addAll(savedRevs);
    }

    _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
    _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
    _mockReviewsStreamController.add(List.unmodifiable(_mockReviews));
    notifyListeners();
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
          .map((snapshot) => snapshot.docs
              .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
              .where((r) =>
                  r.customerId == customerId ||
                  (customerEmail != null &&
                      customerEmail.isNotEmpty &&
                      r.email.trim().toLowerCase() ==
                          customerEmail.trim().toLowerCase()))
              .toList());
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

  Stream<List<ServiceRequest>> streamAvailableRequests({String? skill}) {
    final skillFilter = (skill != null &&
            skill.trim().isNotEmpty &&
            skill.trim().toLowerCase() != 'general service' &&
            skill.trim().toLowerCase() != 'all')
        ? skill.trim().toLowerCase()
        : null;

    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
              .where((r) {
                if (skillFilter == null) return true;
                final reqService = r.service.trim().toLowerCase();
                if (reqService == 'general service' || reqService == 'general') return true;
                return reqService == skillFilter;
              })
              .toList());
    } else {
      return Stream<List<ServiceRequest>>.multi((controller) {
        List<ServiceRequest> filter(List<ServiceRequest> list) {
          return list.where((r) {
            if (r.status != 'pending') return false;
            if (skillFilter == null) return true;
            final reqService = r.service.trim().toLowerCase();
            if (reqService == 'general service' || reqService == 'general') return true;
            return reqService == skillFilter;
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
          .map((snapshot) => snapshot.docs
              .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
              .toList());
    } else {
      return Stream<List<ServiceRequest>>.multi((controller) {
        List<ServiceRequest> filter(List<ServiceRequest> list) {
          return list.where((r) => r.workerId == workerId).toList();
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

  // --- IN-APP NOTIFICATIONS ---

  List<AppNotification> getNotifications(String userId) {
    return _mockNotifications.where((n) => n.userId == userId).toList();
  }

  Stream<List<AppNotification>> streamNotifications(String userId) =>
      streamNotificationsForUser(userId);

  Stream<List<AppNotification>> streamNotificationsForUser(String userId) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), id: doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } else {
      return Stream<List<AppNotification>>.multi((controller) {
        List<AppNotification> filter(List<AppNotification> list) {
          final res = list.where((n) => n.userId == userId).toList();
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
  }) async {
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

    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notif.id)
          .set(notif.toMap());
    } else {
      _mockNotifications.insert(0, notif);
      await _storage.saveNotification(notif);
      _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
      notifyListeners();
    }
  }

  Future<void> markNotificationsAsRead(String userId) async {
    if (_isFirebaseInitialized) {
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
    } else {
      for (int i = 0; i < _mockNotifications.length; i++) {
        if (_mockNotifications[i].userId == userId) {
          _mockNotifications[i] = _mockNotifications[i].copyWith(isRead: true);
        }
      }
      await _storage.markNotificationsRead(userId);
      _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) =>
      markNotificationsAsRead(userId);

  Future<void> markNotificationAsRead(String notificationId) async {
    final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _mockNotifications[idx] = _mockNotifications[idx].copyWith(isRead: true);
      await _storage.saveNotification(_mockNotifications[idx]);
      _mockNotificationsStreamController.add(List.unmodifiable(_mockNotifications));
      notifyListeners();
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
        final list = snapshot.docs
            .map((doc) => Review.fromMap(doc.data(), id: doc.id))
            .toList();
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
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(review.id)
          .set(review.toMap());

      // Mark request reviewed
      final fieldToUpdate = review.fromUserRole == 'customer'
          ? {'customerReviewed': true}
          : {'workerReviewed': true};

      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(review.requestId)
          .update(fieldToUpdate);

      // Recalculate recipient rating
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
    } else {
      _mockReviews.insert(0, review);
      await _storage.saveReview(review);
      _mockReviewsStreamController.add(List.unmodifiable(_mockReviews));

      // Update Service Request review flag
      final reqIdx = _mockRequests.indexWhere((r) => r.id == review.requestId);
      if (reqIdx != -1) {
        final updated = review.fromUserRole == 'customer'
            ? _mockRequests[reqIdx].copyWith(customerReviewed: true)
            : _mockRequests[reqIdx].copyWith(workerReviewed: true);
        _mockRequests[reqIdx] = updated;
        await _storage.saveRequest(updated);
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      }

      // Update recipient user rating metrics
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
    final newReq = request.copyWith(status: request.status.isEmpty ? 'pending' : request.status);
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(newReq.id)
          .set(newReq.toMap());
    } else {
      _mockRequests.insert(0, newReq);
      await _storage.saveRequest(newReq);
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
    }
  }

  Future<void> updateRequest(ServiceRequest request) async {
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(request.id)
          .update(request.toMap());
    } else {
      final index = _mockRequests.indexWhere((r) => r.id == request.id);
      if (index != -1) {
        _mockRequests[index] = request;
        await _storage.saveRequest(request);
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
        notifyListeners();
      }
    }
  }

  Future<void> deleteRequest(String requestId) async {
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .delete();
    } else {
      _mockRequests.removeWhere((r) => r.id == requestId);
      await _storage.deleteRequest(requestId);
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
    }
  }

  /// Cancels a customer service request and notifies any workers involved.
  Future<void> cancelRequest({
    required String requestId,
    String? reason,
  }) async {
    ServiceRequest? targetReq;

    if (_isFirebaseInitialized) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'status': 'cancelled',
        'completed': false,
      });
    } else {
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
        final workerSkill = worker.workerSkill!.trim().toLowerCase();
        final reqService = targetReq.service.trim().toLowerCase();
        if (workerSkill != 'general service' && workerSkill != 'all') {
          if (reqService.isNotEmpty &&
              reqService != 'general service' &&
              reqService != 'general' &&
              reqService != workerSkill) {
            throw Exception(
              'Specialization mismatch: Your profile is registered as $workerSkill and cannot accept $reqService requests.',
            );
          }
        }
      }
    }

    ServiceRequest? target;
    if (_isFirebaseInitialized) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        target = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }

      if (target != null && target.status != 'pending') {
        throw Exception('This job has already been confirmed and assigned to another worker.');
      }

      if (autoConfirm) {
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
    } else {
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        target = _mockRequests[index];
        if (target.status != 'pending') {
          throw Exception('This job has already been confirmed and assigned to another worker.');
        }

        if (autoConfirm) {
          final updated = _mockRequests[index].copyWith(
            workerId: workerId,
            workerName: workerName,
            status: 'assigned',
          );
          _mockRequests[index] = updated;
          await _storage.saveRequest(updated);
        } else {
          final updatedApplicants = List<String>.from(_mockRequests[index].applicantWorkerIds);
          if (!updatedApplicants.contains(workerId)) {
            updatedApplicants.add(workerId);
          }
          final updated = _mockRequests[index].copyWith(
            applicantWorkerIds: updatedApplicants,
          );
          _mockRequests[index] = updated;
          await _storage.saveRequest(updated);
        }
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
        notifyListeners();
      }
    }

    if (target != null) {
      if (target.customerId != null && target.customerId!.isNotEmpty) {
        await sendNotification(
          userId: target.customerId!,
          title: 'Worker Applied!',
          message: '$workerName wants to do your ${target.service} job! Review their profile and confirm.',
          type: 'worker_applied',
          requestId: requestId,
          relatedUserId: workerId,
        );
      }

      await sendNotification(
        userId: workerId,
        title: 'Application Sent!',
        message: 'You applied for ${target.name}\'s ${target.service} request. Waiting for customer confirmation.',
        type: 'worker_applied',
        requestId: requestId,
        relatedUserId: target.customerId,
      );
    }
  }

  /// Customer confirms an applicant worker.
  Future<void> confirmWorker({
    required String requestId,
    required String workerId,
    required String workerName,
    String? customerId,
  }) async {
    ServiceRequest? targetReq;

    if (_isFirebaseInitialized) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }

      await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({
        'workerId': workerId,
        'workerName': workerName,
        'status': 'assigned',
      });
    } else {
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        targetReq = _mockRequests[index];
        final updated = _mockRequests[index].copyWith(
          workerId: workerId,
          workerName: workerName,
          status: 'assigned',
        );
        _mockRequests[index] = updated;
        await _storage.saveRequest(updated);
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
        notifyListeners();
      }
    }

    if (targetReq != null) {
      await sendNotification(
        userId: workerId,
        title: 'Job Confirmed! 🎉',
        message: '${targetReq.name} accepted your application for ${targetReq.service}! You can now start work.',
        type: 'customer_accepted',
        requestId: requestId,
        relatedUserId: targetReq.customerId,
      );

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
    ServiceRequest? targetReq;

    if (_isFirebaseInitialized) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }

      await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({
        'applicantWorkerIds': FieldValue.arrayRemove([workerId]),
        'declinedWorkerIds': FieldValue.arrayUnion([workerId]),
      });
    } else {
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        targetReq = _mockRequests[index];
        final applicants = List<String>.from(_mockRequests[index].applicantWorkerIds)..remove(workerId);
        final declined = List<String>.from(_mockRequests[index].declinedWorkerIds);
        if (!declined.contains(workerId)) declined.add(workerId);

        final updated = _mockRequests[index].copyWith(
          applicantWorkerIds: applicants,
          declinedWorkerIds: declined,
        );
        _mockRequests[index] = updated;
        await _storage.saveRequest(updated);
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
        notifyListeners();
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
    ServiceRequest? targetReq;
    if (_isFirebaseInitialized) {
      final doc = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        targetReq = ServiceRequest.fromMap(doc.data()!, id: doc.id);
      }
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'status': newStatus,
        'completed': newStatus == 'completed',
      });
    } else {
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        targetReq = _mockRequests[index];
        final updated = _mockRequests[index].copyWith(
          status: newStatus,
          completed: newStatus == 'completed',
        );
        _mockRequests[index] = updated;
        await _storage.saveRequest(updated);
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
        notifyListeners();
      }
    }

    if (newStatus == 'completed' && targetReq != null) {
      if (targetReq.customerId != null && targetReq.customerId!.isNotEmpty) {
        await sendNotification(
          userId: targetReq.customerId!,
          title: 'Job Completed!',
          message: 'Your ${targetReq.service} job is complete. Please leave a review for ${targetReq.workerName ?? "your worker"}!',
          type: 'job_completed',
          requestId: requestId,
          relatedUserId: targetReq.workerId,
        );
      }
      if (targetReq.workerId != null && targetReq.workerId!.isNotEmpty) {
        await sendNotification(
          userId: targetReq.workerId!,
          title: 'Job Completed!',
          message: 'The ${targetReq.service} job for ${targetReq.name} is complete. Please leave a review for the customer!',
          type: 'job_completed',
          requestId: requestId,
          relatedUserId: targetReq.customerId,
        );
      }
    }
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
  }) async {
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': name,
        'mobile': mobile,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'workerSkill': workerSkill,
        'bio': bio,
      });
    }

    final index = _mockUsers.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      final updated = _mockUsers[index].copyWith(
        name: name,
        mobile: mobile,
        address: address,
        latitude: latitude,
        longitude: longitude,
        workerSkill: workerSkill,
        bio: bio,
      );
      _mockUsers[index] = updated;
      await _storage.saveUser(updated);
      notifyListeners();
    }
  }

  Future<void> updateUserLocation({
    required String uid,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });
    }

    final index = _mockUsers.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      final updated = _mockUsers[index].copyWith(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      _mockUsers[index] = updated;
      await _storage.saveUser(updated);
      notifyListeners();
    } else {
      final stored = _storage.getUserById(uid);
      final updated = (stored != null)
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
      await _storage.saveUser(updated);
      notifyListeners();
    }
  }

  // --- CATEGORY WORKER DISCOVERY & DIRECT BOOKING (1-HOUR EXPIRY) ---

  /// Finds all verified workers for a given category, sorted by distance from the customer
  List<AppUser> getWorkersForCategory(
    String category, {
    double? customerLat,
    double? customerLon,
    double maxDistanceKm = 20.0,
    bool strictWithinRadius = false,
  }) {
    final catNorm = category.trim().toLowerCase();
    final workers = _mockUsers.where((u) {
      if (u.role != UserRole.worker) return false;
      final skill = (u.workerSkill ?? '').trim().toLowerCase();
      if (skill.isEmpty || skill == 'general service' || skill == 'all') return true;
      if (catNorm == 'general service' || catNorm == 'all') return true;
      return skill == catNorm;
    }).toList();

    // Sort by distance if customer has coordinates
    if (customerLat != null && customerLon != null) {
      workers.sort((a, b) {
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
        return distA.compareTo(distB);
      });

      if (strictWithinRadius) {
        return workers.where((w) {
          final dist = calculateDistanceKm(
            lat1: customerLat,
            lon1: customerLon,
            lat2: w.latitude,
            lon2: w.longitude,
          );
          return dist == null || dist <= maxDistanceKm;
        }).toList();
      }
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
  }

  /// Worker accepts a direct request within the 1-hour window
  Future<void> acceptDirectRequest({
    required String requestId,
    required String workerId,
    required String workerName,
  }) async {
    await checkAndExpireDirectRequests();

    final target = _mockRequests.where((r) => r.id == requestId).firstOrNull;
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
  }

  /// Worker declines a direct request
  Future<void> declineDirectRequest({
    required String requestId,
    required String workerId,
    required String workerName,
    String? reason,
  }) async {
    final target = _mockRequests.where((r) => r.id == requestId).firstOrNull;
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
  }

  /// Stream direct invitations targeted specifically to this worker
  Stream<List<ServiceRequest>> streamWorkerDirectInvitations(String workerId) {
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
