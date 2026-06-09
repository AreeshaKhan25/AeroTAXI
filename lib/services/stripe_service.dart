import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class StripeService {
  static String get secretKey => Env.stripeSecretKey;

  /// Create a PaymentIntent via Stripe API (works on mobile, not web due to CORS).
  static Future<String?> createPaymentIntent({
    required int amountInPence,
    String currency = 'gbp',
    String? description,
    String? customerEmail,
  }) async {
    try {
      final body = <String, String>{
        'amount': amountInPence.clamp(50, 99999999).toString(),
        'currency': currency,
        'payment_method_types[]': 'card',
      };
      if (description != null) body['description'] = description;
      if (customerEmail != null) body['receipt_email'] = customerEmail;

      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['client_secret'] as String?;
      } else {
        debugPrint('Stripe PI error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Stripe createPaymentIntent error: $e');
    }
    return null;
  }
}
