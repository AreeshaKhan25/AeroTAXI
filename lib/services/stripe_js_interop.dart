import 'dart:js_interop';

@JS('createPaymentIntent')
external JSPromise<JSString?> _createPaymentIntent(
    JSNumber amount, JSString currency, JSString description);

@JS('openStripePaymentSheet')
external JSPromise<JSString> _openStripePaymentSheet(JSString clientSecret);

Future<String?> createPaymentIntentJS({
  required int amountInPence,
  String currency = 'gbp',
  String description = '',
}) async {
  final result = await _createPaymentIntent(
    amountInPence.toJS, currency.toJS, description.toJS).toDart;
  return result?.toDart;
}

Future<String> openStripePaymentSheet(String clientSecret) async {
  final result = await _openStripePaymentSheet(clientSecret.toJS).toDart;
  return result.toDart;
}
