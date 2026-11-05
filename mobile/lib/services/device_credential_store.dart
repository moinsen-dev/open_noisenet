import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores a distinct randomly generated device credential for each backend.
class DeviceCredentialStore {
  DeviceCredentialStore({
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  })  : _read = read ?? _readSecure,
        _write = write ?? _writeSecure;

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static Future<String?> _readSecure(String key) => _storage.read(key: key);
  static Future<void> _writeSecure(String key, String value) =>
      _storage.write(key: key, value: value);

  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  final Map<String, Future<String?>> _pending = {};

  Future<String?> get(String baseUrl, String deviceId, {bool create = false}) {
    final scope = sha256.convert(utf8.encode('$baseUrl\u0000$deviceId')).toString();
    // Concurrent first registration requests must share one generated key.
    final pendingKey = '$scope:$create';
    return _pending.putIfAbsent(pendingKey, () async {
      try {
        final storageKey = 'noisenet_device_key_$scope';
        final existing = await _read(storageKey);
        if (existing != null) {
          if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(existing)) {
            throw StateError('Stored device credential has an invalid format');
          }
          return existing;
        }
        if (!create) return null;
        final random = Random.secure();
        final key = base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
        await _write(storageKey, key);
        return key;
      } finally {
        _pending.remove(pendingKey);
      }
    });
  }
}
