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
