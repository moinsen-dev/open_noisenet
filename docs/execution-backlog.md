# OpenNoiseNet Execution Backlog

Last updated: 2026-06-01

## Recently Advanced (2026-06-01 Housekeeping Pass)

- All components audit: builds, tests, lint verified
- Security patches: Next.js 15.5.18, js-cookie 3.0.8
- Docker: Node 18→22 in frontend Dockerfile, `alembic.ini` created
- Mobile: `build_runner` run, `assets/models/` created, iOS build verified
- E2E demo script: `scripts/e2e-demo.sh` — 10 checks, all green
- Field test checklist: `docs/field-test-checklist.md`
- Landing: Next.js critical CVE resolved

## Priority 0: Close The Stabilization Gate

Status: **Software ready, field validation pending.**

Remaining:
- Fix Android APK build (`pi-natives` Cargo/NDK issue in `mobile/vendor/audio_streamer`)
- 24h iOS field run (use `docs/field-test-checklist.md`)
- 24h Android field run
- Verify: no data loss, heartbeat continuity, upload reliability >95%

## Priority 1: Harden The Existing Pro Slice

The codebase already contains Phase 1-3 Pro domain slices. Hardening needed:

### Tenant and boundary hardening
- Add explicit verification that public surfaces do not leak tenant-bound Pro data
- Strengthen tenant-isolation tests around organizations, sites, zones, episodes, cases, and exports

### Operator workflow hardening
- Audit trail and review history semantics
- Case lifecycle beyond simple `open` creation
- Export fidelity: PDF/CSV/JSON read like real operator artifacts

### Release boundary clarity
- Keep Pro features visibly pre-release until hardened
- Keep docs, UI copy, and API expectations aligned

## Priority 2: Align Mobile With The Pro Domain

- Support organization/site/zone context on the device
- Support policy and calibration context sync
- Preserve stable tenant-safe device identity
- Keep `event_uuid`, lifecycle state, and upload receipts trustworthy
- Connect device health and sync state to the operator workflow

## Priority 3: Prepare Commercial Readiness

- Define entitlement boundaries for `Free/Public`, `Pro Site`, and `Portfolio`
- Prepare hosted SaaS assumptions and staging/runtime baseline
- Add customer admin basics, support diagnostics, retention visibility, and compliance-facing docs

## Known Issues

- **Android build**: `pi-natives` Cargo error prevents APK build. Root cause: vendored `audio_streamer` plugin at `mobile/vendor/audio_streamer/`.
- **Pydantic V2 deprecation**: Backend uses class-based `Config` instead of `ConfigDict` (cosmetic).
- **SQLAlchemy 2.0 deprecation**: `as_declarative()` deprecated (cosmetic).
- **`datetime.utcnow()` deprecation**: Used in `spl_calculation_service.py` (cosmetic, Python 3.13).
- **iOS SPM warnings**: 9 plugins don't support Swift Package Manager yet (future Flutter requirement).
- **Port 8000 in settings reset**: `mobile/lib/features/settings/presentation/pages/settings_page.dart:952` uses port 8000 instead of 8100.

## Explicitly Not Near-Term

- Enterprise API and webhooks
- Dedicated hardware commercialization
- Consultant/municipal reporting packs
- Cloud-default audio workflows
- Consumer/community app mechanics
- Apple Watch / CarPlay
- Health-app exports
