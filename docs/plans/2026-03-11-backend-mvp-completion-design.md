# Backend MVP Completion + Frontend Integration

**Date:** 2026-03-11
**Status:** Approved

## Goal

Bring the backend to 100% MVP, activate the worker pipeline, and ensure Mobile (Flutter) + Frontend (React) can consume the API.

## Decisions

- **Auth:** Device API-Keys + User JWT (Email/Password). Map endpoints are public read-only.
- **Workers:** Aggregation + Maintenance + Realtime Processing (SPL + Threshold). No AI, no notifications.
- **Frontend Integration:** Adapt client service layers in Flutter + React (no UI changes).
- **Tests:** Backend unit + integration tests with real PostgreSQL via Docker.

## Current State

### Critical Blockers (Backend won't start)
1. `get_logger()` missing in `app/core/logging.py` — all services import it
2. `NoiseEvent` model referenced in `ThresholdDetectionService` and `GeospatialService` — model is actually `Event`

### What Works (after bugfixes)
- Device registration + heartbeat (~90%)
- Event ingestion + SPL storage (~95%)
- SPL Calculation Service (IEC 61672-1 compliant)
- DB Schema + Migration (8 tables, complete)
- Docker + Config

### What's Missing
- Map API endpoints (GeospatialService exists but not exposed)
- Auth endpoints (JWT + API-Key, only stubs)
- Audio snippet endpoints (model exists, no API)
- Tests (0% — empty /tests directory)
- Worker task implementations (framework only)

## Team

| Role | Responsibility |
|---|---|
| **Team Lead** | Coordinate, define API contract, review |
| **Backend Specialist** | Fix blockers, implement auth, map endpoints, worker integration |
| **Tester** | pytest setup, service unit tests, DB+API integration tests |
| **Frontend Specialist** | Adapt React + Flutter API client services |

## Execution Phases

### Phase 1: Fix Blockers (Backend)
- Implement `get_logger()` in `app/core/logging.py`
- Fix `NoiseEvent` → `Event` references in services
- Verify backend starts without import errors

### Phase 2: API Contract (Team Lead)
- Define OpenAPI schema for all MVP endpoints
- Document request/response formats, auth headers, error codes
- This contract is the reference for all subsequent work

### Phase 3 (Parallel)
- **Backend:** Implement JWT auth (login, register, refresh, middleware)
- **Backend:** Implement Device API-Key auth (generate, validate, middleware)
- **Backend:** Wire GeospatialService into map endpoints (events GeoJSON, heatmap, stats)
- **Backend:** Wire SPL + Threshold services into event ingestion pipeline
- **Backend:** Implement realtime + aggregation worker tasks
- **Tester:** Set up pytest with fixtures, conftest, factory-boy or similar
- **Tester:** Write unit tests for SPLCalculationService, ThresholdDetectionService, GeospatialService

### Phase 4 (Parallel, after Phase 3)
- **Tester:** Integration tests against real PostgreSQL (device CRUD, event lifecycle, auth flow)
- **Tester:** API endpoint tests with TestClient
- **Frontend Specialist:** Update React API client services for new endpoints + auth headers
- **Frontend Specialist:** Update Flutter API client services for new endpoints + auth headers

### Phase 5: Verification
- Docker-Compose up (backend + PostgreSQL + Redis)
- Run full integration test suite
- Smoke test: verify Mobile + Frontend service layers compile and make valid requests

## Out of Scope
- UI changes (neither Flutter nor React)
- AI/ML processing
- Notification system (email, push)
- Admin panel
- Audio snippet encryption
- Deployment/CI/CD
- Firmware/hardware

## Key Files

### Backend
- `backend/app/core/logging.py` — fix get_logger
- `backend/app/core/config.py` — configuration
- `backend/app/main.py` — app setup
- `backend/app/db/models/` — device.py, event.py, snippet.py, user.py
- `backend/app/schemas/` — device.py, event.py
- `backend/app/services/` — spl_calculation, threshold_detection, geospatial
- `backend/app/api/v1/endpoints/` — all endpoint files
- `backend/app/workers/` — celery tasks

### Frontend (React)
- `frontend/src/services/` — API client services
- `frontend/src/hooks/` — data fetching hooks

### Mobile (Flutter)
- `mobile/lib/services/api_client_service.dart` — API client
- `mobile/lib/services/backend_sync_service.dart` — backend sync
- `mobile/lib/core/models/api_models.dart` — API response models
- `mobile/lib/core/config/app_config.dart` — config with base URL
