# OpenNoiseNet Active Implementation Program

This file summarizes the active execution focus for the repository.

Use it together with:

- [docs/current-status.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/current-status.md) for current repo truth
- [docs/opennoisenet-pro-roadmap.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/opennoisenet-pro-roadmap.md) for the full commercialization roadmap

## Current Phase

The repository is currently executing **Phase 0: Stabilization Exit and Commercial Baseline** from the OpenNoiseNet Pro roadmap.

That means the project is still intentionally grounded on the current supported MVP surface:

- `/api/v1/auth`
- `/api/v1/devices`
- `/api/v1/events`
- `/api/v1/map`

The following remain unreleased until later phases:

- `/api/v1/admin`
- `/api/v1/snippets`
- organizations, sites, zones, policies, episodes, cases, exports
- AI workflows as productized user-facing features
- notification workflows as committed product behavior
- hardware and firmware commercialization

## Phase 0 Goal

Turn the current software stack into a repeatable, field-capable baseline that can safely carry the first Pro domain work.

## Phase 0 Exit Criteria

- one truthful current-status document and one canonical commercialization roadmap
- one reproducible local and Docker baseline for backend, dashboard, landing, and mobile
- stable mobile node behavior for unattended capture, queueing, ACK/receipt, and device health
- stable device registration -> event upload -> server receipt -> dashboard visibility flow
- monitoring and Docker without recurring avoidable misconfiguration alerts

## Active Workstreams

### 1. Runtime, Docker, and Monitoring

- keep Compose, migrations, monitoring, and exporters reproducible
- eliminate recurring false-positive or configuration-driven container alerts
- preserve a clean local/staging baseline for pilots and demos

### 2. Mobile Node Reliability

- keep the smartphone node focused on unattended monitoring, recovery, and sync
- maintain a trustworthy local/server event lifecycle with receipts and diagnostics
- use [docs/plans/2026-04-16-mobile-server-event-lifecycle-and-on-device-ai.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/plans/2026-04-16-mobile-server-event-lifecycle-and-on-device-ai.md) as the node design reference

### 3. Product Narrative Alignment

- align README, current status, and component roadmaps with the Hybrid Public + Pro direction
- keep today’s repo truth separate from future Pro capabilities
- stop presenting old consumer/demo assumptions as the active product plan

### 4. Phase 1 Preparation

- prepare the codebase and docs for the Pro domain foundation
- keep current APIs stable while defining where organizations, sites, zones, and policies will attach
- avoid shipping Pro behavior before tenant boundaries and public/pro separation are designed

## Next Phases After Phase 0

Once the stabilization exit is complete, execution proceeds through the roadmap in this order:

1. Pro Domain Foundation
2. Episode Engine and Evidence Model
3. Operator Product for Housing / Property
4. Commercial Readiness and Self-Serve Beta
5. Post-Beta Expansion

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
