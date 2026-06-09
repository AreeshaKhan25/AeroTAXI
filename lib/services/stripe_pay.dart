import 'package:flutter_stripe/flutter_stripe.dart';
import 'stripe_service.dart';

Future<String> payWithStripe({
  required int amountInPence,
  String? description,
  String? customerEmail,
}) async {
  final clientSecret = await StripeService.createPaymentIntent(
    amountInPence: amountInPence,
    description: description,
    customerEmail: customerEmail,
  );

  if (clientSecret == null) {
    return 'Could not connect to payment service';
  }

  try {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'AeroTaxi',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return 'success';
  } on StripeException catch (e) {
    if (e.error.code == FailureCode.Canceled) return 'cancelled';
    return e.error.localizedMessage ?? 'Payment failed';
  } catch (e) {
    return e.toString();
  }
}
