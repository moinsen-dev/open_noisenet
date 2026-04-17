# OpenNoiseNet Execution Backlog

Last updated: 2026-04-17

## Recently Advanced

Completed or materially advanced in the latest execution pass:

- `Priority 0 / Docker and monitoring baseline`
  - calmer Compose dependency behavior
  - stable backend container command without reload churn
  - bounded monitoring/proxy log growth
  - exporter topology verified against the live stack
- `Priority 0 / Mobile field reliability`
  - periodic backend maintenance loop for queued events
  - sensor-runtime heartbeats tied to actual device diagnostics
  - runtime heartbeat status visible in the debug surface
- `Priority 1 / Tenant and boundary hardening`
  - structured episode review metadata
  - JSON export carries review audit metadata
  - cross-tenant regression tests for case/episode/export access
- `Priority 1 / Operator workflow hardening`
  - cases now carry audit history and explicit lifecycle transitions
  - JSON/CSV/PDF exports now include case summary metrics and operator audit context
  - live Docker flow verified through `event -> episode -> case -> in_review -> export -> closed`
- `Priority 2 / Episode-ready reconciliation`
  - event submissions now carry device-context and runtime metadata
  - operator-visible device health now updates through heartbeats
- `Priority 2 / Domain alignment`
  - the mobile client now resolves backend-known `organization`, `site`, `zone`, `calibration_profile`, and effective policy context
  - Pro-context snapshots are now surfaced in sync diagnostics for operator troubleshooting

This file is the compact ordered backlog for the remaining work after the first Pro slices landed in the repo.

It assumes:

- the stabilization gate is still open
- partial Phase 1-3 slices already exist
- no commercial release is allowed until the gate is explicitly closed

## Priority 0: Close The Stabilization Gate

This is the hard prerequisite for pilots, demos with confidence, and any commercial posture.

### Mobile field reliability

- complete real-device 24h and 72h runs on at least one iPhone-class and one Android-class device
- verify unattended capture, restart recovery, queue durability, upload, ACK, and health diagnostics
- eliminate remaining runtime issues that threaten long-running sensor-node behavior

### Docker and monitoring baseline

- stop recurring container alerts caused by configuration drift, exporter reconnect noise, or startup mismatches
- keep clean-room `docker compose up --build` reproducible
- keep migrations, health checks, monitoring, and exporters aligned with the live stack

### End-to-end baseline

- preserve one deterministic flow:
  `device registration -> event upload -> server receipt -> episode creation -> dashboard visibility`
- keep this flow scripted or documented tightly enough for demos and pilot setup

## Priority 1: Harden The Existing Pro Slice

The codebase already contains the first commercial vertical slice. It now needs pilot-grade hardening.

### Tenant and boundary hardening

- add explicit verification that public surfaces do not leak tenant-bound Pro data
- strengthen tenant-isolation tests around organizations, sites, zones, episodes, cases, and exports

### Operator workflow hardening

- add proper audit trail and review history semantics
- tighten case lifecycle beyond simple `open` creation
- improve export fidelity so PDF/CSV/JSON read like real operator artifacts, not just technical dumps

### Release boundary clarity

- keep Pro features visibly pre-release until the stabilization gate is closed
- keep docs, UI copy, and API expectations aligned with that reality

## Priority 2: Align Mobile With The Pro Domain

The mobile node must stop behaving like a global-only ingest client and start fitting the Pro model without violating privacy posture.

### Domain alignment

- support organization/site/zone context on the device
- support policy and calibration context sync
- preserve stable tenant-safe device identity

### Episode-ready reconciliation

- keep `event_uuid`, lifecycle state, and upload receipts trustworthy
- expose enough metadata for the server to reconcile into episodes deterministically
- connect device health and sync state to the operator workflow

## Priority 3: Prepare Commercial Readiness

Only start this once Priority 0 is credibly close to done.

### SaaS foundations

- define entitlement boundaries for `Free/Public`, `Pro Site`, and `Portfolio`
- prepare hosted SaaS assumptions and staging/runtime baseline

### Operational surfaces

- add customer admin basics, support diagnostics, retention visibility, and compliance-facing docs
- make support troubleshooting possible without direct DB access

## Explicitly Not Near-Term

These stay out of the near-term critical path:

- enterprise API and webhooks
- dedicated hardware commercialization
- consultant/municipal reporting packs
- cloud-default audio workflows
- consumer/community app mechanics

## Exit Condition For This Backlog

This backlog is considered complete when:

- the stabilization gate is explicitly closed
- the existing Pro slice is hardened enough for pilot use
- the team can move into `Commercial Readiness and Self-Serve Beta` without relying on developer-only workflows
