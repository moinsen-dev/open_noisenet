import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  test('probing another backend does not change it or leak a bearer token',
      () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await first.close(force: true);
      await second.close(force: true);
    });
    final seenFirst = <String?>[];
    final seenSecond = <String?>[];
    void answer(HttpRequest request, List<String?> seen) {
      seen.add(request.headers.value(HttpHeaders.authorizationHeader));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'healthy'}));
      unawaited(request.response.close());
    }

    first.listen((request) => answer(request, seenFirst));
    second.listen((request) => answer(request, seenSecond));
    final original = 'http://127.0.0.1:${first.port}/api/v1';
    final candidate = 'http://127.0.0.1:${second.port}/api/v1';
    SharedPreferences.setMockInitialValues({
      'api_base_url': original,
      'access_token': 'test-token',
      'refresh_token': 'test-refresh',
    });
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClientService(prefs: prefs, logger: Talker());

    await api.healthCheck();
    expect(seenFirst, ['Bearer test-token']);
    final probe = await api.testConnectionDetailed(candidateUrl: candidate);
    expect(probe.success, isTrue);
    expect(api.baseUrl, original);
    expect(api.isAuthenticated, isTrue);
    expect(seenSecond, [null]);

    await api.setBaseUrl(candidate);
    expect(api.isAuthenticated, isFalse);
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
    await api.healthCheck();
    expect(seenSecond, [null, null]);
  });

  test('does not follow an authenticated redirect to another host', () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await first.close(force: true);
      await second.close(force: true);
    });
    var redirectedRequests = 0;
    first.listen((request) {
      request.response.statusCode = HttpStatus.temporaryRedirect;
      request.response.headers.set(
          HttpHeaders.locationHeader, 'http://127.0.0.1:${second.port}/health');
      unawaited(request.response.close());
    });
    second.listen((request) {
      redirectedRequests++;
      unawaited(request.response.close());
    });
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'http://127.0.0.1:${first.port}/api/v1',
      'access_token': 'test-token',
    });
    final api = ApiClientService(
        prefs: await SharedPreferences.getInstance(), logger: Talker());
    await expectLater(api.healthCheck(), throwsA(isA<Exception>()));
    expect(redirectedRequests, 0);
  });

  test('rejects URLs carrying embedded credentials or unsupported schemes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClientService(
        prefs: await SharedPreferences.getInstance(), logger: Talker());
    await expectLater(api.setBaseUrl('http://user:secret@example.com/api/v1'),
        throwsFormatException);
    await expectLater(
        api.setBaseUrl('file:///tmp/backend'), throwsFormatException);
  });
  test('a late login response cannot authenticate the newly selected backend',
      () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await first.close(force: true);
      await second.close(force: true);
    });
    final arrived = Completer<void>();
    final release = Completer<void>();
    String? secondAuthorization;
    first.listen((request) async {
      arrived.complete();
      await release.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'access_token': 'old-server-token',
        'refresh_token': 'old-server-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
      }));
      await request.response.close();
    });
    second.listen((request) async {
      secondAuthorization =
          request.headers.value(HttpHeaders.authorizationHeader);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'healthy'}));
      await request.response.close();
    });
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'http://127.0.0.1:${first.port}/api/v1',
    });
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClientService(prefs: prefs, logger: Talker());
    final pendingLogin =
        api.login('synthetic@example.test', 'synthetic-password');
    final loginFailure = expectLater(pendingLogin, throwsA(isA<Exception>()));
    await arrived.future;
    await api.setBaseUrl('http://127.0.0.1:${second.port}/api/v1');
    release.complete();
    await loginFailure;
    await api.healthCheck();
    expect(api.isAuthenticated, isFalse);
    expect(prefs.getString('access_token'), isNull);
    expect(secondAuthorization, isNull);
  });

  test('a late device response cannot restore the old backend context',
      () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await first.close(force: true);
      await second.close(force: true);
    });
    final arrived = Completer<void>();
    final release = Completer<void>();
    first.listen((request) async {
      arrived.complete();
      await release.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'device_id': 'test-device',
        'name': 'Old backend device',
        'device_type': 'smartphone',
        'site_id': 'old-site',
      }));
      await request.response.close();
    });
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'http://127.0.0.1:${first.port}/api/v1',
    });
    final api = ApiClientService(
        prefs: await SharedPreferences.getInstance(), logger: Talker());
    final request = api.getDevice('test-device');
    final rejected = expectLater(request, throwsA(isA<Exception>()));
    await arrived.future;
    await api.setBaseUrl('http://127.0.0.1:${second.port}/api/v1');
    release.complete();
    await rejected;
    expect(api.assignedSiteId, isNull);
  });

  test('a rejected refresh is attempted only once', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var refreshRequests = 0;
    server.listen((request) async {
      if (request.uri.path.endsWith('/auth/refresh')) refreshRequests++;
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
    });
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'http://127.0.0.1:${server.port}/api/v1',
      'access_token': 'expired-token',
      'refresh_token': 'expired-refresh',
    });
    final api = ApiClientService(
        prefs: await SharedPreferences.getInstance(), logger: Talker());
    await expectLater(api.healthCheck(), throwsA(isA<Exception>()));
    expect(refreshRequests, 1);
    expect(api.isAuthenticated, isFalse);
  });
  test('an unauthorized retry does not enter a refresh loop', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var refreshRequests = 0;
    var healthRequests = 0;
    server.listen((request) async {
      if (request.uri.path.endsWith('/auth/refresh')) {
        refreshRequests++;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'access_token': 'renewed',
          'refresh_token': 'renewed-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
        }));
      } else {
        healthRequests++;
        request.response.statusCode = HttpStatus.unauthorized;
      }
      await request.response.close();
    });
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'http://127.0.0.1:${server.port}/api/v1',
      'access_token': 'expired-token',
      'refresh_token': 'valid-refresh',
    });
    final api = ApiClientService(
        prefs: await SharedPreferences.getInstance(), logger: Talker());
    await expectLater(api.healthCheck(), throwsA(isA<Exception>()));
    expect(refreshRequests, 1);
    expect(healthRequests, 2);
  });
}
