# OpenNoiseNet Current Status

Last updated: 2026-08-17 (verified audit + stabilization fixes)

## Verified Situation

Full audit executed on 2026-08-17 from a clean dependency install. See
[docs/finalization-plan.md](./finalization-plan.md) for the complete plan and the fix list.

### Audit Results

| Component | Build | Tests | Lint | Key Fixes |
|-----------|-------|-------|------|-----------|
| Backend | `uv sync` clean | **133 passed, 2 skipped** | deprecation warnings (cosmetic) | 10 stale workflow tests rewritten to the current API contract |
| Frontend | `vite build` clean | 0 tests (gap) | `tsc --noEmit` clean | 2 unused-variable TS errors fixed |
| Landing | `next build` clean | - | - | - |
| Mobile | APK + analyze clean | 1 passed (gap) | `flutter analyze` clean | 1 lint fixed; Android toolchain bumped |
| Docker Compose | config valid (12 services) | - | - | - |

### Android Build: Resolved

The long-standing "pi-natives Cargo error" is gone. The real failure was a stale Android
toolchain vs. Flutter 3.47 minimums. Fixed:

- Gradle 8.12 → **8.14** (`mobile/android/gradle/wrapper/gradle-wrapper.properties`)
- AGP 8.9.1 → **8.11.1** (`mobile/android/settings.gradle.kts`)
- Kotlin 2.1.0 → **2.2.20** (`mobile/android/settings.gradle.kts`)

`flutter build apk --debug` now succeeds (`app-debug.apk`, 206 MB).

### Backend Suite: 133 Tests, Green

The suite grew to 133 tests; 10 tests in `test_episode_case_workflow.py` asserted a superseded
API contract (POST /episodes/, PUT /cases/{id}/transition, export content-type headers) and were
rewritten against the live contract: episodes are created by event ingestion with lifecycle
`closed`/`extended`, review closes episodes, case transitions go through PATCH, exports report
`content_type` in the body, and cross-tenant access is blocked (403).

### E2E Script: Schema Alignment

`scripts/e2e-demo.sh` posted pre-refactor payloads (`peak_db`, `pct_over`, `rule`,
`latitude`/`longitude`) that are silently dropped by the current schemas. Updated to
`lmax_db`, `exceedance_pct`, `rule_triggered`, `location_lat`/`location_lng`, and
`status.capture_active`. Re-run against the docker stack before declaring the gate closed.

## Gate Status

**Phase 0 (Stabilization Exit): software ready, real-device field validation pending.**

| ✅ Done | ⚠️ Pending |
|---------|-----------|
| All components build/test clean | 24h+ field run on a real iOS device |
| Android APK build fixed and verified | 24h+ field run on a real Android device |
| Docker stack config valid (12 services) | E2E demo script re-run against live stack |
| Backend 133 tests green | Frontend/mobile test coverage gap |
| E2E script aligned with current schemas | |
| Field test checklist documented | |

### To Close The Gate

1. Re-run `scripts/e2e-demo.sh` against `docker compose up --build -d`
2. Run 24h field test on one iOS device (`docs/field-test-checklist.md`)
3. Run 24h field test on one Android device (APK now builds)
4. Verify no data loss, heartbeat continuity, upload reliability
5. Record results and update this document

## After Gate Closure: Pro Slice Hardening

1. **Case lifecycle**: implement the intended transition matrix (closed → open currently
   succeeds silently); flip the documenting test to assert enforcement.
2. **Tenant isolation**: extend cross-tenant regression tests to all Pro surfaces.
3. **Export fidelity**: PDF/CSV/JSON already carry review metadata and audit history.
4. **Mobile domain alignment**: device carries site/zone/policy context (implemented; field-validate).
5. **Frontend/mobile tests**: add smoke tests (frontend has zero; mobile has one).
6. **Cosmetic debt**: Pydantic `Config` → `ConfigDict`, `as_declarative()`, `datetime.utcnow()`.

## Verification Commands

```bash
# Backend
cd backend && uv sync --extra dev && uv run pytest -q

# Frontend
cd frontend && npm ci && npx tsc --noEmit && npm run build

# Landing
cd landing && npm install && npm run build

# Mobile
cd mobile && flutter pub get && flutter analyze && flutter test
cd mobile && flutter build apk --debug

# Full stack
docker compose config --quiet

# E2E demo
docker compose up --build -d && bash scripts/e2e-demo.sh http://localhost:8100
```

Expected local ports:
- Backend API: `http://localhost:8100`
- Backend docs: `http://localhost:8100/docs`
- Dashboard: `http://localhost:3100`
- Grafana: `http://localhost:3101` (admin/admin)
- Prometheus: `http://localhost:9190`