import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:noisenet_mobile/core/logging/app_logger.dart';
import 'package:noisenet_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:noisenet_mobile/services/sqlite_preferences_service.dart';

class _Preferences implements SQLitePreferencesService {
  bool completed = false;
  @override
  Future<void> setOnboardingComplete(bool value) async { completed = value; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppLogger.initialize);

  for (final denyLocation in [false, true]) {
    testWidgets(denyLocation ? 'denied location still completes setup' : 'skip location completes setup without requesting it', (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = _Preferences();
      GetIt.instance.registerSingleton<SQLitePreferencesService>(preferences);
      addTearDown(GetIt.instance.reset);
      var requests = 0;
      const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'requestPermissions') {
          requests++;
          final permissions = (call.arguments as List).cast<int>();
          return {for (final permission in permissions) permission: requests == 1 ? 1 : 0};
        }
        return 0;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      final router = GoRouter(initialLocation: '/onboarding', routes: [
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Setup complete'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grant Microphone Access'));
      await tester.pumpAndSettle();
      expect(find.text('Location is optional'), findsOneWidget);
      await tester.tap(find.text(denyLocation ? 'Grant Location Access' : 'Continue without location'));
      await tester.pumpAndSettle();
      expect(find.text('Setup complete'), findsOneWidget);
      expect(preferences.completed, isTrue);
      expect(requests, denyLocation ? 2 : 1);
    });
  }
}
