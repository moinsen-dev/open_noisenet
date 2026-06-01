# OpenNoiseNet Restart Plan — June 2026

Last updated: 2026-06-01

## Audit Result (Housekeeping complete)

All four components build, type-check, and test clean after dependency updates:

| Component | Build | Tests | Lint | Security |
|-----------|-------|-------|------|----------|
| Backend (FastAPI/Python) | `uv sync` | 69 passed | deprecation warnings (cosmetic) | clean |
| Frontend (React/Vite) | `vite build` | - | `tsc --noEmit` clean | 8 transitive (vite/eslint old) |
| Landing (Next.js) | `next build` | - | - | 2 false-positive (next internal postcss) |
| Mobile (Flutter) | `pub get` | 1 passed | `flutter analyze` clean | SPM plugin warnings (future) |
| Docker Compose | config valid | - | - | - |

## Gate Status

**Phase 0 (Stabilization Exit) is still open.** The blocker is real-device field validation — the rest of the software stack is stable.

What's done:
- Docker/monitoring baseline hardened
- Backend MVP API surface stable (17 endpoints, 69 tests)
- Frontend dashboard aligned to MVP APIs
- Mobile has heartbeat, queued-event maintenance, sync diagnostics, Pro context resolution
- Pro slices (organizations, sites, zones, episodes, cases, exports) implemented but pre-release
- Landing page production-ready

What remains for gate closure:
1. **Mobile 24h+ field runs** — at least one iPhone, one Android, unattended capture validated
2. **End-to-end demo flow** — `device registration → event upload → server receipt → dashboard visibility` scripted
3. **Docker baseline** — verify `docker compose up --build` still works clean (not tested today)

## Immediate Next Steps (Next 1-2 Sessions)

### Step 1: Docker Compose Smoke Test (15 min)
```bash
docker compose up --build -d
# verify: backend health, dashboard loads, map events visible
docker compose down
```
Fix any drift from the 6-week gap.

### Step 2: Mobile Field Run (parallel, real-device)
- Build mobile to a physical iPhone and Android device
- Run 24h unattended capture
- Verify: queue durability across restarts, upload+ACK, heartbeat visibility in dashboard

### Step 3: E2E Demo Script
Script the canonical demo flow:
```
register device → assign to site/zone → start capture → 
trigger threshold event → verify upload → verify dashboard visibility
```

### Step 4: Close the Gate
Once steps 1-3 pass, declare Phase 0 closed. Update docs. Then:

## After Gate Closure: Phase 1-3 Hardening

The Pro slices already exist in code. The hardening needed:

1. **Tenant isolation tests** — verify public surfaces don't leak Pro data
2. **Case lifecycle completeness** — verify `open → in_review → closed` with audit trail
3. **Export fidelity** — PDF/CSV/JSON read like operator artifacts
4. **Mobile domain alignment** — device carries site/zone/policy context through full lifecycle

## After Hardening: Commercial Readiness

- SaaS entitlement model (Free/Public, Pro Site, Portfolio)
- Hosted staging environment
- Self-serve onboarding for small property customers

## What NOT to Start Yet

- Hardware/firmware — separate track, not on critical path
- AI/ML classification — future work
- Enterprise API/webhooks — after beta
- Consumer/community app mechanics — not Pro track

## Verification Commands (Current Baseline)

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
cp .env.example .env && cp .env.example backend/.env && docker compose config --quiet
```
