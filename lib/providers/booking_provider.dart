import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/email_service.dart';

class BookingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  StreamSubscription<User?>? _authSub;

  // Step 1 - Location & Vehicle
  String _fromLocation = '';
  String _toLocation = '';
  double? _fromLat;
  double? _fromLng;
  double? _toLat;
  double? _toLng;
  double? _distanceMiles;
  double? _durationMinutes;
  String _departDate = '';
  String? _departTime;
  Vehicle? _selectedVehicle;
  double _estimatedPrice = 0;

  // Step 2 - Passenger Details
  String _passengerName = '';
  String _email = '';
  String _phone = '';
  String? _flightNumber;
  String? _noteToDriver;
  String? _countryCode;
  bool _subscribeToEmails = false;
  int _passengers = 1;
  int _luggage = 0;
  int _suitcases = 0;
  bool _meetAndGreet = false;
  bool _pet = false;
  bool _oversizedItem = false;
  List<String> _childSeats = [];

  // Step 3 - Payment & Confirmation
  Booking? _currentBooking;
  bool _isProcessing = false;
  String? _error;

  // History
  List<Booking> _allBookings = [];
  bool _loadingBookings = false;

  BookingProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        loadBookings();
      } else {
        _clearBookings();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // Getters
  String get fromLocation => _fromLocation;
  String get toLocation => _toLocation;
  String get departDate => _departDate;
  String? get departTime => _departTime;
  Vehicle? get selectedVehicle => _selectedVehicle;
  double get estimatedPrice => _estimatedPrice;
  String get passengerName => _passengerName;
  String get email => _email;
  String get phone => _phone;
  String? get flightNumber => _flightNumber;
  String? get noteToDriver => _noteToDriver;
  String? get countryCode => _countryCode;
  bool get subscribeToEmails => _subscribeToEmails;
  Booking? get currentBooking => _currentBooking;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  List<Booking> get allBookings => _allBookings;
  bool get loadingBookings => _loadingBookings;

  List<Booking> get upcomingBookings => _allBookings.where((b) {
        if (b.status != 'confirmed' && b.status != 'pending') return false;
        try {
          final date = DateTime.parse(b.departDate);
          final time = b.departTime;
          final DateTime depart;
          if (time != null && time.contains(':')) {
            final parts = time.split(':');
            depart = DateTime(date.year, date.month, date.day,
                int.parse(parts[0]), int.parse(parts[1]));
          } else {
            // No time stored — keep all day if today or future
            depart = DateTime(date.year, date.month, date.day, 23, 59, 59);
          }
          return !depart.isBefore(DateTime.now());
        } catch (_) {
          return true;
        }
      }).toList();

  List<Booking> get pastBookings => _allBookings
      .where((b) => b.status == 'completed' || b.status == 'cancelled')
      .toList();

  // Fetch this user's bookings from Firestore
  Future<void> loadBookings() async {
    if (_loadingBookings) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _loadingBookings = true;
    notifyListeners();

    try {
      _allBookings = await FirestoreService.getUserBookings();
    } catch (_) {}

    _loadingBookings = false;
    notifyListeners();
  }

  void _clearBookings() {
    _allBookings = [];
    notifyListeners();
  }

  // Add a booking to the in-memory list immediately (Firestore save is separate)
  void _addBooking(Booking booking) {
    _allBookings.removeWhere((b) => b.reference == booking.reference);
    _allBookings.insert(0, booking);
    notifyListeners();
  }

  // Step 1 setters
  void setLocations(String from, String to,
      {double? fromLat,
      double? fromLng,
      double? toLat,
      double? toLng,
      double? distanceMiles,
      double? durationMinutes}) {
    _fromLocation = from;
    _toLocation = to;
    _fromLat = fromLat;
    _fromLng = fromLng;
    _toLat = toLat;
    _toLng = toLng;
    _distanceMiles = distanceMiles;
    _durationMinutes = durationMinutes;
    notifyListeners();
  }

  void setDateTime(String date, String? time) {
    _departDate = date;
    _departTime = time;
    notifyListeners();
  }

  void selectVehicle(Vehicle vehicle, double price) {
    _selectedVehicle = vehicle;
    _estimatedPrice = price;
    notifyListeners();
  }

  // Step 2 setters
  void setPassengerDetails({
    required String name,
    required String email,
    required String phone,
    String? flightNumber,
    String? noteToDriver,
    String? countryCode,
    bool subscribe = false,
    int passengers = 1,
    int luggage = 0,
    int suitcases = 0,
    bool meetAndGreet = false,
    bool pet = false,
    bool oversizedItem = false,
    List<String> childSeats = const [],
  }) {
    _passengerName = name;
    _email = email;
    _phone = phone;
    _flightNumber = flightNumber;
    _noteToDriver = noteToDriver;
    _countryCode = countryCode;
    _subscribeToEmails = subscribe;
    _passengers = passengers;
    _luggage = luggage;
    _suitcases = suitcases;
    _meetAndGreet = meetAndGreet;
    _pet = pet;
    _oversizedItem = oversizedItem;
    _childSeats = childSeats;
    notifyListeners();
  }

  // Create booking
  Future<bool> submitBooking() async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    final vehicleId = _selectedVehicle?.id ?? 0;
    final ref =
        'ATH-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    _currentBooking = Booking(
      id: DateTime.now().millisecondsSinceEpoch,
      reference: ref,
      fromLocation: _fromLocation,
      toLocation: _toLocation,
      departDate: _departDate,
      departTime: _departTime,
      vehicleId: vehicleId,
      passengerName: _passengerName,
      email: _email,
      phone: _phone,
      flightNumber: _flightNumber,
      noteToDriver: _noteToDriver,
      countryCode: _countryCode,
      passengers: _passengers,
      luggage: _luggage,
      suitcases: _suitcases,
      meetAndGreet: _meetAndGreet,
      pet: _pet,
      oversizedItem: _oversizedItem,
      childSeats: _childSeats,
      totalPrice: _estimatedPrice,
      fromLat: _fromLat,
      fromLng: _fromLng,
      toLat: _toLat,
      toLng: _toLng,
      distanceMiles: _distanceMiles,
      durationMinutes: _durationMinutes,
      status: 'confirmed',
    );

    // Update in-memory list immediately for instant UI feedback
    _addBooking(_currentBooking!);
    // Persist to Firestore in background
    FirestoreService.saveBooking(_currentBooking!);
    _isProcessing = false;
    notifyListeners();
    return true;
  }

  /// Call this AFTER payment is confirmed
  Future<void> sendConfirmationEmail() async {
    if (_currentBooking != null) {
      await EmailService.sendBookingConfirmation(_currentBooking!);
    }
  }

  // Payment
  Future<String?> createPaymentIntent() async {
    if (_currentBooking == null) return null;
    final response = await _api.createPaymentIntent(
      _currentBooking!.totalPrice,
      _currentBooking!.reference!,
    );
    return response['clientSecret'] as String?;
  }

  // Lookup
  Future<Booking?> lookupBooking(String reference) async {
    return _api.lookupBooking(reference);
  }

  // Validate flight
  Future<Map<String, dynamic>?> validateFlight(String flightNumber) async {
    return _api.validateFlight(flightNumber);
  }

  // Reset current booking flow (keeps history)
  void reset() {
    _fromLocation = '';
    _toLocation = '';
    _departDate = '';
    _departTime = null;
    _selectedVehicle = null;
    _estimatedPrice = 0;
    _passengerName = '';
    _email = '';
    _phone = '';
    _flightNumber = null;
    _noteToDriver = null;
    _countryCode = null;
    _subscribeToEmails = false;
    _currentBooking = null;
    _isProcessing = false;
    _error = null;
    notifyListeners();
  }
}
