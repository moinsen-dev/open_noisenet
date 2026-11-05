import datetime as dt
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('fieldtest_level_chart', Path(__file__).resolve().parents[1] / 'fieldtest-level-chart.py')
chart = importlib.util.module_from_spec(spec)
spec.loader.exec_module(chart)


class FieldtestChartTest(unittest.TestCase):
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
