class Airport {
  final int id;
  final String code;
  final String name;
  final String city;
  final String country;
  final String? description;
  final String? image;
  final int sortOrder;

  Airport({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    this.country = 'United Kingdom',
    this.description,
    this.image,
    this.sortOrder = 0,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? 'United Kingdom',
      description: json['description'],
      image: json['image'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'city': city,
        'country': country,
        'description': description,
        'image': image,
        'sort_order': sortOrder,
      };

  String get imageAsset {
    if (image == null) return 'assets/images/airports/lhr.png';
    return 'assets/images/airports/$image';
  }

  String get displayName => '$name ($code)';
}
