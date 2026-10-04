import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:localserve/main.dart';
import 'package:localserve/models/user_model.dart';
import 'package:localserve/screens/auth/register_screen.dart';
import 'package:localserve/screens/history_screen.dart';
import 'package:localserve/screens/service_request_screen.dart';
import 'package:localserve/services/auth_service.dart';
import 'package:localserve/services/database_service.dart';
import 'package:localserve/services/geocoding_service.dart';
import 'package:localserve/services/local_storage_service.dart';
import 'package:localserve/widgets/app_image_view.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  setUp(() {
    LocalStorageService().resetForTesting();
    GeocodingService.mockLocationForTesting = const LocationSearchResult(
      latitude: 23.0225,
      longitude: 72.5714,
      displayName: 'Navrangpura, Ahmedabad, Gujarat',
      road: 'Navrangpura',
      city: 'Ahmedabad',
      state: 'Gujarat',
      isLiveGps: true,
    );
  });

  testWidgets(
    'LocalServe displays LoginScreen when unauthenticated',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      // Check LocalServe branding & header
      expect(find.text('LOCALSERVE ON-DEMAND'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);

      // Check Sign In button
      expect(find.text('Sign In'), findsOneWidget);

      // Check Role chips for quick demo login
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Worker (Plumbing)'), findsOneWidget);
    },
  );

  testWidgets(
    '1-click Customer demo sign-in navigates to Customer Dashboard',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      final customerChip = find.text('Customer');
      expect(customerChip, findsOneWidget);
      await tester.ensureVisible(customerChip);
      await tester.pumpAndSettle();

      await tester.tap(customerChip);
      await tester.pumpAndSettle();

      expect(find.text('Plumbing'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    '1-click Worker demo sign-in navigates to Worker Dashboard',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      final workerChip = find.text('Worker (Plumbing)');
      expect(workerChip, findsOneWidget);
      await tester.ensureVisible(workerChip);
      await tester.pumpAndSettle();

      await tester.tap(workerChip);
      await tester.pumpAndSettle();

      expect(find.text('Available Jobs'), findsOneWidget);
      expect(find.text('My Active Jobs'), findsOneWidget);

      // Verify "My Location" banner is completely removed from worker dashboard
      expect(find.text('My Location (OpenStreetMap)'), findsNothing);
      expect(find.text('Set your base location on the map to unlock 20 km proximity jobs.'), findsNothing);
    },
  );

  test(
    'Registered worker preserves Worker role upon login and routes to Worker Dashboard',
    () async {
      final auth = AuthService();
      const testEmail = 'carpenter.bob@example.com';
      const testPass = 'secret123';

      // 1. Sign up as Worker
      await auth.signUp(
        email: testEmail,
        password: testPass,
        name: 'Bob Builder',
        mobile: '9876543210',
        role: UserRole.worker,
        workerSkill: 'Carpentry',
      );

      expect(auth.currentUser?.role, UserRole.worker);

      // 2. Log out
      await auth.signOut();
      expect(auth.currentUser, isNull);

      // 3. Log back in with the registered email
      await auth.signIn(email: testEmail, password: testPass);
      expect(auth.currentUser?.role, UserRole.worker);
      expect(auth.currentUser?.workerSkill, 'Carpentry');
    },
  );

  testWidgets(
    'Customer request auto-fills name, email, phone, and address by default and shows issue photos section',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      // Sign in as Customer demo
      final customerChip = find.text('Customer');
      await tester.ensureVisible(customerChip);
      await tester.pumpAndSettle();
      await tester.tap(customerChip);
      await tester.pumpAndSettle();

      // Click "New Request" FAB
      final requestButton = find.widgetWithText(FloatingActionButton, 'New Request');
      expect(requestButton, findsOneWidget);
      await tester.tap(requestButton);
      await tester.pumpAndSettle();

      // Verify ServiceRequestScreen is opened with Service Type and Issue Photos section
      expect(find.text('Service Type'), findsOneWidget);
      expect(find.text('Issue Photos'), findsOneWidget);

      // Verify name is prefilled and can be changed
      final nameFinder = find.widgetWithText(TextFormField, 'John Customer');
      expect(nameFinder, findsOneWidget);
      await tester.enterText(nameFinder, 'Jane Customer');
      await tester.pumpAndSettle();
      expect(find.text('Jane Customer'), findsOneWidget);

      // Verify email and mobile are prefilled by default
      final emailFinder = find.widgetWithText(TextFormField, 'customer@localserve.com');
      await tester.ensureVisible(emailFinder);
      await tester.pumpAndSettle();
      expect(emailFinder, findsOneWidget);

      final mobileFinder = find.widgetWithText(TextFormField, '9876543210');
      await tester.ensureVisible(mobileFinder);
      await tester.pumpAndSettle();
      expect(mobileFinder, findsOneWidget);

      // Verify Take Photo & Phone Storage quick buttons are displayed
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Phone Storage'), findsOneWidget);
    },
  );

  testWidgets(
    'AppImageView renders base64 image data URI correctly',
    (WidgetTester tester) async {
      const base64Png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppImageView(
              imageUrl: base64Png,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    },
  );

  test(
    'Worker history data integrity: Plumber worker strictly has only Plumbing history and reviews',
    () async {
      final db = DatabaseService();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final allReqs = db.allRequests;
      final plumberReqs = allReqs.where((r) => r.workerId == 'demo_worker_1').toList();

      expect(plumberReqs.isNotEmpty, isTrue);
      for (final req in plumberReqs) {
        expect(
          req.service,
          equals('Plumbing'),
          reason: 'Plumber worker jobs must strictly be Plumbing and never other trades',
        );
      }

      final reviews = db.getReviewsForUser('demo_worker_1');
      for (final rev in reviews) {
        expect(
          rev.service,
          equals('Plumbing'),
          reason: 'Reviews for plumber must strictly be Plumbing',
        );
      }
    },
  );

  testWidgets(
    'Service request screen provides 1-tap Live GPS button and Map picker in Address field',
    (WidgetTester tester) async {
      final auth = AuthService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
          ],
          child: const MaterialApp(
            home: ServiceRequestScreen(
              selectedService: 'Plumbing',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that both GPS button and Map button are displayed on Address field
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'Worker service history page has no upper right corner items (Showing My Requests)',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final auth = AuthService();
      final db = DatabaseService();
      final workerUser = AppUser(
        uid: 'demo_worker_plumber',
        email: 'plumber@localserve.com',
        name: 'John Plumber',
        mobile: '9876543210',
        role: UserRole.worker,
        workerSkill: 'Plumbing',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<DatabaseService>.value(value: db),
          ],
          child: MaterialApp(
            home: HistoryScreen(
              currentUser: workerUser,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service History'), findsOneWidget);
      // Ensure upper-right actions (filter icon or "Showing My Requests") are NOT present
      expect(find.byTooltip('Showing My Requests'), findsNothing);
      expect(find.byTooltip('Showing All Requests'), findsNothing);
      expect(find.byIcon(Icons.filter_alt), findsNothing);
      expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
      expect(find.text('Show All History'), findsNothing);
    },
  );

  testWidgets(
    'Register page loads without dialogs or notification popups, allowing address modification',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 1400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final auth = AuthService();
      final db = DatabaseService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<DatabaseService>.value(value: db),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no dialog or notification popped up
      expect(find.text('Use Current Location as Address?'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      // Verify live location was automatically put into the address field
      expect(find.text('Navrangpura, Ahmedabad, Gujarat'), findsOneWidget);

      // Verify base address field exists and user can change it
      expect(find.text('Base Address & Map Location:'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    },
  );
}


class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  bool autoUncompress = true;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestHttpClientResponse implements HttpClientResponse {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];