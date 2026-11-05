// Separate debug-only field-test application. Never use this entry point for release.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:noisenet_mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  if (!kDebugMode) {
    throw StateError('Field test entry point is restricted to debug builds');
  }
  const certificate = String.fromEnvironment('NOISENET_FIELDTEST_CA_BASE64');
  const backend = String.fromEnvironment('NOISENET_FIELDTEST_URL');
  final uri = Uri.tryParse(backend);
  final address = uri == null ? null : InternetAddress.tryParse(uri.host);
  final bytes = address?.rawAddress;
  final privateAddress = bytes != null && bytes.length == 4 &&
      (bytes[0] == 10 ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168));
  if (certificate.isEmpty || uri?.scheme != 'https' || !privateAddress) {
    throw StateError('Field testing requires a private IPv4 HTTPS backend and test CA');
  }
  WidgetsFlutterBinding.ensureInitialized();
  SecurityContext.defaultContext.setTrustedCertificatesBytes(base64.decode(certificate));
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('api_base_url', backend);
  app.main();
}
