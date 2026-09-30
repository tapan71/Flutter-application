class ServiceRequest {
  final String id;
  final String service;
  final String name;
  final String email;
  final String mobile;
  final String address;
  final double? latitude;
  final double? longitude;
  final String priority;
  final bool reminder;
  final String description;
  final DateTime? dueDate;
  final String status; // 'pending', 'assigned', 'in_progress', 'completed', 'cancelled'
  final String? customerId;
  final String? workerId;
  final String? workerName;
  final String? targetWorkerId;
  final String? targetWorkerName;
  final DateTime? directRequestExpiresAt;
  final DateTime? createdAt;
  final List<String> applicantWorkerIds;
  final List<String> declinedWorkerIds;
  final bool customerReviewed;
  final bool workerReviewed;

  ServiceRequest({
    required this.id,
    required this.service,
    required this.name,
    required this.email,
    required this.mobile,
    required this.address,
    this.latitude,
    this.longitude,
    required this.priority,
    required this.reminder,
    required this.description,
    this.dueDate,
    bool completed = false,
    String? status,
    this.customerId,
    this.workerId,
    this.workerName,
    this.targetWorkerId,
    this.targetWorkerName,
    this.directRequestExpiresAt,
    this.createdAt,
    this.applicantWorkerIds = const [],
    this.declinedWorkerIds = const [],
    this.customerReviewed = false,
    this.workerReviewed = false,
  }) : status = status ?? (completed ? 'completed' : 'pending');

  bool get completed => status == 'completed';

  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isInProgress => status == 'in_progress';
  bool get isCancelled => status == 'cancelled';
  bool get isDirectPending => status == 'direct_pending';
  bool get isRejected => status == 'rejected';

  bool get isDirectRequest => targetWorkerId != null && targetWorkerId!.isNotEmpty;
  bool get isDirectExpired =>
      isDirectPending &&
      directRequestExpiresAt != null &&
      DateTime.now().isAfter(directRequestExpiresAt!);

  bool get hasLocation => latitude != null && longitude != null;

  ServiceRequest copyWith({
    String? id,
    String? service,
    String? name,
    String? email,
    String? mobile,
    String? address,
    double? latitude,
    double? longitude,
    String? priority,
    bool? reminder,
    String? description,
    DateTime? dueDate,
    bool? completed,
    String? status,
    String? customerId,
    String? workerId,
    String? workerName,
    String? targetWorkerId,
    String? targetWorkerName,
    DateTime? directRequestExpiresAt,
    DateTime? createdAt,
    List<String>? applicantWorkerIds,
    List<String>? declinedWorkerIds,
    bool? customerReviewed,
    bool? workerReviewed,
  }) {
    String finalStatus = status ?? this.status;
    if (completed != null && status == null) {
      finalStatus = completed ? 'completed' : 'pending';
    }

    return ServiceRequest(
      id: id ?? this.id,
      service: service ?? this.service,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      priority: priority ?? this.priority,
      reminder: reminder ?? this.reminder,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: finalStatus,
      customerId: customerId ?? this.customerId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      targetWorkerId: targetWorkerId ?? this.targetWorkerId,
      targetWorkerName: targetWorkerName ?? this.targetWorkerName,
      directRequestExpiresAt: directRequestExpiresAt ?? this.directRequestExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      applicantWorkerIds: applicantWorkerIds ?? this.applicantWorkerIds,
      declinedWorkerIds: declinedWorkerIds ?? this.declinedWorkerIds,
      customerReviewed: customerReviewed ?? this.customerReviewed,
      workerReviewed: workerReviewed ?? this.workerReviewed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'service': service,
      'name': name,
      'email': email,
      'mobile': mobile,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'priority': priority,
      'reminder': reminder,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'customerId': customerId,
      'workerId': workerId,
      'workerName': workerName,
      'targetWorkerId': targetWorkerId,
      'targetWorkerName': targetWorkerName,
      'directRequestExpiresAt': directRequestExpiresAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'applicantWorkerIds': applicantWorkerIds,
      'declinedWorkerIds': declinedWorkerIds,
      'customerReviewed': customerReviewed,
      'workerReviewed': workerReviewed,
    };
  }

  factory ServiceRequest.fromMap(Map<String, dynamic> map, {String? id}) {
    final statusStr = map['status'] as String? ??
        ((map['completed'] == true) ? 'completed' : 'pending');

    return ServiceRequest(
      id: id ?? map['id'] ?? '',
      service: map['service'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      mobile: map['mobile'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      priority: map['priority'] ?? 'Medium',
      reminder: map['reminder'] as bool? ?? false,
      description: map['description'] ?? '',
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'].toString())
          : null,
      status: statusStr,
      customerId: map['customerId'] as String?,
      workerId: map['workerId'] as String?,
      workerName: map['workerName'] as String?,
      targetWorkerId: map['targetWorkerId'] as String?,
      targetWorkerName: map['targetWorkerName'] as String?,
      directRequestExpiresAt: map['directRequestExpiresAt'] != null
          ? DateTime.tryParse(map['directRequestExpiresAt'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      applicantWorkerIds: map['applicantWorkerIds'] != null
          ? List<String>.from(map['applicantWorkerIds'] as List)
          : const [],
      declinedWorkerIds: map['declinedWorkerIds'] != null
          ? List<String>.from(map['declinedWorkerIds'] as List)
          : const [],
      customerReviewed: map['customerReviewed'] as bool? ?? false,
      workerReviewed: map['workerReviewed'] as bool? ?? false,
    );
  }
}