#!/usr/bin/env python3
"""Replay known scene schedules using measured clip classifications.

This is a score replay, NOT a continuous 33-minute audio/room experiment.
Both probes use the same Dart app engine. No device or service is contacted.
"""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    args = parser.parse_args()
    root = args.root
    repo = Path(__file__).resolve().parents[1]
    comparison = json.loads((root / 'comparison.json').read_text())
    raw = json.loads((root / 'yamnet-features.json').read_text())
    labels = (repo / 'mobile/assets/models/yamnet_label_list.txt').read_text().splitlines()
    request = {'labels': labels, 'clips': [{'id': r['id'], 'yamnet': r['raw']} for r in raw['items']]}
    command = ['dart', str(repo / 'scripts/acoustic-phases.dart')]
    taxonomy = json.loads(subprocess.run(command, input=json.dumps(request), text=True,
        capture_output=True, check=True).stdout)['classifications']
    (root / 'yamnet-app-taxonomy.json').write_text(json.dumps(taxonomy, indent=2))
    manifest = json.loads((root / 'audio-manifest.json').read_text())
    heldout = {r['id']: r for r in manifest if r['split'] == 'heldout'}
    def family(category):
        return {'loud_conversation': 'speech', 'road_traffic': 'traffic', 'sawing': 'tools',
                'door_or_impact': 'impact', 'animals': 'animals'}.get(category, 'unknown')
    app_predictions = [r for r in taxonomy if r['id'] in heldout]
    app_correct = sum(r['family'] == family(heldout[r['id']]['category']) for r in app_predictions)
    scenes = []
    for name, model in comparison['models'].items():
        # Head is nearest centroid on development clips. Scores here encode its
        # decision, NOT confidence/probability from the embedding similarity.
        speech = [p['predicted'] for p in model['predictions'] if p['expected'] == 'loud_conversation']
        for case, duration in [('speech_33m', 1980), ('speech_long_pause', 900),
                               ('speech_inference_gap', 900), ('sparse_speech', 600)]:
            frames = []
            for t in range(0, duration * 1000 - 975 + 1, 480):
                if case == 'speech_inference_gap' and 400000 <= t < 410000:
                    continue
                active = ((t % 30000 < 20000 or t >= 1970000) if case == 'speech_33m'
                          else (not 300000 <= t < 480000) if case == 'speech_long_pause'
                          else t % 60000 < 1000 if case == 'sparse_speech' else True)
                scores = {speech[(t // 30000) % len(speech)]: 1.0} if active else {}
                frames.append({'start_ms': t, 'end_ms': t + 975, 'scores': scores})
            scenes.append({'id': name + ':' + case, 'frames': frames})
    result = json.loads(subprocess.run(command, input=json.dumps({'scenes': scenes}), text=True,
        capture_output=True, check=True).stdout)
    summaries = []
    for scene in result['scenes']:
        speech = [p for p in scene['phases'] if p['family'] == 'speech']
        summaries.append({'id': scene['id'], 'speech_phases': len(speech),
            'longest_speech_seconds': max((p['end_ms']-p['start_ms'] for p in speech), default=0)/1000,
            'source_segments': scene['source_segment_count']})
    result.update(summaries=summaries, yamnet_existing_head_family_correct=app_correct,
                  heldout_total=len(heldout),
                  limitation='Deterministic score replay of repeated short clips, no long continuous audio inference')
    (root / 'scene-replay.json').write_text(json.dumps(result, indent=2))
    print(json.dumps({'replay': summaries, 'yamnet_existing_head_family_correct': app_correct,
                      'heldout_total': len(heldout)}, indent=2))


if __name__ == '__main__':
    main()
