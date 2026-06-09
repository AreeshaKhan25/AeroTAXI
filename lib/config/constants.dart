class AppConstants {
  static const String appName = 'AeroTAXI';
  static const String appTagline = 'Premium Airport Transfers';

  // API Base URL - change this to your Laravel server URL
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  static const String webBaseUrl = 'http://localhost:8000'; // Web
  static const String apiUrl = '$baseUrl/api';

  // Contact
  static const String supportEmail = 'supportaerotaxi@gmail.com';
  static const String supportPhone = '+44 XXX XXX XXXX';

  // Booking statuses
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusAssigned = 'assigned';
  static const String statusBidding = 'bidding';
  static const String statusNew = 'new';

  // Payment statuses
  static const String paymentUnpaid = 'unpaid';
  static const String paymentPaid = 'paid';
  static const String paymentRefunded = 'refunded';
}
