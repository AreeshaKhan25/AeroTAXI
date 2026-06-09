import '../models/booking.dart';
import 'email_sender_stub.dart' if (dart.library.io) 'email_sender.dart';

class EmailService {
  static Future<bool> sendBookingConfirmation(Booking booking) async {
    if (booking.email.isEmpty) return true;

    final vehicleNames = {
      1: 'Saloon', 2: 'Executive', 3: 'Estate',
      4: 'People Carrier', 5: 'Executive People Carrier',
      6: 'Minibus', 7: '16 Pax',
    };
    final vehicleName = vehicleNames[booking.vehicleId] ?? 'Vehicle';
    final from = _short(booking.fromLocation);
    final to = _short(booking.toLocation);

    return sendEmail(
      to: booking.email,
      subject: 'Booking Confirmed - ${booking.reference}',
      html: _buildHtml(booking, vehicleName, from, to),
    );
  }

  static String _buildHtml(
      Booking booking, String vehicleName, String from, String to) {
    return '''<!DOCTYPE html>
<html>
<head>
<style>
body{font-family:'Plus Jakarta Sans',Arial,sans-serif;background:#FCF9F6;margin:0;padding:0}
.c{max-width:600px;margin:0 auto;padding:32px 20px}
.card{background:#fff;border-radius:16px;padding:28px;margin-bottom:16px}
.hdr{text-align:center;margin-bottom:24px}
.chk{display:inline-block;width:60px;height:60px;background:#E8F5E9;border-radius:50%;line-height:60px;font-size:28px;color:#22C55E}
h1{color:#1C1C1A;font-size:24px;margin:16px 0 8px}
.ref{background:#F7F4F0;border-radius:12px;padding:16px;text-align:center;margin:16px 0}
.rc{font-size:24px;font-weight:800;color:#1C1C1A;letter-spacing:2px}
.bg{display:inline-block;background:#E8F5E9;color:#22C55E;padding:4px 12px;border-radius:12px;font-size:11px;font-weight:700}
.dr{padding:8px 0;border-bottom:1px solid #F1EDE8}
.dl{color:#5F5E5E;font-size:13px;display:inline-block;width:100px}
.dv{color:#1C1C1A;font-weight:600;font-size:13px}
.pr{font-size:22px;font-weight:800;color:#1C1C1A}
.ft{text-align:center;color:#5F5E5E;font-size:12px;margin-top:24px}
</style>
</head>
<body>
<div class="c">
<div class="card">
<div class="hdr">
<div class="chk">&#10003;</div>
<h1>Booking Confirmed!</h1>
<p style="color:#5F5E5E;font-size:14px">Your airport transfer has been booked successfully.</p>
</div>
<div class="ref">
<div style="color:#5F5E5E;font-size:11px;letter-spacing:1px;margin-bottom:4px">BOOKING REFERENCE</div>
<div class="rc">${booking.reference ?? 'N/A'}</div>
<div style="margin-top:8px"><span class="bg">CONFIRMED</span></div>
</div>
</div>
<div class="card">
<div style="font-weight:700;font-size:16px;color:#1C1C1A;margin-bottom:16px">Journey Details</div>
<div class="dr"><span class="dl">FROM</span><span class="dv">$from</span></div>
<div class="dr"><span class="dl">TO</span><span class="dv">$to</span></div>
<div class="dr"><span class="dl">DATE</span><span class="dv">${booking.departDate}</span></div>
<div class="dr"><span class="dl">TIME</span><span class="dv">${booking.departTime ?? '--:--'}</span></div>
<div class="dr"><span class="dl">VEHICLE</span><span class="dv">$vehicleName</span></div>
<div class="dr"><span class="dl">PASSENGER</span><span class="dv">${booking.passengerName}</span></div>
${booking.flightNumber != null ? '<div class="dr"><span class="dl">FLIGHT</span><span class="dv">${booking.flightNumber}</span></div>' : ''}
<div style="margin-top:16px;text-align:right">
<span style="color:#5F5E5E;font-size:12px">TOTAL</span><br>
<span class="pr">&pound;${booking.totalPrice.toStringAsFixed(2)}</span>
</div>
</div>
<div class="card">
<div style="font-weight:700;font-size:16px;color:#1C1C1A;margin-bottom:12px">What's Included</div>
<div style="padding:6px 0;color:#1C1C1A">&#9992; Flight tracking</div>
<div style="padding:6px 0;color:#1C1C1A">&#128260; Free cancellation up to 24h</div>
<div style="padding:6px 0;color:#1C1C1A">&#129309; Meet &amp; greet</div>
<div style="padding:6px 0;color:#1C1C1A">&#128222; 24/7 customer support</div>
</div>
<div class="ft">
<p>Thank you for choosing <strong style="color:#735C00">AeroTaxi</strong></p>
<p>For support, contact us at supportaerotaxi@gmail.com</p>
</div>
</div>
</body>
</html>''';
  }

  static String _short(String location) {
    if (location.isEmpty) return '--';
    final parts = location.split(',');
    if (parts.length >= 2) return '${parts[0].trim()}, ${parts[1].trim()}';
    return parts.first;
  }
}
