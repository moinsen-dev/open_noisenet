import 'package:flutter/foundation.dart';

// A syntactically valid base URI for clients that require one. No request to
// this sentinel may reach the transport, including connection probes.
abstract final class BackendDefaults {
  static const localOnly = 'https://offline.invalid/api/v1';
  static const development = 'http://localhost:8100/api/v1';
  static const current = kReleaseMode ? localOnly : development;

  static bool isLocalOnly(Uri uri) => uri.host == 'offline.invalid';
}
