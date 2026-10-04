enum UserRole {
  customer,
  worker;

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.worker:
        return 'Worker';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'worker':
        return UserRole.worker;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String mobile;
  final String? address;
  final double? latitude;
  final double? longitude;
  final UserRole role;
  final String? workerSkill;
  final bool isApproved;
  final DateTime? createdAt;
  final String? avatarUrl;
  final String? bio;
  final double rating;
  final int ratingCount;
  final int completedJobsCount;
  final String? membershipPlan; // 'customer_plus_monthly', 'customer_gold_yearly', 'worker_pro_monthly', 'worker_elite_yearly'
  final String? membershipTier; // 'Plus', 'Gold VIP', 'Pro', 'Elite'
  final DateTime? membershipExpiresAt;
  final bool isProMember;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.mobile,
    this.address,
    this.latitude,
    this.longitude,
    required this.role,
    this.workerSkill,
    this.isApproved = true,
    this.createdAt,
    this.avatarUrl,
    this.bio,
    this.rating = 4.8,
    this.ratingCount = 0,
    this.completedJobsCount = 0,
    this.membershipPlan,
    this.membershipTier,
    this.membershipExpiresAt,
    this.isProMember = false,
  });

  bool get isCustomer => role == UserRole.customer;
  bool get isWorker => role == UserRole.worker;

  bool get hasLocation => latitude != null && longitude != null;

  /// Returns true if user has an unexpired membership plan or active Pro/Plus status
  bool get hasActiveMembership {
    if (isProMember) return true;
    if (membershipPlan == null || membershipPlan == 'none' || membershipPlan!.isEmpty) {
      return false;
    }
    if (membershipExpiresAt == null) return true;
    return DateTime.now().isBefore(membershipExpiresAt!);
  }

  /// Whether customer is currently entitled to Plus/Gold zero inspection fees & discounts
  bool get isCustomerMember => isCustomer && hasActiveMembership;

  /// Whether worker is currently entitled to Pro badge & top category ranking
  /// Worker membership has been removed: all workers can work freely without any membership.
  bool get isWorkerPro => false;

  /// Number of days left on the current membership
  int? get membershipDaysRemaining {
    if (!hasActiveMembership || membershipExpiresAt == null) return null;
    final diff = membershipExpiresAt!.difference(DateTime.now()).inDays;
    return diff >= 0 ? diff : 0;
  }

  /// Display string for the user's membership badge
  String get membershipBadgeLabel {
    if (isWorker) {
      return 'Verified Specialist';
    } else {
      if (isCustomerMember) return membershipTier ?? 'LocalServe Plus';
      return 'Standard Member';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'mobile': mobile,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'role': role.name,
      'workerSkill': workerSkill,
      'isApproved': isApproved,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'avatarUrl': avatarUrl,
      'bio': bio,
      'rating': rating,
      'ratingCount': ratingCount,
      'completedJobsCount': completedJobsCount,
      'membershipPlan': membershipPlan,
      'membershipTier': membershipTier,
      'membershipExpiresAt': membershipExpiresAt?.toIso8601String(),
      'isProMember': isProMember,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {String? uid}) {
    return AppUser(
      uid: uid ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      address: map['address'] as String?,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      role: UserRole.fromString(map['role'] as String?),
      workerSkill: map['workerSkill'] as String?,
      isApproved: map['isApproved'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      avatarUrl: map['avatarUrl'] as String?,
      bio: map['bio'] as String?,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : 4.8,
      ratingCount: map['ratingCount'] != null ? (map['ratingCount'] as num).toInt() : 0,
      completedJobsCount: map['completedJobsCount'] != null
          ? (map['completedJobsCount'] as num).toInt()
          : 0,
      membershipPlan: map['membershipPlan'] as String?,
      membershipTier: map['membershipTier'] as String?,
      membershipExpiresAt: map['membershipExpiresAt'] != null
          ? DateTime.tryParse(map['membershipExpiresAt'].toString())
          : null,
      isProMember: map['isProMember'] as bool? ?? false,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? mobile,
    String? address,
    double? latitude,
    double? longitude,
    UserRole? role,
    String? workerSkill,
    bool? isApproved,
    DateTime? createdAt,
    String? avatarUrl,
    String? bio,
    double? rating,
    int? ratingCount,
    int? completedJobsCount,
    String? membershipPlan,
    String? membershipTier,
    DateTime? membershipExpiresAt,
    bool? isProMember,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      role: role ?? this.role,
      workerSkill: workerSkill ?? this.workerSkill,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      completedJobsCount: completedJobsCount ?? this.completedJobsCount,
      membershipPlan: membershipPlan ?? this.membershipPlan,
      membershipTier: membershipTier ?? this.membershipTier,
      membershipExpiresAt: membershipExpiresAt ?? this.membershipExpiresAt,
      isProMember: isProMember ?? this.isProMember,
    );
  }
}
