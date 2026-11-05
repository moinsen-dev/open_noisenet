# Sensor context onboarding

Status: concept contract agreed on 2026-08-19.

This feature extends the placement rules in
[`sensor-placement-profiles.md`](sensor-placement-profiles.md). A context belongs
to one stable Sensor Placement, not permanently to a phone. Moving the phone or
changing a material condition such as the window state starts a new placement
period and must not rewrite historical events.

## Main Screen Wireframe

Screen goal:
- Create a user-confirmed placement context for one unattended phone sensor.

Primary actor:
- The person installing or moving a sensor phone.

Layout:
- Top area: setup progress, device name, and a short statement that context
  improves interpretation but does not identify a sound by itself.
- Main area: placement questions followed by an optional location-derived
  environment suggestion.
- Footer: back, save placement, and a visible path that skips automatic context.

Primary flow:
1. Name the sensor zone and describe the physical placement.
2. Select monitoring targets and known local confounders.
3. Optionally request a one-time location-derived environment suggestion.
4. Confirm, edit, or reject the suggestion and save the placement.

Important states:
- Manual: all required context is supplied by the operator; no environment
  lookup is needed.
- Suggested: location-derived context is visibly unconfirmed until the operator
  accepts or edits it.
- Confirmed: the profile is active from a recorded start time.
- Unavailable: location permission, lookup, or source coverage failed; manual
  setup remains fully usable.
- Changed: moving the phone or changing the window state ends the old placement
  and creates a new version.

ASCII sketch:

```text
+--------------------------------------------------+
| Sensorstandort                         Schritt 3/4|
| Kontext hilft bei unsicheren Ergebnissen.        |
| Er ersetzt niemals das akustische Signal.        |
+--------------------------------------------------+
| Name / Zone                                      |
| [ Bürofenster Straße__________________________ ] |
|                                                  |
| Wo steht das Telefon?                            |
| [Innen] [Außen]   [Am Fenster] [Im Raum]         |
| Fenster: [geschlossen v]  Mikrofon: [Fenster v] |
|                                                  |
| Was möchtest du beobachten?                      |
| [x] Straßenverkehr  [ ] Baustelle  [ ] Innenhof |
|                                                  |
| Bekannte Geräusche direkt am Gerät               |
| [x] Gespräche/Meetings  [x] Schreibtischstöße    |
|                                                  |
| Umgebung optional vorschlagen                    |
| [Einmaligen Standort verwenden]                  |
|                                                  |
| Vorschlag - noch nicht bestätigt                 |
| Stadtgebiet - Hauptstraße in der Nähe            |
| Kreuzung möglicherweise in der Nähe              |
| Quelle und Unsicherheit anzeigen                 |
| [Korrigieren]                         [Bestätigen]|
+--------------------------------------------------+
| [Zurück]           [Ohne Vorschlag] [Speichern]  |
+--------------------------------------------------+
```

# PAD/PRD: Confirmed Sensor Context

## Problem
- Sound classification lacks knowledge about where and how a stationary phone
  is installed, so ambiguous acoustic evidence can be harder to interpret.
- Automatic location-derived context can be wrong and can expand the privacy
  boundary if treated as silent ground truth.
- A phone can have several materially different placements over time; one
  permanent device label would corrupt comparisons and historical interpretation.

## Context
- OpenNoiseNet is a citizen-science screening system, not a calibrated legal
  measurement system.
- The mobile app already requests location for mapped events. Environment
  enrichment remains a separate, explicit action even when location permission
  has already been granted.
- The agreed product policy is hybrid capture with human confirmation and soft
  contextual influence.
- Normal operation remains structured-data only; this feature requires no audio,
  waveform, or transcript retention.

## Users / Actors
- Sensor operator: installs a phone, describes its physical placement, and
  confirms or corrects suggested context.
- OpenNoiseNet classifier: produces acoustic evidence independently and may use
  confirmed context only to resolve ambiguity.
- Environment-data source: supplies a bounded suggestion with provenance,
  coverage, and uncertainty; it is never authoritative.

## User Value
- Results can distinguish the intended monitoring target from known local
  confounders such as meetings, television, router noise, or desk impacts.
- Comparisons remain tied to a known phone position, window state, and monitoring
  purpose.
- Setup is convenient without making automatic location inference mandatory.

## Core System Behavior
- Create one versioned placement profile per stable device position.
- Ask for a human-readable zone, indoor/outdoor position, room or window relation,
  window state where relevant, microphone orientation, monitoring targets, and
  known local confounders.
- Offer a one-time location-derived environment suggestion only after a separate,
  explicit user action.
- Present every suggestion as unconfirmed and allow confirm, edit, reject, or
  continue manually.
- Preserve the source, observation time, coverage, and uncertainty of suggested
  attributes. Unsupported attributes remain unknown rather than guessed.
- Keep the acoustic classification as primary evidence. Confirmed context may
  reorder similarly plausible low-confidence candidates, but it cannot introduce
  a category without acoustic evidence, erase strong contradictory evidence, or
  turn a context prior into a detected event.
- Preserve both the acoustic result and any contextual adjustment so an operator
  can understand why the displayed result changed.
- End the current placement and create a new version after a material change;
  never retroactively alter previous events.
- Allow the operator to review, correct, deactivate, or replace the active
  placement after onboarding.

## Main Screen
- Purpose: create and confirm the active placement context for one sensor phone.
- Key zones: placement identity, physical setup, monitoring intent, local
  confounders, optional environment suggestion, provenance/uncertainty, and
  confirmation controls.
- Primary flow: describe placement -> optionally obtain suggestion -> confirm or
  edit -> review privacy boundary -> activate placement.

## Major Features / Epics
- Placement questionnaire and reusable profile review.
- Optional location-derived environment suggestion with explicit confirmation.
- Versioned placement lifecycle and historical event linkage.
- Auditable soft-context interpretation for ambiguous classifications.
- Multi-device placement overview for office, bedroom, and future sensor phones.

## Constraints
- Manual setup must remain fully usable without an environment lookup.
- A previously granted location permission is not consent for enrichment.
- Exact coordinates must not be exposed merely to display a human-readable
  environment description.
- User-confirmed placement context is authoritative only for the installation
  description, not for the physical origin of any detected sound.
- Map context such as road class, nearby intersection, land use, or construction
  is evidence about surroundings, not proof of the current noise source.
- Context must never rewrite raw level, timestamp, acoustic category scores, or
  previously stored event evidence.
- Every device and materially changed position is evaluated separately.

## Expected Outputs
- An active, versioned Sensor Placement with a validity start time.
- A user-confirmed physical setup and monitoring intent.
- Optional environment attributes with provenance, observation time, and
  uncertainty.
- Event and episode views that distinguish acoustic evidence, contextual hints,
  and known local confounders.
- A clear explanation when context affected the ranking of an ambiguous result.

## Out of Scope
- Inferring the exact physical origin or direction of a sound from map context.
- Treating map data as current proof of construction, traffic volume, parties,
  animals, or window state.
- Continuous background location tracking for context enrichment.
- Automatic confirmation or silent replacement of user-entered context.
- Cross-device event merging or legal-grade source attribution.

## Open Questions
- None at concept level. Exact question wording, environment attributes, privacy
  transformations, and contextual ranking rules are implementation decisions.
