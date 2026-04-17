"""Integration tests for the Pro episode/case/export workflow."""

import pytest
from httpx import AsyncClient


pytestmark = pytest.mark.asyncio


async def _auth_headers(client: AsyncClient, email: str = "pro-ops@example.com"):
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "strongpass123",
            "full_name": "Pro Ops",
        },
    )
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def _bootstrap_site_context(client: AsyncClient):
    headers = await _auth_headers(client)
    organization = await client.post(
        "/api/v1/organizations/",
        json={"name": "Case Ops", "slug": "case-ops", "plan_tier": "pro_site"},
        headers=headers,
    )
    assert organization.status_code == 201
    organization_id = organization.json()["id"]

    site = await client.post(
        "/api/v1/sites/",
        json={
            "organization_id": organization_id,
            "name": "Pilot Building",
            "timezone": "Europe/Berlin",
        },
        headers=headers,
    )
    assert site.status_code == 201
    site_id = site.json()["id"]

    zone = await client.post(
        "/api/v1/zones/",
        json={
            "site_id": site_id,
            "name": "Courtyard",
            "quiet_hours_start": "22:00",
            "quiet_hours_end": "06:00",
        },
        headers=headers,
    )
    assert zone.status_code == 201
    zone_id = zone.json()["id"]

    policy = await client.post(
        "/api/v1/policies/",
        json={
            "scope_type": "zone",
            "zone_id": zone_id,
            "name": "Night evidence policy",
            "evidence_mode": "derived_only",
            "day_threshold_db": 65,
            "night_threshold_db": 55,
            "quiet_hours_start": "22:00",
            "quiet_hours_end": "06:00",
        },
        headers=headers,
    )
    assert policy.status_code == 201

    device = await client.post(
        "/api/v1/devices/register",
        json={"device_id": "ops-phone-001", "name": "Ops Phone"},
    )
    assert device.status_code == 200

    assignment = await client.put(
        "/api/v1/sites/devices/ops-phone-001/assignment",
        json={"site_id": site_id, "zone_id": zone_id},
        headers=headers,
    )
    assert assignment.status_code == 200

    return headers, organization_id, site_id, zone_id


def _event_payload(**overrides):
    payload = {
        "event_uuid": "evt-episode-case-001",
        "device_id": "ops-phone-001",
        "timestamp_start": "2026-04-17T22:15:00Z",
        "timestamp_end": "2026-04-17T22:19:00Z",
        "leq_db": 69.0,
        "lmax_db": 81.0,
        "lmin_db": 56.0,
        "classification_label": "sustained_noise",
        "classification_confidence": 0.82,
        "classification_source": "device_rule_engine",
        "segment_type": "sustained",
        "reportability_score": 0.88,
        "reportability_reason": "Long nuisance event during quiet hours",
        "threshold_exceedance_ratio": 0.77,
    }
    payload.update(overrides)
    return payload


async def test_event_creates_episode_and_merges_recent_followup(client: AsyncClient):
    headers, organization_id, site_id, _zone_id = await _bootstrap_site_context(client)

    created = await client.post("/api/v1/events/", json=_event_payload())
    assert created.status_code == 200
    assert created.json()["episode_id"] is not None

    episodes = await client.get(
        "/api/v1/episodes/",
        params={"organization_id": organization_id, "site_id": site_id},
        headers=headers,
    )
    assert episodes.status_code == 200
    assert episodes.json()["total"] == 1
    first_episode = episodes.json()["episodes"][0]
    assert first_episode["device_public_id"] == "ops-phone-001"
    assert first_episode["primary_class"] == "sustained_noise"
    assert first_episode["quiet_hours_triggered"] is True
    assert first_episode["evidence_mode"] == "derived_only"

    followup = await client.post(
        "/api/v1/events/",
        json=_event_payload(
            event_uuid="evt-episode-case-002",
            timestamp_start="2026-04-17T22:22:00Z",
            timestamp_end="2026-04-17T22:24:00Z",
            leq_db=71.0,
        ),
    )
    assert followup.status_code == 200
    assert followup.json()["episode_id"] == first_episode["id"]

    episodes = await client.get(
        "/api/v1/episodes/",
        params={"organization_id": organization_id, "site_id": site_id},
        headers=headers,
    )
    merged = episodes.json()["episodes"][0]
    assert merged["event_count"] == 2
    assert merged["lifecycle_state"] == "extended"


async def test_episode_review_case_and_export_flow(client: AsyncClient):
    headers, organization_id, site_id, zone_id = await _bootstrap_site_context(
        client
    )
    event = await client.post("/api/v1/events/", json=_event_payload())
    assert event.status_code == 200
    episode_id = event.json()["episode_id"]

    reviewed = await client.post(
        f"/api/v1/episodes/{episode_id}/review",
        json={
            "review_state": "overridden",
            "review_label": "recurring_night_disturbance",
            "severity": "high",
            "notes": "Matches tenant complaint pattern.",
        },
        headers=headers,
    )
    assert reviewed.status_code == 200
    assert reviewed.json()["effective_label"] == "recurring_night_disturbance"
    assert reviewed.json()["effective_severity"] == "high"
    assert reviewed.json()["review_metadata"]["previous_review_state"] == "pending_review"
    assert reviewed.json()["review_metadata"]["new_review_state"] == "overridden"
    assert reviewed.json()["review_metadata"]["closed_by_review"] is True

    created_case = await client.post(
        "/api/v1/cases/",
        json={
            "organization_id": organization_id,
            "site_id": site_id,
            "zone_id": zone_id,
            "title": "Courtyard quiet-hours disturbance",
            "summary": "First exportable nuisance case for the pilot site.",
            "episode_ids": [episode_id],
        },
        headers=headers,
    )
    assert created_case.status_code == 201
    case_id = created_case.json()["id"]
    assert created_case.json()["episode_count"] == 1
    assert created_case.json()["audit_history"][0]["event_type"] == "case_created"

    updated_case = await client.patch(
        f"/api/v1/cases/{case_id}",
        json={
            "status": "in_review",
            "summary": "Escalated into formal operator review.",
            "note": "Operator triage started.",
        },
        headers=headers,
    )
    assert updated_case.status_code == 200
    assert updated_case.json()["status"] == "in_review"
    assert updated_case.json()["summary"] == "Escalated into formal operator review."
    assert updated_case.json()["last_status_changed_by_id"] is not None
    assert updated_case.json()["last_status_changed_at"] is not None
    assert any(
        entry["event_type"] == "status_changed"
        and entry["to_status"] == "in_review"
        for entry in updated_case.json()["audit_history"]
    )

    case_episodes = await client.get(
        f"/api/v1/cases/{case_id}/episodes",
        headers=headers,
    )
    assert case_episodes.status_code == 200
    assert case_episodes.json()[0]["id"] == episode_id

    other_headers = await _auth_headers(client, email="other-tenant@example.com")
    other_org = await client.post(
        "/api/v1/organizations/",
        json={
            "name": "Other Tenant",
            "slug": "other-tenant",
            "plan_tier": "pro_site",
        },
        headers=other_headers,
    )
    assert other_org.status_code == 201

    other_case_view = await client.get(
        f"/api/v1/cases/{case_id}",
        headers=other_headers,
    )
    assert other_case_view.status_code == 403

    other_case_update = await client.patch(
        f"/api/v1/cases/{case_id}",
        json={"status": "closed", "note": "Should not be allowed"},
        headers=other_headers,
    )
    assert other_case_update.status_code == 403

    other_episode_list = await client.get(
        "/api/v1/episodes/",
        params={"organization_id": organization_id, "site_id": site_id},
        headers=other_headers,
    )
    assert other_episode_list.status_code == 403

    exported = await client.post(
        "/api/v1/exports/",
        json={"case_id": case_id, "format": "json"},
        headers=headers,
    )
    assert exported.status_code == 201
    export_id = exported.json()["id"]
    assert exported.json()["content_type"] == "application/json"
    assert exported.json()["preview"] is not None

    content = await client.get(f"/api/v1/exports/{export_id}/content", headers=headers)
    assert content.status_code == 200
    assert content.headers["content-type"].startswith("application/json")
    assert "recurring_night_disturbance" in content.text
    assert '"review_metadata"' in content.text
    assert '"audit_history"' in content.text
    assert '"summary"' in content.text
    assert '"generated_from_case_status": "in_review"' in content.text

    other_export_content = await client.get(
        f"/api/v1/exports/{export_id}/content",
        headers=other_headers,
    )
    assert other_export_content.status_code == 403

    closed_case = await client.patch(
        f"/api/v1/cases/{case_id}",
        json={"status": "closed", "note": "Export package finalized."},
        headers=headers,
    )
    assert closed_case.status_code == 200
    assert closed_case.json()["status"] == "closed"
    assert closed_case.json()["closed_at"] is not None
    assert closed_case.json()["closed_by_id"] is not None
    assert any(
        entry["event_type"] == "status_changed"
        and entry["to_status"] == "closed"
        for entry in closed_case.json()["audit_history"]
    )


async def test_pdf_export_is_generated(client: AsyncClient):
    headers, organization_id, site_id, zone_id = await _bootstrap_site_context(
        client
    )
    event = await client.post("/api/v1/events/", json=_event_payload())
    assert event.status_code == 200
    episode_id = event.json()["episode_id"]

    created_case = await client.post(
        "/api/v1/cases/",
        json={
            "organization_id": organization_id,
            "site_id": site_id,
            "zone_id": zone_id,
            "title": "PDF Export Check",
            "episode_ids": [episode_id],
        },
        headers=headers,
    )
    assert created_case.status_code == 201

    exported = await client.post(
        "/api/v1/exports/",
        json={"case_id": created_case.json()["id"], "format": "pdf"},
        headers=headers,
    )
    assert exported.status_code == 201
    assert exported.json()["content_type"] == "application/pdf"

    content = await client.get(
        f"/api/v1/exports/{exported.json()['id']}/content", headers=headers
    )
    assert content.status_code == 200
    assert content.headers["content-type"].startswith("application/pdf")
    assert content.content.startswith(b"%PDF")
