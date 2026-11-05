#!/usr/bin/env python3
"""Collect minimal health counters for a time-bounded private Android field test."""

import argparse
import datetime
import json
import os
import subprocess
import time
import urllib.request


def command(args, timeout=12):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=True)
        return result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None


def snapshot(serial, container, backend_port):
    record = {'at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    record['adb_available'] = command(['adb', '-s', serial, 'get-state']) == 'device'
    if record['adb_available']:
        record['app_process_alive'] = bool(command(['adb', '-s', serial, 'shell', 'pidof', 'dev.moinsen.noisenet_mobile.fieldtest']))
        battery = command(['adb', '-s', serial, 'shell', 'dumpsys', 'battery']) or ''
        for line in battery.splitlines():
            key, separator, value = line.strip().partition(': ')
            if separator and key in {'level', 'temperature', 'USB powered', 'AC powered'}:
                record[key.lower().replace(' ', '_')] = value
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{backend_port}/health', timeout=4) as response:
            record['backend_healthy'] = response.status == 200
    except OSError:
        record['backend_healthy'] = False
    sql = """SELECT row_to_json(s) FROM (
        SELECT d.last_heartbeat, d.is_public,
        d.location_lat IS NULL AND d.location_lng IS NULL AS no_location,
        d.hardware_info::jsonb->'last_runtime_status'->>'captured_sample_count' AS captured_sample_count,
        d.hardware_info::jsonb->'last_runtime_status'->>'queued_events' AS queued_events,
        d.hardware_info::jsonb->'last_runtime_status'->>'restart_count' AS restart_count,
        (SELECT count(*) FROM events e WHERE e.device_id=d.id) AS events
        FROM devices d WHERE d.device_id <> 'synthetic-backup-check'
    ) s;"""
    shell = 'export PGPASSWORD="$POSTGRES_PASSWORD"; psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "$1"'
    output = command(['docker', 'exec', container, 'sh', '-c', shell, 'field-monitor', sql])
    try:
        records = [json.loads(line) for line in (output or '').splitlines()]
        record['device'] = records[0] if len(records) == 1 else None
        record['matching_devices'] = len(records)
    except ValueError:
        record['device'] = None
    return record


def summarize(path):
    """Describe measured evidence without inferring data loss or calibration."""
    with open(path) as source:
        records = [json.loads(line) for line in source if line.strip()]
    times = [datetime.datetime.fromisoformat(item['at_utc']) for item in records]
    gaps = [(later - earlier).total_seconds() for earlier, later in zip(times, times[1:])]
    devices = [item['device'] for item in records if item.get('device') is not None]
    samples = [int(item['captured_sample_count']) for item in devices if str(item.get('captured_sample_count') or '').isdigit()]
    heartbeat_ages = []
    for item in records:
        device = item.get('device') or {}
        if device.get('last_heartbeat'):
            observed = datetime.datetime.fromisoformat(item['at_utc'])
            heartbeat = datetime.datetime.fromisoformat(device['last_heartbeat'])
            heartbeat_ages.append(max((observed - heartbeat).total_seconds(), 0))
    return {
        'observations': len(records),
        'first_utc': records[0]['at_utc'] if records else None,
        'last_utc': records[-1]['at_utc'] if records else None,
        'max_observation_gap_seconds': max(gaps) if gaps else None,
        'backend_unavailable_observations': sum(not item.get('backend_healthy') for item in records),
        'device_status_missing_observations': sum(item.get('device') is None for item in records),
        'max_heartbeat_age_seconds': max(heartbeat_ages) if heartbeat_ages else None,
        'sample_counter_decreases': sum(later < earlier for earlier, later in zip(samples, samples[1:])),
        'first_sample_count': samples[0] if samples else None,
        'last_sample_count': samples[-1] if samples else None,
        'last_event_count': devices[-1].get('events') if devices else None,
        'last_queue_count': devices[-1].get('queued_events') if devices else None,
        'battery_unplugged_observations': sum(item.get('usb_powered') == 'false' and item.get('ac_powered') == 'false' for item in records),
        'limitations': 'Counters do not establish acoustic accuracy, complete event delivery, or battery life.',
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--serial', required=True)
    parser.add_argument('--postgres-container', required=True)
    parser.add_argument('--backend-port', type=int, default=18190)
    parser.add_argument('--output', required=True)
    parser.add_argument('--duration-seconds', type=int, default=86400)
    parser.add_argument('--interval-seconds', type=int, default=60)
    parser.add_argument('--end-utc', help='Optional original ISO-8601 UTC deadline when resuming a run')
    parser.add_argument('--stop-app-at-end', action='store_true', help='Stop only the separate field-test app at the deadline')
    args = parser.parse_args()
    if args.duration_seconds <= 0 or args.interval_seconds <= 0:
        parser.error('Duration and interval must be positive')
    remaining = args.duration_seconds
    if args.end_utc:
        end = datetime.datetime.fromisoformat(args.end_utc)
        if end.tzinfo is None:
            parser.error('The end time must include a timezone')
        remaining = max((end - datetime.datetime.now(datetime.timezone.utc)).total_seconds(), 0)
    deadline = time.monotonic() + remaining
    descriptor = os.open(args.output, os.O_CREAT | os.O_WRONLY | os.O_APPEND, 0o600)
    with os.fdopen(descriptor, 'a', buffering=1) as output:
        while True:
            record = snapshot(args.serial, args.postgres_container, args.backend_port)
            record['complete'] = time.monotonic() >= deadline
            output.write(json.dumps(record, sort_keys=True) + '\n')
            if record['complete']:
                stopped = None
                if args.stop_app_at_end and record['adb_available']:
                    result = command(['adb', '-s', args.serial, 'shell', 'am', 'force-stop', 'dev.moinsen.noisenet_mobile.fieldtest'])
                    if result is not None and command(['adb', '-s', args.serial, 'get-state']) == 'device':
                        stopped = not bool(command(['adb', '-s', args.serial, 'shell', 'pidof', 'dev.moinsen.noisenet_mobile.fieldtest']))
                summary_path = args.output + '.summary.json'
                summary_fd = os.open(summary_path, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
                with os.fdopen(summary_fd, 'w') as summary_file:
                    summary = summarize(args.output)
                    summary['field_test_app_stopped'] = stopped
                    json.dump(summary, summary_file, indent=2, sort_keys=True)
                    summary_file.write('\n')
                return
            time.sleep(min(args.interval_seconds, max(deadline - time.monotonic(), 0)))


if __name__ == '__main__':
    main()
