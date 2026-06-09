import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/vehicle.dart';
import '../../providers/app_provider.dart';
import '../../providers/booking_provider.dart';

class HomeScreen extends StatefulWidget {
  final String? rebookFrom;
  final String? rebookTo;
  final double? rebookFromLat;
  final double? rebookFromLng;
  final double? rebookToLat;
  final double? rebookToLng;

  const HomeScreen({
    super.key,
    this.rebookFrom,
    this.rebookTo,
    this.rebookFromLat,
    this.rebookFromLng,
    this.rebookToLat,
    this.rebookToLng,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedVehicleIndex = 0;
  bool _isDrawerOpen = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final MapController _mapController = MapController();

  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropoffFocus = FocusNode();

  String _pickupValue = '';
  String _dropoffValue = '';
  bool _pickupSelected = false;
  bool _dropoffSelected = false;

  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  List<LatLng> _routePoints = [];
  double? _distanceMiles;
  double? _durationMinutes;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _pickupFocused = false;
  bool _dropoffFocused = false;

  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _dropoffSuggestions = [];
  Timer? _debounce;
  bool _isSearchingPickup = false;
  bool _isSearchingDropoff = false;

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(_onPickupFocusChange);
    _dropoffFocus.addListener(_onDropoffFocusChange);
    _sheetController.addListener(_onSheetChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadInitialData();
      _handleRebook();
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rebookFrom != widget.rebookFrom ||
        oldWidget.rebookTo != widget.rebookTo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleRebook());
    }
  }

  bool _rebooking = false;

  void _handleRebook() async {
    final hasFrom = widget.rebookFrom != null && widget.rebookFrom!.isNotEmpty;
    final hasTo = widget.rebookTo != null && widget.rebookTo!.isNotEmpty;
    if (!hasFrom && !hasTo) return;

    _rebooking = true;

    // Set everything directly — _rebooking flag prevents onChanged from clearing
    if (hasFrom) {
      _pickupValue = widget.rebookFrom!;
      _pickupController.text = widget.rebookFrom!;
      if (widget.rebookFromLat != null && widget.rebookFromLng != null) {
        _pickupLatLng = LatLng(widget.rebookFromLat!, widget.rebookFromLng!);
      }
    }
    if (hasTo) {
      _dropoffValue = widget.rebookTo!;
      _dropoffController.text = widget.rebookTo!;
      if (widget.rebookToLat != null && widget.rebookToLng != null) {
        _dropoffLatLng = LatLng(widget.rebookToLat!, widget.rebookToLng!);
      }
    }

    _rebooking = false;
    setState(() {});

    // Wait for map to be ready then fit
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (_pickupLatLng != null && _dropoffLatLng != null) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([_pickupLatLng!, _dropoffLatLng!]),
          padding: const EdgeInsets.fromLTRB(60, 200, 60, 120),
        ));
      } catch (_) {}
    } else if (_pickupLatLng != null) {
      try { _mapController.move(_pickupLatLng!, 14); } catch (_) {}
    }

    // Fetch route
    await _fetchRouteIfReady();
    if (!mounted) return;
    setState(() {});

    // Prompt for date
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pickDate();
    });
  }

  void _onSheetChanged() {
    final open = _sheetController.size > 0.20;
    if (open != _isDrawerOpen) {
      setState(() => _isDrawerOpen = open);
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupFocus.removeListener(_onPickupFocusChange);
    _dropoffFocus.removeListener(_onDropoffFocusChange);
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPickupFocusChange() {
    if (_pickupFocus.hasFocus) {
      setState(() => _pickupFocused = true);
    } else {
      // Delay so onTap on suggestion fires before list disappears
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _pickupFocused = false);
      });
    }
  }

  void _onDropoffFocusChange() {
    if (_dropoffFocus.hasFocus) {
      setState(() => _dropoffFocused = true);
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _dropoffFocused = false);
      });
    }
  }

  List<Map<String, dynamic>> _getAirportSuggestions() {
    final airports = context.read<AppProvider>().airports;
    return airports
        .map((a) => {
              'display_name': '${a.name} (${a.code}), ${a.city}, UK',
              'lat': _airportCoords[a.code]?['lat'] ?? '51.4700',
              'lon': _airportCoords[a.code]?['lon'] ?? '-0.4543',
            })
        .toList();
  }

  // Known airport coordinates
  static const Map<String, Map<String, String>> _airportCoords = {
    'LHR': {'lat': '51.4700', 'lon': '-0.4543'},
    'LGW': {'lat': '51.1537', 'lon': '-0.1821'},
    'STN': {'lat': '51.8860', 'lon': '0.2389'},
    'LTN': {'lat': '51.8747', 'lon': '-0.3683'},
    'LCY': {'lat': '51.5048', 'lon': '0.0495'},
    'MAN': {'lat': '53.3537', 'lon': '-2.2750'},
    'BHX': {'lat': '52.4539', 'lon': '-1.7480'},
    'BRS': {'lat': '51.3827', 'lon': '-2.7191'},
    'EDI': {'lat': '55.9500', 'lon': '-3.3725'},
    'NCL': {'lat': '55.0375', 'lon': '-1.6917'},
    'SEN': {'lat': '51.5714', 'lon': '0.6956'},
    'BFS': {'lat': '54.6575', 'lon': '-6.2158'},
  };

  void _onPickupChanged(String query) {
    if (_rebooking) return;
    if (_pickupSelected) {
      _pickupSelected = false;
      return;
    }
    _debounce?.cancel();
    _pickupValue = '';
    if (query.length < 3) {
      setState(() => _pickupSuggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchLocations(query, isPickup: true);
    });
  }

  void _onDropoffChanged(String query) {
    if (_rebooking) return;
    if (_dropoffSelected) {
      _dropoffSelected = false;
      return;
    }
    _debounce?.cancel();
    _dropoffValue = '';
    if (query.length < 3) {
      setState(() => _dropoffSuggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchLocations(query, isPickup: false);
    });
  }

  Future<void> _searchLocations(String query, {required bool isPickup}) async {
    setState(() {
      if (isPickup) {
        _isSearchingPickup = true;
      } else {
        _isSearchingDropoff = true;
      }
    });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query,UK&format=json&addressdetails=1&limit=5',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'AeroTaxiApp/1.0',
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final results = data
            .map((e) => {
                  'display_name': e['display_name'] as String,
                  'lat': e['lat'] as String,
                  'lon': e['lon'] as String,
                })
            .toList();
        setState(() {
          if (isPickup) {
            _pickupSuggestions = results;
          } else {
            _dropoffSuggestions = results;
          }
        });
      }
    } catch (e) {
      debugPrint('Location search error: $e');
    }
    setState(() {
      if (isPickup) {
        _isSearchingPickup = false;
      } else {
        _isSearchingDropoff = false;
      }
    });
  }

  void _selectPickup(Map<String, dynamic> item) {
    final name = item['display_name'] as String;
    final lat = double.parse(item['lat'] as String);
    final lon = double.parse(item['lon'] as String);

    // Prevent same location
    if (_dropoffLatLng != null &&
        _dropoffLatLng!.latitude == lat &&
        _dropoffLatLng!.longitude == lon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup must be different from dropoff'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _pickupSuggestions = []);
      return;
    }

    _pickupSelected = true;
    _pickupValue = name;
    _pickupLatLng = LatLng(lat, lon);
    setState(() => _pickupSuggestions = []);
    _pickupController.text = name;
    _pickupController.selection =
        TextSelection.collapsed(offset: name.length);
    _pickupFocus.unfocus();
    // Move map to pickup
    _mapController.move(_pickupLatLng!, 14);
    _fetchRouteIfReady();
    // Auto-jump to dropoff
    Future.delayed(const Duration(milliseconds: 150), () {
      _dropoffFocus.requestFocus();
    });
  }

  void _selectDropoff(Map<String, dynamic> item) {
    final name = item['display_name'] as String;
    final lat = double.parse(item['lat'] as String);
    final lon = double.parse(item['lon'] as String);

    // Prevent same location for both pickup and dropoff
    if (_pickupLatLng != null &&
        _pickupLatLng!.latitude == lat &&
        _pickupLatLng!.longitude == lon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dropoff must be different from pickup'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _dropoffSuggestions = []);
      return;
    }

    _dropoffSelected = true;
    _dropoffValue = name;
    _dropoffLatLng = LatLng(lat, lon);
    setState(() => _dropoffSuggestions = []);
    _dropoffController.text = name;
    _dropoffController.selection =
        TextSelection.collapsed(offset: name.length);
    _dropoffFocus.unfocus();
    _fetchRouteIfReady();
    // Auto-jump to date picker
    Future.delayed(const Duration(milliseconds: 150), () {
      _pickDate();
    });
  }

  Future<void> _fetchRouteIfReady() async {
    if (_pickupLatLng != null && _dropoffLatLng != null) {
      // Skip if same location
      if (_pickupLatLng!.latitude == _dropoffLatLng!.latitude &&
          _pickupLatLng!.longitude == _dropoffLatLng!.longitude) {
        return;
      }
      // Fit map to show both markers
      try {
        final bounds = LatLngBounds.fromPoints([_pickupLatLng!, _dropoffLatLng!]);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(60, 200, 60, 120),
          ),
        );
      } catch (_) {
        // Map not ready yet — ignore
      }
      // Fetch route from OSRM
      try {
        final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
          '${_pickupLatLng!.longitude},${_pickupLatLng!.latitude};'
          '${_dropoffLatLng!.longitude},${_dropoffLatLng!.latitude}'
          '?overview=full&geometries=geojson',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;
          final distMeters = (route['distance'] as num).toDouble();
          final durSeconds = (route['duration'] as num).toDouble();
          setState(() {
            _routePoints = coords
                .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
            _distanceMiles = distMeters / 1609.344;
            _durationMinutes = durSeconds / 60;
          });
        }
      } catch (e) {
        debugPrint('Route fetch error: $e');
        setState(() {
          _routePoints = [_pickupLatLng!, _dropoffLatLng!];
          _distanceMiles = null;
          _durationMinutes = null;
        });
      }
    } else if (_pickupLatLng != null) {
      _mapController.move(_pickupLatLng!, 14);
    } else if (_dropoffLatLng != null) {
      _mapController.move(_dropoffLatLng!, 14);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.gold,
              onPrimary: AppTheme.darkText,
              surface: AppTheme.white,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      // Auto-jump to time picker
      Future.delayed(const Duration(milliseconds: 150), () {
        _pickTime();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.gold,
              onPrimary: AppTheme.darkText,
              surface: AppTheme.white,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
      // Auto-pull up the drawer
      _sheetController.animateTo(
        0.55,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  void _swapLocations() {
    _pickupSelected = true;
    _dropoffSelected = true;
    final tempText = _pickupController.text;
    final tempValue = _pickupValue;
    final tempLatLng = _pickupLatLng;
    _pickupController.text = _dropoffController.text;
    _pickupValue = _dropoffValue;
    _pickupLatLng = _dropoffLatLng;
    _dropoffController.text = tempText;
    _dropoffValue = tempValue;
    _dropoffLatLng = tempLatLng;
    setState(() {
      _pickupSuggestions = [];
      _dropoffSuggestions = [];
    });
    _fetchRouteIfReady();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<AppProvider>().vehicles;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMapBackground()),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  _buildLocationCard(),
                  const SizedBox(height: 10),
                  _buildDateTimeCard(),
                  if (_distanceMiles != null && _durationMinutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildRouteInfoCard(),
                    ),
                ],
              ),
            ),
            _buildBottomSheet(vehicles),
            if (_isDrawerOpen)
              Positioned(
                left: 24,
                right: 24,
                bottom: 16,
                child: _buildBookNowButton(vehicles),
              ),
          ],
        ),
      ),
    );
  }



  // ── Map ──
  Widget _buildMapBackground() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(51.4700, -0.4543),
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aerotaxi.app',
          keepBuffer: 8,
          tileSize: 256,
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: AppTheme.primaryContainer,
                strokeWidth: 4.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_pickupLatLng != null)
              Marker(
                point: _pickupLatLng!,
                width: 44,
                height: 44,
                child: const _MapPin(
                  color: AppTheme.primaryContainer,
                  icon: Icons.circle,
                  iconSize: 12,
                ),
              ),
            if (_dropoffLatLng != null)
              Marker(
                point: _dropoffLatLng!,
                width: 44,
                height: 44,
                child: const _MapPin(
                  color: AppTheme.onSurface,
                  icon: Icons.location_on,
                  iconSize: 18,
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Location Card (glass overlay, no hard borders) ──
  Widget _buildLocationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.ambientShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline dots
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryContainer,
                                ),
                              ),
                              Container(
                                width: 3,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            children: [
                              _buildInputField(
                                label: 'PICK UP',
                                hint: 'Enter pickup location',
                                controller: _pickupController,
                                focusNode: _pickupFocus,
                                onChanged: _onPickupChanged,
                                isSearching: _isSearchingPickup,
                              ),
                              const SizedBox(height: 8),
                              _buildInputField(
                                label: 'DROP OFF',
                                hint: 'Where to?',
                                controller: _dropoffController,
                                focusNode: _dropoffFocus,
                                onChanged: _onDropoffChanged,
                                isSearching: _isSearchingDropoff,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Swap button
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _swapLocations,
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Image.asset(
                              'assets/images/swap-icon.png',
                              width: 30,
                              height: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Suggestions
              if (_pickupSuggestions.isNotEmpty)
                _buildSuggestionsList(_pickupSuggestions, isPickup: true)
              else if (_pickupFocused && _pickupController.text.length < 3)
                _buildSuggestionsList(_getAirportSuggestions(), isPickup: true),
              if (_dropoffSuggestions.isNotEmpty)
                _buildSuggestionsList(_dropoffSuggestions, isPickup: false)
              else if (_dropoffFocused && _dropoffController.text.length < 3)
                _buildSuggestionsList(_getAirportSuggestions(),
                    isPickup: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    required bool isSearching,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.secondary,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
          ),
          SizedBox(
            height: 26,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.outlineVariant,
                    ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
                suffixIconConstraints:
                    const BoxConstraints(maxWidth: 24, maxHeight: 24),
                suffixIcon: isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryContainer,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestions (no dividers — tonal separation) ──
  Widget _buildSuggestionsList(List<Map<String, dynamic>> suggestions,
      {required bool isPickup}) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final item = suggestions[index];
          final name = item['display_name'] as String;
          final shortName =
              name.length > 55 ? '${name.substring(0, 55)}...' : name;
          return InkWell(
            onTap: () =>
                isPickup ? _selectPickup(item) : _selectDropoff(item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        size: 15, color: AppTheme.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shortName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Date/Time Card (glass) ──
  Widget _buildDateTimeCard() {
    final dateText = _selectedDate != null
        ? DateFormat('EEE, d MMM yyyy').format(_selectedDate!)
        : 'Select date';
    final timeText = _selectedTime != null
        ? _selectedTime!.format(context)
        : 'Select time';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.ambientShadow,
          ),
          child: Row(
            children: [
              Flexible(
                flex: 65,
                child: GestureDetector(
                  onTap: _pickDate,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppTheme.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(dateText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _selectedDate != null
                                    ? AppTheme.onSurface
                                    : AppTheme.outlineVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: AppTheme.ghostBorder,
              ),
              Flexible(
                flex: 35,
                child: GestureDetector(
                  onTap: _pickTime,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: AppTheme.secondary),
                      const SizedBox(width: 6),
                      Text(timeText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _selectedTime != null
                                  ? AppTheme.onSurface
                                  : AppTheme.outlineVariant),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Sheet (editorial feel) ──
  Widget _buildRouteInfoCard() {
    final miles = _distanceMiles!;
    final mins = _durationMinutes!;
    final hours = mins ~/ 60;
    final remainMins = (mins % 60).round();
    final durationStr =
        hours > 0 ? '${hours}h ${remainMins}m' : '$remainMins min';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.ambientShadow,
          ),
          child: Row(
            children: [
              Flexible(
                flex: 65,
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded,
                        size: 13, color: AppTheme.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${miles.toStringAsFixed(1)} mi',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.onSurface,
                              fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: AppTheme.ghostBorder,
              ),
              Flexible(
                flex: 35,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 13, color: AppTheme.secondary),
                    const SizedBox(width: 6),
                    Text(durationStr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w600),
                        maxLines: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(List<Vehicle> vehicles) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.14,
      minChildSize: 0.14,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.14, 0.55, 0.85],
      snapAnimationDuration: const Duration(milliseconds: 200),
      builder: (context, scrollController) {
        return Material(
          color: AppTheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          elevation: 8,
          shadowColor: AppTheme.onSurface.withValues(alpha: 0.15),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 20),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Choose a ride',
                  style:
                      Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.onSurface,
                            fontSize: 24,
                          ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Available vehicles in your area',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondary,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              if (vehicles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryContainer),
                  ),
                )
              else
                ...List.generate(vehicles.length, (index) {
                  return _buildVehicleRow(vehicles[index], index);
                }),
              const SizedBox(height: 88),
            ],
          ),
        );
      },
    );
  }

  // ── Price calc ──
  double _calculatePrice(Vehicle vehicle) {
    if (_distanceMiles == null) return vehicle.price;
    final miles = _distanceMiles!;
    if (miles <= 50) {
      return vehicle.shortBase + (vehicle.shortPerMile * miles);
    } else {
      return vehicle.longBase + (vehicle.longPerMile * miles);
    }
  }

  // ── Book Now (gradient CTA, glassmorphism) ──
  bool get _isBookingReady =>
      _pickupValue.isNotEmpty &&
      _dropoffValue.isNotEmpty &&
      _selectedDate != null &&
      _selectedTime != null;

  void _handleBookNow(Vehicle? vehicle, double? price) {
    // Prompt to fill missing fields
    if (_pickupValue.isEmpty) {
      _pickupFocus.requestFocus();
      _sheetController.animateTo(0.08,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }
    if (_dropoffValue.isEmpty) {
      _dropoffFocus.requestFocus();
      _sheetController.animateTo(0.08,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }
    if (_selectedDate == null) {
      _pickDate();
      return;
    }
    if (_selectedTime == null) {
      _pickTime();
      return;
    }
    if (vehicle == null) return;

    final bp = context.read<BookingProvider>();
    final from = _pickupValue.isNotEmpty ? _pickupValue : _pickupController.text;
    final to = _dropoffValue.isNotEmpty ? _dropoffValue : _dropoffController.text;
    bp.setLocations(from, to,
        fromLat: _pickupLatLng?.latitude,
        fromLng: _pickupLatLng?.longitude,
        toLat: _dropoffLatLng?.latitude,
        toLng: _dropoffLatLng?.longitude,
        distanceMiles: _distanceMiles,
        durationMinutes: _durationMinutes);
    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    bp.setDateTime(dateStr, timeStr);
    bp.selectVehicle(vehicle, price ?? vehicle.price);
    context.push('/transfer-details');
  }

  Widget _buildBookNowButton(List<Vehicle> vehicles) {
    final vehicle =
        vehicles.isNotEmpty ? vehicles[_selectedVehicleIndex] : null;
    final price = vehicle != null ? _calculatePrice(vehicle) : null;
    final ready = _isBookingReady;
    return GestureDetector(
      onTap: () => _handleBookNow(vehicle, price),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: ready
              ? AppTheme.primaryContainer
              : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          boxShadow: ready
              ? [
                  BoxShadow(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              price != null && ready
                  ? 'Book Now — \u00A3${price.toStringAsFixed(2)}'
                  : 'Book Now',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ready
                        ? AppTheme.onPrimaryContainer
                        : AppTheme.outlineVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded,
                size: 20,
                color: ready
                    ? AppTheme.onPrimaryContainer
                    : AppTheme.outlineVariant),
          ],
        ),
      ),
    );
  }

  // ── Vehicle Row (no borders — tonal shift for selected) ──
  Widget _buildVehicleRow(Vehicle vehicle, int index) {
    final isSelected = index == _selectedVehicleIndex;
    final price = _calculatePrice(vehicle);

    return GestureDetector(
      onTap: () => setState(() => _selectedVehicleIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.surfaceContainerLowest
              : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(color: AppTheme.primaryContainer, width: 2)
              : null,
          boxShadow: isSelected ? AppTheme.ambientShadow : [],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildVehicleImage(vehicle),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(vehicle.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurface, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (vehicle.carModel != null)
                    Text(vehicle.carModel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.secondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _specChip(Icons.people_outlined, '${vehicle.passengers}'),
                      const SizedBox(width: 8),
                      _specChip(Icons.luggage_outlined, '${vehicle.luggage}'),
                      const SizedBox(width: 8),
                      _specChip(Icons.work_outline, '${vehicle.suitcases}'),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '\u00A3${price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.secondary),
        const SizedBox(width: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildVehicleImage(Vehicle vehicle) {
    final asset = vehicle.imageAsset;
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(asset, fit: BoxFit.contain);
    }
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.directions_car,
        size: 32,
        color: AppTheme.outlineVariant,
      ),
    );
  }

}

// ── Map Pin ──
class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double iconSize;

  const _MapPin({
    required this.color,
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: AppTheme.surfaceContainerLowest, size: iconSize),
      ),
    );
  }
}
