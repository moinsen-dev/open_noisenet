# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

Open NoiseNet is an open-source environmental noise monitoring platform that democratizes noise monitoring through affordable DIY devices. The project combines hardware (ESP32/Raspberry Pi + MEMS microphones), firmware, backend services, and frontend visualization to create a global network of citizen-operated noise sensors.

## Architecture Components

Based on the technical specification in `technology.md`, the project will consist of:

### Hardware Stack
- **ESP32-based devices** (baseline): ESP32 DevKit + INMP441 I2S MEMS microphone (~€30-45)
- **Raspberry Pi option**: Pi Zero 2 W + USB/I2S mic for advanced ML (~€60-70)
- **Enclosures**: Weather-resistant (IP54+) with acoustic mesh for outdoor deployment

### Software Stack
- **Device Firmware**: ESP32/Arduino-based firmware for audio capture and SPL calculation
- **Backend**: FastAPI + PostgreSQL + TimescaleDB + Docker for event ingestion and processing
- **Frontend**: React + Leaflet/Mapbox for public noise mapping visualization
- **Analytics**: Celery + Redis for async ML/audio processing and pattern detection

### Data Flow
1. Devices capture ambient sound via I2S MEMS microphones
2. Calculate A-weighted SPL and Leq15 (15-minute equivalent levels)
3. Trigger threshold rules (e.g., Leq15 > 55dBA night/65dBA day)
4. POST JSON events to server via HTTPS
5. Optional encrypted audio snippets for ML classification
6. Public map visualization with event markers and heatmaps

## Project Structure (Planned)

According to the technical specification, the project will be organized as:

```
/open_noisenet
 ├── firmware/         # ESP32 / Pi device code
 ├── backend/          # FastAPI, DB, Celery workers
 ├── frontend/         # React + Leaflet map
 ├── hardware/         # BOM, 3D-print models, wiring diagrams
 ├── docs/             # Setup guides, calibration manual, GDPR notes
 ├── CONTRIBUTING.md   # Community guidelines
 ├── TECHNICAL_SOLUTION.md
 ├── PRODUCT_REQUIREMENTS.md
 └── LICENSE
```

## Development Phases

### Phase 1: MVP (3–6 months)
- Hardware BOM and DIY build guide
- ESP32 firmware: SPL logging + 15-min exceedance reporting
- FastAPI backend: ingest & store events
- Basic map frontend with event markers
- Documentation + community onboarding

### Phase 2: Expansion (6–12 months)
- Periodicity detection (recurring noise patterns)
- Optional audio snippet upload + ML classification
- Public open noise map launch
- NGO partnerships for pilot campaigns

### Phase 3: Scale (12–24 months)
- LTE option for rural deployments
- Solar-powered variants
- Advanced analytics dashboard
- Policy engagement toolkit

## Privacy & Compliance Requirements

- **Default behavior**: Store only non-speech SPL values
- **Audio snippets**: Optional, encrypted, max 10s, deleted after 7 days
- **GDPR/DSGVO compliance**: Anonymized metadata only, explicit consent for audio
- **Device communication**: HTTPS/TLS 1.3 only
- **Data retention**: 7 days for audio, 2 years for statistics

## Community & Open Source Focus

- Complete open-source stack (hardware, firmware, backend, frontend)
- Community-driven with transparent governance model
- Data licensed under Open Data Commons (ODC-ODbL)
- Focus on citizen science and advocacy applications
- Target users: citizen scientists, NGOs, researchers, policymakers

## Key Technologies to Use

When implementing components, prefer these technologies aligned with the technical specification:

- **Firmware**: Arduino/ESP-IDF for ESP32, I2S for audio capture
- **Backend**: FastAPI, PostgreSQL with TimescaleDB extension, Docker Compose
- **Frontend**: React, Leaflet or Mapbox for mapping, responsive design
- **Processing**: Celery for async tasks, Redis as message broker
- **Deployment**: Docker containers, cloud deployment (Hetzner/DigitalOcean preferred)
- **Audio**: A-weighting filters, Leq calculations, Opus/WAV for snippets
- **Security**: Device token authentication, HTTPS everywhere, encryption for audio

## Important Notes

- This is a citizen science project focused on environmental advocacy
- Privacy-by-design is critical - default to numeric data only
- Hardware must be affordable and DIY-friendly
- All data should be open and accessible to communities
- Focus on standardized, comparable noise measurements
- Consider regulatory compliance (GDPR) throughout development
- Remeember to use uv as Python package manager

## Execution Policy For Agents

Agents working in this repository should optimize for autonomous execution, not micro-confirmations.

### Default Operating Mode

- Execute the next obvious blocker-removal step without asking for confirmation.
- Continue until the current feature or bugfix is usable end-to-end, not just partially improved.
- Treat follow-up fixes discovered during implementation as part of the same task when they are tightly coupled.
- Prefer reporting completed work and remaining real risks after acting, instead of asking whether to proceed.

### No-Brainer Decisions That Must Not Be Confirmed

These should be handled autonomously unless the user explicitly says otherwise:

- Fixing broken tests, analyzers, type errors, migrations, and local build issues caused by the current task
- Updating touched schemas, generated files, serializers, API clients, and UI wiring to keep the stack consistent
- Removing misleading UI text, debug affordances, and demo semantics when they conflict with the product goal
- Restarting local services, rebuilding local containers, and applying local development migrations required for validation
- Fixing adjacent regressions or implementation drift discovered while completing the requested work
- Making small architectural cleanups inside the touched area when needed to make the feature coherent

### When Agents Should Ask

Agents should stop and ask only when a decision materially changes product scope, data safety, or external behavior, for example:

- Destructive actions with user data, irreversible deletion, or resets beyond normal local development flows
- Changes to privacy posture, retention policy, consent model, or audio-capture policy
- Major product-direction changes, such as choosing hardware strategy, background-execution strategy, or public API commitments
- Production-impacting infrastructure changes, secrets, billing, external vendors, or compliance-sensitive behavior
- Conflicts where two plausible directions exist and each has meaningful tradeoffs for the business or product

### Communication Style

- Do not ask “should I fix this obvious blocker?” when the answer is clearly yes.
- Do not ask for confirmation for one-file or one-constant follow-up fixes discovered during implementation.
- Group related no-brainer fixes into one execution pass.
- Escalate only with a concrete decision to make, not with generic permission-seeking.

### Product Goal Bias

For the mobile app specifically, agents should bias toward the product goal of an unattended autonomous sensor.

- Prefer autonomous capture, upload, and recovery flows over interactive/demo UI behavior.
- Treat manual save/debug actions as secondary tooling, not core workflow.
- Favor decisions that make the app viable for long-running unattended monitoring, provided they do not violate privacy or platform constraints.
