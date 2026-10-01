import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:localserve/models/user_model.dart';
import 'package:localserve/models/service_request.dart';
import 'package:localserve/models/review_model.dart';
import 'package:localserve/services/geocoding_service.dart';
import 'package:localserve/services/auth_service.dart';
import 'package:localserve/services/database_service.dart';
import 'package:localserve/services/local_storage_service.dart';
import 'package:localserve/services/razorpay_service.dart';

void main() {
  setUp(() {
    LocalStorageService().resetForTesting();
  });

  group('OpenStreetMap & Nominatim Location Tests', () {
    test('LocationSearchResult parses Nominatim JSON response correctly', () {
      final json = {
        'lat': '23.022505',
        'lon': '72.571362',
        'display_name': 'Green Heights, 5th Main Road, Navrangpura, Ahmedabad, Gujarat, India',
        'address': {
          'road': '5th Main Road',
          'suburb': 'Navrangpura',
          'city': 'Ahmedabad',
          'state': 'Gujarat',
          'postcode': '380009',
        }
      };

      final result = LocationSearchResult.fromJson(json);

      expect(result.latitude, closeTo(23.0225, 0.0001));
      expect(result.longitude, closeTo(72.5713, 0.0001));
      expect(result.road, '5th Main Road');
      expect(result.suburb, 'Navrangpura');
      expect(result.city, 'Ahmedabad');
      expect(result.state, 'Gujarat');
      expect(result.shortAddress, '5th Main Road, Navrangpura, Ahmedabad, Gujarat');
    });

    test('AppUser handles coordinates and hasLocation getter', () {
      const userWithoutLoc = AppUser(
        uid: 'u1',
        email: 'u1@example.com',
        name: 'User 1',
        mobile: '1234567890',
        role: UserRole.worker,
      );
      expect(userWithoutLoc.hasLocation, isFalse);

      final userWithLoc = userWithoutLoc.copyWith(
        latitude: 23.0225,
        longitude: 72.5714,
        address: 'Ahmedabad Center',
      );
      expect(userWithLoc.hasLocation, isTrue);
      expect(userWithLoc.latitude, 23.0225);
      expect(userWithLoc.longitude, 72.5714);

      // Verify toMap & fromMap
      final map = userWithLoc.toMap();
      expect(map['latitude'], 23.0225);
      expect(map['longitude'], 72.5714);
      expect(map['address'], 'Ahmedabad Center');

      final deserialized = AppUser.fromMap(map, uid: 'u1');
      expect(deserialized.latitude, 23.0225);
      expect(deserialized.longitude, 72.5714);
      expect(deserialized.address, 'Ahmedabad Center');
    });

    test('ServiceRequest handles coordinates and hasLocation getter', () {
      final req = ServiceRequest(
        id: 'r1',
        service: 'Plumbing',
        name: 'Customer',
        email: 'c@example.com',
        mobile: '9876543210',
        address: '102 Green Heights',
        latitude: 23.0225,
        longitude: 72.5714,
        priority: 'High',
        reminder: true,
        description: 'Pipe leaking',
      );

      expect(req.hasLocation, isTrue);
      expect(req.latitude, 23.0225);
      expect(req.longitude, 72.5714);

      final map = req.toMap();
      expect(map['latitude'], 23.0225);
      expect(map['longitude'], 72.5714);

      final deserialized = ServiceRequest.fromMap(map, id: 'r1');
      expect(deserialized.hasLocation, isTrue);
      expect(deserialized.latitude, 23.0225);
      expect(deserialized.longitude, 72.5714);
    });

    test('latlong2 distance calculation between worker and customer', () {
      // Customer: 23.0225, 72.5714
      // Worker: 23.0338, 72.5850 (~1.8 km distance)
      const distanceCalc = Distance();
      final p1 = const LatLng(23.0225, 72.5714);
      final p2 = const LatLng(23.0338, 72.5850);

      final meters = distanceCalc.as(LengthUnit.Meter, p1, p2);
      expect(meters, greaterThan(1500));
      expect(meters, lessThan(2500));
    });

    test('AuthService & DatabaseService update user location in real-time', () async {
      final auth = AuthService();
      final db = DatabaseService();

      auth.signInWithDemoUser(AuthService.demoUsers.last); // Worker
      expect(auth.currentUser?.role, UserRole.worker);

      await auth.updateCurrentUserLocation(
        latitude: 23.0500,
        longitude: 72.6000,
        address: 'New Workshop, CG Road',
      );

      expect(auth.currentUser?.latitude, 23.0500);
      expect(auth.currentUser?.longitude, 72.6000);
      expect(auth.currentUser?.address, 'New Workshop, CG Road');

      await db.updateUserLocation(
        uid: auth.currentUser!.uid,
        latitude: 23.0500,
        longitude: 72.6000,
        address: 'New Workshop, CG Road',
      );

      final updatedUserInDb = db.allUsers.firstWhere((u) => u.uid == auth.currentUser!.uid);
      expect(updatedUserInDb.latitude, 23.0500);
      expect(updatedUserInDb.address, 'New Workshop, CG Road');
    });

    test('AuthService.signUp accepts default coordinates and persists them on AppUser', () async {
      final auth = AuthService();
      const testEmail = 'newuser.location@example.com';

      await auth.signUp(
        email: testEmail,
        password: 'password123',
        name: 'GPS User',
        mobile: '9988776655',
        address: 'Shiva Statue, Raopura Road, Vadodara',
        latitude: 22.3008,
        longitude: 73.2043,
        role: UserRole.customer,
      );

      final user = auth.currentUser;
      expect(user, isNotNull);
      expect(user?.email, testEmail);
      expect(user?.hasLocation, isTrue);
      expect(user?.latitude, 22.3008);
      expect(user?.longitude, 73.2043);
      expect(user?.address, 'Shiva Statue, Raopura Road, Vadodara');
    });

    test('DatabaseService enforces 20 km service radius for worker job acceptance', () async {
      final db = DatabaseService();

      // Worker in Ahmedabad
      const workerInAhmedabad = AppUser(
        uid: 'worker_ahmedabad',
        email: 'ahmedabad.worker@example.com',
        name: 'Ahmedabad Plumber',
        mobile: '9123456789',
        address: 'Navrangpura, Ahmedabad',
        latitude: 23.0260,
        longitude: 72.5760,
        role: UserRole.worker,
      );

      // req_1 is in Ahmedabad (~0.6 km away, well within 20 km)
      await db.acceptJob(
        requestId: 'req_1',
        workerId: workerInAhmedabad.uid,
        workerName: workerInAhmedabad.name,
        worker: workerInAhmedabad,
        autoConfirm: true,
      );

      final acceptedReq1 = db.allRequests.firstWhere((r) => r.id == 'req_1');
      expect(acceptedReq1.status, 'assigned');
      expect(acceptedReq1.workerId, workerInAhmedabad.uid);

      // req_4 is in Vadodara (~100 km away, far beyond 20 km limit)
      expect(
        () async => await db.acceptJob(
          requestId: 'req_4',
          workerId: workerInAhmedabad.uid,
          workerName: workerInAhmedabad.name,
          worker: workerInAhmedabad,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('20 km'),
          ),
        ),
      );

      // Worker without location attempting to accept job
      const workerWithoutLocation = AppUser(
        uid: 'worker_no_loc',
        email: 'noloc@example.com',
        name: 'No Location Worker',
        mobile: '9111111111',
        role: UserRole.worker,
      );

      expect(
        () async => await db.acceptJob(
          requestId: 'req_1',
          workerId: workerWithoutLocation.uid,
          workerName: workerWithoutLocation.name,
          worker: workerWithoutLocation,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('set your base location'),
          ),
        ),
      );
    });

    test('Worker specialization filters available service requests and blocks mismatching job acceptance', () async {
      final db = DatabaseService();

      // Create test requests
      final plumbingReq = ServiceRequest(
        id: 'spec_test_plumbing_1',
        service: 'Plumbing',
        name: 'Plumbing Customer',
        email: 'pc@test.com',
        mobile: '9898989898',
        address: 'Ahmedabad',
        latitude: 23.0225,
        longitude: 72.5714,
        priority: 'High',
        reminder: false,
        description: 'Leaking bathroom pipe',
        status: 'pending',
      );
      final electricalReq = ServiceRequest(
        id: 'spec_test_electrical_1',
        service: 'Electrical',
        name: 'Electrical Customer',
        email: 'ec@test.com',
        mobile: '9797979797',
        address: 'Ahmedabad',
        latitude: 23.0230,
        longitude: 72.5720,
        priority: 'Medium',
        reminder: false,
        description: 'Bedroom light socket short circuit',
        status: 'pending',
      );
      final generalReq = ServiceRequest(
        id: 'spec_test_general_1',
        service: 'General Service',
        name: 'General Customer',
        email: 'gc@test.com',
        mobile: '9696969696',
        address: 'Ahmedabad',
        latitude: 23.0240,
        longitude: 72.5730,
        priority: 'Low',
        reminder: false,
        description: 'Need general assistance with household fixture assembly',
        status: 'pending',
      );

      await db.addRequest(plumbingReq);
      await db.addRequest(electricalReq);
      await db.addRequest(generalReq);

      // Stream with skill: 'Plumbing' must return Plumbing requests AND General Service requests
      final plumbingStreamList = await db.streamAvailableRequests(skill: 'Plumbing').first;
      expect(plumbingStreamList.any((r) => r.id == 'spec_test_plumbing_1'), isTrue);
      expect(plumbingStreamList.any((r) => r.id == 'spec_test_general_1'), isTrue);
      expect(plumbingStreamList.any((r) => r.id == 'spec_test_electrical_1'), isFalse);
      for (final req in plumbingStreamList) {
        final s = req.service.toLowerCase();
        expect(s == 'plumbing' || s == 'general service', isTrue);
      }

      // Stream with skill: 'Electrical' must return Electrical requests AND General Service requests
      final electricalStreamList = await db.streamAvailableRequests(skill: 'Electrical').first;
      expect(electricalStreamList.any((r) => r.id == 'spec_test_electrical_1'), isTrue);
      expect(electricalStreamList.any((r) => r.id == 'spec_test_general_1'), isTrue);
      expect(electricalStreamList.any((r) => r.id == 'spec_test_plumbing_1'), isFalse);
      for (final req in electricalStreamList) {
        final s = req.service.toLowerCase();
        expect(s == 'electrical' || s == 'general service', isTrue);
      }

      // Worker with 'Electrical' skill cannot accept plumbing request
      const electricalWorker = AppUser(
        uid: 'elec_worker_1',
        email: 'elec@test.com',
        name: 'Elec Worker',
        mobile: '9876543211',
        role: UserRole.worker,
        workerSkill: 'Electrical',
        latitude: 23.0225,
        longitude: 72.5714,
      );

      expect(
        () async => await db.acceptJob(
          requestId: 'spec_test_plumbing_1',
          workerId: electricalWorker.uid,
          workerName: electricalWorker.name,
          worker: electricalWorker,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Specialization mismatch'),
          ),
        ),
      );

      // Worker with 'Plumbing' skill can accept plumbing request
      const plumbingWorker = AppUser(
        uid: 'plumb_worker_1',
        email: 'plumb@test.com',
        name: 'Plumbing Worker',
        mobile: '9876543212',
        role: UserRole.worker,
        workerSkill: 'Plumbing',
        latitude: 23.0225,
        longitude: 72.5714,
      );

      await db.acceptJob(
        requestId: 'spec_test_plumbing_1',
        workerId: plumbingWorker.uid,
        workerName: plumbingWorker.name,
        worker: plumbingWorker,
        autoConfirm: true,
      );

      final accepted = db.allRequests.firstWhere((r) => r.id == 'spec_test_plumbing_1');
      expect(accepted.status, 'assigned');
      expect(accepted.workerId, plumbingWorker.uid);

      // ANY worker (such as electricalWorker) can accept a 'General Service' request!
      await db.acceptJob(
        requestId: 'spec_test_general_1',
        workerId: electricalWorker.uid,
        workerName: electricalWorker.name,
        worker: electricalWorker,
        autoConfirm: true,
      );

      final acceptedGeneral = db.allRequests.firstWhere((r) => r.id == 'spec_test_general_1');
      expect(acceptedGeneral.status, 'assigned');
      expect(acceptedGeneral.workerId, electricalWorker.uid);
    });

    test('Full workflow: Worker application notifications, customer profile check, worker confirmation/rejection, and mutual reviews', () async {
      final db = DatabaseService();

      const customerId = 'cust_flow_test';
      const worker1Id = 'worker_flow_alex';
      const worker2Id = 'worker_flow_david';
      const requestId = 'req_flow_plumbing_1';

      // 1. Create a customer request
      final request = ServiceRequest(
        id: requestId,
        service: 'Plumbing',
        name: 'Priya Patel',
        email: 'priya@example.com',
        mobile: '9898001122',
        address: 'Satellite, Ahmedabad',
        latitude: 23.0280,
        longitude: 72.5070,
        priority: 'High',
        reminder: true,
        description: 'Urgent kitchen pipe repair',
        status: 'pending',
        customerId: customerId,
      );

      await db.addRequest(request);

      const worker1 = AppUser(
        uid: worker1Id,
        email: 'alex@example.com',
        name: 'Alex Plumber',
        mobile: '9123456780',
        role: UserRole.worker,
        workerSkill: 'Plumbing',
        latitude: 23.0260,
        longitude: 72.5060,
        bio: 'Licensed plumber with 9+ years experience.',
        rating: 4.9,
        ratingCount: 15,
      );

      const worker2 = AppUser(
        uid: worker2Id,
        email: 'david@example.com',
        name: 'David Mehta',
        mobile: '9811223399',
        role: UserRole.worker,
        workerSkill: 'Plumbing',
        latitude: 23.0290,
        longitude: 72.5080,
        bio: 'Experienced in bathroom pipe fittings.',
        rating: 4.7,
        ratingCount: 8,
      );

      // 2. Worker 1 accepts/applies for the request
      await db.acceptJob(
        requestId: requestId,
        workerId: worker1Id,
        workerName: worker1.name,
        worker: worker1,
        autoConfirm: false, // Awaits customer confirmation
      );

      // Customer and Worker 1 receive in-app notifications
      final customerNotifsAfterW1 = db.getNotifications(customerId);
      expect(customerNotifsAfterW1.any((n) => n.relatedUserId == worker1Id), isTrue);

      final worker1Notifs = db.getNotifications(worker1Id);
      expect(worker1Notifs.any((n) => n.requestId == requestId), isTrue);

      // 3. Worker 2 also accepts/applies for the request
      await db.acceptJob(
        requestId: requestId,
        workerId: worker2Id,
        workerName: worker2.name,
        worker: worker2,
        autoConfirm: false,
      );

      final currentReq = db.allRequests.firstWhere((r) => r.id == requestId);
      expect(currentReq.applicantWorkerIds, containsAll([worker1Id, worker2Id]));
      expect(currentReq.status, 'pending');

      // 4. Customer inspects worker profiles and reviews
      final worker1Profile = await db.getUserById(worker1Id);
      expect(worker1Profile?.name, 'Alex Plumber');

      // 5. Customer confirms Worker 1:
      // Worker 1 is confirmed and assigned; Worker 2 is rejected
      await db.confirmWorker(
        requestId: requestId,
        workerId: worker1Id,
        workerName: worker1.name,
        customerId: customerId,
      );

      final confirmedReq = db.allRequests.firstWhere((r) => r.id == requestId);
      expect(confirmedReq.status, 'assigned');
      expect(confirmedReq.workerId, worker1Id);

      // Worker 1 receives Job Confirmed notification
      final w1NotifsAfterConfirm = db.getNotifications(worker1Id);
      expect(w1NotifsAfterConfirm.any((n) => n.type == 'customer_accepted'), isTrue);

      // Worker 2 receives Job Assigned to Another Worker notification (rejected)
      final w2NotifsAfterConfirm = db.getNotifications(worker2Id);
      expect(w2NotifsAfterConfirm.any((n) => n.type == 'worker_rejected'), isTrue);

      // No 2 workers can do 1 job: a 3rd worker attempting to accept fails
      const worker3 = AppUser(
        uid: 'worker_3',
        email: 'w3@example.com',
        name: 'Worker Three',
        mobile: '9000000000',
        role: UserRole.worker,
        workerSkill: 'Plumbing',
        latitude: 23.0280,
        longitude: 72.5070,
      );

      expect(
        () async => await db.acceptJob(
          requestId: requestId,
          workerId: worker3.uid,
          workerName: worker3.name,
          worker: worker3,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already been confirmed and assigned'),
          ),
        ),
      );

      // 6. Complete the job
      await db.updateStatus(requestId: requestId, newStatus: 'completed');
      final completedReq = db.allRequests.firstWhere((r) => r.id == requestId);
      expect(completedReq.completed, isTrue);

      // Both receive notifications to review
      expect(db.getNotifications(customerId).any((n) => n.type == 'job_completed'), isTrue);
      expect(db.getNotifications(worker1Id).any((n) => n.type == 'job_completed'), isTrue);

      // 7. Mutual Two-Way Reviews
      // Customer reviews Worker 1
      final customerReview = Review(
        id: 'rev_cust_w1',
        requestId: requestId,
        service: 'Plumbing',
        fromUserId: customerId,
        fromUserName: 'Priya Patel',
        fromUserRole: 'customer',
        toUserId: worker1Id,
        toUserName: worker1.name,
        rating: 5.0,
        comment: 'Excellent plumbing work! Fixed our leaking pipe under 30 minutes.',
        createdAt: DateTime.now(),
      );

      await db.submitReview(customerReview);
      final reqAfterCustReview = db.allRequests.firstWhere((r) => r.id == requestId);
      expect(reqAfterCustReview.customerReviewed, isTrue);

      // Worker 1 reviews Customer
      final workerReview = Review(
        id: 'rev_w1_cust',
        requestId: requestId,
        service: 'Plumbing',
        fromUserId: worker1Id,
        fromUserName: worker1.name,
        fromUserRole: 'worker',
        toUserId: customerId,
        toUserName: 'Priya Patel',
        rating: 5.0,
        comment: 'Great customer, clear instructions and quick confirmation!',
        createdAt: DateTime.now(),
      );

      await db.submitReview(workerReview);
      final reqAfterWorkerReview = db.allRequests.firstWhere((r) => r.id == requestId);
      expect(reqAfterWorkerReview.workerReviewed, isTrue);

      // Check reviews stream
      final w1Reviews = db.getReviewsForUser(worker1Id);
      expect(w1Reviews.any((r) => r.id == 'rev_cust_w1'), isTrue);

      final custReviews = db.getReviewsForUser(customerId);
      expect(custReviews.any((r) => r.id == 'rev_w1_cust'), isTrue);
    });
  });

  group('Razorpay Payment & Distance-based Service Charge Tests', () {
    test('Inspection charge is exactly 100 rupees', () {
      expect(DatabaseService.inspectionFee, 100.0);
    });

    test('Distance fee calculates 250 under 10 km and 500 under 20 km', () {
      // <= 10 km -> 250
      expect(DatabaseService.calculateDistanceFee(0.0), 250.0);
      expect(DatabaseService.calculateDistanceFee(4.5), 250.0);
      expect(DatabaseService.calculateDistanceFee(10.0), 250.0);

      // > 10 km and <= 20 km -> 500
      expect(DatabaseService.calculateDistanceFee(10.1), 500.0);
      expect(DatabaseService.calculateDistanceFee(15.0), 500.0);
      expect(DatabaseService.calculateDistanceFee(20.0), 500.0);

      // Null or edge distance fallback defaults to under-10km base
      expect(DatabaseService.calculateDistanceFee(null), 250.0);
    });

    test('Worker decides payment after inspection; notification sent to customer', () async {
      final db = DatabaseService();

      // Create worker and customer
      const worker = AppUser(
        uid: 'w_electrician_1',
        name: 'Ramesh Patel',
        email: 'ramesh@example.com',
        mobile: '9876543210',
        role: UserRole.worker,
        workerSkill: 'Electrical',
        latitude: 23.0225, // Navrangpura
        longitude: 72.5714,
        address: 'Navrangpura, Ahmedabad',
      );

      const customer = AppUser(
        uid: 'c_priya_1',
        name: 'Priya Shah',
        email: 'priya@example.com',
        mobile: '9123456780',
        role: UserRole.customer,
        latitude: 23.0400, // ~2.5 km away (< 10 km)
        longitude: 72.5800,
        address: 'Usmanpura, Ahmedabad',
      );

      final req = ServiceRequest(
        id: 'req_electrical_pay_test',
        name: customer.name,
        email: customer.email,
        mobile: customer.mobile,
        address: customer.address ?? '',
        latitude: customer.latitude,
        longitude: customer.longitude,
        service: 'Electrical',
        priority: 'High',
        description: 'Short circuit in kitchen main switchboard',
        status: 'in_progress',
        reminder: false,
        customerId: customer.uid,
        workerId: worker.uid,
        workerName: worker.name,
        createdAt: DateTime.now(),
      );

      await db.addRequest(req);

      // Worker assesses work and decides base charge = 350
      // Condition inspection fee = 100
      // Distance fee (< 10 km) = 250
      // Total expected = 350 + 100 + 250 = 700
      await db.submitBill(
        requestId: req.id,
        worker: worker,
        baseAmount: 350.0,
      );

      final billedReq = db.allRequests.firstWhere((r) => r.id == req.id);
      expect(billedReq.isBilled, isTrue);
      expect(billedReq.isPaymentPending, isTrue);
      expect(billedReq.isPaid, isFalse);
      expect(billedReq.baseAmount, 350.0);
      expect(billedReq.inspectionFee, 100.0);
      expect(billedReq.distanceFee, 250.0);
      expect(billedReq.distanceKm, isNotNull);
      expect(billedReq.distanceKm!, lessThan(10.0));
      expect(billedReq.totalAmount, 700.0);
      expect(billedReq.paymentStatus, 'pending');

      // Verify customer received notification
      final customerNotifs = db.getNotifications(customer.uid);
      expect(customerNotifs.isNotEmpty, isTrue);
      final billNotif = customerNotifs.firstWhere((n) => n.type == 'payment_request');
      expect(billNotif.title, contains('Invoice: ₹700'));
      expect(billNotif.message, contains('700'));
      expect(billNotif.message, contains('₹100'));
      expect(billNotif.message, contains('₹250'));
    });

    test('Worker submits bill for job between 10 km and 20 km; charges 500 distance fee', () async {
      final db = DatabaseService();

      const worker = AppUser(
        uid: 'w_plumber_2',
        name: 'Suresh Kumar',
        email: 'suresh@example.com',
        mobile: '9876500000',
        role: UserRole.worker,
        workerSkill: 'Plumbing',
        latitude: 23.0225,
        longitude: 72.5714,
      );

      // Customer ~15 km away (still under 20 km)
      // 0.13 deg latitude approx 14.5 km
      const customer = AppUser(
        uid: 'c_distant_1',
        name: 'Amit Joshi',
        email: 'amit@example.com',
        mobile: '9123400000',
        role: UserRole.customer,
        latitude: 23.1550,
        longitude: 72.5714,
      );

      final req = ServiceRequest(
        id: 'req_distance_500_test',
        name: customer.name,
        email: customer.email,
        mobile: customer.mobile,
        address: 'Bopal Extension, Ahmedabad',
        latitude: customer.latitude,
        longitude: customer.longitude,
        service: 'Plumbing',
        priority: 'Normal',
        description: 'Water pressure pump repair',
        status: 'in_progress',
        reminder: false,
        customerId: customer.uid,
        workerId: worker.uid,
        workerName: worker.name,
        createdAt: DateTime.now(),
      );

      await db.addRequest(req);

      // Base amount = 400
      // Inspection = 100
      // Distance fee (>10 km, <=20 km) = 500
      // Total = 400 + 100 + 500 = 1000
      await db.submitBill(
        requestId: req.id,
        worker: worker,
        baseAmount: 400.0,
      );

      final billedReq = db.allRequests.firstWhere((r) => r.id == req.id);
      expect(billedReq.distanceKm, isNotNull);
      expect(billedReq.distanceKm!, greaterThan(10.0));
      expect(billedReq.distanceKm!, lessThanOrEqualTo(20.0));
      expect(billedReq.distanceFee, 500.0);
      expect(billedReq.inspectionFee, 100.0);
      expect(billedReq.baseAmount, 400.0);
      expect(billedReq.totalAmount, 1000.0);
    });

    test('Customer completes Razorpay payment; status updates to paid and sends receipt notifications', () async {
      final db = DatabaseService();

      const workerId = 'w_carpenter_9';
      const customerId = 'c_neha_9';

      final billedRequest = ServiceRequest(
        id: 'req_razorpay_checkout_test',
        name: 'Neha Verma',
        email: 'neha@example.com',
        mobile: '9988776655',
        address: 'Satellite, Ahmedabad',
        service: 'Carpentry',
        priority: 'Normal',
        description: 'Door lock and hinge replacement',
        status: 'in_progress',
        reminder: false,
        customerId: customerId,
        workerId: workerId,
        workerName: 'Vikram Carpenter',
        baseAmount: 300.0,
        inspectionFee: 100.0,
        distanceFee: 250.0,
        totalAmount: 650.0,
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      await db.addRequest(billedRequest);

      // Generate Razorpay transaction
      final paymentId = RazorpayService.generatePaymentId();
      expect(paymentId.startsWith('pay_'), isTrue);

      // Customer completes payment
      await db.completePayment(
        requestId: billedRequest.id,
        paymentId: paymentId,
        amount: 650.0,
        paymentMethod: 'razorpay',
      );

      final paidReq = db.allRequests.firstWhere((r) => r.id == billedRequest.id);
      expect(paidReq.isPaid, isTrue);
      expect(paidReq.isPaymentPending, isFalse);
      expect(paidReq.paymentStatus, 'paid');
      expect(paidReq.paymentId, paymentId);
      expect(paidReq.paymentMethod, 'razorpay');
      expect(paidReq.paidAt, isNotNull);

      // Verify worker received payment notification
      final workerNotifs = db.getNotifications(workerId);
      final workerPayNotif = workerNotifs.firstWhere((n) => n.type == 'payment_received');
      expect(workerPayNotif.title, contains('Payment Received: ₹650'));
      expect(workerPayNotif.message, contains('₹650'));
      expect(workerPayNotif.message, contains(paymentId));

      // Verify customer received payment receipt notification
      final customerNotifs = db.getNotifications(customerId);
      final custReceiptNotif = customerNotifs.firstWhere((n) => n.type == 'payment_success');
      expect(custReceiptNotif.title, contains('Payment Successful!'));
      expect(custReceiptNotif.message, contains('₹650'));
      expect(custReceiptNotif.message, contains(paymentId));
    });

    test('Payment failure notifies customer to retry, and retrying completes payment with notifications to both sides', () async {
      final db = DatabaseService();

      const workerId = 'w_retry_worker';
      const customerId = 'c_retry_customer';

      final pendingReq = ServiceRequest(
        id: 'req_retry_payment_test',
        name: 'Aarav Mehta',
        email: 'aarav@example.com',
        mobile: '9898001122',
        address: 'CG Road, Ahmedabad',
        service: 'Electrical',
        priority: 'High',
        description: 'Inverter wiring breakdown',
        status: 'in_progress',
        reminder: false,
        customerId: customerId,
        workerId: workerId,
        workerName: 'Kishore Electrician',
        baseAmount: 500.0,
        inspectionFee: 100.0,
        distanceFee: 250.0,
        distanceKm: 3.2,
        totalAmount: 850.0,
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      await db.addRequest(pendingReq);

      // 1. Payment fails or is incomplete
      await db.recordPaymentFailure(
        requestId: pendingReq.id,
        reason: 'Bank authorization timed out',
      );

      final failedReq = db.allRequests.firstWhere((r) => r.id == pendingReq.id);
      expect(failedReq.isPaymentFailed, isTrue);
      expect(failedReq.canPay, isTrue);
      expect(failedReq.paymentStatus, 'failed');

      // Verify customer received retry payment notification
      final custNotifs = db.getNotifications(customerId);
      final retryNotif = custNotifs.firstWhere((n) => n.type == 'payment_failed');
      expect(retryNotif.title, contains('Payment Incomplete'));
      expect(retryNotif.message, contains('₹850'));
      expect(retryNotif.message, contains('retry'));

      // 2. Customer retries payment via Razorpay successfully
      final newPaymentId = RazorpayService.generatePaymentId();
      await db.completePayment(
        requestId: pendingReq.id,
        paymentId: newPaymentId,
        amount: 850.0,
        paymentMethod: 'Razorpay UPI',
      );

      final completedReq = db.allRequests.firstWhere((r) => r.id == pendingReq.id);
      expect(completedReq.isPaid, isTrue);
      expect(completedReq.isPaymentFailed, isFalse);
      expect(completedReq.canPay, isFalse);
      expect(completedReq.paymentStatus, 'paid');
      expect(completedReq.paymentId, newPaymentId);

      // Verify payment details printed in history are complete
      expect(completedReq.baseAmount, 500.0);
      expect(completedReq.inspectionFee, 100.0);
      expect(completedReq.distanceFee, 250.0);
      expect(completedReq.distanceKm, 3.2);
      expect(completedReq.totalAmount, 850.0);
      expect(completedReq.paymentMethod, 'Razorpay UPI');
      expect(completedReq.paidAt, isNotNull);

      // Verify BOTH sides received success notification
      // Worker received payment confirmation
      final workerNotifs = db.getNotifications(workerId);
      final wNotif = workerNotifs.firstWhere((n) => n.type == 'payment_received');
      expect(wNotif.title, contains('Payment Received: ₹850'));
      expect(wNotif.message, contains(newPaymentId));

      // Customer received receipt confirmation
      final updatedCustNotifs = db.getNotifications(customerId);
      final cSuccessNotif = updatedCustNotifs.firstWhere((n) => n.type == 'payment_success');
      expect(cSuccessNotif.title, contains('Payment Successful!'));
      expect(cSuccessNotif.message, contains(newPaymentId));
    });
  });
}

