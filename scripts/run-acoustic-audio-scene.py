#!/usr/bin/env python3
"""Five-minute PCM scene, actual sliding-window inference, never audio playback.

Known schedule fixed before inference: speech 0..80 and 210..290 seconds,
with 10-second pauses every 30s and overlapping knocks at 45s and 235s.
The long gap separates the two phases. A second analysis drops 250..255s.
The source clips are public/local synthetic fixtures, never Pixel recordings.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

os.environ.update(HF_HUB_OFFLINE='1', TRANSFORMERS_OFFLINE='1',
                  HF_HUB_DISABLE_PROGRESS_BARS='1', TOKENIZERS_PARALLELISM='false',
                  TF_CPP_MIN_LOG_LEVEL='2', OMP_NUM_THREADS='2')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, required=True)
    ap.add_argument('--model', choices=['yamnet', 'gemma'], required=True)
    ap.add_argument('--matched-windows', action='store_true',
                    help='Fit development centroids on the same 975ms windows as inference')
    args = ap.parse_args()
    import numpy as np
    import soundfile as sf
    from scipy.signal import resample_poly
    import math
    root = args.root
    repo = Path(__file__).resolve().parents[1]
    manifest = json.loads((root / 'audio-manifest.json').read_text())
    speech = next(r for r in manifest if r['category'] == 'loud_conversation' and r['split'] == 'heldout')
    knock = next(r for r in manifest if r['category'] == 'door_or_impact' and r['split'] == 'heldout')
    def audio(row):
        wav, sr = sf.read(row['file'], dtype='float32')
        if wav.ndim > 1:
            wav = wav.mean(1)
        gcd = math.gcd(sr, 16000)
        return resample_poly(wav, 16000//gcd, sr//gcd).astype(np.float32)
    voice, door = audio(speech), audio(knock)
    wave = np.zeros(300*16000, dtype=np.float32)
    for t in [0, 30, 60, 210, 240, 270]:
        wave[t*16000:(t+20)*16000] = np.resize(voice, 20*16000) * .6
    for t in [45, 235]:
        wave[t*16000:t*16000+len(door)] += door * .35
    np.clip(wave, -1, 1, out=wave)
    # The fixture is generated deterministically; it is not a saved user recording.
    sf.write(root / 'controlled-five-minute-scene.wav', wave, 16000, subtype='FLOAT')
    features = json.loads((root / f'{args.model}-features.json').read_text())
    vectors = {r['id']: np.array(r['vector']) for r in features['items']}
    categories = sorted({r['category'] for r in manifest})
    centers = []
    for category in categories:
        center = np.mean([vectors[r['id']] for r in manifest
                          if r['split'] == 'development' and r['category'] == category], axis=0)
        centers.append(center / np.linalg.norm(center))
    centers = np.stack(centers)
    if args.model == 'yamnet':
        import tensorflow as tf
        interpreter = tf.lite.Interpreter(model_path=str(repo/'mobile/assets/models/yamnet.tflite'), num_threads=2)
        interpreter.allocate_tensors()
        inp, out = interpreter.get_input_details()[0], interpreter.get_output_details()[0]
        def encode(wav):
            interpreter.set_tensor(inp['index'], wav.reshape(inp['shape']))
            interpreter.invoke()
            return interpreter.get_tensor(out['index']).reshape(-1)
    else:
        import torch
        from transformers import AutoConfig, AutoModel, AutoProcessor
        torch.set_num_threads(2)
        p = root/'embeddinggemma-2'
        config = AutoConfig.from_pretrained(p, local_files_only=True); config.vision_config = None
        processor = AutoProcessor.from_pretrained(p, local_files_only=True)
        model = AutoModel.from_pretrained(p, config=config, local_files_only=True, dtype=torch.float32).eval()
        def encode(wav):
            inputs = processor(audio=[wav], sampling_rate=16000, return_tensors='pt')
            with torch.inference_mode():
                h = model(**inputs).last_hidden_state; mask = inputs['attention_mask'].unsqueeze(-1)
                return ((h*mask).sum(1)/mask.sum(1)).numpy()[0]
    if args.matched_windows:
        fitted = {category: [] for category in categories}
        for row in manifest:
            if row['split'] != 'development':
                continue
            clip = audio(row)[:77040]
            for t in range(0, len(clip)-15600+1, 7680):
                value = encode(clip[t:t+15600])
                if not np.isfinite(value).all():
                    raise ValueError('Invalid development features')
                fitted[row['category']].append(value/max(np.linalg.norm(value),1e-12))
        centers = np.stack([np.mean(fitted[c],axis=0) for c in categories])
        centers /= np.linalg.norm(centers,axis=1,keepdims=True)
        print('Development centroids refit on 975ms windows, no heldout fitting',flush=True)
    frames, app_frames = [], []
    infer_seconds = 0; inferences = 0
    for t in range(0, len(wave)-15600+1, 7680):
        wav = wave[t:t+15600]
        row = {'start_ms': t//16, 'end_ms': (t+15600)//16}
        # Only exact generated digital silence is bypassed, identical for both.
        if np.max(np.abs(wav)) == 0:
            frames.append({**row, 'scores': {}})
            app_frames.append({**row, 'scores': {}})
            continue
        before = time.monotonic(); raw = encode(wav); infer_seconds += time.monotonic()-before
        inferences += 1
        if not np.isfinite(raw).all():
            raise ValueError('Non-finite model result')
        vector = raw / max(np.linalg.norm(raw), 1e-12)
        category = categories[int(np.argmax(centers@vector))]
        frames.append({**row, 'scores': {category: 1.0}})
        if args.model == 'yamnet':
            app_frames.append({**row, 'yamnet': raw.tolist()})
        if inferences % 50 == 0:
            print(args.model, 'actual windows', inferences, flush=True)
    scenes = [{'id': args.model+':audio_5m', 'frames': frames},
              {'id': args.model+':audio_5m_gap', 'frames': [r for r in frames if not 250000 <= r['start_ms'] < 255000]}]
    if args.model == 'yamnet':
        scenes.append({'id': 'yamnet_existing_app:audio_5m', 'frames': app_frames})
    request = {'scenes': scenes, 'labels': (repo/'mobile/assets/models/yamnet_label_list.txt').read_text().splitlines()}
    result = json.loads(subprocess.run(['dart',str(repo/'scripts/acoustic-phases.dart')],
        input=json.dumps(request), text=True, capture_output=True, check=True).stdout)
    result.update(inference_seconds=infer_seconds, inferred_windows=inferences,
                  known_schedule={'speech_phases_seconds': [[0,80],[210,290]],
                                  'knock_starts_seconds': [45,235], 'dropped_seconds': [250,255]},
                  centroid_window_ms=975 if args.matched_windows else 4815,
                  limitation='Controlled composite of repeated short clips; no natural conversation or room validation')
    suffix='-matched' if args.matched_windows else ''
    (root/f'{args.model}-audio-scene{suffix}.json').write_text(json.dumps(result,indent=2))
    print(json.dumps({ 'model':args.model,'inferences':inferences,'seconds':infer_seconds,
      'scenes':[{'id':s['id'],'speech':[[p['start_ms']/1000,p['end_ms']/1000] for p in s['phases'] if p['family']=='speech'],
                 'families':sorted({p['family'] for p in s['phases']})} for s in result['scenes']]}),flush=True)


if __name__ == '__main__':
    main()
