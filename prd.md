Open NoiseNet: Open-Source Environmental Noise Monitoring Project

Product Requirement Document (PRD)

⸻

1. Executive Summary

Noise pollution is a growing urban and rural health issue, yet reliable, distributed, and independent monitoring is scarce. NoiseNet is an open-source hardware and software platform that empowers citizens to measure, log, and share environmental noise data.

Participants purchase a low-cost device (ESP32 or Raspberry Pi + MEMS mic), set it up outdoors, and connect it to the internet. The system collects sound level data, detects noise patterns (e.g., recurring car alarms, construction, traffic), and shares anonymized events with a central server.

A global map visualizes noise intensity, duration, and sources, enabling communities to engage with policymakers, urban planners, and funding bodies.

⸻

2. Goals & Objectives
	•	Democratize noise monitoring with affordable, DIY-friendly devices.
	•	Provide standardized, reliable, and comparable noise data.
	•	Build an open global map of noise events and patterns.
	•	Enable advocacy and political action against chronic noise pollution.
	•	Foster a collaborative, transparent, and open-source community.
	•	Ensure privacy and GDPR/DSGVO compliance.

⸻

3. Target Users
	•	Citizen scientists concerned about noise in their neighborhoods.
	•	Local communities organizing against construction/traffic noise.
	•	NGOs & activists campaigning for better noise regulation.
	•	Researchers studying urban soundscapes and health impacts.
	•	Policymakers & municipalities seeking crowd-sourced insights.

⸻

4. Hardware Requirements

Device
	•	Microcontroller-based: ESP32 DevKit + I2S MEMS mic (INMP441)
	•	Optional Raspberry Pi Zero 2 W for advanced local ML and storage
	•	Enclosure: weather-resistant (IP54+), small form factor
	•	Power: USB 5 V adapter (outdoor-rated) or solar + battery option
	•	Connectivity: Wi-Fi (LTE option later)

Cost Target
	•	ESP32-based build: < €30 per unit
	•	Raspberry Pi-based build: < €70 per unit

⸻

5. Software Requirements

Device Firmware
	•	Capture ambient sound via MEMS mic
	•	Compute A-weighted SPL + 15-min Leq
	•	Apply threshold rules (continuous exceedance detection)
	•	Optional: short audio snippet (compressed, 5–10s) for classification
	•	Send JSON payloads to server via HTTPS (MQTT optional later)
	•	OTA firmware updates

Server Backend
	•	Framework: FastAPI + Postgres + Docker
	•	Endpoints:
	•	POST /events — noise event uploads
	•	POST /snippets — optional audio snippets
	•	GET /map — geoJSON feed for visualization
	•	Storage:
	•	Device registry
	•	Events (timestamps, Leq, thresholds exceeded)
	•	Snippets (optional, encrypted, short-lived)
	•	Analytics: periodicity detection (e.g., “car alarm every 15 min”)
	•	Export: CSV/JSON, open-data portal

Frontend
	•	Public noise map (Leaflet/Mapbox/Kepler.gl)
	•	Heatmaps of average dB levels
	•	Event markers (time, type, duration, classification)
	•	Community dashboard: device health, uptime, local stats

⸻

6. Data Privacy & Compliance
	•	Store only non-speech SPL values by default.
	•	Optional audio snippets: encrypted, max 10s, deleted after 7 days.
	•	Devices send anonymized metadata (device_id, city/coords, firmware).
	•	GDPR/DSGVO-compliant privacy statement, opt-in required.

⸻

7. Community & Governance
	•	Open-source repo (GitHub/GitLab): firmware, backend, frontend.
	•	Community docs: setup guide, BOM, calibration how-to, contribution guidelines.
	•	Governance model: core maintainers + community contributors.
	•	Data license: Open Data Commons (ODC-ODbL).

⸻

8. Success Metrics
	•	Number of deployed devices
	•	Active contributors (software/hardware/community)
	•	Monthly active devices reporting data
	•	Coverage (cities, regions)
	•	Engagement: NGOs, universities, municipalities using data
	•	Policy impact (noise mitigation measures influenced)

⸻

9. Roadmap

Phase 1: MVP (3–6 months)
	•	Hardware BOM and DIY build guide
	•	ESP32 firmware: SPL logging + 15-min exceedance reporting
	•	FastAPI backend: ingest & store events
	•	Basic map frontend with event markers
	•	Documentation + community onboarding

Phase 2: Expansion (6–12 months)
	•	Add periodicity detection (e.g., car alarm every 15 min)
	•	Implement optional audio snippet upload + ML classification
	•	Launch public open noise map
	•	Partner with NGOs for pilot campaigns
	•	Explore EU citizen science funding

Phase 3: Scale (12–24 months)
	•	Add LTE option for rural deployments
	•	Develop solar-powered variant
	•	Advanced analytics dashboard (trends, seasonal patterns)
	•	Policy engagement toolkit (reports, exports for city councils)
	•	Funding applications (EU Horizon, local grants)

⸻

10. Risks & Mitigation
	•	Privacy concerns → Default to numeric SPL, short retention of snippets
	•	Device calibration differences → Provide calibration procedure + community calibration tool
	•	Hardware availability → Provide alternatives (ESP32, Pi, microcontrollers)
	•	Community fatigue → Build a vibrant open-source community with transparent governance
