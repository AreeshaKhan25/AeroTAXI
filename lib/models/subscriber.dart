class Subscriber {
  final int id;
  final String email;
  final String? name;
  final bool active;
  final String? createdAt;

  Subscriber({
    required this.id,
    required this.email,
    this.name,
    this.active = true,
    this.createdAt,
  });

  factory Subscriber.fromJson(Map<String, dynamic> json) {
    return Subscriber(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      name: json['name'],
      active: json['active'] == true || json['active'] == 1,
      createdAt: json['created_at'],
    );
  }
}
