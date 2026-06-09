import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/airport.dart';
import '../../providers/app_provider.dart';

class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key});

  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  final _refController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<AppProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryContainer),
                    );
                  }
                  final airports = provider.airports;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text('Airport Coverage',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                      color: AppTheme.onSurface,
                                      fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                              'We cover all major UK airports for transfers',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: AppTheme.secondary,
                                      height: 1.5)),
                        ),
                        const SizedBox(height: 24),
                        // Airport grid
                        if (airports.isEmpty)
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                children: [
                                  Icon(Icons.flight_rounded,
                                      size: 48,
                                      color: AppTheme.outlineVariant),
                                  const SizedBox(height: 12),
                                  Text('No airports available',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: AppTheme.secondary)),
                                ],
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: airports
                                  .map((a) => _buildAirportCard(context, a))
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 32),
                        // My Bookings section
                        _buildMyBookingsSection(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirportCard(BuildContext context, Airport airport) {
    return GestureDetector(
      onTap: () {
        context.go(Uri(
          path: '/home',
          queryParameters: {
            'from': '${airport.name} (${airport.code}), ${airport.city}, UK'
          },
        ).toString());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image thumbnail
            Container(
              width: 104,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _buildImage(airport),
            ),
            const SizedBox(width: 14),
            // Name + city
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(airport.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(airport.city,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.secondary)),
                ],
              ),
            ),
            // Code badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(airport.code,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Airport airport) {
    final asset = airport.imageAsset;
    if (asset.endsWith('.svg')) {
      return Container(
        color: AppTheme.surfaceContainerLow,
        padding: const EdgeInsets.all(16),
        child: SvgPicture.asset(asset, fit: BoxFit.contain),
      );
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.surfaceContainerLow,
        child: Center(
          child: Icon(Icons.flight_rounded,
              size: 36, color: AppTheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildMyBookingsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text('My bookings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          // Reference input
          TextFormField(
            controller: _refController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Booking reference',
              hintStyle: TextStyle(color: AppTheme.outlineVariant),
            ),
          ),
          const SizedBox(height: 16),
          // Retrieve + Help row
          GestureDetector(
            onTap: _searching ? null : _retrieveBooking,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.onPrimaryContainer))
                    : Text('Retrieve booking',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: AppTheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showHelp(context),
            child: Text('Help with Booking reference',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)),
          ),
          const SizedBox(height: 16),
          Text(
            'Amend or cancel your reservation online up to 24 hours before the scheduled pick-up/flight arrival time.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.secondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Your booking reference was sent to your email. It starts with ATH-'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _retrieveBooking() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a booking reference'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _searching = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(ref)
          .get();

      if (!mounted) return;
      setState(() => _searching = false);

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final booking = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        _showBookingDetails(context, booking);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking not found. Please check your reference.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBookingDetails(
      BuildContext context, Map<String, String> b) {
    final vehicleNames = {
      '1': 'Saloon', '2': 'Executive', '3': 'Estate',
      '4': 'People Carrier', '5': 'Executive People Carrier',
      '6': 'Minibus', '7': '16 Pax',
    };
    final vehicleName = vehicleNames[b['vehicle_id']] ?? 'Vehicle';
    final from = _shortLoc(b['from_location'] ?? '');
    final to = _shortLoc(b['to_location'] ?? '');
    final status = b['status'] ?? 'pending';
    String dateDisplay = b['depart_date'] ?? '';
    try {
      dateDisplay =
          DateFormat('MMM dd, yyyy').format(DateTime.parse(dateDisplay));
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Handle
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Center(
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
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Booking Details',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 20),
                  // Reference + Status
                  _sheetCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('BOOKING REFERENCE',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppTheme.secondary,
                                              letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(b['reference'] ?? 'N/A',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              color: AppTheme.onSurface,
                                              fontWeight:
                                                  FontWeight.w800)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: status == 'confirmed'
                                    ? AppTheme.success
                                        .withValues(alpha: 0.12)
                                    : AppTheme.warning
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(status.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: status == 'confirmed'
                                              ? AppTheme.success
                                              : AppTheme.warning,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Route
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          AppTheme.primaryContainer)),
                              Container(
                                  width: 2,
                                  height: 22,
                                  color:
                                      AppTheme.surfaceContainerHigh),
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.onSurface)),
                            ]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('FROM',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppTheme.secondary,
                                              letterSpacing: 0.5)),
                                  Text(from,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: AppTheme.onSurface,
                                              fontWeight:
                                                  FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  Text('TO',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppTheme.secondary,
                                              letterSpacing: 0.5)),
                                  Text(to,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: AppTheme.onSurface,
                                              fontWeight:
                                                  FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Details
                  _sheetCard(
                    context,
                    child: Column(children: [
                      _detailRow(context, 'DATE', dateDisplay),
                      const SizedBox(height: 12),
                      _detailRow(context, 'TIME',
                          b['depart_time']?.isNotEmpty == true ? b['depart_time']! : '--'),
                      const SizedBox(height: 12),
                      _detailRow(context, 'VEHICLE', vehicleName),
                      const SizedBox(height: 12),
                      _detailRow(context, 'PASSENGER',
                          b['passenger_name']?.isNotEmpty == true ? b['passenger_name']! : 'Guest'),
                      const SizedBox(height: 12),
                      _detailRow(context, 'EMAIL',
                          b['email']?.isNotEmpty == true ? b['email']! : '--'),
                      const SizedBox(height: 12),
                      _detailRow(context, 'PHONE',
                          b['phone']?.isNotEmpty == true ? b['phone']! : '--'),
                      if (b['flight_number']?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        _detailRow(
                            context, 'FLIGHT', b['flight_number']!),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Total
                  _sheetCard(
                    context,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TOTAL',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.secondary,
                                    letterSpacing: 0.5)),
                        Text(
                            '\u00A3${double.tryParse(b['total_price'] ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetCard(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.secondary, letterSpacing: 0.5)),
        Flexible(
          child: Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  String _shortLoc(String location) {
    if (location.isEmpty) return '--';
    final parts = location.split(',');
    if (parts.length >= 2) return '${parts[0].trim()}, ${parts[1].trim()}';
    return parts.first;
  }

}
