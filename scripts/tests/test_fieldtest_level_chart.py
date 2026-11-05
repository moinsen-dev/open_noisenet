import datetime as dt
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import contextlib
import io
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('fieldtest_level_chart', Path(__file__).resolve().parents[1] / 'fieldtest-level-chart.py')
chart = importlib.util.module_from_spec(spec)
spec.loader.exec_module(chart)


class FieldtestChartTest(unittest.TestCase):
    def test_source_phases_clip_activity_not_just_parent_and_reject_overlap(self):
        start = dt.datetime.fromtimestamp(30, dt.timezone.utc)
        end = dt.datetime.fromtimestamp(150, dt.timezone.utc)
        exported = {'acoustic_phases': [{'algorithm': 'source_phases_v1', 'family': 'speech',
            'activity': [{'start_ms': 0, 'end_ms': 60000}, {'start_ms': 80000, 'end_ms': 180000}]}]}
        phases = chart.clipped_source_phases(exported, start, end)
        self.assertEqual(phases[0]['active_ms'], 100000)
        self.assertEqual(phases[0]['pause_ms'], 20000)
        self.assertEqual(phases[0]['start_ms'], 30000)
        self.assertEqual(phases[0]['end_ms'], 150000)
        html = chart.make_html([[60, 20, None, 10]], start, end, acoustic_phases=phases)
        self.assertIn('source-phases', html)
        self.assertIn('"active_ms":100000', html)
        exported['acoustic_phases'][0]['activity'][1]['start_ms'] = 50000
        with self.assertRaises(ValueError):
            chart.clipped_source_phases(exported, start, end)

    def test_app_export_cli_preserves_parameters_and_requires_no_adb(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, output = Path(tmp) / 'history.json', Path(tmp) / 'report.html'
            source.write_text(json.dumps({'schema': 'opennoisenet.private_history.v1',
                'window_start': '1970-01-01T00:00:00+00:00',
                'window_end': '1970-01-01T00:03:00+00:00',
                'analysis': {'comparison_line': 30, 'max_pause_minutes': 1},
                'source_hints': [], 'minutes': [{'timestamp': 60, 'estimated_level': 20,
                    'highest_buffer_estimate': None, 'samples_count': 100}]}))
            args = ['chart', '--history-export', str(source), '--output', str(output)]
            with patch('sys.argv', args), contextlib.redirect_stdout(io.StringIO()), patch.object(chart, 'stable_rows', side_effect=AssertionError('No ADB')):
                chart.main()
            html = output.read_text()
            self.assertIn('"comparisonLine":30', html)
            self.assertIn('"maxPauseMinutes":1', html)
            self.assertIn('"rows":[[60,20,null,100]]', html)
            self.assertNotIn('PIXEL 10A', html)
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)

    def test_device_export_preserves_missing_peaks_and_clips_source_window(self):
        start = dt.datetime.fromtimestamp(60, dt.timezone.utc)
        end = dt.datetime.fromtimestamp(180, dt.timezone.utc)
        report = {'schema': 'opennoisenet.private_history.v1', 'source_hints': [
            {'start': dt.datetime.fromtimestamp(30, dt.timezone.utc).isoformat(),
             'end': dt.datetime.fromtimestamp(240, dt.timezone.utc).isoformat(),
             'category': 'road_traffic', 'confidence': .4}]}
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / 'export.json';file.write_text(json.dumps(report))
            hints = chart.load_hints(file, start, end)
        self.assertEqual(hints[0]['duration_ms'], 120000)
        self.assertEqual(hints[0]['observed_end'], 180)
        rows = chart.filtered([(60, 20, None, 100)], start, end)
        self.assertIsNone(rows[0][2])
        html = chart.make_html(rows, start, end, hints,
                               'not_recorded_per_minute', 'device_export', 30)
        self.assertIn('Berechnungsmethode wurde nicht je Minute gespeichert', html)
        self.assertIn('Hinweise aus dem Geräteexport', html)
        self.assertNotIn('flüchtigen Diagnosepuffer', html)

    def test_new_rms_report_keeps_source_and_measurement_provenance(self):
        start = dt.datetime.fromtimestamp(0, dt.timezone.utc)
        end = dt.datetime.fromtimestamp(300, dt.timezone.utc)
        html = chart.make_html([[60, 20, 30, 10]], start, end,
                               measurement_method='pcm_rms_unweighted_v1',
                               hint_origin='event_receipts', comparison_line=30)
        self.assertIn('ohne aktive A-Bewertung', html)
        self.assertNotIn('ältere, ungeeichte Pegelberechnung', html)
        self.assertIn('Gerätehistorie ist in diesem Bericht nicht enthalten', html)
        self.assertIn('"comparisonLine":30', html)
        legacy = chart.make_html([[60, 20, 30, 10]], start, end)
        self.assertIn('pegelabhängiger Korrektur', legacy)
        with self.assertRaises(ValueError):
            chart.make_html([], start, end, comparison_line=float('nan'))

    def test_only_complete_minutes_of_test_are_included(self):
        start = dt.datetime.fromtimestamp(106, dt.timezone.utc)
        end = dt.datetime.fromtimestamp(300, dt.timezone.utc)
        rows = [(60, 30, 40, 100), (120, 31, 40, 100), (180, 32, 40, 100),
                (240, 33, 40, 100), (300, 34, 40, 100)]
        self.assertEqual([r[0] for r in chart.filtered(rows, start, end)], [120, 180, 240])

    def test_duplicate_and_invalid_minutes_are_not_silently_visualized(self):
        start = dt.datetime.fromtimestamp(0, dt.timezone.utc)
        end = dt.datetime.fromtimestamp(300, dt.timezone.utc)
        with self.assertRaises(ValueError):
            chart.filtered([(60, 1, 2, 3), (60, 1, 2, 3)], start, end)
        with self.assertRaises(ValueError):
            chart.filtered([(120, float('nan'), 2, 3)], start, end)

    def test_snapshot_disagreement_fails_closed_and_newest_minute_is_excluded(self):
        first = [(60, 1, 2, 3), (120, 2, 3, 4)]
        with patch.object(chart, 'read_snapshot', side_effect=[first, first]):
            self.assertEqual(chart.stable_rows('serial'), [first[0]])
        changed = [(60, 9, 2, 3), (120, 2, 3, 4)]
        with patch.object(chart, 'read_snapshot', side_effect=[first, changed] * 3):
            with self.assertRaises(RuntimeError):
                chart.stable_rows('serial')

    def test_untrusted_hints_are_validated_and_limited_to_test_period(self):
        start = dt.datetime.fromtimestamp(100, dt.timezone.utc)
        end = dt.datetime.fromtimestamp(200, dt.timezone.utc)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'hints.json'
            valid = {'observed_end': 150, 'category': 'road_traffic',
                     'duration_ms': 2000, 'confidence_pct': 30}
            path.write_text(json.dumps({'segments': [valid, {**valid, 'observed_end': 99}]}))
            self.assertEqual(chart.load_hints(path, start, end), [valid])
            path.write_text(json.dumps({'segments': [{**valid, 'category': '<script>'}]}))
            with self.assertRaises(ValueError):
                chart.load_hints(path, start, end)


if __name__ == '__main__':
    unittest.main()
