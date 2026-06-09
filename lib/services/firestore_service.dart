import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/booking.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Users ─────────────────────────────────────────────────────────────────

  static Future<void> saveUser(
      String uid, String name, String email) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email.toLowerCase().trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore saveUser error: $e');
    }
  }

  // ── Bookings ──────────────────────────────────────────────────────────────

  static Future<bool> saveBooking(Booking booking) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final data = booking.toJson();
      data['userId'] = userId;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _db
          .collection('bookings')
          .doc(booking.reference)
          .set(data, SetOptions(merge: true));

      debugPrint('Firestore: Booking saved — ${booking.reference}');
      return true;
    } catch (e) {
      debugPrint('Firestore saveBooking error: $e');
      return false;
    }
  }

  static Future<List<Booking>> getUserBookings() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final snap = await _db
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      final bookings = snap.docs
          .map((doc) => Booking.fromJson(doc.data()))
          .toList();
      bookings.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      return bookings;
    } catch (e) {
      debugPrint('Firestore getUserBookings error: $e');
      return [];
    }
  }
}
