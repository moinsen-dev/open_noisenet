"""Test map endpoints."""

import uuid
from datetime import datetime, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device, DeviceType
from app.db.models.event import Event, EventStatus

pytestmark = pytest.mark.asyncio


async def _seed_map_data(db: AsyncSession):
    device = Device(
        id=uuid.uuid4(),
        device_id=f"test-device-{uuid.uuid4().hex[:8]}",
        name="Map Test Device",
        device_type=DeviceType.SMARTPHONE,
        location_lat=52.520008,
        location_lng=13.404954,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)

    event = Event(
        id=uuid.uuid4(),
        device_id=str(device.id),
        timestamp_start=datetime.now(timezone.utc),
        timestamp_end=datetime.now(timezone.utc),
        leq_db=65.0,
        lmax_db=72.0,
        lmin_db=45.0,
        location_lat=52.520008,
        location_lng=13.404954,
        status=EventStatus.PROCESSED,
    )
    db.add(event)
    await db.flush()
    return device, event


async def test_get_map_events_geojson(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get("/api/v1/map/events")
    assert response.status_code == 200
    data = response.json()
    assert data["type"] == "FeatureCollection"
    assert len(data["features"]) >= 1
    feature = data["features"][0]
    assert feature["type"] == "Feature"
    assert feature["geometry"]["type"] == "Point"


async def test_get_map_events_with_bbox(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get(
        "/api/v1/map/events",
        params={
            "min_lat": 52.0,
            "max_lat": 53.0,
            "min_lng": 13.0,
            "max_lng": 14.0,
        },
    )
    assert response.status_code == 200
    assert len(response.json()["features"]) >= 1


async def test_get_map_events_bbox_excludes(
    client: AsyncClient, db_session: AsyncSession
):
    """Events outside the bounding box should not be returned."""
    await _seed_map_data(db_session)
    response = await client.get(
        "/api/v1/map/events",
        params={
            "min_lat": 40.0,
            "max_lat": 41.0,
            "min_lng": 10.0,
            "max_lng": 11.0,
        },
    )
    assert response.status_code == 200
    assert len(response.json()["features"]) == 0


async def test_get_heatmap_data(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get(
        "/api/v1/map/heatmap",
        params={
            "min_lat": 52.0,
            "max_lat": 53.0,
            "min_lng": 13.0,
            "max_lng": 14.0,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "points" in data
    assert len(data["points"]) >= 1
    assert data["points"][0]["intensity"] == 65.0
    assert data["min_intensity"] is not None
    assert data["max_intensity"] is not None


async def test_get_heatmap_requires_bbox(
    client: AsyncClient, db_session: AsyncSession
):
    """Heatmap endpoint requires bounding box parameters."""
    response = await client.get("/api/v1/map/heatmap")
    assert response.status_code == 422


async def test_get_map_stats(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get("/api/v1/map/stats")
    assert response.status_code == 200
    data = response.json()
    assert "total_events" in data
    assert "total_devices" in data
    assert data["total_events"] >= 1
    assert data["total_devices"] >= 1
    assert data["avg_leq_db"] is not None
    assert data["max_leq_db"] is not None
    assert data["active_devices_24h"] >= 1
    assert data["events_24h"] >= 1


async def test_get_map_stats_empty(client: AsyncClient, db_session: AsyncSession):
    """Stats endpoint works with no data."""
    response = await client.get("/api/v1/map/stats")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] == 0
    assert data["total_devices"] == 0
    assert data["avg_leq_db"] is None
    assert data["active_devices_24h"] == 0
