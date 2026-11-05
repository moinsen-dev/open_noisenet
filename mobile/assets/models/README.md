# Bundled audio model

`yamnet.tflite` is Google's official MediaPipe YAMNet audio-classifier model.
It is bundled so normal monitoring remains fully offline.

- Source: `https://storage.googleapis.com/mediapipe-models/audio_classifier/yamnet/float32/latest/yamnet.tflite`
- Retrieved: 2026-08-18
- SHA-256: `4d8b4a53282dc83ef04e3e7dbc4fbc98082e34e44ed798e16c3a0cdd4c584faf`
- Input: mono Float32 waveform, 16 kHz, 15,600 samples
- Output: 521 AudioSet category scores
- Quantization: Float32 (the official current artifact is not INT8)

`yamnet_label_list.txt` is the label metadata embedded in the same official
model artifact. YAMNet's TensorFlow Model Garden source is Apache-2.0 licensed.

The model is used only as an on-device feature/category encoder. OpenNoiseNet
does not upload waveform samples or run speech recognition.
