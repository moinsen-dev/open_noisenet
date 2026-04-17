import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'package:noisenet_mobile/core/models/api_models.dart';
import 'package:noisenet_mobile/services/api_client_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveBackendSmokeApp());
}

class LiveBackendSmokeApp extends StatelessWidget {
  const LiveBackendSmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LiveBackendSmokePage(),
    );
  }
}

class LiveBackendSmokePage extends StatefulWidget {
  const LiveBackendSmokePage({super.key});

  @override
  State<LiveBackendSmokePage> createState() => _LiveBackendSmokePageState();
}

class _LiveBackendSmokePageState extends State<LiveBackendSmokePage> {
  String _status = 'RUNNING';
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();
    _runSmoke();
  }

  Future<void> _runSmoke() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final apiClient = ApiClientService(
        prefs: prefs,
        logger: Talker(),
      );

      const baseUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8100/api/v1',
      );
      await apiClient.setBaseUrl(baseUrl);
      _append('Base URL: $baseUrl');

      final suffix = DateTime.now().millisecondsSinceEpoch;
      final email = 'mobile-live-$suffix@example.com';
      const password = 'SmokePass123!';

      await apiClient.register(email, password, 'Mobile Live Smoke');
      _append('Registered user: $email');

      final device = await apiClient.ensureDeviceRegistered(
        name: 'Mobile Live Smoke Device',
        locationLat: 52.52,
        locationLng: 13.405,
      );
      _append('Registered device: ${device.deviceId}');

      final now = DateTime.now().toUtc();
      final createdReceipt = await apiClient.createEvent(
        NoiseEventModel(
          eventUuid: 'mobile-live-$suffix',
          deviceId: device.deviceId,
          timestampStart: now.subtract(const Duration(minutes: 5)),
          timestampEnd: now,
          leqDb: 64.4,
          lmaxDb: 67.1,
          lminDb: 58.2,
          laeqDb: 63.8,
          exceedancePct: 12.5,
          samplesCount: 300,
          ruleTriggered: 'mobile_live_smoke',
          locationLat: 52.52,
          locationLng: 13.405,
          eventMetadata: <String, dynamic>{
            'source': 'flutter_live_runtime',
          },
        ),
      );
      _append('Created event for device: ${createdReceipt.deviceId}');

      final events = await apiClient.listEvents(
        deviceId: device.deviceId,
        limit: 10,
      );
      _append('Fetched ${events.length} events for ${device.deviceId}');

      final stats = await apiClient.getMapStats();
      if (createdReceipt.deviceId != device.deviceId) {
        throw StateError(
          'Expected created event to reference ${device.deviceId}, got ${createdReceipt.deviceId}',
        );
      }
      if (!events.any(
        (event) =>
            event.deviceId == device.deviceId &&
            event.ruleTriggered == 'mobile_live_smoke',
      )) {
        throw StateError(
          'Live event was not returned for ${device.deviceId}',
        );
      }
      if (stats['events_24h'] == null) {
        throw StateError('Map stats did not include events_24h');
      }

      _append('Map stats total devices: ${stats['total_devices']}');
      _append('Map stats events_24h: ${stats['events_24h']}');

      setState(() {
        _status = 'PASS';
      });
    } catch (error, stackTrace) {
      _append('ERROR: $error');
      _append(stackTrace.toString());
      setState(() {
        _status = 'FAIL';
      });
    }
  }

  void _append(String line) {
    if (!mounted) {
      _logs.add(line);
      return;
    }

    setState(() {
      _logs.add(line);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (_status) {
      'PASS' => Colors.green,
      'FAIL' => Colors.red,
      _ => Colors.orange,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenNoiseNet Mobile Live Smoke'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Status:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Runtime log',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return SelectableText(_logs[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
