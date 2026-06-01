"""Integration tests for devices API."""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


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


@pytest.mark.asyncio
async def test_update_device(client: AsyncClient):
    """PUT /devices/{device_id} with new name updates the device."""
    await client.post("/api/v1/devices/register", json={
        "device_id": "update-test-001",
        "name": "Original Name",
    })
    response = await client.put("/api/v1/devices/update-test-001", json={
        "name": "Updated Name",
    })
    assert response.status_code == 200
    assert response.json()["name"] == "Updated Name"


@pytest.mark.asyncio
async def test_update_nonexistent_device(client: AsyncClient):
    """PUT /devices/nonexistent returns 404."""
    response = await client.put("/api/v1/devices/nonexistent", json={
        "name": "No Device",
    })
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_delete_device(client: AsyncClient):
    """DELETE /devices/{device_id} removes the device."""
    # Register + login to get a token
    resp = await client.post("/api/v1/auth/register", json={
        "email": "delete-test@test.noisenet.org",
        "password": "testpass123",
        "full_name": "Delete Tester",
    })
    token = resp.json()["access_token"]

    await client.post("/api/v1/devices/register", json={
        "device_id": "delete-test-001",
        "name": "Delete Me",
    })
    response = await client.delete(
        "/api/v1/devices/delete-test-001",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 204

    get_response = await client.get("/api/v1/devices/delete-test-001")
    assert get_response.status_code == 404


@pytest.mark.asyncio
async def test_list_devices_only_returns_owned(
    client: AsyncClient, db_session: AsyncSession
):
    """List only returns devices owned by the authenticated user."""
    from tests.factories import create_user, create_device

    user_a = await create_user(db_session, email="owner-a@test.noisenet.org", password="pw-a")
    await create_device(db_session, device_id="owned-a-001", name="A's Device", owner_id=user_a.id)

    user_b = await create_user(db_session, email="owner-b@test.noisenet.org", password="pw-b")
    await create_device(db_session, device_id="owned-b-001", name="B's Device", owner_id=user_b.id)

    # Login as user A
    login_resp = await client.post("/api/v1/auth/login", json={
        "email": "owner-a@test.noisenet.org",
        "password": "pw-a",
    })
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"

    response = await client.get("/api/v1/devices/")
    assert response.status_code == 200
    device_ids = [d["device_id"] for d in response.json()]

    assert "owned-a-001" in device_ids
    assert "owned-b-001" not in device_ids, (
        "Ownership enforcement missing: list_devices returned another user's device"
    )


@pytest.mark.asyncio
async def test_cannot_access_other_users_device(
    client: AsyncClient, db_session: AsyncSession
):
    """GET /devices/{device_id} returns 404 for another user's device."""
    from tests.factories import create_user, create_device

    user_a = await create_user(db_session, email="sec-a@test.noisenet.org", password="pw-a")
    await create_device(db_session, device_id="secret-device", name="A's Secret", owner_id=user_a.id)

    await create_user(db_session, email="sec-b@test.noisenet.org", password="pw-b")

    # Login as user B
    login_resp = await client.post("/api/v1/auth/login", json={
        "email": "sec-b@test.noisenet.org",
        "password": "pw-b",
    })
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"

    response = await client.get("/api/v1/devices/secret-device")
    assert response.status_code == 404, (
        f"Ownership enforcement missing: got {response.status_code}, "
        f"another user can access device they don't own"
    )
