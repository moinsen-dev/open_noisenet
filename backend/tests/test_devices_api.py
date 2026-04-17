"""Integration tests for devices API."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_register_device(client: AsyncClient):
    response = await client.post("/api/v1/devices/register", json={
        "device_id": "my-phone-001",
        "name": "My Phone",
        "device_type": "smartphone",
        "location_lat": 52.52,
        "location_lng": 13.405,
    })
    assert response.status_code == 200
    data = response.json()
    assert data["device_id"] == "my-phone-001"


@pytest.mark.asyncio
async def test_get_device(client: AsyncClient):
    await client.post("/api/v1/devices/register", json={
        "device_id": "get-test-001",
        "name": "Get Test",
    })
    response = await client.get("/api/v1/devices/get-test-001")
    assert response.status_code == 200
    assert response.json()["name"] == "Get Test"


@pytest.mark.asyncio
async def test_device_heartbeat(client: AsyncClient):
    await client.post("/api/v1/devices/register", json={
        "device_id": "heartbeat-001",
        "name": "Heartbeat Device",
    })
    response = await client.post("/api/v1/devices/heartbeat-001/heartbeat", json={
        "device_id": "heartbeat-001",
        "timestamp": "2026-03-11T10:00:00Z",
        "battery_level": 85.5,
        "signal_strength": -67,
        "status": {
            "sensor_mode_active": True,
            "queued_events": 2,
            "last_sample_at": "2026-03-11T09:59:58Z",
        },
    })
    assert response.status_code == 200

    device_response = await client.get("/api/v1/devices/heartbeat-001")
    assert device_response.status_code == 200
    device = device_response.json()
    assert device["last_heartbeat"].startswith("2026-03-11T10:00:00")
    assert device["last_seen"].startswith("2026-03-11T10:00:00")
    assert device["hardware_info"]["battery_level"] == 85.5
    assert device["hardware_info"]["signal_strength"] == -67
    assert device["hardware_info"]["last_runtime_status"]["queued_events"] == 2


@pytest.mark.asyncio
async def test_list_devices(client: AsyncClient):
    await client.post("/api/v1/devices/register", json={
        "device_id": "list-test-001",
        "name": "List Device",
    })
    response = await client.get("/api/v1/devices/")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
