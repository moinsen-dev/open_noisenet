# Smartphone sensor placement profiles

Status: initial three-device field plan, 2026-08-19.

This plan treats each stable phone position as a separate **Sensor Placement**.
Moving or rotating a phone, changing its power arrangement, or changing the
window state starts a new placement period. Data from different placements may
be compared, but must not be presented as one uninterrupted measurement series.

OpenNoiseNet remains a citizen-science screening system. The current smartphone
level path is not a standards-compliant sound-level meter, and classification
confidence does not prove where a sound originated.

## Evidence and review rules

- The raw Noise Events remain immutable evidence of what the sensor measured.
- Source Segments with the same acoustic family may form one Noise Episode
  across a category-specific pause. The pause stays visible as an interval with
  no threshold/source evidence; it is not counted as continuous noise.
- A confirmed local activity, such as a Teams meeting in the sensor room, is
  retained but excluded from the placement's external target-source total.
- Human context supplements the model result. It never rewrites the original
  level, classification, confidence, or timestamp evidence.
- Episodes from different devices remain separate. Later multi-sensor
  correlation may support a shared-source hypothesis, but must not silently
  merge or duplicate-count measurements from different rooms.
- Normal operation uploads structured levels, categories, confidence and
  timing only. No audio or transcript is required for these profiles.

## Placement 1: office window facing the road

**Primary target:** `road_traffic`

**Expected local confounders:** Teams calls, conversations, television/music,
keyboard and desk impacts.

Placement contract:

- Put the Huawei on a stable stand near the road-facing window, with its
  microphone unobstructed.
- Do not let the phone touch the window pane, frame, radiator, desk cable hub,
  or another vibrating structure. This reduces structure-borne artefacts.
- Record whether the window is `closed`, `tilted`, or `open`. Each change starts
  a new Sensor Placement; these states are not directly interchangeable.
- Record approximate distance to the window and whether the microphone points
  toward the room, window, or side.
- Keep USB power and cable routing stable. Avoid a cable that knocks against the
  phone or stand.
- Confirm known desk-side speech episodes as local activity. Keep them in the
  evidence history, but exclude them from the road-traffic target total.

Acceptance run:

1. Run at least 24 hours without moving the phone.
2. Mark one known local conversation and one known road-traffic interval.
3. Confirm that local speech is excluded from target totals while traffic is
   retained.
4. Repeat only as a new placement if the window state or geometry changes.

## Placement 2: bedroom facing construction and courtyard

**Primary targets:** `drilling`, `hammering`, `sawing`,
`construction_other`, `party_or_music_with_people`,
`shouting_or_dispute`, and `footsteps_or_impact_noise` where applicable.

**Expected local confounders:** bedroom speech, television/music, alarms,
vacuuming, doors and objects handled near the phone.

Placement contract:

- Use a stable position near the courtyard-facing window without contact with
  the pane, frame, bed, heating pipe, or furniture that is regularly moved.
- Record the same window state, distance, orientation, USB power and calibration
  fields as for the office placement.
- Treat 22:00-06:00 local time as a reporting view, not as proof that every
  detected sound came from neighbours.
- Construction and party episodes use different source families and timing
  tolerances. Keep uncertainty visible when music, speech and impacts alternate.
- Confirm known activity inside the bedroom as local. Do not automatically
  suppress all speech or music, because those classes are also targets when they
  arrive from the courtyard.

Acceptance run:

1. Capture a 24-hour quiet/background baseline for this exact placement.
2. Mark known construction or courtyard intervals when independently known.
3. Review at least one false/local example for each common target class.
4. Compare night totals only within the same placement and window state.

## Placement 3: HTC beside the Fritzbox

**Primary role now:** network resilience and tethering fallback.

This device must not yet run the current full-rate continuous YAMNet pipeline.
The Huawei field run showed roughly one continuously occupied CPU core and high
memory pressure. On a phone responsible for fallback connectivity, that load
could harm thermal stability, battery reserve, tethering, or recovery exactly
when the network is degraded.

Initial contract:

- Keep tethering/failover authoritative over sound monitoring.
- Use the HTC as a relay or heartbeat device only until its exact model, Android
  version, battery health, thermal behaviour and microphone/background limits
  are measured.
- When it is connected for evaluation, test tethering and sensor capture
  together under a controlled network outage. Do not infer coexistence from an
  ordinary Wi-Fi run.
- A future sensor mode on this phone should be lower duty-cycle or adaptive and
  must yield resources immediately when tethering/failover becomes active.
- If sound monitoring is later enabled, create a separate Fritzbox placement;
  router/fan noise and cable vibration are local confounders.

## Placement record

Create this record whenever a placement starts or changes:

| Field | Example |
| --- | --- |
| Placement ID | `office-road-window-closed-v1` |
| Device ID and model | Huawei / Android device ID |
| Monitoring zone | Office road window |
| Started at | Explicit local time and UTC offset |
| Target sources | `road_traffic` |
| Known local confounders | Teams calls, desk impacts |
| Window state | Closed / tilted / open |
| Position and orientation | 35 cm from pane, mic toward window |
| Power and cable | USB, stable cable route |
| App/model build | App version and model bundle ID |
| Calibration state | Uncalibrated estimate or profile ID |
| End reason | Moved, rebooted, window changed, app updated |

## Common field gates

- Complete a 24-hour run with no unexplained capture gaps, restarts or uploads
  left queued.
- Verify standalone HTTPS upload without USB/ADB forwarding before calling a
  placement autonomous.
- Calibrate each phone separately against a reference instrument. A calibration
  offset from one phone must not be copied to another model.
- Record CPU, memory, temperature, charging state and battery behaviour on each
  older Android device.
- Keep known-stimulus validation separate from ordinary field evidence: traffic,
  speech, music and construction need per-device precision/recall observations.
- Re-evaluate after every app/model update or material placement change.
