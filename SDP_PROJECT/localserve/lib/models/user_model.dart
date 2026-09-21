enum UserRole {
  customer,
  worker,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.worker:
        return 'Worker';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'worker':
        return UserRole.worker;
      case 'admin':
        return UserRole.admin;
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
  final UserRole role;
  final String? workerSkill;
  final bool isApproved;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.mobile,
    required this.role,
    this.workerSkill,
    this.isApproved = true,
    this.createdAt,
  });

  bool get isCustomer => role == UserRole.customer;
  bool get isWorker => role == UserRole.worker;
  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'mobile': mobile,
      'role': role.name,
      'workerSkill': workerSkill,
      'isApproved': isApproved,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {String? uid}) {
    return AppUser(
      uid: uid ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      role: UserRole.fromString(map['role'] as String?),
      workerSkill: map['workerSkill'] as String?,
      isApproved: map['isApproved'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? mobile,
    UserRole? role,
    String? workerSkill,
    bool? isApproved,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      workerSkill: workerSkill ?? this.workerSkill,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
