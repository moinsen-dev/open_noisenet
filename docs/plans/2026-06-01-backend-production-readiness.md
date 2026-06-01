# Backend Production-Readiness Plan

**Date:** 2026-06-01
**Current:** 69 tests, 65% coverage
**Target:** Production-ready backend (estimated ~90% meaningful coverage)

## Phase 0: Foundation (1 Session)

Fix the test infrastructure so we can write fast, reliable tests.

### T0.1: Fix DB session in tests
- Current: `test_events_api.py` uses `app.deps.get_db` override — fragile
- Fix: Standardize on a single conftest fixture that creates/destroys tables per test module
- Why first: Every subsequent test depends on this being solid

### T0.2: Add test factories
- Create `tests/factories.py` with `create_user()`, `create_device()`, `create_event()`, `create_org()`
- Use these in all tests — removes boilerplate, makes tests readable
- ~30 min, pays back immediately

## Phase 1: Core Security Hardening (1 Session)

These are the "if broken, users notice" endpoints.

### T1.1: Auth — Token Refresh + Error Cases
**File:** `tests/test_auth.py` (extend)
- Test: refresh with valid token → new access token
- Test: refresh with expired token → 401
- Test: refresh with tampered token → 401
- Test: register with duplicate email → 409
- Test: login with wrong password → 401

### T1.2: Auth — Rate Limiting
**File:** `app/api/v1/endpoints/auth.py` (add), `tests/test_auth.py`
- Add: 5 login attempts per IP per minute → 429
- Test: rapid-fire login attempts → rate limited
- Why: No brute-force protection currently

### T1.3: Device — Full CRUD + Ownership
**File:** `tests/test_devices_api.py` (extend)
- Test: update device name/firmware → 200
- Test: update device belonging to another user → 403
- Test: delete device → 204, list no longer contains it
- Test: heartbeat updates last_seen timestamp
- Test: list devices filters by user ownership

## Phase 2: Event Pipeline Hardening (1 Session)

The core value proposition — events must be reliable.

### T2.1: Event — Full CRUD
**File:** `tests/test_events_api.py` (extend)
- Test: update event metadata → 200
- Test: delete event → 204
- Test: get non-existent event → 404
- Test: create event with invalid leq_db (>194dB) → 422
- Test: create event with future timestamp → 422

### T2.2: Event — Search + Filtering
- Test: filter by device_id → only that device's events
- Test: filter by timestamp range → correct subset
- Test: filter by leq_db range → correct subset
- Test: pagination (offset/limit) → correct page
- Test: sort by timestamp desc → correct order

### T2.3: Event — Duplicate Idempotency
**File:** `app/api/v1/endpoints/events.py` (check)
- Test: submit same event_uuid twice → 200 (idempotent), not 409
- Test: second submission returns same server_event_id

## Phase 3: Map API Completeness (1 Session)

### T3.1: Map — GeoJSON Completeness
**File:** `tests/test_map.py` (extend)
- Test: events with location → appear as Features with geometry
- Test: events without location → excluded from GeoJSON
- Test: bbox filter → only events in bounding box
- Test: time window filter → only recent events

### T3.2: Map — Stats Correctness
- Test: stats reflect actual event counts
- Test: avg_leq_db computed correctly (create 3 events, verify average)
- Test: events_24h counts only recent events

### T3.3: Map — Heatmap Endpoint
**File:** `app/services/geospatial_service.py` + `tests/test_map.py`
- Test: heatmap returns grid cells with intensity values
- Test: empty dataset → empty grid (not 500)

## Phase 4: Pro Domain — Tenant Isolation (2 Sessions)

This is the biggest gap. Pro features are implemented but untested. Tenant isolation is the #1 production concern.

### T4.1: Organization CRUD + Membership
**File:** `tests/test_pro_domain_api.py` (extend)
- Test: create org → 201, user is owner
- Test: list orgs → only orgs user belongs to
- Test: get org belonging to another user → 404 (not 403 — don't leak existence)
- Test: add member to org → 200
- Test: remove member → 200
- Test: non-member cannot see org members

### T4.2: Site CRUD + Device Assignment
- Test: create site in org → 201
- Test: assign device to site → 200, device.site_id updated
- Test: list sites → only sites in user's orgs
- Test: site in another org → 404

### T4.3: Zone CRUD + Policy Binding
- Test: create zone in site → 201
- Test: assign policy to zone → zone references policy
- Test: zone in another org → 404

### T4.4: Policy CRUD + Threshold Rules
- Test: create policy with day/night thresholds → 201
- Test: policy with invalid threshold (>194dB) → 422
- Test: list policies for org → only that org's policies

### T4.5: Calibration Profile CRUD
- Test: create profile → 201
- Test: assign profile to device → device.calibration_profile_id updated
- Test: cross-org access → 404

## Phase 5: Pro Incidents — Lifecycle Completeness (2 Sessions)

### T5.1: Episode Lifecycle
**File:** `tests/test_episode_case_workflow.py` (extend)
- Test: create episode → 201, status=open
- Test: add events to episode → event.episode_id updated
- Test: close episode → status=closed, closed_at set
- Test: reopen episode → status=open, closed_at cleared
- Test: merge two episodes → events consolidated, old episode archived
- Test: auto-close episode after inactivity → status=auto_closed

### T5.2: Case Lifecycle
- Test: create case from episode → 201, references episode
- Test: case transitions: open → in_review → closed
- Test: invalid transition (closed → open) → 422
- Test: case audit trail records who changed what when
- Test: case links to episodes, events, exports

### T5.3: Export Fidelity
- Test: export case as PDF → valid PDF with all sections
- Test: export case as CSV → valid CSV with correct columns
- Test: export case as JSON → valid JSON matching schema
- Test: export includes events, episodes, timeline
- Test: empty case export → valid minimal document (not error)

## Phase 6: Services — Edge Cases (1 Session)

### T6.1: Threshold Detection — Day/Night Rules
**File:** `tests/test_services.py` (extend)
- Test: daytime (06:00-22:00) → day threshold applies
- Test: nighttime (22:00-06:00) → night threshold applies
- Test: exactly at boundary (22:00:00) → night threshold
- Test: multi-threshold policy → correct rule selected

### T6.2: SPL Calculation — Edge Cases
- Test: negative dB values (below reference) → handled correctly
- Test: very short sample (< 1s) → Leq still computed
- Test: zero samples → returns 0, not error

### T6.3: Geospatial — Reverse Geocoding
**File:** `tests/test_services.py` (add)
- Test: known coordinates → returns location string
- Test: null island (0,0) → handled gracefully
- Test: invalid coordinates (lat > 90) → error, not crash

## Phase 7: Workers + Integration (1 Session)

### T7.1: Worker Task Execution
**File:** `tests/test_workers.py` (extend)
- Test: noise_processing task processes event → classification updated
- Test: aggregation task computes hourly stats → stats table populated
- Test: maintenance task cleans old audio → snippets older than 7d deleted
- Test: worker retries on transient DB error → eventually succeeds

### T7.2: End-to-End Integration
- Test: register → create org → create site → assign device → submit event → event auto-classified → episode created → case opened → exported
- This is ONE test that verifies the full Pro workflow end-to-end

## Phase 8: Production Hardening (1 Session)

### T8.1: Error Handling Consistency
- Audit all endpoints: do they return `{"detail": "..."}` on errors? Or HTML traces?
- Fix: consistent JSON error responses everywhere
- Test: every endpoint returns JSON, never HTML

### T8.2: CORS + Security Headers
- Verify CORS allows frontend origin only
- Add: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`
- Test: OPTIONS preflight returns correct headers

### T8.3: Health Check Depth
**File:** `app/api/v1/endpoints/admin.py` (extend)
- Current: `/health` returns `{"status": "healthy"}` (static)
- Add: DB ping check, Redis ping check
- Test: health fails when DB down → 503

---

## Summary

| Phase | Sessions | Tests Added (est.) | Coverage Gain |
|-------|----------|-------------------|---------------|
| 0: Foundation | 1 | 0 (infrastructure) | - |
| 1: Core Security | 1 | ~15 | 55%→65% |
| 2: Event Pipeline | 1 | ~15 | 46%→60% |
| 3: Map API | 1 | ~10 | 60%→75% |
| 4: Pro Tenant | 2 | ~35 | 34%→70% |
| 5: Pro Lifecycle | 2 | ~25 | 45%→75% |
| 6: Service Edge | 1 | ~15 | 64%→80% |
| 7: Worker+E2E | 1 | ~10 | +integration |
| 8: Hardening | 1 | ~5 | +security |

**Total:** ~10 sessions, ~130 new tests, coverage 65%→~85%

The plan is ordered by risk: first what's user-facing and security-critical, then what's feature-complete but untested, finally hardening. Each phase is independently shippable — you can deploy after any phase and the backend is strictly better than before.
