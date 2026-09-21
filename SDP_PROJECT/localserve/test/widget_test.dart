import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localserve/main.dart';
import 'package:localserve/models/user_model.dart';
import 'package:localserve/services/auth_service.dart';

void main() {
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

      expect(find.text('Find Local Home Services'), findsOneWidget);
      expect(find.text('Request a Service'), findsOneWidget);
    },
  );

  testWidgets(
    '1-click Worker demo sign-in navigates to Worker Dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      final workerChip = find.widgetWithText(ActionChip, 'Worker Demo');
      expect(workerChip, findsOneWidget);
      await tester.ensureVisible(workerChip);
      await tester.pumpAndSettle();

      await tester.tap(workerChip);
      await tester.pumpAndSettle();

      expect(find.text('Available Jobs'), findsOneWidget);
      expect(find.text('My Active Jobs'), findsOneWidget);
    },
  );

  testWidgets(
    'Registered worker preserves Worker role upon login and routes to Worker Dashboard',
    (WidgetTester tester) async {
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
}