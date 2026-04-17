# Mobile/Server Event Lifecycle And On-Device AI Design

**Date:** 2026-04-16
**Status:** Proposed

## Goal

Define the next implementation track after software stabilization so that:

- the mobile app and backend share one trustworthy event lifecycle
- maintainers can see what happened on-device vs what reached the server
- on-device event detection is segmented and classified in a way that supports real environmental monitoring
- future AI work stays privacy-first and offline-capable by default

## Why This Track Exists

The current mobile stack has enough functionality to capture sound levels, store local events, and submit supported event payloads to the backend. It does not yet provide a single, observable lifecycle that answers these questions reliably:

- Was an event only detected locally, or was it uploaded?
- Was an upload acknowledged by the server, or only queued?
- Was the event classified locally, server-side, or both?
- Is a UI counter showing local detections, persisted events, or server-confirmed events?

The current codebase also contains AI-related services and worker placeholders, but they are not yet a production-quality sound classification pipeline.

## Current Constraints

### Mobile

- The monitoring UI displays local detection counters from `NoiseEventDetector`.
- The backend submission path is driven by `EventDetectionService` and `BackendSyncService`.
- Local event metadata already has placeholders for classification, confidence, and recording references.
- Continuous audio recording exists locally, but raw audio is not part of the supported MVP backend API.

### Backend

- The supported MVP API accepts numeric event payloads and device registration data.
- The backend does not yet expose a robust event receipt or sync-status contract for reconciling mobile and server state.
- AI worker modules exist but are still placeholder-oriented and should not be treated as production behavior.

### Product And Privacy

- Default behavior must remain numeric-only.
- Audio snippets must stay opt-in, encrypted, short-lived, and separately governed.
- The primary event decision should remain offline-capable on the device.

## Scope

This design covers:

- event lifecycle modeling
- device/server observability
- sync contract design
- on-device event segmentation
- on-device classification phases
- server-side enrichment and evaluation

This design does not cover:

- firmware or external hardware sensors
- production cloud deployment
- policy notification workflows
- large-language-model-based audio classification on the device

## Architecture Decisions

### 1. One Event Identity Across Device And Server

Every detected event must carry a stable client-generated identity from the moment the device decides that a real event exists.

Required identifiers:

- `event_uuid`: globally unique client-generated ID
- `device_id`: public device identity already used by the MVP
- `capture_session_id`: a UUID representing one monitoring run on the device
- `device_event_seq`: monotonic event sequence number for the device session
- `upload_attempt_id`: unique ID per submission attempt
- `server_event_id`: backend primary identifier returned after acceptance
- `analysis_job_id`: optional server-side analysis/enrichment job identifier

### 2. One Explicit Event Lifecycle

The system should model the following lifecycle states:

- `detected_local`
- `segmented_local`
- `classified_local`
- `queued_for_upload`
- `uploading`
- `uploaded`
- `acknowledged_by_server`
- `server_enriched`
- `server_analyzed`
- `failed`

Transitions must be append-only in the audit trail. The current state can be derived, but history must not be overwritten.

### 3. Separate Local Detections From Uploadable Events

The current UI mixes local heuristic detections with the concept of actual noise events. That should be split into two concepts:

- `signal detections`: low-level local findings such as spikes, sustained periods, or speech segments
- `reportable events`: merged, segmented, policy-relevant events that survive minimum duration, threshold, and quality rules

Only `reportable events` become `event_uuid` records that are synced to the backend.

### 4. The Device Is The Primary Event Detector

The smartphone should remain the primary source of truth for:

- event start and end times
- initial severity metrics
- initial class prediction
- offline queue behavior

The server should enrich, validate, aggregate, and score confidence, but not be required for first-pass event detection.

### 5. AI Should Be Cascaded, Not Monolithic

Do not start with one large model trying to classify everything. Use a staged pipeline:

- Stage A: voice activity and non-speech filtering
- Stage B: event segmentation and temporal aggregation
- Stage C: coarse event classification
- Stage D: optional refined subclassification

This keeps latency, battery, debugging, and retraining manageable.

## Data Model Changes

### Mobile Local Event Record

Extend the local event representation so it can act as the canonical client-side envelope.

Required fields:

- `event_uuid`
- `capture_session_id`
- `device_event_seq`
- `lifecycle_state`
- `created_at_local`
- `updated_at_local`
- `upload_attempt_count`
- `last_upload_attempt_at`
- `server_event_id`
- `server_acknowledged_at`
- `last_error_code`
- `last_error_message`

Keep existing event fields:

- `timestamp_start`
- `timestamp_end`
- `leq_db`
- `lmax_db`
- `lmin_db`
- `laeq_db`
- `exceedance_pct`
- `samples_count`
- `location_*`
- `event_metadata`
- `recording_file_id`
- `recording_start_offset_ms`
- `recording_end_offset_ms`
- `event_type`
- `event_confidence`
- `duration_class`
- `intensity_class`

### Mobile Event Journal

Add a local append-only journal table, for example `event_lifecycle_journal`.

Fields:

- `id`
- `event_uuid`
- `state`
- `source`
- `timestamp`
- `payload_json`

`source` should distinguish:

- `monitoring_ui`
- `event_detection_service`
- `backend_sync_service`
- `api_client_service`
- `server_receipt`

### Backend Event Model

The backend should persist these client-facing correlation fields:

- `event_uuid`
- `capture_session_id`
- `device_event_seq`
- `client_created_at`
- `client_classification`
- `client_confidence`
- `client_event_type`
- `ingestion_status`
- `received_at`
- `acknowledged_at`

### Backend Receipt And Analysis Tables

Add separate tables if needed:

- `event_ingestion_receipts`
- `event_analysis_results`
- `event_sync_failures`

This avoids overloading the core `events` table with transport-specific state.

## API Contract

### Event Create Response Must Become A Receipt

`POST /api/v1/events/` should return a deterministic receipt rather than only mirroring an event payload.

Proposed response shape:

```json
{
  "event_uuid": "4c2c5f5e-8d91-45ad-a7a0-6f2f0cfed8d5",
  "server_event_id": "evt_01JSR2Z5M5RPK9J1B5B8N9Q4Q8",
  "device_id": "ios-abc12345",
  "status": "acknowledged_by_server",
  "received_at": "2026-04-16T18:12:33Z",
  "acknowledged_at": "2026-04-16T18:12:33Z",
  "analysis_state": "not_started"
}
```

### Event Create Must Be Idempotent

`POST /api/v1/events/` must treat `event_uuid` as the client idempotency key.

Rules:

- first submission creates the event and returns `201`
- repeated submission with the same `event_uuid` returns the same receipt and does not duplicate the event
- conflicting payload under the same `event_uuid` returns `409`

### Sync Status Endpoints

Add one or both:

- `GET /api/v1/events/{event_uuid}/status`
- `GET /api/v1/devices/{device_id}/sync-status`

The device must be able to reconcile local queue state with backend state after reconnect or app restart.

### Optional Batch Endpoint

If queued upload volume grows, add:

- `POST /api/v1/events/batch`

The response should contain one receipt per `event_uuid`.

## Observability Design

### On-Device Debug Surfaces

Add a dedicated mobile debug/status screen that shows:

- active `capture_session_id`
- local signal detections in the last hour
- local reportable events in the last hour
- queued events
- uploaded events
- acknowledged events
- failed events
- last server receipt time
- current backend mode

The current app bar status plus the monitoring card are not enough because they collapse multiple concepts into one visual signal.

### Structured Logs

All logs touching an event should include:

- `event_uuid`
- `device_id`
- `capture_session_id`
- `lifecycle_state`
- `upload_attempt_id`

On the backend, also include:

- `server_event_id`
- `request_id`

### Metrics

Track at minimum:

- detections per hour
- reportable events per hour
- queued events count
- upload success rate
- duplicate submission rate
- average server acknowledgement latency
- battery cost per hour of monitoring
- CPU time spent in segmentation and classification
- false positive rate from reviewed samples

## On-Device Detection And Classification Pipeline

### Phase A: Segmentation

The first problem is not final labeling. It is deciding where an event starts and ends.

Use:

- rolling SPL and Leq windows
- onset and decay thresholds
- grace-period merging
- voice activity probability
- peak-to-average ratio
- temporal continuity features

Output:

- candidate event segments with start/end boundaries

### Phase B: Speech Versus Non-Speech

Introduce a lightweight on-device classifier that first decides:

- `speech`
- `non_speech`
- `mixed`
- `unknown`

Recommended implementation direction:

- log-mel spectrogram features
- a small TFLite classifier or VAD-capable frontend
- frame-level inference aggregated into event-level confidence

### Phase C: Conversation Versus Short Shout/Call

For speech-like segments, classify the event into:

- `conversation`
- `short_shout_or_call`
- `crowd_or_multiple_voices`
- `uncertain_speech`

Core separating features:

- total voiced duration
- speech occupancy ratio across the segment
- onset sharpness
- peak-to-average ratio
- number and spacing of voiced bursts
- temporal continuity over several seconds

Expected heuristics:

- conversation:
  - longer continuous or repeated voiced content
  - moderate peaks
  - several speech-active windows over time
- short shout or call:
  - short duration
  - strong onset
  - isolated burst behavior
  - high peak relative to the surrounding level

### Phase D: Non-Speech Environmental Classes

For non-speech segments, classify:

- `traffic`
- `construction`
- `music`
- `siren`
- `animal`
- `household_mechanical`
- `unknown`

This phase should follow only after sync and speech/non-speech are working reliably.

## AI Implementation Strategy

### Recommended Technical Direction

Use a compact on-device model stack rather than an LLM-like approach.

Preferred path:

- feature extraction on-device from short windows
- TFLite-compatible classifier
- event-level aggregation and smoothing in Dart

Avoid relying on:

- on-device LLM inference for primary classification
- server-only classification for first-pass decisions
- raw audio upload as a default requirement

### Model Rollout

#### Stage 1

- rule-based segmentation
- VAD or speech-probability frontend
- event-level heuristics for conversation vs short shout

#### Stage 2

- small supervised classifier for speech subclasses
- confidence calibration
- uncertainty bucket for low-confidence events

#### Stage 3

- environmental non-speech class expansion
- optional server-side secondary validation on consented audio snippets

## Privacy And Audio Policy

- Numeric event submission remains the default.
- Audio snippets stay opt-in and separately gated.
- If audio-assisted evaluation is needed, store only short encrypted references with TTL.
- The mobile app must make it explicit whether an event has:
  - numeric-only evidence
  - local audio reference only
  - uploaded audio snippet

## Rollout Phases

### Phase 1: Lifecycle And Observability

Deliver:

- `event_uuid` and receipt contract
- append-only local event journal
- backend idempotent event ingestion
- mobile debug screen for lifecycle visibility
- structured logs with shared IDs

Exit criteria:

- maintainers can explain any single event from detection to server acknowledgement
- duplicate uploads do not create duplicate backend rows

### Phase 2: Event Segmentation Hardening

Deliver:

- split between signal detections and reportable events
- stable segmentation logic
- replayable test fixtures for local event segmentation

Exit criteria:

- UI counters distinguish local detections from reportable events
- reportable events are stable across app restarts and reconnects

### Phase 3: Speech Versus Non-Speech

Deliver:

- small on-device classifier
- confidence scoring
- classification traces in local event metadata

Exit criteria:

- event journal and debug UI show classifier output and confidence
- battery and latency stay within acceptable bounds

### Phase 4: Conversation Versus Short Shout

Deliver:

- speech subclassification
- evaluation dataset and metrics
- uncertainty handling for ambiguous cases

Exit criteria:

- reviewed benchmark set exists
- false positive behavior is measurable

### Phase 5: Server Enrichment And Model Operations

Deliver:

- server-side enrichment pipeline
- analysis result persistence
- dashboards for event receipt, classification quality, and drift

Exit criteria:

- device and server results can be reconciled by `event_uuid`
- future model updates are observable and testable

## Acceptance Criteria

- A maintainer can pick one `event_uuid` and trace it end-to-end on device and server.
- The monitoring UI no longer implies that local detections are already server-confirmed events.
- The backend accepts idempotent replays without duplication.
- The device can distinguish at least `speech` vs `non_speech` before attempting richer classes.
- The first speech subclassification iteration can separate `conversation` from `short_shout_or_call` with explicit confidence and uncertainty handling.

## Risks

- Segment boundaries may dominate model quality more than classifier architecture.
- Battery and thermal cost may become unacceptable if inference frequency is too high.
- Audio labeling quality may be the real bottleneck rather than model complexity.
- If UI counters remain ambiguous, maintainers will continue to misread system state.

## Open Questions

- Should `event_uuid` be introduced directly on the existing backend `events` table or via a migration plus compatibility layer?
- Do we want server-side receipts only for authenticated mode, or also for anonymous submissions?
- Is audio-assisted evaluation limited to internal debug builds first?
- What battery budget per hour of monitoring is acceptable on iPhone and Android?

## Suggested Initial Implementation Slice

Build this track in the following order:

1. Add `event_uuid`, lifecycle states, and local journal support.
2. Return server receipts and make event ingestion idempotent.
3. Add a mobile sync/debug screen that shows local, queued, uploaded, and acknowledged counts separately.
4. Refactor the monitoring card so it no longer uses one ambiguous `recent_events_count`.
5. Only then start the first on-device speech/non-speech classifier.
