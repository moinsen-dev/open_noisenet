"""End-to-end integration test for the full Pro operator workflow."""
import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_full_pro_workflow(client: AsyncClient):
    """Walk the entire Pro flow: register → org → site → zone → policy
    → device → assign → event → list → case → export."""

    # ── 1. Register user ────────────────────────────────────────────────
    user_email = "e2e-pro@example.com"
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": user_email,
            "password": "e2e-test-pass",
            "full_name": "E2E Pro Operator",
        },
    )
    assert resp.status_code == 201, f"register failed: {resp.text}"
    token = resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # ── 2. Create organization ───────────────────────────────────────────
    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "E2E City Council", "slug": "e2e-city", "plan_tier": "pro_site"},
        headers=headers,
    )
    assert org.status_code == 201, f"create org failed: {org.text}"
    organization_id = org.json()["id"]

    # ── 3. Create site ───────────────────────────────────────────────────
    site = await client.post(
        "/api/v1/sites/",
        json={
            "organization_id": organization_id,
            "name": "E2E Town Hall",
            "timezone": "America/New_York",
        },
        headers=headers,
    )
    assert site.status_code == 201, f"create site failed: {site.text}"
    site_id = site.json()["id"]

    # ── 4. Create zone ──────────────────────────────────────────────────
    zone = await client.post(
        "/api/v1/zones/",
        json={
            "site_id": site_id,
            "name": "E2E Main Plaza",
            "quiet_hours_start": "22:00",
            "quiet_hours_end": "07:00",
        },
        headers=headers,
    )
    assert zone.status_code == 201, f"create zone failed: {zone.text}"
    zone_id = zone.json()["id"]

    # ── 5. Create policy ────────────────────────────────────────────────
    policy = await client.post(
        "/api/v1/policies/",
        json={
            "scope_type": "zone",
            "zone_id": zone_id,
            "name": "E2E Plaza Night Policy",
            "evidence_mode": "derived_only",
            "day_threshold_db": 65,
            "night_threshold_db": 50,
            "quiet_hours_start": "22:00",
            "quiet_hours_end": "07:00",
        },
        headers=headers,
    )
    assert policy.status_code == 201, f"create policy failed: {policy.text}"

    # ── 6. Register device ──────────────────────────────────────────────
    device_id = "e2e-phone-001"
    device = await client.post(
        "/api/v1/devices/register",
        json={
            "device_id": device_id,
            "name": "E2E Field Phone",
            "device_type": "smartphone",
            "location_lat": 40.7128,
            "location_lng": -74.0060,
        },
    )
    assert device.status_code == 200, f"register device failed: {device.text}"

    # ── 7. Assign device to site ────────────────────────────────────────
    assignment = await client.put(
        f"/api/v1/sites/devices/{device_id}/assignment",
        json={"site_id": site_id, "zone_id": zone_id},
        headers=headers,
    )
    assert assignment.status_code == 200, f"assign device failed: {assignment.text}"
    assert assignment.json()["site_id"] == site_id
    assert assignment.json()["zone_id"] == zone_id

    # ── 8. Submit event ─────────────────────────────────────────────────
    event = await client.post(
        "/api/v1/events/",
        json={
            "event_uuid": "e2e-event-001",
            "device_id": device_id,
            "timestamp_start": "2026-05-31T22:30:00Z",
            "timestamp_end": "2026-05-31T22:35:00Z",
            "leq_db": 68.0,
            "lmax_db": 85.0,
            "lmin_db": 52.0,
            "classification_label": "sustained_noise",
            "classification_confidence": 0.85,
            "classification_source": "device_rule_engine",
            "segment_type": "sustained",
            "reportability_score": 0.92,
            "reportability_reason": "Nuisance noise during quiet hours",
            "threshold_exceedance_ratio": 0.72,
        },
    )
    assert event.status_code == 200, f"submit event failed: {event.text}"
    event_data = event.json()
    assert event_data["device_id"] == device_id
    assert event_data["analysis_state"] in ("server_classified", "classified_on_device")
    server_event_id = event_data["server_event_id"]
    episode_id = event_data.get("episode_id")
    assert episode_id is not None

    # ── 9. Verify event appears in list ─────────────────────────────────
    event_list = await client.get(
        "/api/v1/events/",
        params={"device_id": device_id, "limit": 10},
    )
    assert event_list.status_code == 200, f"list events failed: {event_list.text}"
    events = event_list.json()["events"]
    assert any(e["id"] == server_event_id for e in events), (
        f"Submitted event {server_event_id} not found in list"
    )

    # ── 10. Create case from event ──────────────────────────────────────
    case = await client.post(
        "/api/v1/cases/",
        json={
            "organization_id": organization_id,
            "site_id": site_id,
            "zone_id": zone_id,
            "title": "E2E Plaza Night Disturbance",
            "summary": "End-to-end test case from sustained noise event.",
            "episode_ids": [episode_id],
        },
        headers=headers,
    )
    assert case.status_code == 201, f"create case failed: {case.text}"
    case_id = case.json()["id"]
    assert case.json()["episode_count"] == 1
    assert case.json()["status"] == "open"

    # Update case to in_review via PATCH
    updated = await client.patch(
        f"/api/v1/cases/{case_id}",
        json={"status": "in_review", "note": "Operator triage started."},
        headers=headers,
    )
    assert updated.status_code == 200, f"update case failed: {updated.text}"
    assert updated.json()["status"] == "in_review"

    # ── 11. Export case as JSON ─────────────────────────────────────────
    export = await client.post(
        "/api/v1/exports/",
        json={"case_id": case_id, "format": "json"},
        headers=headers,
    )
    assert export.status_code == 201, f"export case failed: {export.text}"
    export_data = export.json()
    assert export_data["content_type"] == "application/json"
    assert export_data["preview"] is not None
    export_id = export_data["id"]

    # Fetch and verify exported content
    content = await client.get(
        f"/api/v1/exports/{export_id}/content", headers=headers
    )
    assert content.status_code == 200, f"get export content failed: {content.text}"
    assert content.headers["content-type"].startswith("application/json")
    # Sanity: the export JSON contains key identifiers
    assert "E2E Plaza Night Disturbance" in content.text
    assert device_id in content.text