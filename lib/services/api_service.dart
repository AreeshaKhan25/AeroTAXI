import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/airport.dart';
import '../models/vehicle.dart';
import '../models/booking.dart';
import '../models/faq.dart';
import '../models/contact_message.dart';
import '../models/subscriber.dart';
import '../models/admin_notification.dart';

class ApiService {
  static String get baseUrl =>
      kIsWeb ? AppConstants.webBaseUrl : AppConstants.baseUrl;

  final http.Client _client = http.Client();
  Map<String, String>? _adminCookies;

  // ─── Public API ───────────────────────────────────────

  Future<List<Airport>> searchAirports(String query) async {
    final response = await _get('/api/airports/search?q=$query');
    if (response != null && response is List) {
      return response.map((e) => Airport.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> validateFlight(String flightNumber) async {
    final response = await _get('/api/flight/validate?flight_number=$flightNumber');
    return response is Map<String, dynamic> ? response : null;
  }

  // ─── Page Data (fetched via web scraping or dedicated API) ───

  Future<Map<String, dynamic>> getHomeData() async {
    return _getStaticHomeData();
  }

  Future<List<Airport>> getAirports() async {
    // Return static airports matching the Laravel seeder
    return _getStaticAirports();
  }

  Future<List<Vehicle>> getVehicles() async {
    return _getStaticVehicles();
  }

  Future<List<Faq>> getFaqs() async {
    return _getStaticFaqs();
  }

  // ─── Booking ──────────────────────────────────────────

  Future<Map<String, dynamic>> createBooking(Booking booking) async {
    final response = await _post('/booking', booking.toJson());
    return response ?? {};
  }

  Future<Map<String, dynamic>> createPaymentIntent(double amount, String reference) async {
    final response = await _post('/payment/create-intent', {
      'amount': (amount * 100).round(),
      'booking_reference': reference,
    });
    return response ?? {};
  }

  Future<Booking?> lookupBooking(String reference) async {
    final response = await _get('/booking/lookup?reference=$reference');
    if (response != null && response is Map<String, dynamic>) {
      return Booking.fromJson(response);
    }
    return null;
  }

  // ─── Contact ──────────────────────────────────────────

  Future<bool> sendContactMessage({
    required String name,
    required String email,
    String? subject,
    required String message,
  }) async {
    final response = await _post('/contact', {
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
    });
    return response != null;
  }

  // ─── Admin Auth ───────────────────────────────────────

  Future<bool> adminLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {'email': email, 'password': password},
      );
      if (response.statusCode == 200 || response.statusCode == 302) {
        _adminCookies = {'Cookie': response.headers['set-cookie'] ?? ''};
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Admin login error: $e');
      return false;
    }
  }

  Future<void> adminLogout() async {
    await _post('/admin/logout', {});
    _adminCookies = null;
  }

  // ─── Admin Dashboard ──────────────────────────────────

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await _getAdmin('/admin/stats');
    return response ?? {};
  }

  Future<List<Booking>> getAdminBookings() async {
    final response = await _getAdmin('/admin/bookings');
    if (response != null && response is List) {
      return response.map((e) => Booking.fromJson(e)).toList();
    }
    return [];
  }

  Future<Booking?> getAdminBookingDetail(int id) async {
    final response = await _getAdmin('/admin/bookings/$id');
    if (response != null && response is Map<String, dynamic>) {
      return Booking.fromJson(response);
    }
    return null;
  }

  Future<bool> updateAdminBooking(int id, Map<String, dynamic> data) async {
    final response = await _postAdmin('/admin/bookings/$id/update', data);
    return response != null;
  }

  Future<List<Subscriber>> getAdminSubscribers() async {
    final response = await _getAdmin('/admin/subscribers');
    if (response != null && response is List) {
      return response.map((e) => Subscriber.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<ContactMessage>> getAdminContactMessages() async {
    final response = await _getAdmin('/admin/contact-messages');
    if (response != null && response is List) {
      return response.map((e) => ContactMessage.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> markContactMessageRead(int id) async {
    final response =
        await _postAdmin('/admin/contact-messages/$id/mark-read', {});
    return response != null;
  }

  Future<List<AdminNotification>> getAdminNotifications() async {
    final response = await _getAdmin('/admin/notifications');
    if (response != null && response is List) {
      return response.map((e) => AdminNotification.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> markNotificationsRead() async {
    final response =
        await _postAdmin('/admin/notifications/mark-read', {});
    return response != null;
  }

  Future<bool> sendPromotion({
    required String subject,
    required String message,
  }) async {
    final response = await _postAdmin('/admin/promotions/send', {
      'subject': subject,
      'message': message,
    });
    return response != null;
  }

  // ─── HTTP Helpers ─────────────────────────────────────

  Future<dynamic> _get(String path) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('GET $path error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('POST $path error: $e');
    }
    return null;
  }

  Future<dynamic> _getAdmin(String path) async {
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (_adminCookies != null) headers.addAll(_adminCookies!);
      final response =
          await _client.get(Uri.parse('$baseUrl$path'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('GET Admin $path error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _postAdmin(
      String path, Map<String, dynamic> body) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (_adminCookies != null) headers.addAll(_adminCookies!);
      final response = await _client.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('POST Admin $path error: $e');
    }
    return null;
  }

  // ─── Static Data (matching Laravel seeders) ───────────

  static Map<String, dynamic> _getStaticHomeData() {
    return {
      'airports': _getStaticAirports().map((a) => a.toJson()).toList(),
      'vehicles': _getStaticVehicles().map((v) => v.toJson()).toList(),
    };
  }

  static List<Airport> _getStaticAirports() {
    final airports = [
      {'id': 1, 'code': 'LHR', 'name': 'London Heathrow', 'city': 'London', 'image': 'lhr.png', 'sort_order': 1},
      {'id': 2, 'code': 'LGW', 'name': 'London Gatwick', 'city': 'London', 'image': 'lgw.svg', 'sort_order': 2},
      {'id': 3, 'code': 'STN', 'name': 'London Stansted', 'city': 'London', 'image': 'stn.png', 'sort_order': 3},
      {'id': 4, 'code': 'LTN', 'name': 'London Luton', 'city': 'London', 'image': 'ltn.png', 'sort_order': 4},
      {'id': 5, 'code': 'LCY', 'name': 'London City', 'city': 'London', 'image': 'lcy.png', 'sort_order': 5},
      {'id': 6, 'code': 'MAN', 'name': 'Manchester Airport', 'city': 'Manchester', 'image': 'man.svg', 'sort_order': 6},
      {'id': 7, 'code': 'BHX', 'name': 'Birmingham Airport', 'city': 'Birmingham', 'image': 'bhx.svg', 'sort_order': 7},
      {'id': 8, 'code': 'BRS', 'name': 'Bristol Airport', 'city': 'Bristol', 'image': 'brs.svg', 'sort_order': 8},
      {'id': 9, 'code': 'EDI', 'name': 'Edinburgh Airport', 'city': 'Edinburgh', 'image': 'edi.svg', 'sort_order': 9},
      {'id': 10, 'code': 'NCL', 'name': 'Newcastle Airport', 'city': 'Newcastle', 'image': 'ncl.svg', 'sort_order': 10},
      {'id': 11, 'code': 'SEN', 'name': 'London Southend', 'city': 'Southend', 'image': 'sen.png', 'sort_order': 11},
      {'id': 12, 'code': 'BFS', 'name': 'Belfast International', 'city': 'Belfast', 'image': 'bfs.png', 'sort_order': 12},
    ];
    return airports.map((a) => Airport.fromJson(a)).toList();
  }

  static List<Vehicle> _getStaticVehicles() {
    final vehicles = [
      {'id': 1, 'name': 'Saloon', 'slug': 'saloon', 'price': 45.00, 'short_base': 25.0, 'short_per_mile': 1.80, 'long_base': 35.0, 'long_per_mile': 1.50, 'passengers': 3, 'luggage': 3, 'suitcases': 3, 'image': 'saloon.svg', 'car_model': 'Toyota Prius or similar', 'sort_order': 1},
      {'id': 2, 'name': 'Executive', 'slug': 'executive', 'price': 65.00, 'short_base': 35.0, 'short_per_mile': 2.40, 'long_base': 50.0, 'long_per_mile': 2.00, 'passengers': 3, 'luggage': 3, 'suitcases': 3, 'image': 'executive.svg', 'car_model': 'Mercedes E-Class or similar', 'sort_order': 2},
      {'id': 3, 'name': 'Estate', 'slug': 'estate', 'price': 55.00, 'short_base': 30.0, 'short_per_mile': 2.00, 'long_base': 40.0, 'long_per_mile': 1.70, 'passengers': 4, 'luggage': 4, 'suitcases': 4, 'image': 'estate.svg', 'car_model': 'VW Passat or similar', 'sort_order': 3},
      {'id': 4, 'name': 'People Carrier', 'slug': 'people-carrier', 'price': 65.00, 'short_base': 35.0, 'short_per_mile': 2.40, 'long_base': 50.0, 'long_per_mile': 2.00, 'passengers': 5, 'luggage': 5, 'suitcases': 5, 'image': 'people-carrier.svg', 'car_model': 'Ford Galaxy or similar', 'sort_order': 4},
      {'id': 5, 'name': 'Executive People Carrier', 'slug': 'executive-people-carrier', 'price': 85.00, 'short_base': 40.0, 'short_per_mile': 2.60, 'long_base': 55.0, 'long_per_mile': 2.20, 'passengers': 5, 'luggage': 5, 'suitcases': 5, 'image': 'people-carrier.svg', 'car_model': 'Mercedes V-Class or similar', 'sort_order': 5},
      {'id': 6, 'name': 'Minibus', 'slug': 'minibus', 'price': 85.00, 'short_base': 45.0, 'short_per_mile': 2.80, 'long_base': 60.0, 'long_per_mile': 2.40, 'passengers': 8, 'luggage': 8, 'suitcases': 8, 'image': 'minibus.svg', 'car_model': 'Mercedes Vito or similar', 'sort_order': 6},
      {'id': 7, 'name': '16 Pax', 'slug': '16pax', 'price': 120.00, 'short_base': 60.0, 'short_per_mile': 3.50, 'long_base': 80.0, 'long_per_mile': 3.00, 'passengers': 16, 'luggage': 16, 'suitcases': 16, 'image': 'pax16.svg', 'car_model': 'Mercedes Sprinter or similar', 'sort_order': 7},
    ];
    return vehicles.map((v) => Vehicle.fromJson(v)).toList();
  }

  static List<Faq> _getStaticFaqs() {
    return [
      Faq(id: 1, question: 'How do I book a transfer?', answer: 'Simply enter your pickup and drop-off locations, select your preferred vehicle, and complete the booking with your details and payment.', sortOrder: 1),
      Faq(id: 2, question: 'Can I cancel my booking?', answer: 'Yes, you can cancel your booking up to 24 hours before the scheduled pickup time for a full refund. Contact our support team for assistance.', sortOrder: 2),
      Faq(id: 3, question: 'What airports do you cover?', answer: 'We cover all major UK airports including Heathrow, Gatwick, Stansted, Luton, City, Manchester, Birmingham, Bristol, Edinburgh, Newcastle, Southend, and Belfast.', sortOrder: 3),
      Faq(id: 4, question: 'How are prices calculated?', answer: 'Prices are calculated based on the distance between your pickup and drop-off locations, and the type of vehicle you select. All prices are shown upfront before booking.', sortOrder: 4),
      Faq(id: 5, question: 'Do you track my flight?', answer: 'Yes, if you provide your flight number, we will monitor your flight and adjust the pickup time accordingly if there are any delays.', sortOrder: 5),
      Faq(id: 6, question: 'What payment methods do you accept?', answer: 'We accept all major credit and debit cards through our secure Stripe payment system.', sortOrder: 6),
    ];
  }
}
