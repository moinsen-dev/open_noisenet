# OpenNoiseNet Mobile Field Test Checklist

Last updated: 2026-08-18

## Prerequisites

- [ ] Backend running (`docker compose up -d`, verify `curl http://localhost:8100/health`)
- [ ] iOS device with Runner.app installed (built via `flutter build ios --no-codesign --debug`)
- [x] Android debug APK builds and installs (Android 8.0 / API 26 minimum)
- [ ] Device has internet connectivity to backend (use `ngrok` or tailscale for remote testing)

## Android qualification — Huawei EVR-L29

Tested 2026-08-18 on a Huawei Mate 20 X (EVR-L29), Android 10 / API 29,
EMUI 12, Kirin 980, 6 GB RAM. The local backend was reached through an
ADB USB reverse tunnel; this is suitable only for the lab qualification, not
the unattended field deployment.

| Check | Result | Evidence / note |
|------|--------|-----------------|
| Install and launch | **Pass** | Debug APK installed; Impeller produced a black surface on the legacy Mali driver, so the Android sensor build now uses Skia. Pixel 10a also rendered with the compatibility setting. |
| Bundled YAMNet tensor contract | **Pass** | Physical-device integration test passed. |
| Live microphone → PCM → YAMNet | **Pass** | Physical-device test passed without creating an audio file; Huawei uses the `VOICE_RECOGNITION` fallback because `UNPROCESSED` is unavailable. |
| Live source UI | **Pass** | Monitor showed `loud_conversation`, confidence, strongest evidence, and a continuously increasing source duration on the Huawei. |
| Source interval engine | **Pass (software path)** | 480 ms update step, 975 ms boundary uncertainty, activation/release hysteresis, category switching, and waveform-free metadata are unit-tested. Known-duration acoustic accuracy remains a field gate. |
| Foreground service lifecycle | **Pass** | Start, running-state, stop callback, and stop passed on device. |
| Screen-off capture smoke test | **Pass** | Device asleep/display off; sample count rose 522→1197 and heartbeat reported a sample age of 84 ms. |
| Recovery after permission-triggered process restart | **Pass** | Pipeline rebuilt automatically; next heartbeat reported 664 samples and a sample age of 95 ms. |
| Backend registration and heartbeat | **Pass** | Anonymous device registration and one-minute heartbeat observed against the local backend. |
| Location privacy | **Pass** | Tool-granted location permissions revoked; backend device location remains unset. |
| Thermal smoke check | **Pass** | 28 °C before monitoring, 33 °C during charging/screen-off capture, 31 °C after recovery. |
| Event upload | **Pass** | Huawei event `ed64be4c-f2d5-4b3f-972e-20d5630d769a` was acknowledged with `loud_conversation`, 0.704 confidence, two source intervals (26.895 s and 62.895 s), 89.790 s total detected duration, explicit UTC timestamps, and `uncalibrated_estimate`. This uncontrolled ambient run proves transport and structure, not class accuracy. |
| Calibration | **Pending** | Displayed SPL is uncalibrated and must not be treated as validated dB(A). |
| 24 h / 72 h unattended run | **Pending** | Requires persistent HTTPS backend access without ADB/USB tunneling. |

## Test Runs

### Run 1: 15-Minute Sanity Check

| Step | Check | Expected |
|------|-------|----------|
| 1 | App launches | No crash, splash screen visible |
| 2 | Noise meter initializes | SPL value displayed, updates in real-time |
| 3 | Auth/register | Can register or login |
| 4 | Device registration | Device appears in `GET /api/v1/devices/` |
| 5 | Manual capture 5 min | Events accumulate in local storage |
| 6 | Background mode (iOS: lock screen) | Capture continues (check after 2 min) |
| 7 | Foreground restore | App resumes, no data loss |
| 8 | Sync to backend | Events appear in `GET /api/v1/events/` |

### Run 2: 1-Hour Unattended

| Step | Check | Expected |
|------|-------|----------|
| 1 | Start capture, lock device | - |
| 2 | Wait 30 min, check backend | Events arriving |
| 3 | Force-kill app, restart | App recovers, queue not lost |
| 4 | Wait 30 min more | Events arriving after restart |
| 5 | Check heartbeat | `last_heartbeat` updated in device endpoint |

### Run 3: 24-Hour Field Run

| Step | Check | Expected |
|------|-------|----------|
| 1 | Start capture at 09:00 | - |
| 2 | Check at 12:00 | Events flowing, battery > 80% |
| 3 | Check at 18:00 | Events flowing, battery > 40% |
| 4 | Check at 23:00 | Night-time threshold behavior correct |
| 5 | Check at 09:00 next day | 24h complete, no crashes, all events synced |

## Success Criteria

- [ ] No app crashes in 24h
- [ ] No data loss across app restarts
- [ ] >95% of events successfully uploaded
- [ ] Heartbeat updated at least every 15 min
- [ ] Battery drain < 30% in 24h (foreground) or < 15% (background)

## Known Issues

- **Legacy Android renderer**: Huawei EVR-L29 renders a black surface with Impeller. Skia is enabled for Android compatibility; Flutter warns that the opt-out will disappear in a future release, so this needs re-validation before a Flutter upgrade.
- **Field networking**: The current qualification uses an ADB reverse tunnel. A stable private HTTPS endpoint and device authentication are required before untethered deployment.
- **Calibration**: Smartphone SPL and the current simplified A-weighting path are not measurement-grade until reference calibration and DSP validation are complete.
- **Source validation**: The Huawei produces real classifications and source
  intervals, but per-class precision/recall and onset/offset error need a
  labelled, known-duration field matrix before accuracy claims.
- **Lifecycle**: The short process-restart smoke test passed, but reboot recovery and 24 h / 72 h continuity remain unproven.
- **iOS SPM warnings**: 9 plugins don't support Swift Package Manager yet (future Flutter requirement).
