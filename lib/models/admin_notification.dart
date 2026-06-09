class AdminNotification {
  final int id;
  final String type;
  final String message;
  final Map<String, dynamic>? data;
  final bool read;
  final String? createdAt;

  AdminNotification({
    required this.id,
    required this.type,
    required this.message,
    this.data,
    this.read = false,
    this.createdAt,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
      read: json['read'] == true || json['read'] == 1,
      createdAt: json['created_at'],
    );
  }
}
