import 'package:flutter_stripe/flutter_stripe.dart';
import '../config/env.dart';

void initStripe() {
  Stripe.publishableKey = Env.stripePublishableKey;
  Stripe.merchantIdentifier = 'merchant.com.aerotaxi';
}
