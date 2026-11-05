import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noisenet_mobile/core/logging/app_logger.dart';
import 'package:noisenet_mobile/services/android_foreground_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppLogger.initialize);

  testWidgets('Android foreground host starts and stops', (tester) async {
    if (!Platform.isAndroid) return;

    final service = AndroidForegroundService();
    addTearDown(service.stopService);

    expect(await service.initialize(), isTrue);
    expect(await service.startService(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await service.isNativeServiceRunning(), isTrue);

    final stopRequested = service.stopRequests.first.timeout(
      const Duration(seconds: 2),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'com.opennoisenet.mobile/noise_service',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('stopMonitoring'),
      ),
      (_) {},
    );
    await stopRequested;

    await service.stopService();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await service.isNativeServiceRunning(), isFalse);
  });
}
