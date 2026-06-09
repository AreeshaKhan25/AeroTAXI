class ContactMessage {
  final int id;
  final String name;
  final String email;
  final String? subject;
  final String message;
  final bool read;
  final String? createdAt;

  ContactMessage({
    required this.id,
    required this.name,
    required this.email,
    this.subject,
    required this.message,
    this.read = false,
    this.createdAt,
  });

  factory ContactMessage.fromJson(Map<String, dynamic> json) {
    return ContactMessage(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      subject: json['subject'],
      message: json['message'] ?? '',
      read: json['read'] == true || json['read'] == 1,
      createdAt: json['created_at'],
    );
  }
}
