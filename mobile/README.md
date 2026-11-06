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
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

The generated Dart files are ignored by Git and must be regenerated in a clean
checkout. For an Android APK, check 16 KB compatibility after the build with
the Android SDK's `zipalign` and NDK's `llvm-readelf` available via
`ANDROID_HOME` (or `PATH`):

```bash
../scripts/build-mobile-android.sh --no-pub
python3 ../scripts/check_android_16kb.py build/app/outputs/flutter-apk/app-debug.apk
```

This checks APK ZIP alignment and the 64-bit native library segments. It does
not replace a launch and model inference test on an Android 16 KB device.
When switching from a debug build to `flutter build apk --release`, omit
`--no-pub` so Flutter regenerates the release plugin registration. Release builds require the dedicated upload key. The
[internal beta guide](../docs/mobile/store-beta.md) describes signing,
TestFlight-only export and bundle validation.

## Backend Assumption

Development defaults to `http://localhost:8100/api/v1`. Fresh store installs
start locally without a backend. To test transfers, choose an explicit trusted
HTTPS endpoint in Settings and enable the applicable sharing option.

## Live Backend Smoke

To verify the mobile auth, device registration, and event submission path against a real local stack:

```bash
flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 43123 \
  -t tool/live_backend_smoke.dart
```

Open `http://127.0.0.1:43123` and wait for the page status to become `PASS`.

Accepted analyzer debt for this milestone is tracked in [ANALYZER_BASELINE.md](ANALYZER_BASELINE.md).
