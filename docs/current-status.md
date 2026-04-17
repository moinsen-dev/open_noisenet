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

That strategic direction does **not** change the current release-supported MVP surface yet.

## Execution Reality

The repository is currently in a mixed but intentional state:

- the **stabilization gate is still open**
- the repo already contains partial implementation slices from **Phase 1**, **Phase 2**, and **Phase 3**
- those Pro slices should be treated as **pre-release foundations**, not as completed commercial release work

In practice, that means the codebase now contains:

- Pro domain objects such as organizations, sites, zones, policies, and calibration profiles
- server-side episodes, cases, and exports
- an initial operator workflow with episode inbox and case detail pages

But the project is **not yet ready** to call those slices stable, released, or self-serve.

## Supported MVP Surface

The release-supported backend surface for the current milestone is:

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

Implemented in the repo, but still treated as **pre-release Pro surfaces** while the gate remains open:

- `organizations`
- `sites`
- `zones`
- `policies`
- `episodes`
- `cases`
- `exports`

## Current State By Surface

### Recent Execution Progress

- Docker/monitoring baseline was hardened with calmer startup ordering, quieter exporter topology, bounded log rotation, and a stable no-reload backend container path.
- The mobile node now has an active backend heartbeat path tied to sensor runtime, queued-event maintenance, and runtime diagnostics instead of debug-only visibility.
- Device heartbeat data is now visible to operators through backend device models and site-device views, including `last_heartbeat`, `last_seen`, and runtime status metadata.
- The Pro incident slice now includes structured episode review metadata and stronger cross-tenant regression coverage for cases, episodes, and exports.
- Cases now carry operator audit history and explicit lifecycle state changes (`open -> in_review -> closed`) through the API, exports, and operator UI.
- The mobile client now resolves backend-known Pro assignment context into a richer snapshot (`organization -> site -> zone -> calibration profile -> effective policy`) and exposes that context in sync diagnostics.
- The live Docker stack was upgraded to the new `cases` schema and verified end-to-end for `event -> episode -> case -> status transition -> export`.

### Backend

- FastAPI app, auth flow, device registration, event ingestion, and public map endpoints exist.
- Docker Compose, PostgreSQL, Redis, Celery, monitoring, and migrations are present.
- The backend now treats unreleased surfaces as explicit `501 Not Implemented` instead of TODO placeholders.
- The backend also now contains initial Pro-domain and incident-management surfaces for organizations, sites, zones, policies, episodes, cases, and exports, but these are still being hardened.
- Device heartbeats now update operator-visible health fields (`last_seen`, `last_heartbeat`) and persist runtime status metadata for assigned devices.
- Cases now support backend-enforced lifecycle transitions and audit-history persistence, and exports include case summary metrics and operator audit context.

### Dashboard (`frontend/`)

- The React dashboard is now aligned to the supported MVP APIs.
- Home, events, devices, and map pages are intended to read live backend data.
- The unsupported admin route is removed from the main navigation.
- The dashboard also contains an initial operator workflow for Pro setup, episode inbox, and case detail, but that workflow should still be treated as pre-release.
- The case detail flow now exposes operator summary, lifecycle actions, export inventory, and merged case history over the live case API.

### Landing (`landing/`)

- The Next.js landing site is present and production-oriented.
- It is now expected to build without needing network access for Google Fonts.

### Mobile (`mobile/`)

- The Flutter app contains substantial monitoring, storage, and sync infrastructure.
- Backend auth and event submission exist, but the mobile app is still a stabilization target rather than a release candidate.
- The app is being steered toward an unattended sensor-node role and still needs real-device field validation and better alignment with site/zone/policy context.
- The mobile sync path now runs periodic backend maintenance for queued events and device heartbeats, and surfaces assigned site/zone/calibration context when the backend already knows it.
- When authenticated and assigned, the app now also resolves organization and effective policy context from existing Pro backend surfaces for operator-grade sync diagnostics.
- AI-related and advanced analysis paths should be treated as future work, not current MVP functionality.

## Roadmap Context

The canonical commercialization roadmap is [docs/opennoisenet-pro-roadmap.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/opennoisenet-pro-roadmap.md).

Its gating order remains:

1. Stabilization Exit and Commercial Baseline
2. Pro Domain Foundation
3. Episode Engine and Evidence Model
4. Operator Product for Housing / Property
5. Commercial Readiness and Self-Serve Beta
6. Post-Beta Expansion

The current repo already contains partial slices of phases 2-4 in code, but the gating order above still controls release readiness.

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

## Immediate Program After This Status

The active execution summary now lives in [ImplementationPlan.md](/Users/udi/work/moinsen/ideas/open_noisenet/ImplementationPlan.md), and the ordered remaining backlog lives in [docs/execution-backlog.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/execution-backlog.md).

In short, the next agenda is:

1. close the stabilization gate
2. harden the already-implemented Pro slices
3. align the mobile node with tenant/site/zone/policy context
4. then prepare commercial readiness

The deeper mobile/server event reconciliation and on-device AI track remains documented in [docs/plans/2026-04-16-mobile-server-event-lifecycle-and-on-device-ai.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/plans/2026-04-16-mobile-server-event-lifecycle-and-on-device-ai.md).
