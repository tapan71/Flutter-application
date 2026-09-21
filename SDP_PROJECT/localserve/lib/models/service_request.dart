class ServiceRequest {
  final String id;
  final String service;
  final String name;
  final String email;
  final String mobile;
  final String address;
  final String priority;
  final bool reminder;
  final String description;
  final DateTime? dueDate;
  final String status; // 'pending', 'assigned', 'in_progress', 'completed', 'cancelled'
  final String? customerId;
  final String? workerId;
  final String? workerName;
  final DateTime? createdAt;

  ServiceRequest({
    required this.id,
    required this.service,
    required this.name,
    required this.email,
    required this.mobile,
    required this.address,
    required this.priority,
    required this.reminder,
    required this.description,
    this.dueDate,
    bool completed = false,
    String? status,
    this.customerId,
    this.workerId,
    this.workerName,
    this.createdAt,
  }) : status = status ?? (completed ? 'completed' : 'pending');

  bool get completed => status == 'completed';

  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isInProgress => status == 'in_progress';
  bool get isCancelled => status == 'cancelled';

  ServiceRequest copyWith({
    String? id,
    String? service,
    String? name,
    String? email,
    String? mobile,
    String? address,
    String? priority,
    bool? reminder,
    String? description,
    DateTime? dueDate,
    bool? completed,
    String? status,
    String? customerId,
    String? workerId,
    String? workerName,
    DateTime? createdAt,
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
      priority: priority ?? this.priority,
      reminder: reminder ?? this.reminder,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: finalStatus,
      customerId: customerId ?? this.customerId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      createdAt: createdAt ?? this.createdAt,
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
      'priority': priority,
      'reminder': reminder,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'customerId': customerId,
      'workerId': workerId,
      'workerName': workerName,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
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
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}