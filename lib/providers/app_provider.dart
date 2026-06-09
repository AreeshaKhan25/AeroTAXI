import 'package:flutter/material.dart';
import '../models/airport.dart';
import '../models/vehicle.dart';
import '../models/faq.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Airport> _airports = [];
  List<Vehicle> _vehicles = [];
  List<Faq> _faqs = [];
  bool _isLoading = false;

  List<Airport> get airports => _airports;
  List<Vehicle> get vehicles => _vehicles;
  List<Faq> get faqs => _faqs;
  bool get isLoading => _isLoading;

  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    _airports = await _api.getAirports();
    _vehicles = await _api.getVehicles();
    _faqs = await _api.getFaqs();

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Airport>> searchAirports(String query) async {
    if (query.length < 2) return [];
    return _api.searchAirports(query);
  }
}
