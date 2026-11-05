#!/usr/bin/env python3
"""Collect minimal health counters for a time-bounded private Android field test."""

import argparse
import datetime
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import time
import urllib.request
import xml.etree.ElementTree as ET

TEST_PACKAGES = ('dev.moinsen.noisenet_mobile.fieldtest',
                 'dev.moinsen.noisenet_mobile.episodetest')


def command(args, timeout=12):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=True)
        return result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None


def binary_command(args):
    return subprocess.run(args, capture_output=True, timeout=25, check=True).stdout


def local_evidence(serial, package, since=None):
    """Read counters and receipts, never decrypt the device-bound source history.

    Live copies are not transactional backups. Integrity errors are reported;
    final archives are taken separately after graceful capture shutdown.
    """
    adb = ['adb', '-s', serial, 'exec-out', 'run-as', package, 'cat']
    evidence = {}
    for filename, label in [('app_flutter/noisenet.db', 'minutes'),
                            ('databases/personal_noise_diary.db', 'history')]:
        connection = sqlite3.connect(':memory:')
        try:
            connection.deserialize(binary_command(adb + [filename]))
            if connection.execute('pragma integrity_check').fetchone()[0] != 'ok':
                raise ValueError('Snapshot integrity failed')
            if label == 'minutes':
                stamps = [r[0] for r in connection.execute(
                    'SELECT timestamp FROM noise_measurements WHERE timestamp >= ? ORDER BY timestamp',
                    (since or 0,))]
                evidence['minute_count'] = len(stamps)
                evidence['last_minute'] = stamps[-1] if stamps else None
                evidence['minute_gap_count'] = sum(b - a > 60 for a, b in zip(stamps, stamps[1:]))
                evidence['duplicate_minutes'] = len(stamps) - len(set(stamps))
            else:
                evidence['source_history_count'] = connection.execute('SELECT count(*) FROM source_history').fetchone()[0]
            evidence[label + '_integrity'] = 'ok'
        except (OSError, subprocess.SubprocessError, sqlite3.Error, ValueError):
            evidence[label + '_integrity'] = 'unavailable_or_inconsistent_live_copy'
        finally:
            connection.close()
    try:
        prefs = ET.fromstring(binary_command(adb + ['shared_prefs/FlutterSharedPreferences.xml']))
        evidence['history_enabled'] = any(e.attrib.get('name') == 'flutter.private_source_history_enabled_v1'
                                         and e.attrib.get('value') == 'true' for e in prefs)
        receipts = []
        for entry in prefs:
            if not entry.attrib.get('name', '').startswith('flutter.noise_events_'):
                continue
            event = json.loads(entry.text)
            stamp = event.get('timestamp_start')
            if since and stamp and datetime.datetime.fromisoformat(stamp.replace('Z', '+00:00')).timestamp() < since:
                continue
            receipts.append({key: event.get(key) for key in
                             ('event_uuid', 'serverEventId', 'lifecycleState', 'uploadAttemptCount', 'classification_source')})
        evidence['receipts'] = receipts
    except (OSError, subprocess.SubprocessError, ET.ParseError, ValueError, TypeError):
        evidence['receipts'] = None
    return evidence


def snapshot(serial, container, backend_port, package=TEST_PACKAGES[0], device_id=None,
             since=None, collect_local=False):
    record = {'at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    record['adb_available'] = command(['adb', '-s', serial, 'get-state']) == 'device'
    if record['adb_available']:
        record['app_pid'] = command(['adb', '-s', serial, 'shell', 'pidof', package])
        record['app_process_alive'] = bool(record['app_pid'])
        if record['app_pid'] and record['app_pid'].isdigit():
            process_status = command(['adb', '-s', serial, 'shell', 'run-as', package,
                                      'cat', '/proc/' + record['app_pid'] + '/status']) or ''
            rss = re.search(r'^VmRSS:\s+(\d+)\s+kB', process_status, re.MULTILINE)
            record['app_rss_kb'] = int(rss.group(1)) if rss else None
        service = command(['adb', '-s', serial, 'shell', 'dumpsys', 'activity', 'services', package])
        record['sensor_service_running'] = 'NoiseMonitoringService' in (service or '')
        battery = command(['adb', '-s', serial, 'shell', 'dumpsys', 'battery']) or ''
        for line in battery.splitlines():
            key, separator, value = line.strip().partition(': ')
            if separator and key in {'level', 'temperature', 'USB powered', 'AC powered'}:
                record[key.lower().replace(' ', '_')] = value
        if collect_local:
            record['local'] = local_evidence(serial, package, since)
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{backend_port}/health', timeout=4) as response:
            record['backend_healthy'] = response.status == 200
    except OSError:
        record['backend_healthy'] = False
    if device_id and not re.fullmatch(r'[A-Za-z0-9_-]{1,150}', device_id):
        raise ValueError('Invalid device identifier')
    where = "d.device_id = '" + device_id + "'" if device_id else "d.device_id <> 'synthetic-backup-check'"
    sql = """SELECT row_to_json(s) FROM (
        SELECT d.last_heartbeat, d.is_public,
        d.location_lat IS NULL AND d.location_lng IS NULL AS no_location,
        d.hardware_info::jsonb->'last_runtime_status'->>'captured_sample_count' AS captured_sample_count,
        d.hardware_info::jsonb->'last_runtime_status'->>'queued_events' AS queued_events,
        d.hardware_info::jsonb->'last_runtime_status'->>'restart_count' AS restart_count,
        d.hardware_info::jsonb->'last_runtime_status'->>'time_since_last_sample_ms' AS sample_age_ms,
        d.hardware_info::jsonb->'last_runtime_status'->'sound_analysis'->>'inference_count' AS inference_count,
        d.hardware_info::jsonb->'last_runtime_status'->'sound_analysis'->>'dropped_windows' AS dropped_windows,
        d.hardware_info::jsonb->'last_runtime_status'->'sound_analysis'->>'running' AS inference_running,
        (SELECT count(*) FROM events e WHERE e.device_id=d.id) AS events
        FROM devices d WHERE """ + where + ") s;"
    shell = 'export PGPASSWORD="$POSTGRES_PASSWORD"; psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "$1"'
    output = command(['docker', 'exec', container, 'sh', '-c', shell, 'field-monitor', sql])
    try:
        records = [json.loads(line) for line in (output or '').splitlines()]
        record['device'] = records[0] if len(records) == 1 else None
        record['matching_devices'] = len(records)
    except ValueError:
        record['device'] = None
    if collect_local and device_id:
        cutoff = float(since or 0)
        receipt_sql = """SELECT row_to_json(s) FROM (
            SELECT e.event_uuid, e.id, e.classification_source,
            COALESCE(jsonb_array_length(e.event_metadata::jsonb->'source_activity'->'segments'), 0) AS source_segments
            FROM events e JOIN devices d ON d.id=e.device_id WHERE """ + where + f" AND e.timestamp_start >= to_timestamp({cutoff})" + ") s;"
        received = command(['docker', 'exec', container, 'sh', '-c', shell, 'field-monitor', receipt_sql])
        try:
            record['server_receipts'] = [json.loads(line) for line in received.splitlines()] if received is not None else None
        except ValueError:
            record['server_receipts'] = None
        local = record.get('local', {}).get('receipts')
        if local is not None and record['server_receipts'] is not None:
            pairs = {(str(e['event_uuid']), str(e['id'])) for e in record['server_receipts']}
            acknowledged = [e for e in local if e.get('lifecycleState') == 'acknowledged_by_server']
            record['matched_acknowledgements'] = sum((str(e['event_uuid']), str(e['serverEventId'])) in pairs for e in acknowledged)
            record['unmatched_acknowledgements'] = len(acknowledged) - record['matched_acknowledgements']
            record['duplicate_server_uuids'] = len(record['server_receipts']) - len({e['event_uuid'] for e in record['server_receipts']})
    record['health'] = health_evidence(record)
    return record


def health_evidence(record):
    """Freshness is observed separately from mere process/service presence."""
    observed = datetime.datetime.fromisoformat(record['at_utc'])
    device = record.get('device') or {}
    heartbeat_age = None
    if device.get('last_heartbeat'):
        heartbeat_age = max(0, (observed - datetime.datetime.fromisoformat(
            device['last_heartbeat'])).total_seconds())
    minute = (record.get('local') or {}).get('last_minute')
    minute_age = max(0, observed.timestamp() - minute) if minute else None
    problems = []
    if heartbeat_age is None:
        problems.append('heartbeat_unavailable')
    elif heartbeat_age > 180:
        problems.append('heartbeat_stale')
    if minute_age is not None and minute_age > 180:
        problems.append('minute_data_stale')
    sample_age = device.get('sample_age_ms')
    if sample_age is not None and str(sample_age).isdigit() and int(sample_age) > 20000:
        problems.append('capture_stale_at_heartbeat')
    return {'heartbeat_age_seconds': heartbeat_age, 'minute_age_seconds': minute_age,
            'problems': problems}


def stop_capture(serial, package, graceful):
    """A graceful stop finalizes an open event; force-stop would discard it."""
    if package not in TEST_PACKAGES:
        raise ValueError('Only dedicated test packages may be stopped')
    if graceful:
        result = command(['adb', '-s', serial, 'shell', 'run-as', package,
                          '/system/bin/am', 'startservice', '--user', '0',
                          '-n', package + '/dev.moinsen.noisenet_mobile.NoiseMonitoringService',
                          '-a', 'STOP_MONITORING', '--ez', 'notify_flutter', 'true'])
        if result is None:
            return None  # Do not silently fall back to destructive force-stop.
        for _ in range(15):
            service = command(['adb', '-s', serial, 'shell', 'dumpsys', 'activity', 'services', package])
            if service is not None and 'NoiseMonitoringService' not in service:
                return True
            time.sleep(1)
        return False
    result = command(['adb', '-s', serial, 'shell', 'am', 'force-stop', package])
    if result is not None and command(['adb', '-s', serial, 'get-state']) == 'device':
        return not bool(command(['adb', '-s', serial, 'shell', 'pidof', package]))
    return None


def private_archive(serial, package, directory):
    """Preserve encrypted history, settings and minutes outside the repository."""
    destination = Path(directory) / 'after-capture-app.tar'
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, 'wb') as output:
            subprocess.run(['adb', '-s', serial, 'exec-out', 'run-as', package,
                            'tar', '-cf', '-', '.'], stdout=output,
                           stderr=subprocess.PIPE, timeout=120, check=True)
        return str(destination)
    except (OSError, subprocess.SubprocessError):
        return None


def summarize(path):
    """Describe measured evidence without inferring data loss or calibration."""
    with open(path) as source:
        records = [json.loads(line) for line in source if line.strip()]
    times = [datetime.datetime.fromisoformat(item['at_utc']) for item in records]
    gaps = [(later - earlier).total_seconds() for earlier, later in zip(times, times[1:])]
    devices = [item['device'] for item in records if item.get('device') is not None]
    samples = [int(item['captured_sample_count']) for item in devices if str(item.get('captured_sample_count') or '').isdigit()]
    inferences = [int(item['inference_count']) for item in devices if str(item.get('inference_count') or '').isdigit()]
    heartbeat_ages = []
    active_records = [r for r in records if r.get('phase') != 'after_capture']
    pids = [r['app_pid'] for r in active_records if r.get('app_pid')]
    problems = [health_evidence(r)['problems'] for r in active_records]
    rss_values = [r['app_rss_kb'] for r in active_records if r.get('app_rss_kb') is not None]
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
        'observed_process_changes': sum(a != b for a, b in zip(pids, pids[1:])),
        'max_observed_app_rss_kb': max(rss_values) if rss_values else None,
        'stale_heartbeat_observations': sum('heartbeat_stale' in p for p in problems),
        'stale_minute_observations': sum('minute_data_stale' in p for p in problems),
        'sample_counter_unchanged_intervals': sum(b == a for a, b in zip(samples, samples[1:])),
        'sample_counter_decreases': sum(later < earlier for earlier, later in zip(samples, samples[1:])),
        'first_sample_count': samples[0] if samples else None,
        'last_sample_count': samples[-1] if samples else None,
        'first_inference_count': inferences[0] if inferences else None,
        'last_inference_count': inferences[-1] if inferences else None,
        'inference_counter_decreases': sum(b < a for a, b in zip(inferences, inferences[1:])),
        'inference_counter_unchanged_intervals': sum(b == a for a, b in zip(inferences, inferences[1:])),
        'last_event_count': devices[-1].get('events') if devices else None,
        'last_queue_count': devices[-1].get('queued_events') if devices else None,
        'adb_unavailable_observations': sum(not item.get('adb_available') for item in records),
        'sensor_absent_observations': sum(item.get('adb_available') is True and item.get('sensor_service_running') is False
                                         for item in records if item.get('phase') != 'after_capture'),
        'last_local_evidence': next((item['local'] for item in reversed(records) if item.get('local')), None),
        'last_matched_acknowledgements': next((item['matched_acknowledgements'] for item in reversed(records) if 'matched_acknowledgements' in item), None),
        'last_unmatched_acknowledgements': next((item['unmatched_acknowledgements'] for item in reversed(records) if 'unmatched_acknowledgements' in item), None),
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
    parser.add_argument('--package', choices=TEST_PACKAGES, default=TEST_PACKAGES[0])
    parser.add_argument('--device-id', help='Explicit backend device_id; required if multiple devices exist')
    parser.add_argument('--start-utc', help='Capture-window start; excludes earlier local events/minutes')
    parser.add_argument('--collect-local', action='store_true')
    parser.add_argument('--graceful-stop', action='store_true', help='Finalize the open event instead of force-stopping')
    parser.add_argument('--archive-at-end', action='store_true', help='Save private app archive alongside the monitor output')
    args = parser.parse_args()
    if args.duration_seconds <= 0 or args.interval_seconds <= 0:
        parser.error('Duration and interval must be positive')
    if args.device_id and not re.fullmatch(r'[A-Za-z0-9_-]{1,150}', args.device_id):
        parser.error('Invalid device identifier')
    if args.graceful_stop and not args.stop_app_at_end:
        parser.error('Graceful stop requires --stop-app-at-end')
    since = datetime.datetime.fromisoformat(args.start_utc).timestamp() if args.start_utc else None
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
            record = snapshot(args.serial, args.postgres_container, args.backend_port,
                              args.package, args.device_id, since, args.collect_local)
            record['complete'] = time.monotonic() >= deadline
            output.write(json.dumps(record, sort_keys=True) + '\n')
            if record['complete']:
                stopped = None
                if args.stop_app_at_end and record['adb_available']:
                    stopped = stop_capture(args.serial, args.package, args.graceful_stop)
                    if args.graceful_stop and stopped:
                        # Allow event finalization/receipt and the next heartbeat.
                        time.sleep(60)
                        final = snapshot(args.serial, args.postgres_container, args.backend_port,
                                         args.package, args.device_id, since, args.collect_local)
                        final['phase'] = 'after_capture'
                        output.write(json.dumps(final, sort_keys=True) + '\n')
                archive = private_archive(args.serial, args.package, Path(args.output).parent) if args.archive_at_end and stopped else None
                summary_path = args.output + '.summary.json'
                summary_fd = os.open(summary_path, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
                with os.fdopen(summary_fd, 'w') as summary_file:
                    summary = summarize(args.output)
                    summary['field_test_app_stopped'] = stopped
                    summary['stop_method'] = 'graceful_sensor_stop' if args.graceful_stop else 'force_stop'
                    summary['planned_end_utc'] = args.end_utc
                    summary['archive'] = archive
                    json.dump(summary, summary_file, indent=2, sort_keys=True)
                    summary_file.write('\n')
                return
            time.sleep(min(args.interval_seconds, max(deadline - time.monotonic(), 0)))


if __name__ == '__main__':
    main()
