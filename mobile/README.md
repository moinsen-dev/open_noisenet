# OpenNoiseNet Mobile

This package contains the Flutter mobile client used for local monitoring, storage, and backend event submission.

The mobile app is not yet a polished public release. In the current stabilization milestone, the active focus is:

- backend authentication
- device registration and identification
- event submission and sync behavior
- keeping the monitoring flow compatible with the supported backend MVP

Out of scope for the current milestone:

- shipping AI classification as a core user-facing feature
- presenting experimental analysis code as finished product behavior
- expanding into firmware or hardware delivery

## Local Development

```bash
flutter pub get
flutter analyze
flutter test
```

## Backend Assumption

The mobile client expects the local backend at:

- `http://localhost:8100/api/v1`

Override with the `API_BASE_URL` Dart define when needed.

## Live Backend Smoke

To verify the mobile auth, device registration, and event submission path against a real local stack:

```bash
flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 43123 \
  -t tool/live_backend_smoke.dart
```

Open `http://127.0.0.1:43123` and wait for the page status to become `PASS`.

Accepted analyzer debt for this milestone is tracked in [ANALYZER_BASELINE.md](/Users/udi/work/moinsen/ideas/open_noisenet/mobile/ANALYZER_BASELINE.md).
