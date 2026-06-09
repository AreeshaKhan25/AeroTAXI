import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String email;
  final String name;
  final DateTime savedAt;

  SavedAccount({
    required this.email,
    required this.name,
    required this.savedAt,
  });

  String get initial =>
      name.isNotEmpty ? name[0].toUpperCase() : email[0].toUpperCase();

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        email: json['email'] as String,
        name: (json['name'] as String?) ?? '',
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
}

class SavedAccountsService {
  static const _key = 'aerotaxi_saved_accounts';
  static const _maxAccounts = 5;

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _pwdKey(String email) =>
      'aerotaxi_pwd_${email.toLowerCase().trim()}';

  static Future<void> savePassword(String email, String password) =>
      _secure.write(key: _pwdKey(email), value: password);

  static Future<String?> getPassword(String email) =>
      _secure.read(key: _pwdKey(email));

  static Future<void> deletePassword(String email) =>
      _secure.delete(key: _pwdKey(email));

  static Future<List<SavedAccount>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final accounts =
          list.map((e) => SavedAccount.fromJson(e as Map<String, dynamic>)).toList();
      accounts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return accounts;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAccount(String email, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    accounts.removeWhere(
        (a) => a.email.toLowerCase() == email.toLowerCase());
    accounts.insert(
      0,
      SavedAccount(email: email, name: name, savedAt: DateTime.now()),
    );
    final trimmed = accounts.take(_maxAccounts).toList();
    await prefs.setString(
        _key, jsonEncode(trimmed.map((a) => a.toJson()).toList()));
  }

  static Future<void> removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    accounts.removeWhere(
        (a) => a.email.toLowerCase() == email.toLowerCase());
    await prefs.setString(
        _key, jsonEncode(accounts.map((a) => a.toJson()).toList()));
    await deletePassword(email);
  }
}
