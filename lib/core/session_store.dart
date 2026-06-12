import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Authenticated (or guest) session persisted across launches.
class StoredSession {
  const StoredSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.isGuest,
    this.jwtToken,
  });

  final String userId;
  final String name;
  final String email;
  final bool isGuest;
  final String? jwtToken;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'email': email,
        'is_guest': isGuest,
        'jwt_token': jwtToken,
      };

  factory StoredSession.fromJson(Map<String, dynamic> json) => StoredSession(
        userId: json['user_id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        isGuest: json['is_guest'] as bool? ?? false,
        jwtToken: json['jwt_token'] as String?,
      );
}

/// JWT + user identity in the platform keychain/keystore.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'gci_session';
  final FlutterSecureStorage _storage;

  Future<StoredSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return StoredSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _storage.delete(key: _key);
      return null;
    }
  }

  Future<void> write(StoredSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}
