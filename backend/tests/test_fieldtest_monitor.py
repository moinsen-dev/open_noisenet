"""The unattended test must report incomplete evidence and stop only its own app."""
import importlib.util
import json
from pathlib import Path

import pytest


@pytest.fixture
def monitor_module():
    script = Path(__file__).resolve().parents[2] / 'scripts' / 'private-fieldtest-monitor.py'
    spec = importlib.util.spec_from_file_location('noisenet_fieldtest_monitor', script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_summary_reports_missing_evidence_without_claiming_delivery(tmp_path, monitor_module):
    path = tmp_path / 'observations.jsonl'
    records = [
        {'at_utc': '2026-11-03T17:00:00+00:00', 'backend_healthy': True,
         'device': {'last_heartbeat': '2026-11-03T16:59:45+00:00', 'captured_sample_count': '40', 'events': 0, 'queued_events': '0'},
         'usb_powered': 'true', 'ac_powered': 'false'},
        {'at_utc': '2026-11-03T17:05:30+00:00', 'backend_healthy': False, 'device': None},
    ]
    path.write_text(''.join(json.dumps(record) + '\n' for record in records))
    result = monitor_module.summarize(path)
    assert result['max_observation_gap_seconds'] == 330
    assert result['backend_unavailable_observations'] == 1
    assert result['device_status_missing_observations'] == 1
    assert result['battery_unplugged_observations'] == 0
    assert 'do not establish' in result['limitations']


def test_completion_stops_only_fieldtest_app(tmp_path, monkeypatch, monitor_module):
    output = tmp_path / 'run.jsonl'
    ticks = iter([0, 2])
    monkeypatch.setattr(monitor_module.time, 'monotonic', lambda: next(ticks))
    monkeypatch.setattr(monitor_module, 'snapshot', lambda *args: {
        'at_utc': '2026-11-03T17:00:00+00:00', 'adb_available': True,
        'backend_healthy': True, 'device': None,
    })
    calls = []
    def fake_command(args, timeout=12):
        calls.append(args)
        if 'get-state' in args:
            return 'device'
        if 'pidof' in args:
            return None
        return ''
    monkeypatch.setattr(monitor_module, 'command', fake_command)
    monkeypatch.setattr('sys.argv', ['monitor', '--serial', 'test', '--postgres-container', 'test',
                                     '--output', str(output), '--duration-seconds', '1', '--stop-app-at-end'])
    monitor_module.main()
    summary = json.loads(Path(str(output) + '.summary.json').read_text())
    assert summary['field_test_app_stopped'] is True
    assert ['adb', '-s', 'test', 'shell', 'am', 'force-stop', 'dev.moinsen.noisenet_mobile.fieldtest'] in calls


def test_restarted_service_without_capture_is_reported_stale(tmp_path, monitor_module):
    records = [
        {'at_utc': '2026-11-05T10:00:00+00:00', 'app_pid': '101',
         'device': {'last_heartbeat': '2026-11-05T10:00:00+00:00', 'captured_sample_count': '400'}},
        {'at_utc': '2026-11-05T10:05:00+00:00', 'app_pid': '202',
         'app_process_alive': True, 'sensor_service_running': True,
         'device': {'last_heartbeat': '2026-11-05T10:00:00+00:00', 'captured_sample_count': '400'},
         'local': {'last_minute': 1793872800}},
    ]
    path = tmp_path / 'run.jsonl'
    path.write_text(''.join(json.dumps(r) + '\n' for r in records))
    result = monitor_module.summarize(path)
    assert result['observed_process_changes'] == 1
    assert result['stale_heartbeat_observations'] == 1
    assert result['sample_counter_unchanged_intervals'] == 1
    assert 'heartbeat_stale' in monitor_module.health_evidence(records[1])['problems']


def test_graceful_stop_targets_only_selected_package_without_force_fallback(monkeypatch, monitor_module):
    calls = []
    def fake(args, timeout=12):
        calls.append(args)
        return 'No services' if 'dumpsys' in args else 'Starting service'
    monkeypatch.setattr(monitor_module, 'command', fake)
    package = 'dev.moinsen.noisenet_mobile.episodetest'
    assert monitor_module.stop_capture('pixel', package, True) is True
    assert calls[0][5:8] == [package, '/system/bin/am', 'startservice']
    assert 'notify_flutter' in calls[0]
    assert not any('force-stop' in call for call in calls)
    monkeypatch.setattr(monitor_module, 'command', lambda *a: None)
    assert monitor_module.stop_capture('pixel', package, True) is None
    with pytest.raises(ValueError):
        monitor_module.stop_capture('pixel', 'dev.moinsen.noisenet_mobile', True)


def test_receipts_use_server_id_and_selected_device_not_other_test_devices(monkeypatch, monitor_module):
    monkeypatch.setattr(monitor_module, 'local_evidence', lambda *a: {'receipts': [
        {'event_uuid': 'event-1', 'serverEventId': 'server-1', 'lifecycleState': 'acknowledged_by_server'},
        {'event_uuid': 'event-2', 'serverEventId': 'server-2', 'lifecycleState': 'acknowledged_by_server'},
    ]})
    sqls = []
    def fake(args, timeout=12):
        if 'get-state' in args:
            return 'device'
        if args[0] == 'docker':
            sqls.append(args[-1])
            if 'e.event_uuid' in args[-1]:
                return json.dumps({'event_uuid': 'event-1', 'id': 'server-1'})
            return json.dumps({'events': 1, 'is_public': False})
        return ''
    monkeypatch.setattr(monitor_module, 'command', fake)
    monkeypatch.setattr(monitor_module.urllib.request, 'urlopen', lambda *a, **k: (_ for _ in ()).throw(OSError()))
    result = monitor_module.snapshot('pixel', 'db', 1, device_id='selected-device', since=100, collect_local=True)
    assert all("d.device_id = 'selected-device'" in sql for sql in sqls)
    assert 'to_timestamp(100.0)' in sqls[-1]
    assert result['matched_acknowledgements'] == 1
    assert result['unmatched_acknowledgements'] == 1
    assert result['matching_devices'] == 1
