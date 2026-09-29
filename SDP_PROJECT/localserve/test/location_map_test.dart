import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:localserve/models/user_model.dart';
import 'package:localserve/models/service_request.dart';
import 'package:localserve/services/geocoding_service.dart';
import 'package:localserve/services/auth_service.dart';
import 'package:localserve/services/database_service.dart';

void main() {
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
  });
}
