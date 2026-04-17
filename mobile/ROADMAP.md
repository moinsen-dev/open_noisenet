# OpenNoiseNet Mobile Node Roadmap

This roadmap aligns the mobile app with the wider **OpenNoiseNet Pro** direction.

The mobile product is not being treated as a consumer novelty app. It is being treated as a **field node** for a Hybrid Public + Pro system:

- unattended and privacy-first by default
- derived-first uploads
- stable event lifecycle and sync visibility
- smartphone-neutral at product level
- operator value comes from backend episodes, cases, and exports

The canonical product roadmap lives in [../docs/opennoisenet-pro-roadmap.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/opennoisenet-pro-roadmap.md).

## Current Repo Reality

The mobile app already contains substantial monitoring and sync infrastructure:

- real-time monitoring and SPL visualization
- local storage and preferences
- calibration support
- event lifecycle and sync diagnostics
- backend auth, device registration, and event submission
- continuous recording and background-service scaffolding

It is **not** yet a release-ready unattended field node. The remaining work is about runtime stability, field validation, server reconciliation, and alignment with the commercial episode model.

## Guiding Principles

- Treat the phone as a sensor node first and a UI surface second.
- Keep raw audio out of the cloud default path.
- Separate low-level local detections from reportable events.
- Make every reportable event observable across local creation, queueing, upload, ACK, and later episode creation.
- Favor long-running reliability over demo affordances or consumer extras.

## Phase 0: Stabilization Exit

**Goal:** make the mobile node field-capable enough to support the broader commercial baseline.

Core work:

- unattended capture, recovery, and queue handling
- ACK/receipt visibility and device health diagnostics
- background and lock-screen behavior hardening where the platform allows it
- 24-hour and 72-hour real-device validation on both platform classes
- stable device registration -> event upload -> server receipt behavior

Deliverable:

- a field-testable smartphone node suitable for demos, pilots, and Phase 1 backend work

## Phase 1: Pro Domain Alignment

**Goal:** make the node understand the first commercial domain layer.

Core work:

- support assignment to organization, site, and zone context
- support calibration profile sync and local application
- carry tenant-safe device identity and policy references
- stay compatible with the current MVP event APIs while preparing for Pro domain APIs

Deliverable:

- a node that can be placed inside a tenant, site, and zone model without changing the derived-first capture contract

## Phase 2: Episode-Ready Node

**Goal:** feed the server enough structure to construct trustworthy episodes.

Core work:

- refine local candidate vs reportable-event semantics
- preserve stable `event_uuid`, `capture_session_id`, and lifecycle history
- ship reportability, classification, and confidence hints cleanly
- attach derived-only evidence references where policy allows
- keep no mandatory cloud-audio path in the default flow

Deliverable:

- a node whose uploads can be reconciled into server-side episodes without guesswork

## Phase 3: Operator Workflow Support

**Goal:** support the first paid housing/property workflow.

Core work:

- expose the metadata needed for review queues, site and zone filters, and case creation
- support review-safe identifiers and exportable evidence references
- improve diagnostics so support and operators can distinguish local, queued, uploaded, acknowledged, and server-episode states

Deliverable:

- a node that cleanly participates in `episode -> case -> export` workflows

## Phase 4: Field and Fleet Readiness

**Goal:** make the node viable for early paid pilots and self-serve beta.

Core work:

- 7-day and longer field runs
- battery and restart telemetry
- better fleet diagnostics and support tooling
- release packaging and onboarding for small customer deployments

Deliverable:

- a mobile node ready for small property portfolio beta use

## Non-Goals for the Mobile Track

These are explicitly not part of the near-term critical path:

- Apple Watch
- CarPlay
- consumer social or community app mechanics
- health-app exports
- cloud-first audio workflows
- hardware appliance productization

## Success Metrics

### Runtime and Sync

- stable unattended operation in field tests
- high success rate for upload and ACK when online
- clear diagnostics for stalled capture, queue backlog, and sync failure

### Product Readiness

- devices can be assigned to tenant/site/zone context
- uploaded events reconcile into server-side episodes
- operator workflows can trust device identity, timing, and policy context

### Privacy and Compliance

- derived-only remains the default
- evidence behavior is governed by policy, not ad hoc UI actions
- retention and consent behavior stay auditable

## Immediate Priorities

1. Finish stabilization exit items for unattended operation and 72-hour field validation.
2. Keep the mobile/server event lifecycle observable and trustworthy.
3. Prepare the node for site/zone/policy context instead of global-only ingest.
4. Support the future episode model without breaking the current MVP contract.
