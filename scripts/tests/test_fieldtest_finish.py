import datetime as dt
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('finish', Path(__file__).resolve().parents[1] / 'private-fieldtest-finish.py')
finish = importlib.util.module_from_spec(spec)
spec.loader.exec_module(finish)


class FinishTest(unittest.TestCase):
    def test_clips_and_deduplicates_only_actual_uploaded_source_hints(self):
        start = dt.datetime(2026, 11, 5, 10, tzinfo=dt.timezone.utc)
        end = start + dt.timedelta(minutes=2)
        segment = {'start': (start - dt.timedelta(seconds=10)).isoformat(),
                   'end': (start + dt.timedelta(seconds=20)).isoformat(),
                   'category': 'road_traffic', 'confidence': 0.6}
        event = {'event_metadata': {'source_activity': {'segments': [segment]}}}
        result = finish.source_hints([event, event, {'event_metadata': {}}], start, end)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['duration_ms'], 20000)
        self.assertEqual(result[0]['confidence_pct'], 60)
        self.assertEqual(finish.source_hints([], start, end), [])

    def test_rejects_untrusted_categories(self):
        start = dt.datetime(2026, 11, 5, tzinfo=dt.timezone.utc)
        end = start + dt.timedelta(minutes=2)
        bad = {'event_metadata': {'source_activity': {'segments': [
            {'start': start.isoformat(), 'end': end.isoformat(), 'category': '<script>', 'confidence': 1}
        ]}}}
        with self.assertRaises(ValueError):
            finish.source_hints([bad], start, end)


if __name__ == '__main__':
    unittest.main()
