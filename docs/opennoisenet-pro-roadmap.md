# OpenNoiseNet Pro Roadmap

Last updated: 2026-04-17

This document is the canonical roadmap for finishing OpenNoiseNet as a commercial product while preserving its public and open-data mission.

It operationalizes the OpenNoiseNet Pro direction on top of the current repo baseline:

- current supported surfaces stay `auth`, `devices`, `events`, and `map`
- the commercial layer is added above that baseline, not by replacing it
- the product remains privacy-first and derived-first by default

## Product Direction

OpenNoiseNet should be finished as a **Hybrid Public + Pro** system:

- **Public layer**: open visibility, map, community-facing narrative, and aggregated public data
- **Pro layer**: tenant-bound operations for housing and property customers, centered on episodes, review, cases, and exports

Commercial defaults for this roadmap:

- primary buyer: **housing / property**
- revenue model: **SaaS per site**
- first commercial target: **self-serve beta**
- first paid workflow: **episodes + case export**
- scope: **software-first**
- field posture: **smartphone-neutral**
- hardware / firmware commercialization: **later track**

## Guardrails

- No commercial release is allowed before the stabilization gate is complete.
- Public and Pro surfaces must stay technically and commercially separate.
- Audio must not become a cloud-default artifact. The default evidence posture stays **derived_only**.
- The first commercial object is the **episode**, not the raw event.
- Enterprise API, partner integrations, and dedicated hardware stay after self-serve beta.

## Execution Reality

The repo already contains initial implementation slices from later phases:

- Pro domain foundation: organizations, sites, zones, policies, calibration profiles
- incident layer: episodes, cases, exports
- operator UI: Pro setup, episode inbox, case detail

Those slices should be treated as **pre-release foundations**.

The ordering below still describes the required gating sequence for release readiness:

- stabilization exit must close first
- later-phase slices must be hardened before self-serve claims
- commercial packaging still comes after the product and runtime are trustworthy

## Delivery Order

### Phase 0: Stabilization Exit and Commercial Baseline

**Goal:** turn the existing system into a trustworthy base for pilots, demos, and early Pro work.

Status: **active, not yet closed**

Core work:

- finish software stabilization as an explicit gate
- make the mobile node viable for unattended capture, queueing, recovery, and server receipt handling
- make Docker, migrations, monitoring, and deployment repeatable and low-drama
- align public web, dashboard, mobile, and docs to one truthful product narrative
- establish one canonical local, demo, and pilot baseline

Exit criteria:

- 72-hour field run without manual intervention on at least one real smartphone per platform class
- stable flow: device registration -> event upload -> server receipt -> dashboard visibility
- no recurring Docker or monitoring misconfiguration alerts
- one documented baseline suitable for demo, staging, and pilot setups

### Phase 1: Pro Domain Foundation

**Goal:** add the commercial domain layer without breaking the current MVP foundation.

Status: **initial slice implemented, hardening still required**

Core work:

- introduce `organization`, `site`, `zone`, `policy`, and `calibration_profile`
- add tenant boundaries and roles for housing / property workflows
- move devices from a global ingest model into site and zone assignment
- separate public aggregation from Pro tenant operations
- add plan / entitlement hooks without full billing implementation

Planned interface additions:

- `/api/v1/organizations`
- `/api/v1/sites`
- `/api/v1/zones`
- `/api/v1/policies`

Exit criteria:

- a customer can create sites and zones and assign devices to them
- data is tenant-isolated
- public endpoints do not expose Pro-only objects or customer data

### Phase 2: Episode Engine and Evidence Model

**Goal:** convert raw device events into the commercial product object.

Status: **initial slice implemented, hardening still required**

Core work:

- lift the `event_uuid` and lifecycle work into an episode layer
- implement candidate -> episode merge, split, close, and review state transitions
- add quiet-hours-aware scoring, nuisance score, and severity
- make episodes the primary reviewable server object
- introduce evidence modes with `derived_only` as the default
- attach cases and exports to episodes instead of raw events

Planned interface additions:

- `/api/v1/episodes`
- `/api/v1/cases`
- `/api/v1/exports`

Expected mobile contract additions:

- `device_id`
- `capture_session_id`
- `event_uuid`
- lifecycle state
- client classification and confidence
- derived-only evidence references, not mandatory cloud audio

Exit criteria:

- a local device event is reconciled into a server episode
- episodes are filterable and reviewable by site and zone
- severity and policy-aware scoring are deterministic and testable

### Phase 3: Operator Product for Housing / Property

**Goal:** deliver the first genuinely payable workflow.

Status: **initial slice implemented, hardening still required**

Core work:

- build a Pro dashboard around episode inbox, site and zone filters, device health, and review state
- implement case creation from one or many episodes
- support notes, review history, and exportable evidence packages
- ship pragmatic export formats first: PDF, CSV, JSON
- keep the public map separate and minimal
- make onboarding self-serve enough for small property customers

Exit criteria:

- a customer can create a site, attach a device, see episodes, open a case, and export evidence without engineering help
- the core workflow does not require direct DB or CLI intervention

### Phase 4: Commercial Readiness and Self-Serve Beta

**Goal:** make the product sellable as a hosted beta.

Status: **not started**

Core work:

- implement entitlements for `Pro Site` and `Portfolio`
- stand up the hosted SaaS operating model
- add basic customer admin, audit trail visibility, retention UI, and support diagnostics
- update legal, privacy, and compliance docs for the Pro layer
- preserve and improve the free public layer with its own scope
- open a self-serve beta for small property portfolios

Commercial packaging:

- **Free / Public**: open visibility, map, community-facing narrative
- **Pro Site**: per site or device, episodes, review, case export
- **Portfolio**: multi-site governance, analytics, richer reporting
- **Enterprise / API**: after beta, not before

Exit criteria:

- a new Pro customer can activate and use the beta without engineering mediation
- entitlements cleanly separate Public and Pro features
- support can inspect customer issues without direct DB access

### Phase 5: Post-Beta Expansion

**Goal:** expand only after the self-serve beta proves the core workflow.

Status: **not started**

Core work:

- deepen quiet-hours alerts and routing
- expand portfolio analytics and recurring-disturbance workflows
- add enterprise API and webhooks
- add consultant and municipal reports later
- start serious hardware and appliance productization only after beta validation

## Testing and Acceptance

### Platform and Field Validation

- device onboarding on both smartphone platforms
- 24-hour, 72-hour, and 7-day duration runs with queue, recovery, and telemetry checks
- offline -> reconnect -> upload -> receipt -> episode creation

### Product Workflow Validation

- create site, zone, device assignment, and policy
- generate episode from event flow
- review and override severity or label
- create case from one or many episodes
- export a coherent PDF, CSV, and JSON package

### Privacy and Boundary Validation

- `derived_only` remains the default evidence mode
- public surfaces do not show tenant-internal or evidence-sensitive data
- audit trail, retention rules, and policy enforcement behave per tenant scope

### Release Gates

- no commercial release before Phase 0 is complete
- no self-serve beta before episode -> case -> export works without developer help
- no enterprise expansion before early Pro usage is validated

## Assumptions

- planning assumes a **small core team** of 1-3 engineers plus founder/product work
- expected horizon is **6-9 months** to a credible self-serve beta
- hosted SaaS is the primary operating model
- self-hosting is not an early target
- hardware and firmware remain out of the first commercial critical path
- the public and open-data mission remains important, but with clear separation from the Pro customer workflow
