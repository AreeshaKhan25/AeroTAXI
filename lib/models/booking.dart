import 'vehicle.dart';

class Booking {
  final int? id;
  final String? reference;
  final String fromLocation;
  final String toLocation;
  final String departDate;
  final String? departTime;
  final int vehicleId;
  final String passengerName;
  final String email;
  final String phone;
  final String? flightNumber;
  final String? noteToDriver;
  final String? countryCode;
  final String status;
  final String paymentStatus;
  final String? paymentId;
  final double totalPrice;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final double? distanceMiles;
  final double? durationMinutes;
  final int passengers;
  final int luggage;
  final int suitcases;
  final bool meetAndGreet;
  final bool pet;
  final bool oversizedItem;
  final List<String> childSeats;
  final Vehicle? vehicle;
  final String? createdAt;

  Booking({
    this.id,
    this.reference,
    required this.fromLocation,
    required this.toLocation,
    required this.departDate,
    this.departTime,
    required this.vehicleId,
    required this.passengerName,
    required this.email,
    required this.phone,
    this.flightNumber,
    this.noteToDriver,
    this.countryCode,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.paymentId,
    required this.totalPrice,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.distanceMiles,
    this.durationMinutes,
    this.passengers = 1,
    this.luggage = 0,
    this.suitcases = 0,
    this.meetAndGreet = false,
    this.pet = false,
    this.oversizedItem = false,
    this.childSeats = const [],
    this.vehicle,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      reference: json['reference'],
      fromLocation: json['from_location'] ?? '',
      toLocation: json['to_location'] ?? '',
      departDate: json['depart_date'] ?? '',
      departTime: json['depart_time'],
      vehicleId: json['vehicle_id'] ?? 0,
      passengerName: json['passenger_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      flightNumber: json['flight_number'],
      noteToDriver: json['note_to_driver'],
      countryCode: json['country_code'],
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      paymentId: json['payment_id'],
      totalPrice: _toDouble(json['total_price']),
      fromLat: json['from_lat'] != null ? _toDouble(json['from_lat']) : null,
      fromLng: json['from_lng'] != null ? _toDouble(json['from_lng']) : null,
      toLat: json['to_lat'] != null ? _toDouble(json['to_lat']) : null,
      toLng: json['to_lng'] != null ? _toDouble(json['to_lng']) : null,
      distanceMiles: json['distance_miles'] != null ? _toDouble(json['distance_miles']) : null,
      durationMinutes: json['duration_minutes'] != null ? _toDouble(json['duration_minutes']) : null,
      passengers: json['passengers'] ?? 1,
      luggage: json['luggage'] ?? 0,
      suitcases: json['suitcases'] ?? 0,
      meetAndGreet: json['meet_and_greet'] ?? false,
      pet: json['pet'] ?? false,
      oversizedItem: json['oversized_item'] ?? false,
      childSeats: (json['child_seats'] as List?)?.cast<String>() ?? [],
      vehicle:
          json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      createdAt: json['created_at'],
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
        'reference': reference,
        'from_location': fromLocation,
        'to_location': toLocation,
        'depart_date': departDate,
        'depart_time': departTime,
        'vehicle_id': vehicleId,
        'passenger_name': passengerName,
        'email': email,
        'phone': phone,
        'flight_number': flightNumber,
        'note_to_driver': noteToDriver,
        'country_code': countryCode,
        'status': status,
        'payment_status': paymentStatus,
        'total_price': totalPrice,
        'from_lat': fromLat,
        'from_lng': fromLng,
        'to_lat': toLat,
        'to_lng': toLng,
        'distance_miles': distanceMiles,
        'duration_minutes': durationMinutes,
        'passengers': passengers,
        'luggage': luggage,
        'suitcases': suitcases,
        'meet_and_greet': meetAndGreet,
        'pet': pet,
        'oversized_item': oversizedItem,
        'child_seats': childSeats,
      };

  String get priceFormatted => '\u00A3${totalPrice.toStringAsFixed(2)}';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'assigned':
        return 'Assigned';
      case 'bidding':
        return 'Bidding';
      case 'new':
        return 'New';
      default:
        return status;
    }
  }
}
