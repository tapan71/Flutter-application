import 'package:flutter/material.dart';
import 'user_model.dart';

class MembershipPlan {
  final String id;
  final UserRole role;
  final String title;
  final String tierName; // 'Plus', 'Gold VIP', 'Pro', 'Elite'
  final double price;
  final String billingPeriod; // 'month', 'year'
  final int durationDays;
  final String tagline;
  final String? badgeText; // 'POPULAR', 'BEST VALUE', 'PRO CHOICE'
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> features;
  final double inspectionFeeDiscountPercent; // 100% means ₹0 inspection fee
  final double serviceDiscountPercent; // e.g. 10% or 20%

  const MembershipPlan({
    required this.id,
    required this.role,
    required this.title,
    required this.tierName,
    required this.price,
    required this.billingPeriod,
    required this.durationDays,
    required this.tagline,
    this.badgeText,
    required this.primaryColor,
    required this.secondaryColor,
    required this.features,
    this.inspectionFeeDiscountPercent = 100.0,
    this.serviceDiscountPercent = 0.0,
  });

  static const List<MembershipPlan> customerPlans = [
    MembershipPlan(
      id: 'customer_plus_monthly',
      role: UserRole.customer,
      title: 'LocalServe Plus',
      tierName: 'Plus',
      price: 199.0,
      billingPeriod: 'month',
      durationDays: 30,
      tagline: 'Zero inspection fees & 10% instant savings',
      badgeText: 'POPULAR',
      primaryColor: Color(0xFF1E88E5), // Blue
      secondaryColor: Color(0xFFE3F2FD),
      inspectionFeeDiscountPercent: 100.0,
      serviceDiscountPercent: 10.0,
      features: [
        '✨ ₹0 Inspection Fee on all bookings (Save ₹100 each visit)',
        '🏷️ 10% Instant discount on total service charges',
        '⚡ Priority matching with top-rated (4.8+★) workers',
        '🛡️ Free 30-day service revisit warranty',
        '💬 In-app priority customer support desk',
      ],
    ),
    MembershipPlan(
      id: 'customer_gold_yearly',
      role: UserRole.customer,
      title: 'LocalServe Gold VIP',
      tierName: 'Gold VIP',
      price: 999.0,
      billingPeriod: 'year',
      durationDays: 365,
      tagline: 'Ultimate priority, 20% discount & full cover',
      badgeText: 'BEST VALUE (Save 58%)',
      primaryColor: Color(0xFFD4AF37), // Metallic Gold
      secondaryColor: Color(0xFFFFF8E1),
      inspectionFeeDiscountPercent: 100.0,
      serviceDiscountPercent: 20.0,
      features: [
        '👑 Everything in LocalServe Plus included',
        '✨ ₹0 Inspection Fee on unlimited service bookings',
        '🏷️ 20% Instant discount on total service labor charges',
        '⚡ Instant VIP Direct Worker assignment',
        '🛡️ Comprehensive 90-day damage protection cover',
        '📞 24/7 Dedicated VIP Concierge assistance',
      ],
    ),
  ];

  // Worker membership is removed: all workers work freely with 0 fees and without membership.
  static const List<MembershipPlan> workerPlans = [];

  static MembershipPlan? findById(String? planId) {
    if (planId == null) return null;
    final all = customerPlans;
    return all.where((p) => p.id == planId).firstOrNull;
  }
}
