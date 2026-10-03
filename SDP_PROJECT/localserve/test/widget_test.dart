import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localserve/main.dart';
import 'package:localserve/models/user_model.dart';
import 'package:localserve/services/auth_service.dart';
import 'package:localserve/services/local_storage_service.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  setUp(() {
    LocalStorageService().resetForTesting();
  });

  testWidgets(
    'LocalServe displays LoginScreen when unauthenticated',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      // Check LocalServe branding
      expect(find.text('LocalServe'), findsOneWidget);

      // Check Sign In button
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);

      // Check Role chips for quick demo login
      expect(find.text('Customer Demo'), findsOneWidget);
      expect(find.text('Worker Demo'), findsOneWidget);
    },
  );

  testWidgets(
    '1-click Customer demo sign-in navigates to Customer Dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      final customerChip = find.widgetWithText(ActionChip, 'Customer Demo');
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
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      final workerChip = find.widgetWithText(ActionChip, 'Worker Demo');
      expect(workerChip, findsOneWidget);

      await tester.tap(workerChip);
      await tester.pumpAndSettle();

      expect(find.text('Available Jobs'), findsOneWidget);
      expect(find.text('My Active Jobs'), findsOneWidget);
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
    'Customer request auto-fills name, email, phone, and address by default and allows editing',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      // Sign in as Customer demo
      final customerChip = find.widgetWithText(ActionChip, 'Customer Demo');
      await tester.ensureVisible(customerChip);
      await tester.pumpAndSettle();
      await tester.tap(customerChip);
      await tester.pumpAndSettle();

      // Click "New Request" FAB
      final requestButton = find.widgetWithText(FloatingActionButton, 'New Request');
      expect(requestButton, findsOneWidget);
      await tester.tap(requestButton);
      await tester.pumpAndSettle();

      // Verify ServiceRequestScreen is opened
      expect(find.text('Plumbing Request'), findsOneWidget);
      expect(find.text('Account Defaults Auto-filled'), findsOneWidget);

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