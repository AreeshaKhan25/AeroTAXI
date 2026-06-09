import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/booking.dart';
import '../../providers/booking_provider.dart';
import '../../services/auth_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showAll = false;

  String _vehicleImageFromId(int vehicleId) {
    const images = {
      1: 'saloon.svg', 2: 'executive.svg', 3: 'estate.svg',
      4: 'people-carrier.svg', 5: 'people-carrier.svg',
      6: 'minibus.svg', 7: 'pax16.svg',
    };
    return images[vehicleId] ?? 'saloon.svg';
  }

  String _vehicleNameFromId(int vehicleId) {
    const names = {
      1: 'Saloon', 2: 'Executive', 3: 'Estate',
      4: 'People Carrier', 5: 'Executive People Carrier',
      6: 'Minibus', 7: '16 Pax',
    };
    return names[vehicleId] ?? 'Vehicle';
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();
    final upcoming = bp.upcomingBookings;
    final allBookings = bp.allBookings;
    final displayBookings = _showAll ? allBookings : allBookings.take(1).toList();

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : 'U';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: RefreshIndicator(
              onRefresh: () => context.read<BookingProvider>().loadBookings(),
              color: AppTheme.primaryContainer,
              backgroundColor: AppTheme.surfaceContainerLowest,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Rides',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                        color: AppTheme.onSurface,
                                        fontWeight: FontWeight.w800),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.greyText),
                                ),
                            ],
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showAccountSheet(
                                context, displayName, email, initial),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryContainer,
                              child: Text(
                                initial,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Upcoming rides
                    if (upcoming.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('ACTIVE JOURNEY',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.secondary,
                                    letterSpacing: 1)),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('Upcoming',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 16),
                      ...upcoming.map((b) => _buildUpcomingCard(context, b)),
                    ],
                    const SizedBox(height: 32),
                    // History section
                    if (allBookings.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Text('History',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        color: AppTheme.onSurface,
                                        fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (allBookings.length > 1)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showAll = !_showAll),
                                child: Text(
                                    _showAll ? 'Show less' : 'See all',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...displayBookings.map((b) => _buildHistoryItem(
                            context,
                            booking: b,
                          )),
                    ],
                    if (bp.loadingBookings && allBookings.isEmpty) ...[
                      const SizedBox(height: 48),
                      const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.primaryContainer,
                          ),
                        ),
                      ),
                    ] else if (allBookings.isEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.history_rounded,
                                size: 48, color: AppTheme.outlineVariant),
                            const SizedBox(height: 12),
                            Text('No rides yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.secondary)),
                            const SizedBox(height: 6),
                            Text('Pull down to refresh',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.outlineVariant)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    _buildHelpSection(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBookingDate(Booking b) {
    String date = b.departDate;
    try {
      date = DateFormat('MMM dd, yyyy').format(DateTime.parse(b.departDate));
    } catch (_) {}
    final time = b.departTime ?? '';
    return time.isNotEmpty ? '$date \u2022 $time' : date;
  }

  Widget _buildUpcomingCard(BuildContext context, Booking booking) {
    String dateDisplay = 'Upcoming';
    try {
      final d = DateTime.parse(booking.departDate);
      final now = DateTime.now();
      final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff == 0) {
        dateDisplay = 'Today';
      } else if (diff == 1) {
        dateDisplay = 'Tomorrow';
      } else {
        dateDisplay = DateFormat('MMM dd, yyyy').format(d);
      }
    } catch (_) {}

    final time = booking.departTime ?? '--:--';
    final price = booking.totalPrice;
    final from = _short(booking.fromLocation);
    final to = _short(booking.toLocation);
    final vehicleImage = _vehicleImageFromId(booking.vehicleId);
    final imagePath = 'assets/images/vehicles/$vehicleImage';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference
          if (booking.reference != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('REF: ${booking.reference}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.secondary,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600)),
            ),
          // Date + Status
          Row(
            children: [
              Text('$dateDisplay, $time',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondary, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('CONFIRMED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // From/To
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryContainer)),
                Container(
                    width: 2,
                    height: 20,
                    color: AppTheme.surfaceContainerHigh),
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: AppTheme.onSurface)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(from,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(to,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Vehicle + Price
          Row(
            children: [
              Container(
                width: 48,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: vehicleImage.endsWith('.svg')
                      ? SvgPicture.asset(imagePath, fit: BoxFit.contain)
                      : Image.asset(imagePath, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car_rounded,
                              size: 16, color: AppTheme.outlineVariant)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_vehicleNameFromId(booking.vehicleId),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondary, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('\u00A3${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.onSurface, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildHistoryItem(BuildContext context, {required Booking booking}) {
    final from = booking.fromLocation;
    final to = booking.toLocation;
    final reference = booking.reference ?? '';
    final passenger = booking.passengerName.isNotEmpty ? booking.passengerName : 'Guest';
    final vehicleImage = _vehicleImageFromId(booking.vehicleId);
    final vehicleName = _vehicleNameFromId(booking.vehicleId);
    final price = '\u00A3${booking.totalPrice.toStringAsFixed(2)}';
    final date = _formatBookingDate(booking);
    final status = booking.status == 'confirmed' ? 'Confirmed' : 'Completed';
    final fromShort = _short(from);
    final toShort = _short(to);
    final imagePath = 'assets/images/vehicles/$vehicleImage';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference + Status
          if (reference.isNotEmpty) ...[
            Row(
              children: [
                Text('REF: $reference',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.secondary,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(status.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Date + Price
          Row(
            children: [
              Text(date,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.secondary)),
              const Spacer(),
              Text(price,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.onSurface, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          // From / To
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryContainer)),
                  Container(
                      width: 2,
                      height: 20,
                      color: AppTheme.surfaceContainerHigh),
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: AppTheme.onSurface)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fromShort,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(toShort,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Vehicle image + info
          Row(
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: vehicleImage.endsWith('.svg')
                      ? SvgPicture.asset(imagePath, fit: BoxFit.contain)
                      : Image.asset(imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car_rounded,
                              size: 18,
                              color: AppTheme.outlineVariant)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicleName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w600)),
                  Text(passenger,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.outlineVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Rebook + Details buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.go(Uri(
                      path: '/home',
                      queryParameters: {
                        if (from.isNotEmpty) 'from': from,
                        if (to.isNotEmpty) 'to': to,
                        if (booking.fromLat != null) 'fromLat': booking.fromLat.toString(),
                        if (booking.fromLng != null) 'fromLng': booking.fromLng.toString(),
                        if (booking.toLat != null) 'toLat': booking.toLat.toString(),
                        if (booking.toLng != null) 'toLng': booking.toLng.toString(),
                      },
                    ).toString());
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text('Rebook',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: AppTheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showRideDetails(context, booking),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      size: 18, color: AppTheme.secondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRideDetails(BuildContext context, Booking b) {
    final vehicleName = _vehicleNameFromId(b.vehicleId);
    final vehicleImage = _vehicleImageFromId(b.vehicleId);
    final imagePath = 'assets/images/vehicles/$vehicleImage';
    final fromShort = _short(b.fromLocation);
    final toShort = _short(b.toLocation);
    final status = b.status == 'confirmed' ? 'Confirmed' : 'Completed';
    String dateDisplay = b.departDate;
    try { dateDisplay = DateFormat('MMM dd, yyyy').format(DateTime.parse(b.departDate)); } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Center(child: Container(
                      margin: const EdgeInsets.only(top: 14, bottom: 20),
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)))),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Ride Details', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.onSurface, fontWeight: FontWeight.w800))),
                const SizedBox(height: 20),
                // Vehicle image
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  height: 150,
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
                  child: Stack(children: [
                    Center(child: Padding(padding: const EdgeInsets.all(20),
                      child: vehicleImage.endsWith('.svg')
                        ? SvgPicture.asset(imagePath, fit: BoxFit.contain)
                        : Image.asset(imagePath, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_rounded, size: 48, color: AppTheme.outlineVariant)))),
                    Positioned(left: 16, bottom: 14, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                      child: Text(vehicleName.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.onPrimaryContainer, fontWeight: FontWeight.w700, letterSpacing: 0.5)))),
                  ]),
                ),
                const SizedBox(height: 16),
                // Reference + Route card
                _sheetCard(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BOOKING REFERENCE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(b.reference ?? 'N/A', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w800)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(status.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                  ]),
                  const SizedBox(height: 20),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryContainer)),
                      Container(width: 2, height: 22, color: AppTheme.surfaceContainerHigh),
                      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.onSurface)),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('FROM', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
                      Text(fromShort, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text('TO', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
                      Text(toShort, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
                    ])),
                  ]),
                ])),
                const SizedBox(height: 12),
                // Map card
                _buildRouteMapCard(context, b),
                // Distance & Duration
                if (b.distanceMiles != null && b.durationMinutes != null) ...[
                  const SizedBox(height: 12),
                  _sheetCard(context, child: Row(children: [
                    Expanded(child: Row(children: [
                      const Icon(Icons.route_rounded, size: 14, color: AppTheme.secondary),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('DISTANCE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
                        Text('${b.distanceMiles!.toStringAsFixed(1)} mi', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
                      ])),
                    ])),
                    Container(width: 1, height: 30, color: AppTheme.ghostBorder),
                    Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.secondary),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('DURATION', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
                        Text(_formatDuration(b.durationMinutes!), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
                      ]),
                    ])),
                  ])),
                ],
                const SizedBox(height: 12),
                // Booking details card
                _sheetCard(context, child: Column(children: [
                  _detailRow(context, 'DATE', dateDisplay),
                  const SizedBox(height: 12),
                  _detailRow(context, 'TIME', b.departTime ?? '--'),
                  const SizedBox(height: 12),
                  _detailRow(context, 'VEHICLE', vehicleName),
                  const SizedBox(height: 12),
                  _detailRow(context, 'PASSENGER', b.passengerName.isNotEmpty ? b.passengerName : 'Guest'),
                  const SizedBox(height: 12),
                  _detailRow(context, 'EMAIL', b.email.isNotEmpty ? b.email : '--'),
                  const SizedBox(height: 12),
                  _detailRow(context, 'PHONE', b.phone.isNotEmpty ? '${b.countryCode ?? ''} ${b.phone}' : '--'),
                  const SizedBox(height: 12),
                  _detailRow(context, 'PASSENGERS', '${b.passengers}'),
                  const SizedBox(height: 12),
                  _detailRow(context, 'LUGGAGE', '${b.luggage}'),
                  const SizedBox(height: 12),
                  _detailRow(context, 'SUITCASES', '${b.suitcases}'),
                ])),
                // Extras card (if any)
                if (b.meetAndGreet || b.pet || b.oversizedItem || b.childSeats.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sheetCard(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('EXTRAS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    if (b.meetAndGreet) _extraRow(context, Icons.handshake_outlined, 'Meet & Greet'),
                    if (b.pet) _extraRow(context, Icons.pets_rounded, 'Pet'),
                    if (b.oversizedItem) _extraRow(context, Icons.luggage_rounded, 'Oversized Item'),
                    ...b.childSeats.map((s) => _extraRow(context, Icons.child_care_rounded, s)),
                  ])),
                ],
                // Flight & Notes card (if any)
                if (b.flightNumber != null || b.noteToDriver != null) ...[
                  const SizedBox(height: 12),
                  _sheetCard(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (b.flightNumber != null) ...[
                      _detailRow(context, 'FLIGHT', b.flightNumber!),
                      if (b.noteToDriver != null) const SizedBox(height: 14),
                    ],
                    if (b.noteToDriver != null) ...[
                      Text('NOTE TO DRIVER', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(b.noteToDriver!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, height: 1.4)),
                    ],
                  ])),
                ],
                const SizedBox(height: 12),
                // Total card
                _sheetCard(context, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('TOTAL PAID', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
                  Text('\u00A3${b.totalPrice.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w800)),
                ])),
                const SizedBox(height: 12),
                // Features
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
                  child: Column(children: [
                    _featureRow(context, Icons.flight_rounded, 'Flight tracking included'),
                    const SizedBox(height: 12),
                    _featureRow(context, Icons.cancel_outlined, 'Free cancellation (24h)'),
                    const SizedBox(height: 12),
                    _featureRow(context, Icons.handshake_outlined, 'Meet & greet'),
                    const SizedBox(height: 12),
                    _featureRow(context, Icons.support_agent_rounded, '24/7 customer support'),
                  ]),
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

  Widget _buildRouteMapCard(BuildContext context, Booking b) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 180,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _RouteMapView(
        from: b.fromLocation,
        to: b.toLocation,
        fromLat: b.fromLat,
        fromLng: b.fromLng,
        toLat: b.toLat,
        toLng: b.toLng,
      ),
    );
  }

  Widget _sheetCard(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.onSurface.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondary, letterSpacing: 0.5)),
      Flexible(child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w600), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _extraRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _featureRow(BuildContext context, IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 18, color: AppTheme.success),
      const SizedBox(width: 10),
      Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildHelpSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline_rounded,
                size: 24, color: AppTheme.secondary),
          ),
          const SizedBox(height: 16),
          Text('Need help with a trip?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Our support concierge is available 24/7 for any billing or route inquiries.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.secondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showSupportSheet(context),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text('Contact Support',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportSheet(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 32 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Text('Contact Support',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.onSurface,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('We\'re here to help 24/7',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.secondary)),
                const SizedBox(height: 24),
                // Email
                _supportOption(
                  context,
                  icon: Icons.email_rounded,
                  title: 'Email Us',
                  subtitle: 'supportaerotaxi@gmail.com',
                  onTap: () {
                    Navigator.pop(ctx);
                    launchUrl(Uri.parse(
                        'mailto:supportaerotaxi@gmail.com?subject=Support Request'));
                  },
                ),
                const SizedBox(height: 12),
                // Phone
                _supportOption(
                  context,
                  icon: Icons.phone_rounded,
                  title: 'Call Us',
                  subtitle: '+44 XXX XXX XXXX',
                  onTap: () {
                    Navigator.pop(ctx);
                    launchUrl(Uri.parse('tel:+44XXXXXXXX'));
                  },
                ),
                const SizedBox(height: 12),
                // WhatsApp
                _supportOption(
                  context,
                  icon: Icons.chat_rounded,
                  title: 'WhatsApp',
                  subtitle: 'Chat with us instantly',
                  onTap: () {
                    Navigator.pop(ctx);
                    launchUrl(Uri.parse(
                        'https://wa.me/44XXXXXXXX?text=Hi, I need help with my booking'));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _supportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.secondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppTheme.outlineVariant),
          ],
        ),
      ),
    );
  }

  void _showAccountSheet(
      BuildContext context, String name, String email, String initial) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 14, bottom: 24),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primaryContainer,
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.greyText,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await AuthService().signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(double mins) {
    final h = mins ~/ 60;
    final m = (mins % 60).round();
    return h > 0 ? '${h}h ${m}m' : '$m min';
  }

  String _short(String location) {
    if (location.isEmpty) return '--';
    final parts = location.split(',');
    if (parts.length >= 2) return '${parts[0].trim()}, ${parts[1].trim()}';
    return parts.first;
  }
}

class _RouteMapView extends StatefulWidget {
  final String from;
  final String to;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  const _RouteMapView({
    required this.from,
    required this.to,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  @override
  State<_RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<_RouteMapView> {
  LatLng? _fromLatLng;
  LatLng? _toLatLng;
  List<LatLng> _routePoints = [];
  bool _loading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<LatLng?> _geocode(String location) async {
    // Clean up location string — remove codes in parentheses
    var query = location
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Try full query first, then just first part
    for (final q in [query, query.split(',').first.trim()]) {
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)},UK&format=json&limit=1');
        final res = await http.get(url, headers: {'User-Agent': 'AeroTaxiApp/1.0'});
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          if (data.isNotEmpty) {
            return LatLng(
              double.parse(data[0]['lat']),
              double.parse(data[0]['lon']),
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadRoute() async {
    // Use stored coordinates if available, otherwise geocode
    final from = (widget.fromLat != null && widget.fromLng != null)
        ? LatLng(widget.fromLat!, widget.fromLng!)
        : await _geocode(widget.from);
    final to = (widget.toLat != null && widget.toLng != null)
        ? LatLng(widget.toLat!, widget.toLng!)
        : await _geocode(widget.to);
    if (!mounted) return;

    if (from != null && to != null) {
      // Fetch route
      try {
        final url = Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/'
            '${from.longitude},${from.latitude};'
            '${to.longitude},${to.latitude}'
            '?overview=full&geometries=geojson');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          _routePoints = coords
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
        }
      } catch (_) {
        _routePoints = [from, to];
      }

      setState(() {
        _fromLatLng = from;
        _toLatLng = to;
        _loading = false;
      });

      // Fit bounds after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fromLatLng != null && _toLatLng != null) {
          _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([_fromLatLng!, _toLatLng!]),
            padding: const EdgeInsets.all(40),
          ));
        }
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppTheme.surfaceContainerLow,
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primaryContainer),
          ),
        ),
      );
    }

    if (_fromLatLng == null || _toLatLng == null) {
      return Container(
        color: AppTheme.surfaceContainerLow,
        child: Center(
          child: Text('Map unavailable',
              style: TextStyle(color: AppTheme.outlineVariant, fontSize: 13)),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _fromLatLng!,
        initialZoom: 10,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aerotaxi.app',
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(points: _routePoints, color: AppTheme.primaryContainer, strokeWidth: 4),
          ]),
        MarkerLayer(markers: [
          Marker(
            point: _fromLatLng!,
            width: 36, height: 36,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.primaryContainer.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2)],
              ),
              child: const Center(child: Icon(Icons.circle, color: Colors.white, size: 10)),
            ),
          ),
          Marker(
            point: _toLatLng!,
            width: 36, height: 36,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.onSurface,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.onSurface.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2)],
              ),
              child: const Center(child: Icon(Icons.location_on, color: Colors.white, size: 16)),
            ),
          ),
        ]),
      ],
    );
  }
}
