# OpenNoiseNet Active Execution Program

This file summarizes the active execution focus for the repository.

Use it together with:

- [docs/current-status.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/current-status.md) for current repo truth
- [docs/opennoisenet-pro-roadmap.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/opennoisenet-pro-roadmap.md) for the full commercialization roadmap
- [docs/execution-backlog.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/execution-backlog.md) for the ordered remaining work

## Execution Reality

The repository is no longer a pure `Phase 0 only` codebase.

It now contains:

- stabilization work across backend, dashboard, landing, mobile, Docker, and monitoring
- initial **Phase 1** slices for `organizations`, `sites`, `zones`, `policies`, and `calibration_profiles`
- initial **Phase 2** slices for `episodes`, `cases`, and `exports`
- an initial **Phase 3** operator workflow with episode inbox and case detail UI

Those later-phase slices are **implemented but not yet release-ready**. They do not waive the stabilization gate.

## Active Gate

The active gate remains **Phase 0: Stabilization Exit and Commercial Baseline**.

That gate must close before:

- any commercial release
- any self-serve beta claim
- any pilot commitment that depends on unattended field reliability

## Release-Supported Surface Today

The current release-supported software surface is still:

- `/api/v1/auth`
- `/api/v1/devices`
- `/api/v1/events`
- `/api/v1/map`

The following Pro surfaces now exist in the repo, but should still be treated as **pre-release implementation** rather than stable public contract:

- `/api/v1/organizations`
- `/api/v1/sites`
- `/api/v1/zones`
- `/api/v1/policies`
- `/api/v1/episodes`
- `/api/v1/cases`
- `/api/v1/exports`

Still intentionally unreleased:

- `/api/v1/admin`
- `/api/v1/snippets`
- AI classification as a committed end-user product feature
- notification workflows as committed product behavior
- hardware and firmware commercialization

## Immediate Workstreams

### 1. Stabilization Gate Closure

- finish unattended mobile-node reliability work
- complete real-device 24h and 72h validation
- keep Docker, monitoring, exporters, and migrations quiet and reproducible
- preserve one repeatable local/demo/pilot baseline

Recent progress in this workstream:

- backend/device health is now propagated through heartbeats into operator-visible device fields
- the mobile node now performs periodic queued-event maintenance and runtime heartbeats instead of relying only on manual debug sync
- the Docker stack now runs the backend without container reload churn and with quieter monitoring/exporter behavior
- the live stack now carries the updated `cases` schema and has been smoke-tested through `event -> episode -> case -> status transition -> export`

### 2. Existing Pro Slice Hardening

- harden tenant isolation and public/pro separation
- harden case lifecycle, review history, and export quality
- remove any remaining gap between implemented Pro flow and documented release boundaries

Recent progress in this workstream:

- episode review now persists structured `review_metadata`
- JSON exports carry the same review metadata as the operator review flow
- cross-tenant regression coverage now explicitly blocks foreign access to case detail, episode listing, and export content
- cases now persist audit history and explicit lifecycle transitions (`open`, `in_review`, `closed`)
- case detail UI now uses the live case lifecycle contract instead of placeholder-only transition affordances
- JSON/CSV/PDF exports now include case summary metrics and operator audit context

### 3. Mobile Node Alignment With Pro Domain

- prepare the device for tenant/site/zone/policy context
- preserve trustworthy event lifecycle and server reconciliation
- connect device health and sync visibility into the operator workflow

Recent progress in this workstream:

- the mobile sync layer now exposes assigned `site`, `zone`, and `calibration_profile` context when the backend has already assigned the device
- event submissions now include device-context and sensor-runtime metadata for downstream reconciliation
- the mobile node now resolves organization and effective policy context from existing Pro surfaces when authenticated and assigned
- Pro-context snapshots are now visible in sync diagnostics and included in heartbeat/runtime metadata

### 4. Commercial Readiness Preparation

- keep Phase 4 design visible, but do not start billing or self-serve claims prematurely
- prepare entitlement hooks, support diagnostics, retention visibility, and hosted-SaaS assumptions only after the gate is closeable

## Ordered Agenda

Execution should now proceed in this order:

1. Close the Phase 0 stabilization gate.
2. Harden the already-built Phase 1-3 slices to pilot quality.
3. Prepare Phase 4 commercial readiness work.
4. Keep Phase 5 expansion out of the near-term critical path.

The detailed ordered backlog lives in [docs/execution-backlog.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/execution-backlog.md).

## Verification Baseline

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
