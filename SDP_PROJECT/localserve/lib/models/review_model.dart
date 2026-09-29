class Review {
  final String id;
  final String requestId;
  final String service;
  final String fromUserId;
  final String fromUserName;
  final String fromUserRole; // 'customer' or 'worker'
  final String toUserId;
  final String toUserName;
  final double rating; // 1.0 to 5.0
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.requestId,
    required this.service,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserRole,
    required this.toUserId,
    required this.toUserName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'service': service,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserRole': fromUserRole,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map, {String? id}) {
    return Review(
      id: id ?? map['id'] ?? '',
      requestId: map['requestId'] ?? '',
      service: map['service'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? '',
      fromUserRole: map['fromUserRole'] ?? 'customer',
      toUserId: map['toUserId'] ?? '',
      toUserName: map['toUserName'] ?? '',
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : 5.0,
      comment: map['comment'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
