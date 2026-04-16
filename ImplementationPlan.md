# OpenNoiseNet Reactivation Milestone

This file summarizes the active implementation focus for the current software stabilization milestone.

The detailed, canonical project state lives in [docs/current-status.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/current-status.md).

## Goal

Turn the existing codebase into a contributor-ready baseline before starting new feature development.

## Exit Criteria

- one truthful project status document
- one reproducible local setup path
- one supported MVP backend surface
- green core checks for backend, dashboard, landing, and mobile

## Supported MVP Surface

The current milestone supports:

- `/api/v1/auth`
- `/api/v1/devices`
- `/api/v1/events`
- `/api/v1/map`

The following are explicitly unreleased in this milestone:

- `/api/v1/admin`
- `/api/v1/snippets`
- AI workflows
- notification workflows
- hardware and firmware implementation

## Workstreams

### 1. Runtime and Developer Workflow

- standardize Python setup on `uv sync --extra dev`
- make Docker Compose match the documented local ports and env names
- keep event ingestion safe when background services are unavailable

### 2. Dashboard and Landing

- remove unsupported admin exposure from the dashboard
- replace mock or misleading data flows on core pages with live API-backed reads
- keep the landing build offline-safe

### 3. Mobile

- keep the backend integration focused on auth, device registration, and event submission
- remove unsupported backend calls from the active mobile flow
- reduce core analyzer noise in the integration-critical paths

### 4. Documentation

- align README, CONTRIBUTING, and component READMEs with the real repo state
- stop describing the project as concept-only
- stop describing unreleased features as current product behavior

## Verification

### Backend

```bash
cd backend
uv sync --extra dev
uv run pytest -q
```

### Dashboard

```bash
cd frontend
npm ci
npm run type-check
npm run build
```

### Landing

```bash
cd landing
npm install
npm run build
```

### Mobile

```bash
cd mobile
flutter analyze
flutter test
```
