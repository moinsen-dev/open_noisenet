# OpenNoiseNet Mobile Field Test Checklist

Last updated: 2026-06-01

## Prerequisites

- [ ] Backend running (`docker compose up -d`, verify `curl http://localhost:8100/health`)
- [ ] iOS device with Runner.app installed (built via `flutter build ios --no-codesign --debug`)
- [ ] Android device with app-debug.apk installed (⚠️ known build issue: `pi-natives` Cargo error — needs investigation)
- [ ] Device has internet connectivity to backend (use `ngrok` or tailscale for remote testing)

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

- **Android build**: `pi-natives` Cargo/NDK error prevents APK build. Needs investigation of `audio_streamer` plugin vendored at `mobile/vendor/audio_streamer/`.
- **iOS SPM warnings**: 9 plugins don't support Swift Package Manager yet (future Flutter requirement).
- **Port 8000 in settings reset**: Settings page uses port 8000 instead of 8100 for reset action.
