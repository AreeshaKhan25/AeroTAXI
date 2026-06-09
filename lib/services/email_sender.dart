import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config/env.dart';

Future<bool> sendEmail({
  required String to,
  required String subject,
  required String html,
}) async {
  final username = Env.emailUsername;
  final appPassword = Env.emailAppPassword;
  final smtpServer = gmail(username, appPassword);

  final message = Message()
    ..from = Address(username, 'AeroTaxi')
    ..recipients.add(to)
    ..subject = subject
    ..html = html;

  try {
    await send(message, smtpServer);
    debugPrint('Email sent to $to');
    return true;
  } catch (e) {
    debugPrint('Email send error: $e');
    return false;
  }
}
