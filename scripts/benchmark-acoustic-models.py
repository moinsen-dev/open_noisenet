#!/usr/bin/env python3
"""Bounded offline comparison. Never accesses a microphone, ADB or a server.

Input: explicit local manifest with file, sha256, category, split and
source_recording. Each model runs in a separate process for RSS measurement.
The six-class nearest-centroid probe is NOT a calibrated production head.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import time

os.environ.update(HF_HUB_OFFLINE='1', TRANSFORMERS_OFFLINE='1',
                  HF_HUB_DISABLE_PROGRESS_BARS='1', TOKENIZERS_PARALLELISM='false',
                  TF_CPP_MIN_LOG_LEVEL='2', OMP_NUM_THREADS='2')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--model', choices=['yamnet', 'gemma', 'compare'], required=True)
    parser.add_argument('--yamnet', type=Path)
    args = parser.parse_args()
    import numpy as np
    root = args.root.resolve()
    manifest = json.loads((root / 'audio-manifest.json').read_text())
    dev_ids = {r['source_recording'] for r in manifest if r['split'] == 'development'}
    test_ids = {r['source_recording'] for r in manifest if r['split'] == 'heldout'}
    if not dev_ids.isdisjoint(test_ids):
        raise ValueError('Source recording leakage between development and heldout')
    categories = sorted({r['category'] for r in manifest})

    if args.model == 'compare':
        summaries = {}
        for name in ['yamnet', 'gemma']:
            data = json.loads((root / f'{name}-features.json').read_text())
            features = {r['id']: np.array(r['vector']) for r in data['items']}
            centroids = []
            for category in categories:
                selected = [features[r['id']] for r in manifest
                            if r['split'] == 'development' and r['category'] == category]
                if len(selected) < 2:
                    raise ValueError('Need two development examples per category')
                center = np.mean(selected, axis=0)
                centroids.append(center / max(np.linalg.norm(center), 1e-12))
            centroids = np.stack(centroids)
            predictions = []
            for row in manifest:
                if row['split'] != 'heldout':
                    continue
                scores = centroids @ features[row['id']]
                order = np.argsort(scores)[::-1]
                predictions.append({'id': row['id'], 'expected': row['category'],
                                    'predicted': categories[order[0]],
                                    'similarity': float(scores[order[0]]),
                                    'margin': float(scores[order[0]] - scores[order[1]])})
            correct = sum(p['expected'] == p['predicted'] for p in predictions)
            summaries[name] = {'correct': correct, 'total': len(predictions),
                               'predictions': predictions, 'runtime': data['runtime']}
        report = {'protocol': 'closed-set six-class nearest-centroid; two development clips per class',
                  'same_audio_samples': 77040, 'sample_rate': 16000,
                  'temporal_test': 'separate score replay through the exact Dart app engine',
                  'limitations': ['Small diagnostic set, not general accuracy',
                                  'Speech is synthetic monologue, not natural conversation or TV',
                                  'YAMNet features are mean class scores, not hidden embeddings',
                                  'CPU desktop timings are not Pixel energy, thermal or runtime evidence',
                                  'Model pretraining may include public evaluation material; unknown'],
                  'models': summaries}
        (root / 'comparison.json').write_text(json.dumps(report, indent=2))
        print(json.dumps({k: {'correct': v['correct'], 'total': v['total'],
                              'runtime': v['runtime']} for k, v in summaries.items()}, indent=2))
        return

    import soundfile as sf
    from scipy.signal import resample_poly
    import math
    started = time.monotonic()
    if args.model == 'yamnet':
        import tensorflow as tf
        interpreter = tf.lite.Interpreter(model_path=str(args.yamnet), num_threads=2)
        interpreter.allocate_tensors()
        inp, out = interpreter.get_input_details()[0], interpreter.get_output_details()[0]
        def encode(wave):
            outputs = []
            for t in range(0, len(wave) - 15600 + 1, 7680):
                interpreter.set_tensor(inp['index'], wave[t:t+15600].reshape(inp['shape']))
                interpreter.invoke()
                outputs.append(interpreter.get_tensor(out['index']).reshape(-1))
            return np.mean(outputs, axis=0)
        model_hash = hashlib.sha256(args.yamnet.read_bytes()).hexdigest()
    else:
        import torch
        from transformers import AutoConfig, AutoModel, AutoProcessor
        torch.set_num_threads(2)
        model_path = root / 'embeddinggemma-2'
        config = AutoConfig.from_pretrained(model_path, local_files_only=True)
        config.vision_config = None
        processor = AutoProcessor.from_pretrained(model_path, local_files_only=True)
        model = AutoModel.from_pretrained(model_path, config=config,
            local_files_only=True, dtype=torch.float32).eval()
        def encode(wave):
            inputs = processor(audio=[wave], sampling_rate=16000, return_tensors='pt')
            with torch.inference_mode():
                hidden = model(**inputs).last_hidden_state
                mask = inputs['attention_mask'].unsqueeze(-1)
                return ((hidden * mask).sum(1) / mask.sum(1)).numpy()[0]
        model_hash = json.loads((model_path / 'revision.json').read_text())['revision']
    load_seconds = time.monotonic() - started
    results, timings = [], []
    # Warmup outside reported per-clip timings, including lazy native kernels.
    encode(np.zeros(77040, dtype=np.float32))
    for row in manifest:
        path = Path(row['file'])
        if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
            raise ValueError('Audio hash mismatch: ' + row['id'])
        wave, sr = sf.read(path, dtype='float32')
        if wave.ndim == 2:
            wave = wave.mean(axis=1)
        gcd = math.gcd(sr, 16000)
        wave = resample_poly(wave, 16000 // gcd, sr // gcd).astype(np.float32)
        if len(wave) < 77040:
            raise ValueError('Clip shorter than identical comparison window')
        wave = wave[:77040]
        t = time.monotonic()
        raw = encode(wave)
        elapsed = time.monotonic() - t
        if not np.isfinite(raw).all() or np.linalg.norm(raw) < 1e-12:
            raise ValueError('Invalid model representation')
        vector = raw / np.linalg.norm(raw)
        results.append({'id': row['id'], 'vector': vector.tolist(), 'raw': raw.tolist(),
                        'seconds': elapsed})
        timings.append(elapsed)
        print(args.model, row['id'], round(elapsed, 3), flush=True)
    output = {'model': args.model, 'model_revision_or_hash': model_hash, 'items': results,
              'runtime': {'device': 'macOS CPU, two threads, float32', 'load_seconds': load_seconds,
                          'median_seconds_per_4_815s_clip': float(np.median(timings)),
                          'p95_seconds': float(np.quantile(timings, .95)),
                          'process_peak_rss_bytes': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}}
    (root / f'{args.model}-features.json').write_text(json.dumps(output))


if __name__ == '__main__':
    main()
