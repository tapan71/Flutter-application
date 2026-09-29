class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'worker_applied', 'customer_accepted', 'worker_rejected', 'job_completed', 'review_received'
  final String? requestId;
  final String? relatedUserId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.requestId,
    this.relatedUserId,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    String? requestId,
    String? relatedUserId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      requestId: requestId ?? this.requestId,
      relatedUserId: relatedUserId ?? this.relatedUserId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'requestId': requestId,
      'relatedUserId': relatedUserId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppNotification(
      id: id ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      requestId: map['requestId'] as String?,
      relatedUserId: map['relatedUserId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
