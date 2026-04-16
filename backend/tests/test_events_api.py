"""Integration tests for events API."""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.device import Device, DeviceType


async def _create_device(db: AsyncSession) -> Device:
    device = Device(
        device_id="test-device-001",
        name="Test Device",
        device_type=DeviceType.SMARTPHONE,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return device


@pytest.mark.asyncio
async def test_create_event(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    response = await client.post("/api/v1/events/", json={
        "device_id": "test-device-001",
        "timestamp_start": "2026-03-11T10:00:00Z",
        "timestamp_end": "2026-03-11T10:15:00Z",
        "leq_db": 65.0,
        "lmax_db": 72.0,
        "lmin_db": 45.0,
    })
    assert response.status_code == 200
    data = response.json()
    assert data["device_id"] == "test-device-001"
    assert data["leq_db"] == 65.0
    assert data["status"] == "active"


@pytest.mark.asyncio
async def test_create_event_auto_creates_device(client: AsyncClient):
    response = await client.post("/api/v1/events/", json={
        "device_id": "auto-created-device",
        "timestamp_start": "2026-03-11T10:00:00Z",
        "timestamp_end": "2026-03-11T10:15:00Z",
        "leq_db": 55.0,
    })
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_list_events_pagination(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    for i in range(3):
        await client.post("/api/v1/events/", json={
            "device_id": "test-device-001",
            "timestamp_start": f"2026-03-11T{10+i:02d}:00:00Z",
            "timestamp_end": f"2026-03-11T{10+i:02d}:15:00Z",
            "leq_db": 60.0 + i,
        })
    response = await client.get("/api/v1/events/", params={"limit": 2})
    assert response.status_code == 200
    data = response.json()
    assert len(data["events"]) == 2
    assert data["total"] == 3


@pytest.mark.asyncio
async def test_get_event_stats(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    await client.post("/api/v1/events/", json={
        "device_id": "test-device-001",
        "timestamp_start": "2026-03-11T10:00:00Z",
        "timestamp_end": "2026-03-11T10:15:00Z",
        "leq_db": 65.0,
    })
    response = await client.get("/api/v1/events/stats/")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] >= 1
