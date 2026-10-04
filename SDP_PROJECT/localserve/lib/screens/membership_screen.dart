import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/membership_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  String? _selectedPlanId;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('LocalServe Membership')),
        body: const Center(child: Text('Please log in to view membership plans.')),
      );
    }

    // Workers never need a membership — they can work freely with 0% platform fee
    if (user.isWorker) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Worker Access'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF16A34A)),
                ),
                const SizedBox(height: 24),
                const Text(
                  '100% Free Platform for Workers',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Workers never need a membership on LocalServe. You can explore available jobs, accept requests, and serve customers completely free with 0% platform commission!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Dashboard'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final plans = MembershipPlan.customerPlans;

    // Set default selected plan
    _selectedPlanId ??= plans.first.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.stars,
              color: Color(0xFF1E88E5),
              size: 26,
            ),
            SizedBox(width: 8),
            Text(
              'LocalServe Plus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Status Header
            _buildCurrentStatusCard(context, user),

            const SizedBox(height: 16),

            // Plan Title & Value Proposition
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Your Membership Plan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Save ₹100 on every booking with ₹0 inspection fee and instant discounts.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Plans List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: plans.map((plan) {
                  final isSelected = _selectedPlanId == plan.id;
                  return _buildPlanCard(context, plan, isSelected);
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Benefits Comparison Banner
            _buildPerksComparisonBanner(context),

            const SizedBox(height: 24),

            // Upgrade Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _handleSubscribe(context, user, plans),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            user.hasActiveMembership ? 'Switch / Renew Plan' : 'Subscribe via Razorpay',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(BuildContext context, AppUser user) {
    final hasActive = user.hasActiveMembership;
    final daysLeft = user.membershipDaysRemaining;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasActive
              ? [const Color(0xFF1565C0), const Color(0xFF1E88E5)]
              : [const Color(0xFF37474F), const Color(0xFF455A64)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (hasActive ? Colors.blue : Colors.grey).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasActive ? Icons.verified : Icons.lock_outline,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasActive ? 'ACTIVE MEMBERSHIP' : 'FREE ACCOUNT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasActive && daysLeft != null)
                Text(
                  '$daysLeft days remaining',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasActive ? (user.membershipTier ?? 'Active Member') : 'Standard Free Tier',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasActive
                ? '🎉 You enjoy ₹0 Inspection fees on all service requests + exclusive labor discounts!'
                : 'Upgrade to LocalServe Plus to waive the ₹100 inspection fee on every booking.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, MembershipPlan plan, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? plan.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? plan.primaryColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? plan.primaryColor : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.tagline,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (plan.badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: plan.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan.badgeText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹${plan.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: plan.primaryColor,
                  ),
                ),
                Text(
                  ' / ${plan.billingPeriod}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? plan.primaryColor : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? plan.primaryColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.features.map(
              (feat) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: plan.primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feat,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerksComparisonBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.blueGrey[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                '100% Satisfaction Guarantee',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Over ₹2,500 estimated annual savings on inspection fees and emergency household repairs.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe(
    BuildContext context,
    AppUser user,
    List<MembershipPlan> plans,
  ) async {
    final selectedPlan = plans.firstWhere((p) => p.id == _selectedPlanId);
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();
    final messenger = ScaffoldMessenger.of(context);

    // Show Razorpay mock checkout dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.payment, color: selectedPlan.primaryColor),
            const SizedBox(width: 8),
            const Text('Razorpay Checkout'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan: ${selectedPlan.title} (${selectedPlan.tierName})'),
            const SizedBox(height: 4),
            Text(
              'Amount: ₹${selectedPlan.price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Duration: ${selectedPlan.durationDays} Days'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instant activation via Razorpay Secure Sandbox',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedPlan.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Pay ₹${selectedPlan.price.toStringAsFixed(0)}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    // 1. Upgrade in auth service
    await authService.upgradeMembership(
      planId: selectedPlan.id,
      tierName: selectedPlan.tierName,
      durationDays: selectedPlan.durationDays,
    );

    // 2. Upgrade in database service
    await dbService.upgradeMembership(
      userId: user.uid,
      planId: selectedPlan.id,
      tierName: selectedPlan.tierName,
      durationDays: selectedPlan.durationDays,
      price: selectedPlan.price,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    // Show celebratory snackbar
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 ${selectedPlan.title} activated! Your perks are now live.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
