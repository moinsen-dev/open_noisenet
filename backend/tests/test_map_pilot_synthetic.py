from datetime import UTC, date, datetime, timedelta

import pytest

from app.services.map_pilot_synthetic import SyntheticContribution, synthetic_week_available


WEEK = date(2026, 11, 2)
READY = datetime(2026, 11, 11, tzinfo=UTC)


@pytest.mark.parametrize("people", range(5))
def test_under_threshold_is_suppressed(people):
    records = [SyntheticContribution(str(i), WEEK) for i in range(people)]
    assert not synthetic_week_available(records, WEEK, READY)


def test_threshold_counts_people_once_and_requires_closed_week_and_delay():
    records = [SyntheticContribution(str(i), WEEK) for i in range(4)]
    records += [SyntheticContribution("0", WEEK + timedelta(days=1))]
    assert not synthetic_week_available(records, WEEK, READY)
    records.append(SyntheticContribution("4", WEEK + timedelta(days=6)))
    assert not synthetic_week_available(records, WEEK, READY - timedelta(microseconds=1))
    assert synthetic_week_available(records, WEEK, READY)
    assert not synthetic_week_available(records[:-1] + [SyntheticContribution("4", WEEK + timedelta(days=7))], WEEK, READY)


def test_rejects_arbitrary_windows_and_naive_time():
    with pytest.raises(ValueError):
        synthetic_week_available([], WEEK + timedelta(days=1), READY)
    with pytest.raises(ValueError):
        synthetic_week_available([], WEEK, READY.replace(tzinfo=None))
