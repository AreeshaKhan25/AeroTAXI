import 'package:flutter/foundation.dart';

Future<bool> sendEmail({
  required String to,
  required String subject,
  required String html,
}) async {
  debugPrint('Email not supported on web — skipping');
  return true;
}
