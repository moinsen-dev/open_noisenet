Great — let’s put together a comprehensive technical solution draft as a Markdown document you can drop straight into your open-source repo (e.g. TECHNICAL_SOLUTION.md).

⸻

NoiseNet – Technical Solution Proposal

This document outlines a potential technical solution for the NoiseNet open-source noise monitoring platform. It covers hardware, firmware/software, server backend, frontend, and data pipeline design.

⸻

1. Hardware Design

1.1 Core Components
	•	Microcontroller (recommended baseline)
	•	ESP32-WROOM DevKit (Wi-Fi, low-power, OTA updates)
	•	Alternative: ESP32-S3 (more DSP capabilities)
	•	Microphone
	•	INMP441 (I2S MEMS mic) → digital, low-noise, good SPL range
	•	Alternative: ICS-43434, SPH0645
	•	Power Supply
	•	5 V outdoor USB adapter (basic)
	•	Optional: Solar panel + 18650 battery + TP4056 charging circuit
	•	Enclosure
	•	Weather-resistant (IP54+) plastic/ABS enclosure
	•	Acoustic mesh or Gore-Tex membrane for mic port

1.2 Bill of Materials (BOM Example)

Component	Example Part	Cost (€)
ESP32 DevKit V1	Espressif / clones	8–12
MEMS I2S Mic (INMP441)	Adafruit / Aliexpress	6–9
5 V Power Adapter	Outdoor-rated USB	5–10
Weatherproof Enclosure	Hammond / ABS Box	10–15
Misc (wiring, grommet)	–	5
Total (baseline)		~30–45

1.3 Advanced Option
	•	Raspberry Pi Zero 2 W + USB/I2S mic for richer local ML and storage.
	•	Cost: ~60–70 €.

⸻

2. Firmware & Device Software

2.1 Core Functions
	•	Audio Capture
	•	16 kHz, 16-bit I2S stream
	•	Signal Processing
	•	A-weighting filter (biquad IIR)
	•	Compute RMS + SPL (dBA) per second
	•	Leq15 calculation over 900 s rolling window
	•	Decision Rules
	•	Trigger if:
	•	Leq15 > threshold (e.g. 55 dBA night, 65 dBA day), or
	•	X% of seconds above Y dBA
	•	Reporting
	•	POST JSON event to server when threshold exceeded
	•	Include metadata: device_id, timestamp, Leq15, peak, window stats
	•	Connectivity
	•	Wi-Fi → HTTPS API
	•	OTA updates via version check endpoint

2.2 JSON Payload Example

{
  "device_id": "noisenet-001",
  "start_ts": "2025-09-04T19:00:00Z",
  "end_ts": "2025-09-04T19:15:00Z",
  "leq_db": 66.5,
  "peak_db": 78.2,
  "pct_over": 0.42,
  "rule": "15min_Leq_over_65dBA"
}

2.3 Optional Audio Snippets
	•	Store 30s rolling buffer on device
	•	Upload 5–10s Opus/WAV snippet around peak event
	•	Encrypt + auto-delete on server after retention period

⸻

3. Server Backend

3.1 Stack
	•	API Framework: FastAPI (Python)
	•	Database: PostgreSQL + TimescaleDB extension (for time-series)
	•	Containerization: Docker Compose (API, DB, worker, nginx)
	•	Worker Queue: Celery + Redis (for async ML/audio processing)

3.2 API Endpoints
	•	POST /events — ingest noise event JSON
	•	POST /snippets — upload optional audio snippet linked to event_id
	•	GET /events — query events (filters: device_id, time range)
	•	GET /map — serve geoJSON with latest events for visualization
	•	GET /devices — health, firmware, last seen

3.3 Database Schema (simplified)

devices(
  id SERIAL PRIMARY KEY,
  device_id TEXT UNIQUE,
  name TEXT,
  location GEOGRAPHY(Point),
  firmware_version TEXT,
  last_seen TIMESTAMP
);

events(
  id SERIAL PRIMARY KEY,
  device_id TEXT REFERENCES devices(id),
  start_ts TIMESTAMP,
  end_ts TIMESTAMP,
  leq_db REAL,
  peak_db REAL,
  pct_over REAL,
  rule TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

snippets(
  id SERIAL PRIMARY KEY,
  event_id INT REFERENCES events(id),
  codec TEXT,
  duration_s INT,
  file_path TEXT,
  uploaded_at TIMESTAMP DEFAULT NOW()
);

labels(
  id SERIAL PRIMARY KEY,
  event_id INT REFERENCES events(id),
  label TEXT,
  confidence REAL
);


⸻

4. Data Processing & Analytics

4.1 Pattern Detection
	•	Periodicity detection:
	•	Analyze intervals between events per device
	•	Autocorrelation → identify repeating alarms (e.g. ~15 min pattern)
	•	Label assignment:
	•	Car alarm, construction, traffic, music, natural (rain/wind)

4.2 Classification Pipeline
	•	Extract log-mel spectrograms from snippets
	•	Run simple CNN/SVM classifier
	•	Store labels with confidence scores

4.3 Privacy
	•	Default: only numeric SPL data stored
	•	Snippets: opt-in, encrypted, auto-deletion after 7 days

⸻

5. Frontend

5.1 Public Map
	•	Framework: React + Leaflet / Mapbox
	•	Features:
	•	Heatmap of average SPL
	•	Event markers with details (time, level, classification)
	•	Filter by date/time, device, noise type

5.2 Community Dashboard
	•	Device status (online/offline, last seen)
	•	Event history table
	•	Charts (Leq15 trend, daily distribution)
	•	Contribution guide & how to join

⸻

6. Deployment & Ops

6.1 Infrastructure
	•	Cloud (Hetzner / DigitalOcean / AWS Lightsail)
	•	Services:
	•	API: Docker container
	•	DB: Postgres with TimescaleDB
	•	Object storage for snippets (S3/minio)
	•	Monitoring: Prometheus + Grafana

6.2 Device Management
	•	Heartbeat pings (/devices/heartbeat)
	•	OTA updates from /firmware/latest
	•	Secure device token provisioning

⸻

7. Security & Compliance
	•	All device ↔ server communication via HTTPS (TLS 1.3)
	•	Device authentication: pre-shared token or mTLS
	•	GDPR/DSGVO compliance:
	•	Numeric-only by default
	•	Consent required for snippets
	•	Retention policy (7 days audio, 2 years stats)

⸻

8. Roadmap (Technical)
	•	MVP
	•	ESP32 firmware with SPL detection & JSON POST
	•	FastAPI + Postgres backend
	•	Basic React map frontend
	•	V2
	•	Snippet upload + classification
	•	Pattern detection service
	•	OTA firmware updates
	•	V3
	•	Solar/LTE hardware options
	•	Global federation of servers (regional nodes)
	•	Policy/report generation toolkit

⸻

9. Open-Source Project Structure

/NoiseNet
 ├── firmware/         # ESP32 / Pi device code
 ├── backend/          # FastAPI, DB, Celery workers
 ├── frontend/         # React + Leaflet map
 ├── hardware/         # BOM, 3D-print models, wiring diagrams
 ├── docs/             # Setup guides, calibration manual, GDPR notes
 ├── CONTRIBUTING.md   # Community guidelines
 ├── TECHNICAL_SOLUTION.md
 ├── PRODUCT_REQUIREMENTS.md
 └── LICENSE

