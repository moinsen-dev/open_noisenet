# OpenNoiseNet

OpenNoiseNet is an open-source environmental noise monitoring platform for community-operated sensors, public event ingestion, and map-based visibility into noise pollution.

This repository is currently in a software stabilization milestone. The codebase is real and substantial, but it is not yet a polished public MVP. The current goal is to make the existing backend, dashboard, landing site, and mobile app contributor-ready and internally consistent before new feature work starts.

## Current Status

The canonical status document is [docs/current-status.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/current-status.md).

Use that document for:

- the supported MVP backend surface
- what is intentionally unreleased
- the current local development baseline
- the next milestone after stabilization

## Repository Layout

```text
backend/        FastAPI API, models, workers, tests, migrations
frontend/       React dashboard for events, devices, and map views
landing/        Next.js public-facing landing site
mobile/         Flutter mobile client and local monitoring stack
infrastructure/ Nginx, Postgres init, monitoring, deployment examples
docs/           Current status and planning notes
scripts/        Local setup and migration helpers
```

## Supported MVP Surface

The current software milestone supports:

- user authentication
- device registration and heartbeat
- event ingestion and listing
- public map data endpoints

Explicitly not part of the current MVP release:

- admin APIs
- audio snippet APIs
- AI classification workflows
- notification workflows
- firmware and hardware deliverables

## Quick Start

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

Default local URLs:

- Backend API: `http://localhost:8100`
- Backend docs: `http://localhost:8100/docs`
- Dashboard: `http://localhost:3100`

## Contributing

Contributor guidance lives in [CONTRIBUTING.md](/Users/udi/work/moinsen/ideas/open_noisenet/CONTRIBUTING.md).

The short version:

- stabilize before extending
- work against the supported MVP surface
- prefer `uv` for Python dependency and command execution
- keep docs aligned with the actual repo state

## Planning Context

The reactivation milestone summary lives in [ImplementationPlan.md](/Users/udi/work/moinsen/ideas/open_noisenet/ImplementationPlan.md). Historical planning documents remain under `docs/plans/` for reference, but they should not override the current status document.
