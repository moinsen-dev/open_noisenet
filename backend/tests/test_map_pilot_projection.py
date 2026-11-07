"""Synthetic only: exercise API boundaries without opening the real data path."""
from datetime import UTC, date, datetime, timedelta

import pytest
from pydantic import ValidationError

from app.api.v1.endpoints.map_pilot import PublicAreaWeek, public_snapshot
from app.core.config import settings
from app.main import app
from app.services.map_pilot_projection import PrototypeContribution, prototype_projection


WEEK = date(2026, 10, 26)
READY = datetime(2026, 11, 4, tzinfo=UTC)


@pytest.mark.parametrize("people", range(5))
def test_small_groups_are_never_projected(people):
    records = [PrototypeContribution(f"test-{i}", WEEK, "high") for i in range(people)]
    assert prototype_projection(records, WEEK, READY) == []


def test_weekly_projection_weights_people_not_days_and_is_delayed():
    records = [PrototypeContribution("test-0", WEEK + timedelta(days=i), "high") for i in range(7)]
    records += [PrototypeContribution(f"test-{i}", WEEK, "low") for i in range(1, 5)]
    assert prototype_projection(records, WEEK, READY - timedelta(microseconds=1)) == []
    assert prototype_projection(records, WEEK, READY) == [{
        "area": "hamburg-eimsbuettel", "week_start": "2026-10-26", "band": "low"
    }]


def test_many_days_and_repeated_records_cannot_replace_a_fifth_person():
    records = [
        PrototypeContribution(f"test-{person}", WEEK + timedelta(days=day), "high")
        for person in range(4)
        for day in range(7)
    ]
    assert prototype_projection(records * 10, WEEK, READY) == []
    # Records in neighbouring fixed weeks cannot lift the current week over
    # the threshold, even if they belong to different synthetic identities.
    records.extend(PrototypeContribution(f"other-{i}", WEEK + timedelta(days=7), "high") for i in range(20))
    assert prototype_projection(records, WEEK, READY) == []


def test_ties_and_conflicting_days_do_not_create_a_value():
    records = [PrototypeContribution(f"test-{i}", WEEK, "low" if i < 2 else "high") for i in range(4)]
    records.append(PrototypeContribution("test-4", WEEK, "medium"))
    assert prototype_projection(records, WEEK, READY) == []
    with pytest.raises(ValueError):
        prototype_projection(records + [PrototypeContribution("test-0", WEEK, "high")], WEEK, READY)


@pytest.mark.asyncio
@pytest.mark.parametrize("people", range(6))
async def test_public_api_has_only_allowlisted_fields_with_synthetic_dependency(client, monkeypatch, people, caplog):
    monkeypatch.setattr(settings, "ENABLE_MAP_PILOT_INTAKE", True)
    records = [PrototypeContribution(f"test-{i}", WEEK, "medium") for i in range(people)]
    output = prototype_projection(records, WEEK, READY)
    app.dependency_overrides[public_snapshot] = lambda: [PublicAreaWeek(**row) for row in output]
    response = await client.get('/api/v1/map-pilot/public')
    assert response.status_code == 200
    assert response.headers['cache-control'] == 'no-store'
    expected = [{"area": "hamburg-eimsbuettel", "week_start": "2026-10-26", "band": "medium"}] if people == 5 else []
    assert response.json() == {"status": "available" if expected else "not_available", "areas": expected}
    assert 'test-' not in response.text
    assert 'test-' not in caplog.text
    if not expected:
        return
    with pytest.raises(ValidationError):
        PublicAreaWeek(**output[0], device_id='test-device')
    with pytest.raises(ValidationError):
        PublicAreaWeek(**{**output[0], 'week_start': '2026-10-27'})
