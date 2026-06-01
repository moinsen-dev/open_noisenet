"""Integration tests for events API."""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.device import Device, DeviceType


async def _create_device(db: AsyncSession, device_id: str = "test-device-001", name: str = "Test Device") -> Device:
    device = Device(
        device_id=device_id,
        name=name,
        device_type=DeviceType.SMARTPHONE,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return device


def _base_event_payload(**overrides):
    payload = {
        "event_uuid": "evt-default-001",
        "device_id": "test-device-001",
        "timestamp_start": "2026-03-11T10:00:00Z",
        "timestamp_end": "2026-03-11T10:15:00Z",
        "leq_db": 65.0,
    }
    payload.update(overrides)
    return payload


@pytest.mark.asyncio
async def test_create_event(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    response = await client.post(
        "/api/v1/events/",
        json=_base_event_payload(
            event_uuid="evt-test-create-001",
            lmax_db=72.0,
            lmin_db=45.0,
            classification_label="sustained_noise",
            classification_confidence=0.84,
            classification_source="device_rule_engine",
            segment_type="sustained",
            reportability_score=0.91,
            reportability_reason="Exceeded the threshold for most of the event.",
            peak_to_average_delta_db=7.0,
            variability_db=27.0,
            threshold_exceedance_ratio=0.88,
        ),
    )
    assert response.status_code == 200
    data = response.json()
    assert data["event_uuid"] == "evt-test-create-001"
    assert data["device_id"] == "test-device-001"
    assert data["status"] == "acknowledged_by_server"
    assert data["server_event_id"]
    assert data["analysis_state"] == "classified_on_device"
    assert data["classification_label"] == "sustained_noise"
    assert data["reportability_score"] == pytest.approx(0.91)


@pytest.mark.asyncio
async def test_create_event_auto_creates_device(client: AsyncClient):
    response = await client.post(
        "/api/v1/events/",
        json=_base_event_payload(
            event_uuid="evt-test-autocreate-001",
            device_id="auto-created-device",
            leq_db=55.0,
        ),
    )
    assert response.status_code == 200
    assert response.json()["event_uuid"] == "evt-test-autocreate-001"
    assert response.json()["analysis_state"] == "server_classified"


@pytest.mark.asyncio
async def test_list_events_pagination(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    for i in range(3):
        await client.post(
            "/api/v1/events/",
            json=_base_event_payload(
                event_uuid=f"evt-test-list-{i}",
                timestamp_start=f"2026-03-11T{10+i:02d}:00:00Z",
                timestamp_end=f"2026-03-11T{10+i:02d}:15:00Z",
                leq_db=60.0 + i,
            ),
        )
    response = await client.get("/api/v1/events/", params={"limit": 2})
    assert response.status_code == 200
    data = response.json()
    assert len(data["events"]) == 2
    assert data["total"] == 3


@pytest.mark.asyncio
async def test_get_event_stats(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    await client.post(
        "/api/v1/events/",
        json=_base_event_payload(event_uuid="evt-test-stats-001"),
    )
    response = await client.get("/api/v1/events/stats/")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] >= 1


@pytest.mark.asyncio
async def test_create_event_is_idempotent_for_same_event_uuid(
    client: AsyncClient, db_session: AsyncSession
):
    await _create_device(db_session)
    payload = _base_event_payload(
        event_uuid="evt-test-idempotent-001",
        leq_db=61.0,
        classification_label="impulsive_noise",
        classification_confidence=0.77,
        classification_source="device_rule_engine",
        segment_type="impulsive",
        reportability_score=0.73,
        reportability_reason="Large peak in a short event window.",
        peak_to_average_delta_db=11.2,
        variability_db=19.4,
        threshold_exceedance_ratio=0.41,
    )

    first = await client.post("/api/v1/events/", json=payload)
    second = await client.post("/api/v1/events/", json=payload)
    listed = await client.get("/api/v1/events/", params={"device_id": "test-device-001"})

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["server_event_id"] == second.json()["server_event_id"]
    assert listed.json()["total"] == 1


@pytest.mark.asyncio
async def test_create_event_is_idempotent_with_optional_float_fields(
    client: AsyncClient, db_session: AsyncSession
):
    await _create_device(db_session)
    payload = _base_event_payload(
        event_uuid="evt-test-idempotent-floats-001",
        leq_db=63.1,
        lmax_db=67.4,
        lmin_db=55.0,
        location_lat=52.52,
        location_lng=13.405,
        reportability_score=0.604,
        peak_to_average_delta_db=4.3,
        variability_db=12.4,
        threshold_exceedance_ratio=0.61,
    )

    first = await client.post("/api/v1/events/", json=payload)
    second = await client.post("/api/v1/events/", json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["server_event_id"] == second.json()["server_event_id"]


@pytest.mark.asyncio
async def test_create_event_conflicts_for_same_event_uuid_with_different_payload(
    client: AsyncClient, db_session: AsyncSession
):
    await _create_device(db_session)
    first_payload = _base_event_payload(
        event_uuid="evt-test-conflict-001",
        leq_db=61.0,
    )
    conflicting_payload = {
        **first_payload,
        "leq_db": 77.0,
    }

    first = await client.post("/api/v1/events/", json=first_payload)
    second = await client.post("/api/v1/events/", json=conflicting_payload)

    assert first.status_code == 200
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_create_event_derives_server_analysis_when_device_fields_absent(
    client: AsyncClient, db_session: AsyncSession
):
    await _create_device(db_session)
    response = await client.post(
        "/api/v1/events/",
        json=_base_event_payload(
            event_uuid="evt-test-server-analysis-001",
            timestamp_end="2026-03-11T10:03:00Z",
            leq_db=71.5,
            lmax_db=82.0,
            lmin_db=58.0,
            exceedance_pct=82.0,
        ),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["analysis_state"] == "server_classified"
    assert data["classification_label"] == "sustained_noise"
    assert data["classification_source"] == "server_rule_engine"
    assert data["reportability_score"] is not None


@pytest.mark.asyncio
async def test_get_event_status_returns_analysis_details(
    client: AsyncClient, db_session: AsyncSession
):
    await _create_device(db_session)
    payload = _base_event_payload(
        event_uuid="evt-test-status-001",
        timestamp_end="2026-03-11T10:02:00Z",
        leq_db=68.0,
        lmax_db=79.5,
        lmin_db=57.0,
        classification_label="impulsive_noise",
        classification_confidence=0.81,
        classification_source="device_rule_engine",
        segment_type="impulsive",
        reportability_score=0.78,
        reportability_reason="Short but clearly above threshold.",
        peak_to_average_delta_db=11.5,
        variability_db=22.5,
        threshold_exceedance_ratio=0.55,
    )

    created = await client.post("/api/v1/events/", json=payload)
    status = await client.get("/api/v1/events/status/evt-test-status-001")

    assert created.status_code == 200
    assert status.status_code == 200
    data = status.json()
    assert data["event_uuid"] == "evt-test-status-001"
    assert data["lifecycle_state"] == "acknowledged_by_server"
    assert data["analysis_state"] == "classified_on_device"
    assert data["classification_label"] == "impulsive_noise"
    assert data["classification_source"] == "device_rule_engine"
    assert data["segment_type"] == "impulsive"
    assert data["reportability_score"] == pytest.approx(0.78)


# ── Phase 2: Event CRUD + Search ─────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_event_by_id(client: AsyncClient, db_session: AsyncSession):
    """GET /events/{id} returns event details by server ID."""
    await _create_device(db_session)
    resp = await client.post("/api/v1/events/", json=_base_event_payload(device_id="dev-getbyid-001"))
    server_id = resp.json()["server_event_id"]

    detail = await client.get(f"/api/v1/events/{server_id}")
    assert detail.status_code == 200
    assert detail.json()["id"] == server_id


@pytest.mark.asyncio
async def test_get_nonexistent_event_returns_404(client: AsyncClient):
    """GET /events/{nonexistent} returns 404."""
    resp = await client.get("/api/v1/events/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_event_requires_auth(client: AsyncClient, db_session: AsyncSession):
    """DELETE /events/{id} without auth returns 401."""
    await _create_device(db_session)
    resp = await client.post("/api/v1/events/", json=_base_event_payload(device_id="dev-del-001"))
    server_id = resp.json()["server_event_id"]

    del_resp = await client.delete(f"/api/v1/events/{server_id}")
    assert del_resp.status_code == 401


@pytest.mark.asyncio
async def test_delete_event(client: AsyncClient, db_session: AsyncSession):
    """DELETE /events/{id} removes the event."""
    # Register + login
    reg = await client.post("/api/v1/auth/register", json={
        "email": "event-deleter@test.noisenet.org", "password": "testpass123", "full_name": "Deleter",
    })
    token = reg.json()["access_token"]

    await _create_device(db_session)
    resp = await client.post("/api/v1/events/", json=_base_event_payload(device_id="dev-del-002"))
    server_id = resp.json()["server_event_id"]

    del_resp = await client.delete(
        f"/api/v1/events/{server_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert del_resp.status_code == 200
    assert "deleted" in del_resp.json()["message"].lower()

    # Verify gone
    get_resp = await client.get(f"/api/v1/events/{server_id}")
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_nonexistent_event_returns_404(client: AsyncClient):
    """DELETE /events/{nonexistent} returns 404."""
    reg = await client.post("/api/v1/auth/register", json={
        "email": "noevt-del@test.noisenet.org", "password": "testpass123", "full_name": "Nope",
    })
    token = reg.json()["access_token"]
    resp = await client.delete(
        "/api/v1/events/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_filter_events_by_device_id(client: AsyncClient, db_session: AsyncSession):
    """List events filtered by device_id returns only that device's events."""
    await _create_device(db_session, device_id="dev-filter-aa", name="Device AA")
    await _create_device(db_session, device_id="dev-filter-bb", name="Device BB")

    await client.post("/api/v1/events/", json=_base_event_payload(
        event_uuid="evt-aa-1", device_id="dev-filter-aa"))
    await client.post("/api/v1/events/", json=_base_event_payload(
        event_uuid="evt-aa-2", device_id="dev-filter-aa"))
    await client.post("/api/v1/events/", json=_base_event_payload(
        event_uuid="evt-bb-1", device_id="dev-filter-bb"))

    resp = await client.get("/api/v1/events/?device_id=dev-filter-aa")
    assert resp.status_code == 200
    events = resp.json()["events"]
    assert len(events) >= 2
    assert all(e["device_id"] == "dev-filter-aa" for e in events)


@pytest.mark.asyncio
async def test_list_events_by_timestamp_range(client: AsyncClient, db_session: AsyncSession):
    """List events filtered by timestamp range returns correct subset."""
    await _create_device(db_session, device_id="dev-time-001")

    await client.post("/api/v1/events/", json=_base_event_payload(
        event_uuid="evt-time-past", device_id="dev-time-001",
        timestamp_start="2025-01-01T00:00:00Z", timestamp_end="2025-01-01T00:15:00Z",
    ))
    await client.post("/api/v1/events/", json=_base_event_payload(
        event_uuid="evt-time-mid", device_id="dev-time-001",
        timestamp_start="2025-06-15T12:00:00Z", timestamp_end="2025-06-15T12:15:00Z",
    ))
    await client.post("/api/v1/events/", json=_base_event_payload(
        event_uuid="evt-time-future", device_id="dev-time-001",
        timestamp_start="2025-12-31T23:00:00Z", timestamp_end="2025-12-31T23:15:00Z",
    ))

    resp = await client.get("/api/v1/events/?from_ts=2025-06-01T00:00:00Z&to_ts=2025-07-01T00:00:00Z")
    assert resp.status_code == 200
    events = resp.json()["events"]
    assert len(events) >= 1

@pytest.mark.asyncio
async def test_pagination_offset_limit(client: AsyncClient, db_session: AsyncSession):
    """Pagination: offset and limit work correctly."""
    await _create_device(db_session, device_id="dev-page-001")
    for i in range(5):
        await client.post("/api/v1/events/", json=_base_event_payload(
            event_uuid=f"evt-page-{i}", device_id="dev-page-001",
        ))

    page1 = await client.get("/api/v1/events/?offset=0&limit=3")
    assert page1.status_code == 200
    assert len(page1.json()["events"]) >= 1
    assert page1.json()["total"] >= 5