"""Integration tests for the Pro domain foundation API."""

import pytest
from httpx import AsyncClient


pytestmark = pytest.mark.asyncio


async def _auth_headers(client: AsyncClient, email: str = "owner@example.com"):
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "strongpass123",
            "full_name": "Owner User",
        },
    )
    assert response.status_code == 201
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def test_create_and_list_organizations(client: AsyncClient):
    headers = await _auth_headers(client)

    created = await client.post(
        "/api/v1/organizations/",
        json={"name": "Acme Housing", "slug": "acme-housing", "plan_tier": "pro_site"},
        headers=headers,
    )
    assert created.status_code == 201
    assert created.json()["current_user_role"] == "owner"

    listed = await client.get("/api/v1/organizations/", headers=headers)
    assert listed.status_code == 200
    assert listed.json()[0]["slug"] == "acme-housing"


async def test_site_zone_policy_and_calibration_profile_flow(client: AsyncClient):
    headers = await _auth_headers(client, email="ops@example.com")
    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "Portfolio Ops", "slug": "portfolio-ops", "plan_tier": "portfolio"},
        headers=headers,
    )
    org_id = org.json()["id"]

    site = await client.post(
        "/api/v1/sites/",
        json={
            "organization_id": org_id,
            "name": "Building A",
            "timezone": "Europe/Berlin",
            "address": "Example Street 1",
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
            "name": "Night nuisance policy",
            "evidence_mode": "derived_only",
            "retention_days": 365,
            "night_threshold_db": 55,
        },
        headers=headers,
    )
    assert policy.status_code == 201
    assert policy.json()["scope_type"] == "zone"

    profile = await client.post(
        "/api/v1/calibration-profiles/",
        json={
            "organization_id": org_id,
            "site_id": site_id,
            "name": "Building A default",
            "offset_db": -2.5,
            "method": "manual meter alignment",
            "confidence": 0.8,
        },
        headers=headers,
    )
    assert profile.status_code == 201
    assert profile.json()["site_id"] == site_id


async def test_assign_device_to_site_and_list_site_devices(client: AsyncClient):
    headers = await _auth_headers(client, email="field@example.com")

    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "Field Org", "slug": "field-org", "plan_tier": "pro_site"},
        headers=headers,
    )
    org_id = org.json()["id"]

    site = await client.post(
        "/api/v1/sites/",
        json={"organization_id": org_id, "name": "Pilot Site", "timezone": "UTC"},
        headers=headers,
    )
    site_id = site.json()["id"]

    zone = await client.post(
        "/api/v1/zones/",
        json={"site_id": site_id, "name": "North Side"},
        headers=headers,
    )
    zone_id = zone.json()["id"]

    profile = await client.post(
        "/api/v1/calibration-profiles/",
        json={
            "organization_id": org_id,
            "site_id": site_id,
            "name": "Pilot profile",
            "offset_db": 1.25,
        },
        headers=headers,
    )
    profile_id = profile.json()["id"]

    registered = await client.post(
        "/api/v1/devices/register",
        json={"device_id": "site-phone-001", "name": "Site Phone"},
    )
    assert registered.status_code == 200

    assignment = await client.put(
        "/api/v1/sites/devices/site-phone-001/assignment",
        json={
            "site_id": site_id,
            "zone_id": zone_id,
            "calibration_profile_id": profile_id,
        },
        headers=headers,
    )
    assert assignment.status_code == 200
    assert assignment.json()["site_id"] == site_id
    assert assignment.json()["zone_id"] == zone_id

    listed = await client.get(f"/api/v1/sites/{site_id}/devices", headers=headers)
    assert listed.status_code == 200
    assert listed.json()[0]["device_id"] == "site-phone-001"


async def test_pro_domain_requires_authentication(client: AsyncClient):
    response = await client.get("/api/v1/organizations/")
    assert response.status_code == 401
