import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';

class TransferDetailsScreen extends StatefulWidget {
  const TransferDetailsScreen({super.key});

  @override
  State<TransferDetailsScreen> createState() => _TransferDetailsScreenState();
}

class _TransferDetailsScreenState extends State<TransferDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _flightController = TextEditingController();
  final _notesController = TextEditingController();

  String _countryCode = '+44';
  bool _subscribe = false;
  int _passengers = 1;
  int _luggage = 0;
  int _suitcases = 0;

  // Optional extras
  bool _meetAndGreet = false;
  bool _pet = false;
  bool _oversizedItem = false;
  final Map<String, bool> _childSeats = {
    'Baby seat (0-1y, 0-13kg)': false,
    'Toddler seat (1-4y, 9-18kg)': false,
    'Child seat (3-7y, 15-25kg)': false,
    'Booster seat (6-12y, 22-36kg)': false,
  };

  bool _flightValidated = false;
  bool _flightNotFound = false;
  bool _validatingFlight = false;
  String? _flightAirline;
  String? _flightNumber;
  String? _flightDate;

  static const List<String> _countryCodes = [
    '+44', '+1', '+33', '+49', '+34', '+39', '+31',
    '+353', '+61', '+91', '+86', '+81', '+971', '+966', '+974',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _flightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _validateFlight() async {
    final input = _flightController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _validatingFlight = true;
      _flightValidated = false;
      _flightNotFound = false;
      _flightAirline = null;
      _flightNumber = null;
      _flightDate = null;
    });

    try {
      final iata = input.toUpperCase().replaceAll(' ', '');
      final url = Uri.parse(
        'https://api.flightradar24.com/common/v1/search.json?query=$iata&limit=5',
      );
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final flights =
            data['result']?['response']?['flight']?['data'] as List?;

        if (flights != null && flights.isNotEmpty) {
          // Find the exact match for the flight number
          Map<String, dynamic>? match;
          for (final f in flights) {
            final num = f['identification']?['number']?['default'] as String?;
            if (num != null && num.toUpperCase() == iata) {
              match = f;
              break;
            }
          }
          // Fallback: first result with an airline
          match ??= flights.firstWhere(
            (f) => f['airline'] != null,
            orElse: () => null,
          );

          if (match != null && match['airline'] != null) {
            final airline =
                match['airline']?['name'] as String? ?? 'Airline';
            final bp = context.read<BookingProvider>();

            setState(() {
              _validatingFlight = false;
              _flightValidated = true;
              _flightAirline = airline;
              _flightNumber = iata;
              _flightDate = bp.departDate.isNotEmpty ? bp.departDate : null;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Flight validation error: $e');
    }

    // Flight not found or API error
    if (mounted) {
      setState(() {
        _validatingFlight = false;
        _flightNotFound = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final bp = context.read<BookingProvider>();
    final selectedChildSeats = _childSeats.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Update price with extras (taxes + meet & greet)
    final baseRate = bp.estimatedPrice;
    final taxes = baseRate * 0.03;
    final totalWithExtras = baseRate + taxes + (_meetAndGreet ? 10 : 0);
    bp.selectVehicle(bp.selectedVehicle!, totalWithExtras);

    bp.setPassengerDetails(
      name: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      flightNumber: _flightController.text.trim().isEmpty
          ? null
          : _flightController.text.trim(),
      noteToDriver: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      countryCode: _countryCode,
      subscribe: _subscribe,
      passengers: _passengers,
      luggage: _luggage,
      suitcases: _suitcases,
      meetAndGreet: _meetAndGreet,
      pet: _pet,
      oversizedItem: _oversizedItem,
      childSeats: selectedChildSeats,
    );

    final success = await bp.submitBooking();
    if (!mounted) return;

    if (success) {
      context.push('/payment');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bp.error ?? 'Failed to create booking'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // ── Card wrapper ──
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLowest,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.onSurface.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: AppTheme.onSurface, size: 22),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.onSurface.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('STEP 2 OF 3',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.secondary, letterSpacing: 0.5)),
                            const SizedBox(width: 10),
                            _stepDot(false),
                            const SizedBox(width: 4),
                            _stepDot(true),
                            const SizedBox(width: 4),
                            _stepDot(false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitleInline(Icons.flight_takeoff, 'Trip Details'),
                      const SizedBox(height: 20),
                      _buildFlightInputInline(),
                      const SizedBox(height: 20),
                      _buildNoteToDriverInline(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitleInline(Icons.person_outline, 'Passenger Details'),
                      const SizedBox(height: 20),
                      _buildCountersInline(),
                      const SizedBox(height: 20),
                      _buildNameFieldsInline(),
                      const SizedBox(height: 16),
                      _buildEmailFieldInline(),
                      const SizedBox(height: 16),
                      _buildPhoneFieldInline(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_buildOptionalExtrasInline()],
                  ),
                ),
                const SizedBox(height: 16),
                _card(padding: const EdgeInsets.all(16), child: _buildSubscribeCheckboxInline()),
                const SizedBox(height: 16),
                _buildVehicleCard(bp),
                const SizedBox(height: 16),
                _card(child: _buildRouteSummaryInline(bp)),
                const SizedBox(height: 16),
                _card(child: _buildFareSummaryInline(bp)),
                const SizedBox(height: 20),
                _buildPaymentButton(bp),
                const SizedBox(height: 8),
                _buildSslBadge(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }



  // ── Inline widgets (no outer padding — card handles it) ──

  Widget _stepDot(bool active) {
    return Container(
      width: active ? 24 : 16,
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryContainer : AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionTitleInline(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.onSurface),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildFlightInputInline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Flight Number',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _flightController,
                onChanged: (_) {
                  if (_flightValidated || _flightNotFound) {
                    setState(() {
                      _flightValidated = false;
                      _flightNotFound = false;
                      _flightAirline = null;
                      _flightNumber = null;
                      _flightDate = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: 'e.g., BA123',
                  hintStyle: TextStyle(color: AppTheme.outlineVariant),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _validatingFlight ? null : _validateFlight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _validatingFlight
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimaryContainer))
                    : Text('VALIDATE',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700, color: AppTheme.onPrimaryContainer)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_flightValidated) _buildFlightVerified(),
        if (_flightNotFound) _buildFlightNotFound(),
        if (!_flightValidated && !_flightNotFound)
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppTheme.outlineVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('We track your flight to adjust for delays automatically',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondary)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFlightVerified() {
    String dateDisplay = _flightDate ?? '';
    try { dateDisplay = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateDisplay)); } catch (_) {}
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 24, height: 24,
          decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 14, color: Colors.white)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Flight verified', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.success)),
          const SizedBox(height: 4),
          Text('${_flightAirline ?? 'Airline'} flight ${_flightNumber ?? ''}${dateDisplay.isNotEmpty ? ' \u00B7 Date: $dateDisplay' : ''}',
              style: TextStyle(fontSize: 13, color: AppTheme.secondary)),
        ])),
      ]),
    );
  }

  Widget _buildFlightNotFound() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.warning),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'The flight was not found for the specified date. But if you\'re sure it is correct, feel free to proceed with the booking.',
          style: TextStyle(fontSize: 13, color: AppTheme.secondary, height: 1.4))),
      ]),
    );
  }

  Widget _buildNoteToDriverInline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.note_outlined, size: 18, color: AppTheme.secondary),
        const SizedBox(width: 6),
        Text('Note to Driver', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondary)),
      ]),
      const SizedBox(height: 6),
      TextFormField(controller: _notesController, maxLines: 3,
        decoration: InputDecoration(hintText: 'Mention child seats, heavy luggage, or meeting points...',
          hintStyle: TextStyle(color: AppTheme.outlineVariant, fontSize: 14))),
    ]);
  }

  Widget _buildCountersInline() {
    final vehicle = context.read<BookingProvider>().selectedVehicle;
    final maxPassengers = vehicle?.passengers ?? 16;
    final maxLuggage = vehicle?.luggage ?? 10;
    final maxSuitcases = vehicle?.suitcases ?? 10;
    return Column(children: [
      _counterRow(Icons.people_outline, 'Passengers', _passengers, (v) => setState(() => _passengers = v), min: 1, max: maxPassengers),
      const SizedBox(height: 14),
      _counterRow(Icons.work_outline, 'Luggage', _luggage, (v) => setState(() => _luggage = v), max: maxLuggage),
      const SizedBox(height: 14),
      _counterRow(Icons.luggage_outlined, 'Suitcases', _suitcases, (v) => setState(() => _suitcases = v), max: maxSuitcases),
    ]);
  }

  Widget _counterRow(IconData icon, String label, int value, ValueChanged<int> onChanged, {int min = 0, int max = 10}) {
    return Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: AppTheme.secondary)),
      const SizedBox(width: 10),
      Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.onSurface, fontWeight: FontWeight.w500)),
      const Spacer(),
      GestureDetector(
        onTap: value > min ? () => onChanged(value - 1) : null,
        child: Container(width: 34, height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: value > min ? AppTheme.primaryContainer : AppTheme.surfaceContainerLow),
          child: Icon(Icons.remove, size: 16, color: value > min ? AppTheme.onPrimaryContainer : AppTheme.outlineVariant))),
      SizedBox(width: 40, child: Center(child: Text('$value',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface)))),
      GestureDetector(
        onTap: value < max ? () => onChanged(value + 1) : null,
        child: Container(width: 34, height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: value < max ? AppTheme.primaryContainer : AppTheme.surfaceContainerLow),
          child: Icon(Icons.add, size: 16, color: value < max ? AppTheme.onPrimaryContainer : AppTheme.outlineVariant))),
    ]);
  }

  Widget _buildNameFieldsInline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('First Name', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondary)),
      const SizedBox(height: 6),
      TextFormField(controller: _firstNameController,
        decoration: InputDecoration(hintText: 'John', hintStyle: TextStyle(color: AppTheme.outlineVariant)),
        validator: (v) => v == null || v.trim().isEmpty ? 'First name is required' : null),
      const SizedBox(height: 16),
      Text('Last Name', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondary)),
      const SizedBox(height: 6),
      TextFormField(controller: _lastNameController,
        decoration: InputDecoration(hintText: 'Doe', hintStyle: TextStyle(color: AppTheme.outlineVariant)),
        validator: (v) => v == null || v.trim().isEmpty ? 'Last name is required' : null),
    ]);
  }

  Widget _buildEmailFieldInline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Email Address', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondary)),
      const SizedBox(height: 6),
      TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(hintText: 'john.doe@example.com', hintStyle: TextStyle(color: AppTheme.outlineVariant)),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Email is required';
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) return 'Enter a valid email';
          return null;
        }),
    ]);
  }

  Widget _buildPhoneFieldInline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Phone Number', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondary)),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: DropdownButtonFormField<String>(
          value: _countryCode,
          isExpanded: true,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
          items: _countryCodes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _countryCode = v ?? '+44'))),
        const SizedBox(width: 8),
        Expanded(child: TextFormField(controller: _phoneController, keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '7700 900000',
            hintStyle: TextStyle(color: AppTheme.outlineVariant),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
          validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null)),
      ]),
    ]);
  }

  Widget _buildOptionalExtrasInline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Optional extras', style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Flight tracking, child seats and cancellation are included for free.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondary)),
      const SizedBox(height: 16),
      _extraItem('Meet & Greet', 'Your driver will greet you with your name on a sign at the airport arrivals hall',
          '\u00A310.00', _meetAndGreet, () => setState(() => _meetAndGreet = !_meetAndGreet)),
      const SizedBox(height: 12),
      _childSeatsSection(),
      const SizedBox(height: 12),
      _extraItem('Pet', 'Bring your furry friend with you in a pet carrier or leash',
          '\u00A30.00', _pet, () => setState(() => _pet = !_pet)),
      const SizedBox(height: 12),
      _extraItem('Oversized Item', 'Including a child buggy/golf bag/ski gear',
          '\u00A30.00', _oversizedItem, () => setState(() => _oversizedItem = !_oversizedItem)),
    ]);
  }

  Widget _extraItem(String title, String desc, String price, bool selected, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryContainer.withValues(alpha: 0.1) : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
            Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
          ]),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.secondary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        GestureDetector(onTap: onTap, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primaryContainer,
              width: 1.5,
            ),
          ),
          child: Text(selected ? 'Added' : 'Add',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: AppTheme.onSurface)))),
      ]),
    );
  }

  Widget _childSeatsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Child seats (Subject to availability)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText))),
          Text('Free', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
        ]),
        const SizedBox(height: 4),
        Text('Travel with peace of mind', style: TextStyle(fontSize: 12, color: AppTheme.secondary)),
        const SizedBox(height: 12),
        ..._childSeats.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(entry.key, style: TextStyle(fontSize: 13, color: AppTheme.secondary))),
            GestureDetector(
              onTap: () => setState(() => _childSeats[entry.key] = !entry.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: entry.value ? AppTheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primaryContainer,
                    width: 1.5,
                  ),
                ),
                child: Text(entry.value ? 'Added' : 'Add',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface)),
              ),
            ),
          ]))),
      ]),
    );
  }

  Widget _buildSubscribeCheckboxInline() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 24, height: 24, child: Checkbox(
        value: _subscribe, onChanged: (v) => setState(() => _subscribe = v ?? false),
        activeColor: AppTheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(
        onTap: () => setState(() => _subscribe = !_subscribe),
        child: Text('I would like to receive exclusive offers and travel updates via email. You can opt-out at any time.',
          style: TextStyle(fontSize: 13, color: AppTheme.secondary)))),
    ]);
  }

  Widget _buildVehicleCard(BookingProvider bp) {
    final vehicle = bp.selectedVehicle;
    if (vehicle == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          Container(height: 140, width: double.infinity, color: AppTheme.surfaceContainerLow,
            child: vehicle.imageAsset.endsWith('.svg')
              ? SvgPicture.asset(vehicle.imageAsset, fit: BoxFit.cover)
              : Image.asset(vehicle.imageAsset, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          Positioned(left: 14, bottom: 14, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Text(vehicle.name.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.onPrimaryContainer, letterSpacing: 0.5)))),
        ]),
      ),
    );
  }

  Widget _buildRouteSummaryInline(BookingProvider bp) {
    String dateDisplay = bp.departDate;
    try { dateDisplay = DateFormat('MMM dd, yyyy').format(DateTime.parse(bp.departDate)); } catch (_) {}
    return Column(children: [
      _routeRow(Icons.circle, 'FROM', bp.fromLocation, AppTheme.primaryContainer),
      const SizedBox(height: 12),
      _routeRow(Icons.location_on, 'TO', bp.toLocation, AppTheme.onSurface),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _infoChip(Icons.calendar_today_rounded, 'DATE', dateDisplay)),
        const SizedBox(width: 12),
        Expanded(child: _infoChip(Icons.access_time_rounded, 'TIME', bp.departTime ?? '--:--')),
      ]),
    ]);
  }

  Widget _routeRow(IconData icon, String label, String value, Color iconColor) {
    return Row(children: [
      Icon(icon, size: 14, color: iconColor), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value.isNotEmpty ? value.split(',').first : '--',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
          overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Row(children: [
      Container(width: 28, height: 28,
        decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: AppTheme.secondary)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
      ]),
    ]);
  }

  Widget _buildFareSummaryInline(BookingProvider bp) {
    final baseRate = bp.estimatedPrice;
    final taxes = baseRate * 0.03;
    final total = baseRate + taxes + (_meetAndGreet ? 10 : 0);
    return Column(children: [
      Align(alignment: Alignment.centerLeft, child: Text('FARE SUMMARY',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.onSurface, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
      const SizedBox(height: 14),
      _fareRow('Base Rate', '\u00A3${baseRate.toStringAsFixed(2)}'),
      const SizedBox(height: 8),
      _fareRow('Taxes & Fees', '\u00A3${taxes.toStringAsFixed(2)}'),
      if (_meetAndGreet) ...[const SizedBox(height: 8), _fareRow('Meet & Greet', '\u00A310.00')],
      Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(height: 1, color: AppTheme.surfaceContainerHigh)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total Fare', style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.onSurface, fontWeight: FontWeight.w800)),
        Text('\u00A3${total.toStringAsFixed(2)}', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.onSurface)),
      ]),
    ]);
  }

  Widget _fareRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, color: AppTheme.secondary)),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
    ]);
  }

  Widget _buildPaymentButton(BookingProvider bp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: bp.isProcessing ? null : _submit,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppTheme.primaryContainer.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Center(child: bp.isProcessing
            ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimaryContainer))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Proceed to Payment', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20, color: AppTheme.onPrimaryContainer),
              ])),
        ),
      ),
    );
  }

  Widget _buildSslBadge() {
    return Center(child: Padding(padding: const EdgeInsets.only(top: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, size: 14, color: AppTheme.outlineVariant),
        const SizedBox(width: 6),
        Text('SSL SECURE 256-BIT ENCRYPTION',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.outlineVariant, letterSpacing: 0.5)),
      ])));
  }
}
