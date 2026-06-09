import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';

class ConfirmationScreen extends StatelessWidget {
  final String reference;

  const ConfirmationScreen({super.key, required this.reference});

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
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
    final bp = context.read<BookingProvider>();
    final booking = bp.currentBooking;

    String dateDisplay = booking?.departDate ?? bp.departDate;
    try {
      dateDisplay = DateFormat('MMM dd, yyyy').format(DateTime.parse(dateDisplay));
    } catch (_) {}

    final from = booking?.fromLocation ?? bp.fromLocation;
    final to = booking?.toLocation ?? bp.toLocation;
    final time = booking?.departTime ?? bp.departTime ?? '--:--';
    final price = booking?.totalPrice ?? bp.estimatedPrice;
    final vehicleName = bp.selectedVehicle?.name ?? 'Standard';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Success icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 44, color: AppTheme.success),
                  ),
                  const SizedBox(height: 20),
                  Text('Booking Confirmed!',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Your transfer has been booked successfully.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.secondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Reference card
                  _card(context,
                    child: Column(
                      children: [
                        Text('BOOKING REFERENCE',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.secondary, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text(reference,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('CONFIRMED',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Journey details card
                  _card(context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Journey Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 20),
                        // From / To
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
                                  height: 22,
                                  color: AppTheme.surfaceContainerHigh),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('FROM',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppTheme.secondary, letterSpacing: 0.5)),
                                  Text(_short(from),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.onSurface,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  Text('TO',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppTheme.secondary, letterSpacing: 0.5)),
                                  Text(_short(to),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.onSurface,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _infoCol(context, 'DATE', dateDisplay)),
                          Expanded(child: _infoCol(context, 'TIME', time)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _infoCol(context, 'VEHICLE', vehicleName)),
                          Expanded(
                              child: _infoCol(context, 'PRICE',
                                  '\u00A3${price.toStringAsFixed(2)}')),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Features card
                  _card(context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Included',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        _featureRow(context, Icons.flight_rounded,
                            'Flight tracking'),
                        const SizedBox(height: 12),
                        _featureRow(context, Icons.cancel_outlined,
                            'Free cancellation up to 24h'),
                        const SizedBox(height: 12),
                        _featureRow(context, Icons.handshake_outlined,
                            'Meet & greet'),
                        const SizedBox(height: 12),
                        _featureRow(context, Icons.support_agent_rounded,
                            '24/7 customer support'),
                      ],
                    ),
                  ),
                  // Space for floating button
                  const SizedBox(height: 100),
                ],
              ),
            ),
            // Floating back to home button
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: GestureDetector(
                onTap: () => context.go('/history'),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Back to Home',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 20, color: AppTheme.onPrimaryContainer),
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

  Widget _infoCol(BuildContext context, String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.secondary, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _featureRow(BuildContext context, IconData icon, String text) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: AppTheme.success),
      ),
      const SizedBox(width: 12),
      Text(text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onSurface, fontWeight: FontWeight.w500)),
    ]);
  }

  String _short(String location) {
    if (location.isEmpty) return '--';
    final parts = location.split(',');
    if (parts.length >= 2) return '${parts[0].trim()}, ${parts[1].trim()}';
    return parts.first;
  }
}
