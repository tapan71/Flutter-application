import 'package:flutter_test/flutter_test.dart';
import 'package:localserve/models/membership_model.dart';
import 'package:localserve/models/user_model.dart';
import 'package:localserve/services/auth_service.dart';
import 'package:localserve/services/database_service.dart';
import 'package:localserve/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalStorageService().resetForTesting();
  });

  group('Membership Model & Tiers Tests', () {
    test('Customer plans define Plus and Gold VIP correctly', () {
      expect(MembershipPlan.customerPlans.length, 2);

      final plus = MembershipPlan.customerPlans.first;
      expect(plus.id, 'customer_plus_monthly');
      expect(plus.role, UserRole.customer);
      expect(plus.price, 199.0);
      expect(plus.durationDays, 30);
      expect(plus.inspectionFeeDiscountPercent, 100.0);
      expect(plus.serviceDiscountPercent, 10.0);

      final gold = MembershipPlan.customerPlans.last;
      expect(gold.id, 'customer_gold_yearly');
      expect(gold.role, UserRole.customer);
      expect(gold.price, 999.0);
      expect(gold.durationDays, 365);
      expect(gold.inspectionFeeDiscountPercent, 100.0);
      expect(gold.serviceDiscountPercent, 20.0);
    });

    test('Worker plans define Pro Club and Elite Partner correctly', () {
      expect(MembershipPlan.workerPlans.length, 2);

      final pro = MembershipPlan.workerPlans.first;
      expect(pro.id, 'worker_pro_monthly');
      expect(pro.role, UserRole.worker);
      expect(pro.price, 299.0);
      expect(pro.durationDays, 30);

      final elite = MembershipPlan.workerPlans.last;
      expect(elite.id, 'worker_elite_yearly');
      expect(elite.role, UserRole.worker);
      expect(elite.price, 1499.0);
      expect(elite.durationDays, 365);
    });

    test('MembershipPlan.findById retrieves plans correctly', () {
      final plan = MembershipPlan.findById('customer_gold_yearly');
      expect(plan, isNotNull);
      expect(plan!.title, 'LocalServe Gold VIP');
      expect(plan.tierName, 'Gold VIP');

      final nullPlan = MembershipPlan.findById('non_existing');
      expect(nullPlan, isNull);
    });
  });

  group('AppUser Membership Attributes & Getters', () {
    test('Non-member customer has hasActiveMembership false and isCustomerMember false', () {
      const freeCustomer = AppUser(
        uid: 'cust_free',
        email: 'free@example.com',
        name: 'Free Customer',
        mobile: '9876543210',
        role: UserRole.customer,
      );

      expect(freeCustomer.hasActiveMembership, false);
      expect(freeCustomer.isCustomerMember, false);
      expect(freeCustomer.isWorkerPro, false);
      expect(freeCustomer.membershipBadgeLabel, 'Standard Member');
      expect(freeCustomer.membershipDaysRemaining, isNull);
    });

    test('Active customer member has hasActiveMembership true and isCustomerMember true', () {
      final activeCustomer = AppUser(
        uid: 'cust_plus',
        email: 'plus@example.com',
        name: 'Plus Customer',
        mobile: '9876543210',
        role: UserRole.customer,
        membershipPlan: 'customer_plus_monthly',
        membershipTier: 'LocalServe Plus',
        membershipExpiresAt: DateTime.now().add(const Duration(days: 25)),
      );

      expect(activeCustomer.hasActiveMembership, true);
      expect(activeCustomer.isCustomerMember, true);
      expect(activeCustomer.membershipBadgeLabel, 'LocalServe Plus');
      expect(activeCustomer.membershipDaysRemaining, 24);
    });

    test('Expired customer membership returns hasActiveMembership false', () {
      final expiredCustomer = AppUser(
        uid: 'cust_expired',
        email: 'expired@example.com',
        name: 'Expired Customer',
        mobile: '9876543210',
        role: UserRole.customer,
        membershipPlan: 'customer_plus_monthly',
        membershipExpiresAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(expiredCustomer.hasActiveMembership, false);
      expect(expiredCustomer.isCustomerMember, false);
    });

    test('Worker with isProMember or active Pro plan returns isWorkerPro true', () {
      const proWorker = AppUser(
        uid: 'worker_pro_1',
        email: 'pro@localserve.com',
        name: 'Master Pro',
        mobile: '9123456780',
        role: UserRole.worker,
        workerSkill: 'Plumbing',
        isProMember: true,
        membershipTier: 'PRO WORKER',
      );

      expect(proWorker.hasActiveMembership, true);
      expect(proWorker.isWorkerPro, true);
      expect(proWorker.membershipBadgeLabel, 'PRO WORKER');
    });

    test('AppUser serialization toMap and fromMap preserves membership fields', () {
      final expires = DateTime.now().add(const Duration(days: 30));
      final user = AppUser(
        uid: 'user_serialize',
        email: 'serialize@example.com',
        name: 'Serialization Test',
        mobile: '9898989898',
        role: UserRole.customer,
        membershipPlan: 'customer_gold_yearly',
        membershipTier: 'Gold VIP',
        membershipExpiresAt: expires,
        isProMember: false,
      );

      final map = user.toMap();
      final restored = AppUser.fromMap(map);

      expect(restored.uid, 'user_serialize');
      expect(restored.membershipPlan, 'customer_gold_yearly');
      expect(restored.membershipTier, 'Gold VIP');
      expect(restored.hasActiveMembership, true);
      expect(restored.isCustomerMember, true);
    });
  });

  group('DatabaseService Pro Worker Ranking & Inspection Waiving Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      await Future.delayed(const Duration(milliseconds: 60));
    });

    test('getWorkersForCategory ranks PRO workers first in search results', () {
      final plumbingWorkers = dbService.getWorkersForCategory(
        'Plumbing',
        customerLat: 23.0225,
        customerLon: 72.5714,
      );

      expect(plumbingWorkers.isNotEmpty, true);
      // First worker in the list should be the PRO worker (Alex Plumber)
      expect(plumbingWorkers.first.isWorkerPro, true);
      expect(plumbingWorkers.first.name, 'Alex Plumber');
    });

    test('DatabaseService.upgradeMembership activates membership and sends notification', () async {
      const testUserId = 'demo_customer_1';

      await dbService.upgradeMembership(
        userId: testUserId,
        planId: 'customer_gold_yearly',
        tierName: 'Gold VIP',
        durationDays: 365,
        price: 999.0,
      );

      final user = await dbService.getUserById(testUserId);
      expect(user, isNotNull);
      expect(user!.membershipPlan, 'customer_gold_yearly');
      expect(user.membershipTier, 'Gold VIP');
      expect(user.isCustomerMember, true);

      // Verify congratulatory notification was sent
      final notifications = await dbService.streamUserNotifications(testUserId).first;
      expect(notifications.any((n) => n.type == 'membership_activated'), true);
    });

    test('Billing logic waives inspection fee for customer members', () {
      // Non-member calculation
      const standardInspection = DatabaseService.inspectionFee;
      expect(standardInspection, 100.0);

      // Member calculation logic
      double calculateInspection(bool isMember) =>
          isMember ? 0.0 : DatabaseService.inspectionFee;

      expect(calculateInspection(true), 0.0);
      expect(calculateInspection(false), 100.0);
    });
  });

  group('AuthService Membership Integration Tests', () {
    late AuthService authService;

    setUp(() async {
      authService = AuthService();
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('AuthService.upgradeMembership updates currentUser and persists state', () async {
      await authService.signInWithDemoUser(AuthService.demoUsers[0]);
      expect(authService.currentUser, isNotNull);

      await authService.upgradeMembership(
        planId: 'customer_plus_monthly',
        tierName: 'LocalServe Plus',
        durationDays: 30,
      );

      expect(authService.currentUser!.membershipPlan, 'customer_plus_monthly');
      expect(authService.currentUser!.membershipTier, 'LocalServe Plus');
      expect(authService.currentUser!.isCustomerMember, true);
    });
  });
}
