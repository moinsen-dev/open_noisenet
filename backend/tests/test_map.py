"""Test map endpoints."""

import uuid
from datetime import datetime, timedelta, timezone

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
        device_id=device.id,
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


async def test_map_geojson_with_location_filter(
    client: AsyncClient, db_session: AsyncSession
):
    """GeoJSON endpoint excludes events that lack lat/lng."""
    device = Device(
        id=uuid.uuid4(),
        device_id=f"test-device-{uuid.uuid4().hex[:8]}",
        name="LocFilter Device",
        device_type=DeviceType.SMARTPHONE,
    )
    db_session.add(device)
    await db_session.flush()

    # Event with location — should appear
    event_with_loc = Event(
        id=uuid.uuid4(),
        device_id=device.id,
        timestamp_start=datetime.now(timezone.utc),
        timestamp_end=datetime.now(timezone.utc),
        leq_db=65.0,
        location_lat=52.520008,
        location_lng=13.404954,
        status=EventStatus.PROCESSED,
    )
    # Event without location — should be excluded
    event_without_loc = Event(
        id=uuid.uuid4(),
        device_id=device.id,
        timestamp_start=datetime.now(timezone.utc),
        timestamp_end=datetime.now(timezone.utc),
        leq_db=55.0,
        location_lat=None,
        location_lng=None,
        status=EventStatus.PROCESSED,
    )
    db_session.add_all([event_with_loc, event_without_loc])
    await db_session.flush()
    response = await client.get("/api/v1/map/events")
    assert response.status_code == 200
    features = response.json()["features"]
    assert len(features) == 1
    assert features[0]["properties"]["leq_db"] == 65.0

async def test_map_geojson_bbox_filter(
    client: AsyncClient, db_session: AsyncSession
):
    """Bbox parameter filters events to those inside the rectangle."""
    device = Device(
        id=uuid.uuid4(),
        device_id=f"test-device-{uuid.uuid4().hex[:8]}",
        name="Bbox Device",
        device_type=DeviceType.SMARTPHONE,
    )
    db_session.add(device)
    await db_session.flush()
    # Berlin (inside bbox)
    event_berlin = Event(
        id=uuid.uuid4(),
        device_id=device.id,
        timestamp_start=datetime.now(timezone.utc),
        leq_db=70.0,
        location_lat=52.52,
        location_lng=13.41,
        status=EventStatus.PROCESSED,
    )
    # Paris (outside bbox)
    event_paris = Event(
        id=uuid.uuid4(),
        device_id=device.id,
        timestamp_start=datetime.now(timezone.utc),
        leq_db=60.0,
        location_lat=48.86,
        location_lng=2.35,
        status=EventStatus.PROCESSED,
    )
    # Right edge of bbox (included)
    event_edge = Event(
        id=uuid.uuid4(),
        device_id=device.id,
        timestamp_start=datetime.now(timezone.utc),
        leq_db=65.0,
        location_lat=53.0,
        location_lng=14.0,
        status=EventStatus.PROCESSED,
    )
    db_session.add_all([event_berlin, event_paris, event_edge])
    await db_session.flush()
    response = await client.get(
        "/api/v1/map/events",
        params={"min_lat": 52.0, "max_lat": 53.0, "min_lng": 13.0, "max_lng": 14.0},
    )
    assert response.status_code == 200
    features = response.json()["features"]
    ids = {f["properties"]["id"] for f in features}
    # Berlin and edge are inside; Paris is excluded
    assert str(event_berlin.id) in ids
    assert str(event_edge.id) in ids
    assert str(event_paris.id) not in ids

async def test_map_stats_accuracy(
    client: AsyncClient, db_session: AsyncSession
):
    """Stats correctly compute avg_leq_db and total_events from known dB values."""
    device = Device(
        id=uuid.uuid4(),
        device_id=f"test-device-{uuid.uuid4().hex[:8]}",
        name="StatsDevice",
        device_type=DeviceType.SMARTPHONE,
    )
    db_session.add(device)
    await db_session.flush()
    for db_val in (60.0, 70.0, 80.0):
        db_session.add(
            Event(
                id=uuid.uuid4(),
                device_id=device.id,
                timestamp_start=datetime.now(timezone.utc),
                leq_db=db_val,
                location_lat=52.0,
                location_lng=13.0,
                status=EventStatus.PROCESSED,
            )
        )
    await db_session.flush()
    response = await client.get("/api/v1/map/stats")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] == 3
    assert data["total_devices"] == 1
    # (60 + 70 + 80) / 3 = 70.0
    assert data["avg_leq_db"] == 70.0

async def test_map_stats_24h_window(
    client: AsyncClient, db_session: AsyncSession
):
    """events_24h counts only events from the last 24 hours."""
    device = Device(
        id=uuid.uuid4(),
        device_id=f"test-device-{uuid.uuid4().hex[:8]}",
        name="Window Device",
        device_type=DeviceType.SMARTPHONE,
    )
    db_session.add(device)
    await db_session.flush()
    now = datetime.now(timezone.utc)
    # Recent event — within 24h
    db_session.add(
        Event(
            id=uuid.uuid4(),
            device_id=device.id,
            timestamp_start=now,
            leq_db=65.0,
            location_lat=52.0,
            location_lng=13.0,
            status=EventStatus.PROCESSED,
        )
    )
    # Old event — 72h ago, outside 24h window
    db_session.add(
        Event(
            id=uuid.uuid4(),
            device_id=device.id,
            timestamp_start=now - timedelta(hours=72),
            leq_db=55.0,
            location_lat=52.0,
            location_lng=13.0,
            status=EventStatus.PROCESSED,
        )
    )
    await db_session.flush()
    response = await client.get("/api/v1/map/stats")
    assert response.status_code == 200
    data = response.json()
    # total_events counts everything
    assert data["total_events"] == 2
    # events_24h only counts the recent one
    assert data["events_24h"] == 1

async def test_heatmap_returns_grid(
    client: AsyncClient, db_session: AsyncSession
):
    """Heatmap endpoint returns a list of points with lat/lng/intensity."""
    await _seed_map_data(db_session)
    response = await client.get(
        "/api/v1/map/heatmap",
        params={"min_lat": 52.0, "max_lat": 53.0, "min_lng": 13.0, "max_lng": 14.0},
    )
    assert response.status_code == 200
    data = response.json()
    assert "points" in data
    assert isinstance(data["points"], list)
    assert len(data["points"]) >= 1
    # Each point is a grid cell with lat, lng, intensity, event_count
    for point in data["points"]:
        assert "lat" in point
        assert "lng" in point
        assert "intensity" in point
        assert "event_count" in point
        assert isinstance(point["lat"], (int, float))
        assert isinstance(point["lng"], (int, float))
        assert isinstance(point["intensity"], (int, float))
        assert isinstance(point["event_count"], int)

async def test_heatmap_empty_when_no_events(
    client: AsyncClient, db_session: AsyncSession
):
    """Heatmap with no events in DB returns empty collection, not 500."""
    response = await client.get(
        "/api/v1/map/heatmap",
        params={"min_lat": 52.0, "max_lat": 53.0, "min_lng": 13.0, "max_lng": 14.0},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["points"] == []
    assert data["min_intensity"] is None
    assert data["max_intensity"] is None
