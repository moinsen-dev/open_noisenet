"""Regression tests for the anonymous episode detection sweep."""

import pytest
from httpx import AsyncClient


pytestmark = pytest.mark.asyncio


def _event_payload(device_id: str, event_uuid: str, start: str, end: str) -> dict:
    return {
        "event_uuid": event_uuid,
        "device_id": device_id,
        "timestamp_start": start,
        "timestamp_end": end,
        "leq_db": 70.0,
        "lmax_db": 82.0,
        "lmin_db": 58.0,
        "classification_label": "traffic_noise",
        "classification_confidence": 0.9,
        "classification_source": "device_rule_engine",
        "segment_type": "sustained",
        "reportability_score": 0.8,
        "reportability_reason": "Persistent elevated levels",
        "threshold_exceedance_ratio": 0.6,
    }


async def test_detect_episodes_all_devices_resolves_public_device_id(client: AsyncClient):
    """The all-devices sweep must pass public device_id strings, not UUID FKs."""
    device = await client.post(
        "/api/v1/devices/register",
        json={"device_id": "anon-phone-001", "name": "Anon Phone"},
    )
    assert device.status_code == 200

    for i in range(2):
        resp = await client.post(
            "/api/v1/events/",
            json=_event_payload(
                "anon-phone-001",
                f"evt-anon-{i}",
                f"2026-08-17T10:0{i}:00Z",
                f"2026-08-17T10:0{i}:04Z",
            ),
        )
        assert resp.status_code == 200

    response = await client.post("/api/v1/events/detect-episodes")
    assert response.status_code == 200
    data = response.json()
    assert data["devices_processed"] == 1
    assert data["episodes_created"] == 1

    # Events should now be attached to the created episode
    events = await client.get("/api/v1/events/")
    assert events.status_code == 200
    for ev in events.json()["events"]:
        assert ev["episode_id"] is not None


async def test_detect_episodes_single_device_public_id(client: AsyncClient):
    """The explicit device_id path still works with the public string."""
    device = await client.post(
        "/api/v1/devices/register",
        json={"device_id": "anon-phone-002", "name": "Anon Phone 2"},
    )
    assert device.status_code == 200

    for i in range(2):
        resp = await client.post(
            "/api/v1/events/",
            json=_event_payload(
                "anon-phone-002",
                f"evt-anon2-{i}",
                f"2026-08-17T11:0{i}:00Z",
                f"2026-08-17T11:0{i}:04Z",
            ),
        )
        assert resp.status_code == 200

    response = await client.post(
        "/api/v1/events/detect-episodes", params={"device_id": "anon-phone-002"}
    )
    assert response.status_code == 200
    assert response.json()["episodes_created"] == 1
    assert response.json()["device_id"] == "anon-phone-002"
