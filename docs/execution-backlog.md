# OpenNoiseNet Execution Backlog

Last updated: 2026-08-17 (verified audit — see [docs/finalization-plan.md](./finalization-plan.md))

## Resolved Since 2026-06-01

- **Android APK build** ("pi-natives Cargo error"): root cause was a stale Android toolchain,
  not pi_natives. Fixed: Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20. `flutter build apk --debug` passes.
- **Backend workflow tests**: 10 stale tests in `test_episode_case_workflow.py` rewritten to the
  current API contract. Suite green: 133 passed, 2 skipped.
- **Frontend type-check**: 2 unused-variable TS errors fixed; `tsc --noEmit` clean.
- **Mobile analyzer**: `unawaited_return_in_try_block` lint fixed; `flutter analyze` clean.
- **Port 8000 in settings reset**: already fixed in commit `ae1ea48`; no occurrence remains.
- **E2E script schema drift**: `scripts/e2e-demo.sh` payloads aligned with current schemas.

## Priority 0: Close The Stabilization Gate

Status: **software ready, real-device field validation pending.**

Remaining:
- Re-run E2E demo against live docker stack (`bash scripts/e2e-demo.sh http://localhost:8100`)
- 24h iOS field run (use `docs/field-test-checklist.md`)
- 24h Android field run (APK now builds)
- Verify: no data loss, heartbeat continuity, upload reliability >95%

## Priority 1: Harden The Existing Pro Slice

1. **Case lifecycle validation**: implement the intended transition matrix (closed → open should
   be rejected); currently `update_case` accepts any status.
2. **Tenant isolation**: extend cross-tenant regression tests to organizations, sites, zones,
   calibration profiles, snippets (cases/episodes/exports already covered).
3. **Episode lifecycle coherence**: verify `open`/`extended`/`closed`/`exported` end-to-end.
4. **Release boundary clarity**: keep Pro features visibly pre-release until hardened.

## Priority 2: Close The Test Gap

- Frontend: zero tests. Add Vitest smoke tests for Devices, Events, Map, Timeline, Episode Inbox,
  Case Detail (Vitest + Testing Library already configured).
- Mobile: one widget test. Add settings/queue/upload/threshold lifecycle tests.

## Priority 3: Prepare Commercial Readiness

- Entitlement boundaries Free/Public vs Pro Site vs Portfolio
- Hosted SaaS assumptions and staging baseline
- Customer admin, support diagnostics, retention visibility, compliance docs
- **Not before** Phase 0 closes and Pro slices are hardened

## Known Issues (remaining)

- **Case transitions unvalidated** — documented in a test with a TODO marker
- **Pydantic V2 deprecation**: class-based `Config` instead of `ConfigDict` (cosmetic)
- **SQLAlchemy 2.0 deprecation**: `as_declarative()` (cosmetic)
- **`datetime.utcnow()` deprecation**: 6 files in services/workers (cosmetic)
- **iOS SPM warnings**: 9 plugins don't support Swift Package Manager yet (future Flutter requirement)

## Explicitly Not Near-Term

- Enterprise API and webhooks
- Dedicated hardware commercialization
- Consultant/municipal reporting packs
- Cloud-default audio workflows
- Consumer/community app mechanics
- Apple Watch / CarPlay / health-app exports