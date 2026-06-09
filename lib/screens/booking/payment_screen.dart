import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';
import '../../services/stripe_pay_stub.dart' if (dart.library.io) '../../services/stripe_pay.dart';
import '../../services/stripe_js_stub.dart' if (dart.library.html) '../../services/stripe_js_interop.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;

  Future<void> _pay() async {
    if (_processing) return;
    setState(() => _processing = true);

    final bp = context.read<BookingProvider>();
    final total = bp.currentBooking?.totalPrice ?? bp.estimatedPrice;
    final ref = bp.currentBooking?.reference ?? 'ATH-booking';
    final amountPence = (total * 100).round().clamp(50, 99999999);

    String result;

    if (kIsWeb) {
      // Web: use JS interop for Stripe Payment Sheet
      try {
        final clientSecret = await createPaymentIntentJS(
          amountInPence: amountPence,
          description: 'AeroTaxi booking $ref',
        );
        if (clientSecret == null) {
          result = 'Could not connect to payment service';
        } else {
          result = await openStripePaymentSheet(clientSecret);
        }
      } catch (e) {
        result = e.toString();
      }
    } else {
      // Mobile: use flutter_stripe native Payment Sheet
      result = await payWithStripe(
        amountInPence: amountPence,
        description: 'AeroTaxi booking $ref',
        customerEmail: bp.email.isNotEmpty ? bp.email : null,
      );
    }

    if (!mounted) return;
    setState(() => _processing = false);

    if (result == 'success') {
      // Send confirmation email after payment success (non-blocking)
      context.read<BookingProvider>().sendConfirmationEmail();
      context.go('/booking/confirmation/$ref');
    } else if (result != 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();
    final total = bp.currentBooking?.totalPrice ?? bp.estimatedPrice;
    final reference = bp.currentBooking?.reference ??
        'ATH-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button + Step indicator
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
                                Text('STEP 3 OF 3',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppTheme.secondary, letterSpacing: 0.5)),
                                const SizedBox(width: 10),
                                _stepDot(false),
                                const SizedBox(width: 4),
                                _stepDot(false),
                                const SizedBox(width: 4),
                                _stepDot(true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildBookingSummary(bp, reference),
                    const SizedBox(height: 16),
                    _buildTotalCard(bp, total),
                    const SizedBox(height: 32),
                    _buildPaySection(total),
                    const SizedBox(height: 24),
                    _buildSecurityBadges(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaySection(double total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(28),
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
        child: Column(
          children: [
            // Stripe badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF635BFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('stripe',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ),
            const SizedBox(height: 20),
            Text(
              'Secure Payment',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to open the secure payment form powered by Stripe.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.secondary, height: 1.5),
            ),
            const SizedBox(height: 12),
            // Card brands
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                _brandChip('Visa'),
                _brandChip('Mastercard'),
                _brandChip('Amex'),
                _brandChip('Apple Pay'),
                _brandChip('Google Pay'),
              ],
            ),
            const SizedBox(height: 24),
            // Pay button
            GestureDetector(
              onTap: _processing ? null : _pay,
              child: Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppTheme.primaryContainer.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.onPrimaryContainer))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded,
                                size: 18,
                                color: AppTheme.onPrimaryContainer),
                            const SizedBox(width: 8),
                            Text(
                              'Pay \u00A3${total.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: AppTheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 20,
                                color: AppTheme.onPrimaryContainer),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Powered by ',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.outlineVariant)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF635BFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('stripe',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(name,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppTheme.secondary, fontSize: 10)),
    );
  }



  Widget _stepDot(bool active) {
    return Container(
      width: active ? 24 : 16,
      height: 4,
      decoration: BoxDecoration(
        color: active
            ? AppTheme.primaryContainer
            : AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Booking Summary ──
  Widget _buildBookingSummary(BookingProvider bp, String reference) {
    String dateDisplay = bp.departDate;
    try {
      dateDisplay =
          DateFormat('MMM dd, yyyy').format(DateTime.parse(bp.departDate));
    } catch (_) {}

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('BOOKING REFERENCE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.secondary, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(reference,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w800)),
                ])),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('UNPAID',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: 24),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryContainer)),
              Container(
                  width: 2,
                  height: 28,
                  color: AppTheme.surfaceContainerHigh),
              const Icon(Icons.location_on,
                  size: 14, color: AppTheme.onSurface),
            ]),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('FROM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.secondary, letterSpacing: 0.5)),
                  Text(_short(bp.fromLocation),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Text('TO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.secondary, letterSpacing: 0.5)),
                  Text(_short(bp.toLocation),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w700)),
                ])),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _infoCol('DATE', dateDisplay)),
            Expanded(child: _infoCol('TIME', bp.departTime ?? '--:--')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _infoCol(
                    'CLASS', bp.selectedVehicle?.name ?? 'Standard')),
            Expanded(
                child: _infoCol('PASSENGER',
                    bp.passengerName.isNotEmpty ? bp.passengerName : 'Guest')),
          ]),
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value) {
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

  // ── Total Card ──
  Widget _buildTotalCard(BookingProvider bp, double total) {
    final vehicle = bp.selectedVehicle;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TOTAL AMOUNT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.secondary, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('\u00A3${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.onSurface, fontWeight: FontWeight.w800)),
        ])),
        if (vehicle != null)
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: vehicle.imageAsset.endsWith('.svg')
                  ? SvgPicture.asset(vehicle.imageAsset, fit: BoxFit.contain)
                  : Image.asset(vehicle.imageAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.directions_car)),
            ),
          ),
      ]),
    );
  }

  Widget _buildSecurityBadges() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.verified_user_rounded,
            size: 16, color: AppTheme.outlineVariant),
        const SizedBox(width: 6),
        Text('SSL SECURE 256-BIT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.outlineVariant, letterSpacing: 0.5)),
        const SizedBox(width: 20),
        const Icon(Icons.shield_rounded,
            size: 16, color: AppTheme.outlineVariant),
        const SizedBox(width: 6),
        Text('PCI COMPLIANT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.outlineVariant, letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Your payment is processed securely via Stripe. We do not store your card details on our servers.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.secondary, height: 1.5),
        ),
      ),
    ]);
  }

  String _short(String location) {
    if (location.isEmpty) return '--';
    final parts = location.split(',');
    if (parts.length >= 2) return '${parts[0].trim()}, ${parts[1].trim()}';
    return parts.first;
  }
}
