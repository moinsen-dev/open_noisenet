#!/usr/bin/env python3
"""Produce a local post-run report from the selected test app and server only.

The encrypted on-device source history stays encrypted. Only confirmed event
segments are available to this offline chart; it must not claim full coverage.
"""
import argparse
import datetime as dt
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import tarfile


def private_json(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'w') as target:
        json.dump(data, target, indent=2)


def source_hints(events, start, end):
    result = {}
    for event in events:
        for segment in (event.get('event_metadata') or {}).get('source_activity', {}).get('segments', []):
            left = max(start, dt.datetime.fromisoformat(segment['start'].replace('Z', '+00:00')))
            right = min(end, dt.datetime.fromisoformat(segment['end'].replace('Z', '+00:00')))
            category, confidence = segment['category'], segment['confidence']
            if not re.fullmatch(r'[a-z_]{1,80}', category) or not math.isfinite(confidence) or not 0 <= confidence <= 1:
                raise ValueError('Invalid source hint')
            if right <= left:
                continue
            duration = round((right - left).total_seconds() * 1000)
            result[(left, right, category)] = {
                'observed_end': right.timestamp(), 'duration_ms': duration,
                'category': category, 'confidence_pct': round(confidence * 100),
            }
    return sorted(result.values(), key=lambda item: item['observed_end'])


def finish(config):
    root = Path(config['directory'])
    start, end = (dt.datetime.fromisoformat(config[key]) for key in ('start_utc', 'end_utc'))
    if start.tzinfo is None or end.tzinfo is None or end <= start:
        raise ValueError('Invalid capture window')
    device = config['device_id']
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,150}', device):
        raise ValueError('Invalid device identifier')
    # Configuration contains identifiers only. PostgreSQL credentials stay in
    # the existing container environment, never in a command argument or report.
    sql = f"""SELECT row_to_json(s) FROM (
        SELECT e.id,e.event_uuid,e.timestamp_start,e.timestamp_end,
        e.classification_source,e.event_metadata
        FROM events e JOIN devices d ON d.id=e.device_id
        WHERE d.device_id='{device}'
        AND e.timestamp_start >= to_timestamp({start.timestamp()})
        AND e.timestamp_start < to_timestamp({end.timestamp()})
        ORDER BY e.timestamp_start
    ) s;"""
    shell = 'export PGPASSWORD="$POSTGRES_PASSWORD"; psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "$1"'
    received = subprocess.check_output(['docker', 'exec', config['postgres_container'],
                                       'sh', '-c', shell, 'field-finish', sql], timeout=25, text=True)
    events = [json.loads(line) for line in received.splitlines()]
    private_json(root / 'confirmed-events.json', events)
    hints = source_hints(events, start, end)
    private_json(root / 'upload-source-hints.json', {'origin': 'confirmed_event_segments_only', 'segments': hints})
    with tarfile.open(root / 'after-capture-app.tar') as archive:
        data = archive.extractfile('./app_flutter/noisenet.db').read()
    connection = sqlite3.connect(':memory:')
    try:
        connection.deserialize(data)
        if connection.execute('pragma integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Archived minute database integrity failed')
        saved = connection.execute('SELECT timestamp,leq_db,lmax_db,samples_count FROM noise_measurements ORDER BY timestamp,id').fetchall()
    finally:
        connection.close()
    chart_path = Path(__file__).with_name('fieldtest-level-chart.py')
    spec = importlib.util.spec_from_file_location('chart', chart_path)
    chart = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(chart)
    saved = [row for row in saved if row[0] < saved[-1][0]] if saved else []
    rows = chart.filtered(saved, start, end)
    if not rows:
        raise ValueError('No completed minutes in capture window')
    document = chart.make_html(rows, start, end, hints, 'pcm_rms_unweighted_v1',
                               'event_receipts', config['comparison_line'], config['pause_minutes'])
    fd = os.open(root / 'pegelverlauf.html', os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'w') as target:
        target.write(document)
    # Use exactly the tested grouping code embedded in the interactive report.
    script = "const fs=require('fs'),{findEpisodes}=require(process.argv[1]);const d=JSON.parse(fs.readFileSync(0,'utf8'));console.log(JSON.stringify(findEpisodes(d.rows,d.line,d.pause).map(({rows,...b})=>b)));"
    episodes = json.loads(subprocess.check_output(
        ['node', '-e', script, str(Path(__file__).with_name('noise-episodes.js'))],
        input=json.dumps({'rows': rows, 'line': config['comparison_line'], 'pause': config['pause_minutes']}),
        text=True, timeout=20))
    summary = {
        'start_utc': start.isoformat(), 'end_utc': end.isoformat(),
        'completed_minutes': len(rows), 'comparison_line': config['comparison_line'],
        'max_pause_minutes': config['pause_minutes'], 'episodes': episodes,
        'server_events': len(events), 'source_segments_in_uploads': len(hints),
        'duplicate_server_uuids': len(events) - len({e['event_uuid'] for e in events}),
        'inference_health_summary': json.loads((root / 'monitor-inference.jsonl.summary.json').read_text())
            if (root / 'monitor-inference.jsonl.summary.json').exists() else None,
        'limitations': 'Uncalibrated RMS estimates. Episodes are analysis aids, not proven disturbance or causes. Chart source hints come only from confirmed uploads and are incomplete. The full encrypted device history remains in the device/archive; no audio is included.',
    }
    private_json(root / 'episode-summary.json', summary)
    return {'report_created': True, 'completed_minutes': len(rows), 'episodes': len(episodes),
            'server_events': len(events), 'source_segments_in_uploads': len(hints)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    try:
        result = finish(config)
    except Exception as error:
        result = {'report_created': False, 'error_type': type(error).__name__, 'error': str(error)}
    private_json(Path(config['directory']) / 'report-status.json', result)
    print(json.dumps(result))
    raise SystemExit(0 if result['report_created'] else 1)
