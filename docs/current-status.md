# OpenNoiseNet Current Status

Last updated: 2026-04-17

## What This Repo Is Right Now

OpenNoiseNet is an environmental noise monitoring platform in a software reactivation phase. The repository already contains working backend, web, landing, infrastructure, and mobile code, but the project is not yet in a polished public MVP state.

This phase is focused on stabilizing the software stack so maintainers and contributors can run, verify, and extend it safely.

## Strategic Direction

The repo is now being steered toward **OpenNoiseNet Pro** as a **Hybrid Public + Pro** platform:

- the **public layer** keeps open visibility, map-based access, and community-facing narrative
- the **Pro layer** will add tenant-bound workflows for housing and property operators
- the first commercial object will be the **episode**, not the raw event
- the first commercial workflow will be **episodes + case export**

That strategic direction does **not** change the current supported MVP surface yet. It defines the next ordered program after stabilization.

## Supported MVP Surface

The supported backend surface for the current milestone is:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/devices/register`
- `GET /api/v1/devices/`
- `GET /api/v1/devices/{device_id}`
- `PUT /api/v1/devices/{device_id}`
- `POST /api/v1/devices/{device_id}/heartbeat`
- `POST /api/v1/events/`
- `GET /api/v1/events/`
- `GET /api/v1/events/{event_id}`
- `GET /api/v1/events/stats/`
- `DELETE /api/v1/events/{event_id}`
- `GET /api/v1/map/events`
- `GET /api/v1/map/heatmap`
- `GET /api/v1/map/stats`
- `GET /health`

Intentionally unreleased in this milestone:

- `admin` endpoints
- `snippets` endpoints
- AI classification workflows
- notification workflows
- firmware and hardware deliverables

## Current State By Surface

### Backend

- FastAPI app, auth flow, device registration, event ingestion, and public map endpoints exist.
- Docker Compose, PostgreSQL, Redis, Celery, monitoring, and migrations are present.
- The backend now treats unreleased surfaces as explicit `501 Not Implemented` instead of TODO placeholders.

### Dashboard (`frontend/`)

- The React dashboard is now aligned to the supported MVP APIs.
- Home, events, devices, and map pages are intended to read live backend data.
- The unsupported admin route is removed from the main navigation.

### Landing (`landing/`)

- The Next.js landing site is present and production-oriented.
- It is now expected to build without needing network access for Google Fonts.

### Mobile (`mobile/`)

- The Flutter app contains substantial monitoring, storage, and sync infrastructure.
- Backend auth and event submission exist, but the mobile app is still a stabilization target rather than a release candidate.
- AI-related and advanced analysis paths should be treated as future work, not current MVP functionality.

## Roadmap Context

The canonical commercialization roadmap is [docs/opennoisenet-pro-roadmap.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/opennoisenet-pro-roadmap.md).

Its delivery order is:

1. Stabilization Exit and Commercial Baseline
2. Pro Domain Foundation
3. Episode Engine and Evidence Model
4. Operator Product for Housing / Property
5. Commercial Readiness and Self-Serve Beta
6. Post-Beta Expansion

## Local Development Baseline

### Backend

```bash
cd backend
uv sync --extra dev
uv run pytest -q
uv run uvicorn app.main:app --reload --port 8100
```

### Dashboard

```bash
cd frontend
npm ci
npm run type-check
npm run dev
```

### Landing

```bash
cd landing
npm install
npm run build
npm run dev
```

### Mobile

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

### Full Stack

```bash
docker compose up --build
```

Expected local ports:

- Backend API: `http://localhost:8100`
- Backend docs: `http://localhost:8100/docs`
- Dashboard: `http://localhost:3100`

## Next Milestone After Stabilization

Once this baseline is green, execution should move into **Phase 1: Pro Domain Foundation** from the OpenNoiseNet Pro roadmap.

That phase introduces:

- organizations
- sites
- zones
- policies
- calibration profiles
- public/pro separation rules

The deeper mobile/server event reconciliation and on-device AI track remains documented in [docs/plans/2026-04-16-mobile-server-event-lifecycle-and-on-device-ai.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/plans/2026-04-16-mobile-server-event-lifecycle-and-on-device-ai.md).
