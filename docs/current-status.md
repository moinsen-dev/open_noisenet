# OpenNoiseNet Current Status

Last updated: 2026-06-01 (housekeeping + restart pass)

## What Changed Today

Full audit and housekeeping completed. All four components build, type-check, and test clean. The software stabilization gate is ready to close — pending only real-device mobile field validation.

### Audit Results

| Component | Build | Tests | Lint | Key Fixes |
|-----------|-------|-------|------|-----------|
| Backend | `uv sync` | 69 passed | deprecation warnings (cosmetic) | `.env` created, `alembic.ini` created |
| Frontend | `vite build` | - | `tsc --noEmit` clean | Dockerfile Node 18→22, browserslist updated |
| Landing | `next build` | - | - | Next.js 15.5.2→15.5.18 (critical CVE), js-cookie updated |
| Mobile | `pub get` | 1 passed | `flutter analyze` clean | `build_runner` run, `assets/models/` created |

### Docker Stack

- All 12 containers build and run healthy (`docker compose up --build`)
- E2E flow verified: `register user → register device → submit event → server receipt → event list → heartbeat → map stats → dashboard`
- E2E demo script: `scripts/e2e-demo.sh` — 10 checks, all green

### Mobile

- iOS build succeeds for physical device (`flutter build ios --no-codesign --debug`)
- Android build has pre-existing `pi-natives` Cargo/NDK issue in vendored `audio_streamer` plugin
- Field test checklist documented: `docs/field-test-checklist.md`

## Gate Status

**Phase 0 (Stabilization Exit): Software ready, field validation pending.**

| ✅ Done | ⚠️ Pending |
|---------|-----------|
| All components build/test clean | Android APK build fix (pi-natives) |
| Docker stack healthy (12 containers) | iOS 24h field run |
| E2E flow scripted + verified | Android 24h field run |
| Security patches applied (Next.js CVE) | |
| Mobile iOS build verified | |
| Field test checklist documented | |

### To Close The Gate

1. Fix Android APK build (`pi-natives` Cargo error in `mobile/vendor/audio_streamer`)
2. Run 24h field test on one iOS device (use `docs/field-test-checklist.md`)
3. Run 24h field test on one Android device
4. Verify no data loss, heartbeat continuity, upload reliability

## Next Phase: Pro Slice Hardening

Once the gate closes, the already-implemented Pro slices need hardening before commercial readiness:

### Priority 1: Tenant Isolation
- Verify public endpoints don't leak Pro tenant data
- Cross-tenant regression tests for organizations, sites, zones, episodes, cases, exports

### Priority 2: Case Lifecycle Completeness
- Verify `open → in_review → closed` transitions
- Audit trail persistence across all state changes
- Export fidelity (PDF/CSV/JSON read like operator artifacts)

### Priority 3: Mobile Domain Alignment
- Device carries site/zone/policy context through full lifecycle
- Event lifecycle observable from mobile through server to operator dashboard

## Verification Commands

```bash
# Backend
cd backend && uv sync --extra dev && uv run pytest -q

# Frontend  
cd frontend && npm ci && npx tsc --noEmit && npm run build

# Landing
cd landing && npm install && npm run build

# Mobile
cd mobile && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test

# Full stack
docker compose up --build -d

# E2E demo
bash scripts/e2e-demo.sh
```

Expected local ports:
- Backend API: `http://localhost:8100`
- Backend docs: `http://localhost:8100/docs`
- Dashboard: `http://localhost:3100`
- Grafana: `http://localhost:3101` (admin/admin)
- Prometheus: `http://localhost:9190`
