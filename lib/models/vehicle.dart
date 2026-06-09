class Vehicle {
  final int id;
  final String name;
  final String slug;
  final double price;
  final double shortBase;
  final double shortPerMile;
  final double longBase;
  final double longPerMile;
  final int passengers;
  final int luggage;
  final int suitcases;
  final String? handLuggageNote;
  final String? image;
  final String? description;
  final String? carModel;
  final int sortOrder;

  Vehicle({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    this.shortBase = 0,
    this.shortPerMile = 0,
    this.longBase = 0,
    this.longPerMile = 0,
    required this.passengers,
    this.luggage = 0,
    required this.suitcases,
    this.handLuggageNote,
    this.image,
    this.description,
    this.carModel,
    this.sortOrder = 0,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      price: _toDouble(json['price']),
      shortBase: _toDouble(json['short_base']),
      shortPerMile: _toDouble(json['short_per_mile']),
      longBase: _toDouble(json['long_base']),
      longPerMile: _toDouble(json['long_per_mile']),
      passengers: json['passengers'] ?? 0,
      luggage: json['luggage'] ?? json['suitcases'] ?? 0,
      suitcases: json['suitcases'] ?? 0,
      handLuggageNote: json['hand_luggage_note'],
      image: json['image'],
      description: json['description'],
      carModel: json['car_model'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'price': price,
        'short_base': shortBase,
        'short_per_mile': shortPerMile,
        'long_base': longBase,
        'long_per_mile': longPerMile,
        'passengers': passengers,
        'luggage': luggage,
        'suitcases': suitcases,
        'hand_luggage_note': handLuggageNote,
        'image': image,
        'description': description,
        'car_model': carModel,
        'sort_order': sortOrder,
      };

  String get imageAsset {
    if (image == null) return 'assets/images/vehicles/saloon.svg';
    return 'assets/images/vehicles/$image';
  }

  String get priceFormatted => '\u00A3${price.toStringAsFixed(2)}';
}
