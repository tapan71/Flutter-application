import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localserve/main.dart';

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
      expect(find.text('Admin Demo'), findsOneWidget);
    },
  );

  testWidgets(
    '1-click Customer demo sign-in navigates to Customer Dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      // Find and scroll to the customer demo chip
      final customerChip = find.widgetWithText(ActionChip, 'Customer Demo');
      expect(customerChip, findsOneWidget);
      await tester.ensureVisible(customerChip);
      await tester.pumpAndSettle();

      // Tap customer chip
      await tester.tap(customerChip);
      await tester.pumpAndSettle();

      // Should now be on customer dashboard
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

      // Should now be on worker dashboard
      expect(find.text('Available Jobs'), findsOneWidget);
      expect(find.text('My Active Jobs'), findsOneWidget);
    },
  );

  testWidgets(
    '1-click Admin demo sign-in navigates to Admin Dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LocalServeApp());
      await tester.pumpAndSettle();

      final adminChip = find.widgetWithText(ActionChip, 'Admin Demo');
      expect(adminChip, findsOneWidget);
      await tester.ensureVisible(adminChip);
      await tester.pumpAndSettle();

      await tester.tap(adminChip);
      await tester.pumpAndSettle();

      // Should now be on admin dashboard
      expect(find.text('LocalServe Admin'), findsOneWidget);
      expect(find.text('Requests & Stats'), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
    },
  );
}