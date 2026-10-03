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

  static const List<MembershipPlan> workerPlans = [
    MembershipPlan(
      id: 'worker_pro_monthly',
      role: UserRole.worker,
      title: 'Worker Pro Club',
      tierName: 'Pro',
      price: 299.0,
      billingPeriod: 'month',
      durationDays: 30,
      tagline: 'Verified Pro Badge & Top Category Rank',
      badgeText: 'RECOMMENDED',
      primaryColor: Color(0xFFE65100), // Amber Deep Orange
      secondaryColor: Color(0xFFFFF3E0),
      features: [
        '⭐ Golden "VERIFIED PRO" badge on your worker profile',
        '🚀 Ranked #1 in customer search and category listings',
        '💼 0% platform service commission on your bookings',
        '🎯 Priority direct job invitations from VIP customers',
        '📊 Pro performance stats & verified trust rating seal',
      ],
    ),
    MembershipPlan(
      id: 'worker_elite_yearly',
      role: UserRole.worker,
      title: 'Worker Elite Partner',
      tierName: 'Elite',
      price: 1499.0,
      billingPeriod: 'year',
      durationDays: 365,
      tagline: 'Maximum bookings, featured banner & zero fees',
      badgeText: 'BEST VALUE (Save 58%)',
      primaryColor: Color(0xFF6A1B9A), // Royal Purple
      secondaryColor: Color(0xFFF3E5F5),
      features: [
        '👑 All Worker Pro Club perks for an entire year',
        '🌟 Featured Top-Worker banner in your local area',
        '⚡ Unlimited service radius notification access',
        '💼 0% platform commission on all annual earnings',
        '🎖️ Official LocalServe Master Certified Partner Certificate',
        '📞 Dedicated Worker Success Account Manager',
      ],
    ),
  ];

  static MembershipPlan? findById(String? planId) {
    if (planId == null) return null;
    final all = [...customerPlans, ...workerPlans];
    return all.where((p) => p.id == planId).firstOrNull;
  }
}
