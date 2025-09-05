Here’s a ready-to-paste Markdown Change Request for your repo.

⸻

Change Request: Smartphone Node (Android/iOS) with On-Device AI & Event-Only Uploads

Issue Type: Feature Request
Status: Proposed
Owner: @moinsen-dev
Repo: open_noisenet
Epic Link: “Citizen Nodes”

1) Summary

Enable any spare smartphone (Android first; iOS as feasible) to act as an always-on OpenNoiseNet sensor that:
	•	Captures audio locally,
	•	Performs on-device detection and labeling of noise events using MiniCPM-o 2.6 via cactus (llama.cpp/GGUF),
	•	Never uploads raw audio—only event summaries (e.g., “Fire alarm detected 10:00–10:15”, “Trash collection ~10 min at 06:00”).

Android will use a Foreground Service (microphone type) to run continuously across screen locks. iOS will be supported in a best-effort mode (background audio or with screen lock disabled), understanding platform constraints.  ￼ ￼

⸻

2) Motivation & Goals
	•	Leverage existing hardware: Millions of unused phones can become sensors with zero BOM cost.
	•	Privacy-first: Numeric labels/timestamps only; no audio leaves the device by default.
	•	Robust classification: Use an on-device model to infer “what happened” and produce concise, human-readable event logs.
	•	MVP velocity: Android path is straightforward with proper service types; iOS supported with clear caveats.  ￼

⸻

3) Non-Goals
	•	Recording or storing raw audio in the cloud.
	•	Real-time streaming off-device.
	•	Perfect metrology (class-1 SLM). We target community mapping with optional calibration.

⸻

4) User Stories
	1.	As a resident, I can repurpose my old Android phone to log neighborhood noise and contribute to a shared map without uploading audio.
	2.	As a city researcher, I can pull structured event timelines (type, start, end, confidence) and visualize patterns over weeks.
	3.	As a privacy-conscious user, I can confirm that no raw audio leaves the device, and I can pause or delete data locally at any time.

⸻

5) Technical Approach

5.1 On-Device AI Stack
	•	Model: MiniCPM-o 2.6 (8B, multimodal, speech-capable) converted/loaded as GGUF for llama.cpp runtime. GGUF builds exist.  ￼ ￼
	•	Runtime: cactus Flutter framework (supports GGUF / llama.cpp under the hood) to run LLMs/VLMs on Android and iOS.  ￼ ￼

Hybrid pipeline (recommended):
	•	Extract low-level audio features continuously and compute LAeq(1s), LAmax locally.
	•	Use a lightweight audio event embedder/classifier (e.g., YAMNet-style embeddings) to tag moments as siren, alarm, traffic, construction, etc. (on-device).
	•	Periodically pass aggregated candidates to MiniCPM-o for natural-language summarization (e.g., “Trash truck 06:01–06:09; backing alarm 06:04–06:06”).
This reduces LLM compute while keeping inference on device.  ￼

5.2 Android (Primary Target)
	•	Background execution: Foreground Service with foregroundServiceType="microphone"; request required permissions and show persistent notification.  ￼
	•	Start-up pattern: Launch service from foreground UI; keep running through screen locks and Doze.
	•	Upload: Batch event summaries via WorkManager (periodic, retry). (Standard Android guidance; no raw audio.)

5.3 iOS (Best-Effort Support)
	•	Two modes:
	1.	Background Audio enabled (Info.plist UIBackgroundModes: audio) with AVAudioSession .record/.playAndRecord—continues across lock as long as the app isn’t killed.
	2.	Screen lock disabled user mode for continuous operation where App Review policies would otherwise constrain.  ￼ ￼
	•	Uploads: Background URLSession for event summaries.

⸻

6) Data & Telemetry

Local processing only; transmit events:

{
  "device_id": "hashed",
  "timestamp_start": "2025-09-05T08:00:00Z",
  "timestamp_end": "2025-09-05T08:15:00Z",
  "labels": ["fire_alarm"],
  "confidence": 0.94,
  "loudness_metrics": {"LAeq_dBA": 73.2, "LAmax_dBA": 84.7},
  "notes": "Intermittent",
  "local_only_flags": {"raw_audio": false}
}

Retention: Local rolling buffer of features only (e.g., minutes), then discard. No raw audio uploads (default).

⸻

7) Privacy, Security, and Compliance
	•	Default: No raw audio leaves device.
	•	Clear consent for any optional mode that might store snippets locally for model improvement—off by default.
	•	Data is pseudonymous and encrypted in transit.
	•	App surfaces platform mic indicators (Android/iOS) and a visible notification on Android.

⸻

8) Performance Targets (Android reference device)
	•	Background power draw: ≤ 3–5%/hour in continuous mode; ≤ 1–2%/hour in duty-cycled mode (10s per minute).
	•	Real-time LAeq(1s) computation with <10% CPU average.
	•	LLM summarization windows every 1–5 minutes; use quantized GGUF; expose a “Low-Power” profile.

Note: MiniCPM-o 2.6 is an 8B model; use quantized variants and/or the hybrid pipeline to stay within thermals. GGUF builds indicate llama.cpp compatibility, which cactus supports.  ￼ ￼

⸻

9) UX Requirements
	•	Setup wizard: permissions, battery optimizations exclusion (Android), background mode explainers.
	•	Privacy explainer: Bold “No audio leaves this phone.”
	•	Live tile: current LAeq, last detected event, service status.
	•	Controls: Start/Stop sensor; “Low-Power” vs “High-Fidelity” modes.
	•	Calibration helper (optional): user matches readings to a reference SLM or known sound source.

⸻

10) Acceptance Criteria
	•	✅ Android app runs >12h continuously with screen locked, logging events and uploading summaries only. Foreground notification present.  ￼
	•	✅ On-device MiniCPM-o (GGUF via cactus) loads and produces text summaries from candidate segments, with adjustable cadence.  ￼ ￼
	•	✅ No raw audio is transmitted; server receives only structured event JSON.
	•	✅ iOS build can operate in Background Audio mode or with screen lock disabled (documented trade-offs).  ￼
	•	✅ README updated with clear privacy stance and device requirements.

⸻

11) Risks & Mitigations
	•	Thermals/Battery on older phones (8B model) → Use 4-bit quantization, duty-cycle LLM usage, and hybrid pipeline with a small classifier front-end (e.g., YAMNet embeddings).  ￼
	•	iOS background limits / App Review → Provide a user-visible audio metering feature and clear justification; document “screen-unlock mode” as fallback.  ￼
	•	Device mic variance → Provide per-device calibration offsets in settings.

⸻

12) Implementation Plan

Phase 1 (Android MVP)
	1.	Foreground Service (microphone type) + persistent notification; AudioRecord pipeline; LAeq(1s), LAmax.  ￼
	2.	YAMNet-style embeddings & rule-based event grouping (traffic/alarm/siren/garbage).  ￼
	3.	Integrate cactus; load MiniCPM-o 2.6 GGUF; generate interval summaries.  ￼ ￼
	4.	Event summary upload (WorkManager) and minimal map backend integration.

Phase 2 (iOS Beta)
	1.	Enable Background Audio; AVAudioSession .record/.playAndRecord.  ￼
	2.	Mirror Android pipeline; use background URLSession for uploads.
	3.	Document “screen-unlock required” fallback mode.

Phase 3
	•	Calibration flow, model update mechanism, power profiles, and contributor docs.

⸻

13) Repo Changes
	•	/mobile/
	•	android/ (service, audio pipeline, cactus integration)
	•	ios/ (background audio setup, pipeline, cactus integration)
	•	lib/ (Flutter UI, settings, calibration)
	•	Docs
	•	docs/smartphone-node.md (this spec + setup)
	•	Update PRD and technology.md to reflect smartphone track.  ￼

⸻

14) References
	•	MiniCPM-o 2.6 model overview & on-phone positioning (Ollama/HF).  ￼ ￼
	•	MiniCPM-o 2.6 GGUF weights for llama.cpp compatibility.  ￼
	•	cactus (Flutter) for running GGUF/llama.cpp models on Android/iOS; project repo.  ￼ ￼
	•	Android 14+ Foreground Service microphone type requirements.  ￼
	•	iOS background audio recording (UIBackgroundModes: audio, AVAudioSession).  ￼
	•	On-device audio event embeddings/classification (YAMNet).  ￼
	•	OpenNoiseNet repo context (PRD/technology docs).  ￼
