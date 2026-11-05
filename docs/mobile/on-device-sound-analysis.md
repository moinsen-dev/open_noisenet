# On-device sound analysis

Status: initial end-to-end integration implemented locally on 2026-08-18;
field-tuned taxonomy v2 acceptance policy added on 2026-08-19.

## Runtime path

OpenNoiseNet now uses one native mono PCM stream for both level monitoring and
sound-event inference:

1. Android requests 48 kHz `UNPROCESSED` input when the device advertises it,
   otherwise `VOICE_RECOGNITION`; iOS uses `AVAudioSession` measurement mode.
   Android sensor mode also starts a visible microphone foreground service.
2. The existing level path receives a copy of each buffer and keeps its
   calibration offset and explicit quality marker.
3. The inference path resamples PCM to 16 kHz in memory.
4. The bundled official Float32 YAMNet model evaluates 15,600-sample windows
   with a 7,680-sample (480 ms) hop.
5. `OpenNoiseTaxonomyHead` maps the 521 AudioSet scores into the stable product
   taxonomy. Taxonomy v2 requires a pooled category confidence of at least
   0.18, or 0.24 for the broad `animals` category.
6. `SoundSourceActivityTracker` turns stable frame sequences into independent
   source intervals. Two agreeing accepted frames activate and expose a source,
   three missing frames end it, and category changes require two agreeing
   frames. A single weak or unconfirmed candidate remains internal and is shown
   as unknown. Boundaries therefore have a 480 ms update step and up to one
   975 ms model-window of uncertainty.
7. `SoundSceneAggregator` smooths overlapping frames over an event. The
   deterministic event engine independently labels temporal shape as
   `impulse`, `repeated_impulses`, `intermittent`, `continuous`, or
   `background_elevation`. Only frames that pass the category-specific policy
   contribute occupancy, so repeated 12% animal candidates cannot be inflated
   into a confident event classification.
8. Finalized events carry the category, confidence, source intervals and
   durations, temporal shape, model/head version, calibration quality, and top
   local evidence into the existing idempotent event receipt path. Event
   timestamps are serialized as explicit UTC.
9. The backend episode engine preserves the mobile taxonomy as the primary
   class, maps it into speech/environmental/impulsive families, and applies
   explicit per-category impact weights and German timeline labels.

The Monitor screen displays the current source hypothesis, confidence, active
duration, last completed interval, strongest raw YAMNet evidence, privacy
boundary, and calibration state. The source interval is deliberately separate
from the rolling 10-minute Leq threshold episode.

On Android, the notification stop action is routed back into the monitoring
BLoC, so it shuts down microphone capture, inference, event detection, and
sensor-mode sync together rather than only hiding the foreground notification.

Low-confidence or unavailable model results fail transparently to the existing
numeric rule engine. Source-like labels are no longer guessed from loudness and
time of day alone.

## Product taxonomy

- `loud_conversation`
- `shouting_or_dispute`
- `party_or_music_with_people`
- `television_or_music`
- `drilling`
- `hammering`
- `sawing`
- `construction_other`
- `furniture_movement`
- `footsteps_or_impact_noise`
- `door_or_impact`
- `household_appliance`
- `road_traffic`
- `animals`
- `unknown_sound_source`

`party_or_music_with_people` is context evidence derived from co-occurring
music and human-activity scores; it is not a direct YAMNet class.

## Privacy boundary

- Normal operation retains roughly one inference window; a slow-device backlog
  is hard-bounded at 46,320 resampled samples (2,895 ms) and older windows are
  dropped. Stopping monitoring clears the buffer.
- Only structured level, category, confidence, and timing data enters an event.
- Source activity history contains timestamps, categories, confidences, and
  top model scores only; it never contains waveform samples.
- The classifier performs no speech recognition and no transcription.
- Continuous audio persistence is off by default and is never force-enabled by
  monitoring. The existing recording setting is a separate explicit opt-in.
- The optional recording subsystem still stores long local buffers. It is not
  the intended production snippet design and must be replaced by separately
  consented, encrypted, maximum-10-second snippets before any audio-upload
  feature is enabled.

## Model provenance

The bundled artifact is Google's current official MediaPipe YAMNet model:

- source: `https://storage.googleapis.com/mediapipe-models/audio_classifier/yamnet/float32/latest/yamnet.tflite`
- SHA-256: `4d8b4a53282dc83ef04e3e7dbc4fbc98082e34e44ed798e16c3a0cdd4c584faf`
- input: mono Float32, 16 kHz, 15,600 samples
- output: 521 scores
- size: about 3.9 MB

The official artifact is Float32, not INT8. A quantized replacement needs its
own accuracy, latency, battery, and device-compatibility evaluation.

## Honest readiness limits

This slice makes the encoder, taxonomy, temporal aggregation, event contract,
privacy behavior, diagnostics, and fallbacks real. It does not make these
claims:

- The taxonomy adapter is transparent and deterministic; it is not yet the
  learned custom neural head proposed for the mature product.
- The current SPL path remains a calibrated-or-uncalibrated smartphone
  RMS estimate. It is not a standards-compliant sound-level meter. The tested
  A-weighting DSP is not yet enabled in the capture path; reference calibration
  and validation on physical microphones remain open.
- YAMNet has not yet been benchmarked on OpenNoiseNet's through-wall,
  closed-window, cross-phone field corpus.
- The frame-hysteresis timing algorithm is deterministic and unit-tested, and
  a real Huawei event has traversed capture, inference, interval creation,
  local storage, upload, and backend receipt. Its real-world onset/offset error
  still needs comparison with known-duration labelled sources.
- The Android foreground-service host now starts with sensor mode, but
  process-death recovery now uses a single process-owned Flutter engine shared
  by the screen and service. An OS sticky-service restart resumes capture only
  if it was requested before process death and microphone permission remains
  granted; it does not launch UI or request permissions in the background.
  Explicit Stop clears the persisted request. Reboot/force-stop recovery and
  a 24-hour thermal/battery run are separate unverified cases. The legacy
  periodic WorkManager path is not the
  production sensor path. iOS background behavior likewise needs field runs.
  A simulator or successful build is not release evidence.

The learned-head exit gate is a versioned, consented dataset; device-stratified
train/validation/test splits; per-class precision/recall; confidence
calibration; and old-device battery/thermal measurements. Until then, events
retain explicit uncertainty and the rule fallback remains visible.

## Verification

```bash
cd mobile
flutter analyze
flutter test
flutter build web
flutter build apk --debug
flutter build ios --simulator --debug

# Requires an Android/iOS target because the host Flutter test runner does not
# load the bundled TensorFlow Lite native library.
flutter test integration_test/yamnet_model_test.dart -d <device-id>
flutter test integration_test/live_sound_pipeline_test.dart -d <device-id>
flutter test integration_test/android_foreground_service_test.dart -d <android-device-id>

cd ../backend
uv run pytest tests/test_open_noise_taxonomy.py -q
uv run pytest tests/test_events_api.py tests/test_detect_episodes.py \
  tests/test_episode_case_workflow.py -q
```

Runtime model status, frame count, inference latency, last category, failure,
source timing, active duration, and privacy mode are visible on the Event Sync
diagnostic screen. Structured diagnostics also retain the latest unaccepted
candidate, category scores and top YAMNet labels for field tuning; they contain
no waveform or transcript. See `smartphone-reference-calibration.md` for the
reference offset procedure.

### Private-history integration check on iOS Simulator

Use a **dedicated disposable simulator**: Flutter's integration-test runner may
uninstall its test app afterwards. Do not run this against a device containing
personal app data. The check feeds a public prerecorded YAMNet example through
the real model, encrypted storage, a database reopen and the history widget.
Level values are supplied by the test; microphone capture and SPL accuracy are
not covered. The example is not private audio and is not committed to the repo.

With a booted dedicated simulator, Flutter and `ffmpeg` installed, from `mobile`:

```bash
SIMULATOR_ID='<dedicated-simulator-udid>'
flutter build ios --simulator --debug --no-codesign
xcrun simctl install "$SIMULATOR_ID" build/ios/iphonesimulator/Runner.app
curl -L https://storage.googleapis.com/audioset/speech_whistling2.wav -o /tmp/noisenet-public-yamnet-example.wav
TEST_DATA_DIR="$(xcrun simctl get_app_container "$SIMULATOR_ID" dev.moinsen.noisenetMobile data)"
ffmpeg -y -i /tmp/noisenet-public-yamnet-example.wav -ac 1 -ar 48000 -f s16le "$TEST_DATA_DIR/Documents/noisenet_public_test_sample.pcm"
flutter test integration_test/private_sound_history_test.dart -d "$SIMULATOR_ID" --reporter expanded
```

The [TensorFlow YAMNet tutorial](https://www.tensorflow.org/hub/tutorials/yamnet)
uses this same public speech-and-whistling example. Its predicted classes are
model suggestions, not verified causes.


## Episode grouping and private Pixel acceptance (2026-11-05)

The history view now groups maximal runs connected by **observed** lower-level
minutes up to an adjustable pause tolerance (UI default: five minutes). Missing,
duplicate or invalid minutes split runs regardless of the tolerance. Trailing
quiet minutes are excluded. Total span, minutes on/above the comparison line,
short pauses and the energy mean of minute estimates are shown separately.
This is a retrospective analysis view, not proof of a common source or nuisance.
The comparison line does not change the capture detector's separate setting.

Source hints overlapping an episode are shown with their recorded intervals.
Coverage is the union of clipped intervals, not a sum that double-counts overlaps.
No saved hints means missing evidence; it does not mean absence of sound. The old
24-hour build cannot supply source history that it never persisted.

A local event threshold is now respected unless an assigned site policy explicitly
supplies day/night values. The settings page exposes the threshold independently
of the disabled raw-audio recording controls. It takes effect on the next capture
start. Detection still uses its rolling average, minimum-duration and reportability
rules; the retrospective grouping is not identical to upload-event segmentation.

The private report accepts `--database <private-backup.db>` as an alternative to
ADB. It retains the original test window and latest-minute exclusion. Personal
measurements, screenshots and receipts stay outside Git. The new Pixel package is
`dev.moinsen.noisenet_mobile.episodetest`, built with
`NOISENET_TEST_APP_SUFFIX=episodetest scripts/build-mobile-android.sh --target
integration_test/fieldtest_main.dart --dart-define-from-file=<private-defines>`.
Existing ordinary and `.fieldtest` installations remain unchanged. This debug
package and private certificate are not release artifacts.

Current physical acceptance evidence and remaining limits: `../current-status.md`.

## Explicit full-history export and bounded long-run checks

The history toolbar exports its selected window as
`opennoisenet.private_history.v1` JSON after an explicit plaintext warning and
the native file picker. It contains completed minutes, clipped model-hint
intervals, derived episodes and comparison settings. It excludes diary text,
coordinates, device identifiers, credentials and audio. The saved file is
unencrypted; there is no automatic upload. Cancelling does not save a file.
The measurement method was not stored in every historical minute, so exports
explicitly retain that limitation rather than relabelling old values as RMS.

Create an offline report from an explicitly saved private export:

```sh
python3 scripts/fieldtest-level-chart.py \
  --history-export /private/path/history.json \
  --output /private/path/pegelverlauf.html
```

For the dedicated test packages, `private-fieldtest-monitor.py` selects one
backend device and records PID changes, RSS, heartbeat/minute age, capture and
inference counters, encrypted history row counts and matching local/server
receipts. Stale data is an independent failure signal even when a foreground
service remains present. A successful process recovery still counts as an
interruption; missing in-memory samples/events cannot be reconstructed.

The finite private runner uses saved configuration and script hashes, stops
only the selected test sensor through its notification stop path at the
deadline, allows one minute for finalization, and archives app data. A failed
graceful stop does not fall back to force-stop. `private-fieldtest-finish.py`
creates an offline chart from completed minute rows and confirmed event
segments. That automatic chart does **not** represent the full encrypted local
source history; the explicit JSON export above provides that separate view.
All run configuration, logs, receipts, archives and reports stay outside Git.
