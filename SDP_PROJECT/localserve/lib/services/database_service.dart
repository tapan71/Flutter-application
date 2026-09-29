import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';

class DatabaseService extends ChangeNotifier {
  bool _isFirebaseInitialized = false;

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

  // Static in-memory store for mock/demo mode to persist across logins & logouts
  static final List<ServiceRequest> _mockRequests = [
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
  ];

  static final List<AppUser> _mockUsers = [
    const AppUser(
      uid: 'demo_customer_1',
      email: 'customer@localserve.com',
      name: 'John Customer',
      mobile: '9876543210',
      address: '102 Green Heights, 5th Main Road',
      latitude: 23.0225,
      longitude: 72.5714,
      role: UserRole.customer,
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
    ),
  ];

  static final StreamController<List<ServiceRequest>> _mockRequestsStreamController =
      StreamController<List<ServiceRequest>>.broadcast();

  List<ServiceRequest> get allRequests => List.unmodifiable(_mockRequests);
  List<AppUser> get allUsers => List.unmodifiable(_mockUsers);

  DatabaseService() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      }
    } catch (_) {}
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

  Stream<List<ServiceRequest>> streamAvailableRequests() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('service_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ServiceRequest.fromMap(doc.data(), id: doc.id))
              .toList());
    } else {
      return Stream<List<ServiceRequest>>.multi((controller) {
        controller.add(_mockRequests.where((r) => r.status == 'pending').toList());
        final sub = _mockRequestsStreamController.stream.listen((_) {
          controller.add(_mockRequests.where((r) => r.status == 'pending').toList());
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  Stream<List<ServiceRequest>> streamWorkerJobs(String workerId) {
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
        controller.add(_mockRequests.where((r) => r.workerId == workerId).toList());
        final sub = _mockRequestsStreamController.stream.listen((_) {
          controller.add(_mockRequests.where((r) => r.workerId == workerId).toList());
        });
        controller.onCancel = () => sub.cancel();
      });
    }
  }

  // --- ACTIONS ---

  Future<void> addRequest(ServiceRequest request) async {
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(request.id)
          .set(request.toMap());
    } else {
      _mockRequests.insert(0, request);
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
      _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
    }
  }

  Future<void> acceptJob({
    required String requestId,
    required String workerId,
    required String workerName,
    AppUser? worker,
  }) async {
    // 20 km service radius validation
    if (worker != null) {
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
        final km = calculateDistanceKm(
          lat1: worker.latitude,
          lon1: worker.longitude,
          lat2: targetReq.latitude,
          lon2: targetReq.longitude,
        );

        if (km != null && km > maxWorkerDistanceKm) {
          throw Exception(
            'Cannot accept job: Customer is ${km.toStringAsFixed(1)} km away. You can only accept requests within your 20 km service radius.',
          );
        }
      }
    }

    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'status': 'assigned',
        'workerId': workerId,
        'workerName': workerName,
      });
    } else {
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _mockRequests[index] = _mockRequests[index].copyWith(
          status: 'assigned',
          workerId: workerId,
          workerName: workerName,
        );
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
        notifyListeners();
      }
    }
  }

  Future<void> updateStatus({
    required String requestId,
    required String newStatus,
  }) async {
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({'status': newStatus});
    } else {
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _mockRequests[index] = _mockRequests[index].copyWith(
          status: newStatus,
          completed: newStatus == 'completed',
        );
        _mockRequestsStreamController.add(List.unmodifiable(_mockRequests));
        notifyListeners();
      }
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
      _mockUsers[index] = _mockUsers[index].copyWith(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      notifyListeners();
    }
  }
}
