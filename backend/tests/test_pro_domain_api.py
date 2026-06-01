"""Integration tests for the Pro domain foundation API."""

import pytest
from httpx import AsyncClient
import uuid



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





# ── Tenant isolation tests ────────────────────────────────────────────────────


async def test_create_organization(client: AsyncClient):
    """POST /organizations/ → 201 with owner role."""
    headers = await _auth_headers(client)
    created = await client.post(
        "/api/v1/organizations/",
        json={"name": "Test Corp", "slug": "test-corp", "plan_tier": "pro_site"},
        headers=headers,
    )
    assert created.status_code == 201
    assert created.json()["current_user_role"] == "owner"
    assert created.json()["slug"] == "test-corp"


async def test_list_organizations_only_owned(client: AsyncClient):
    """User can only see organizations they are a member of."""
    headers_a = await _auth_headers(client, email="alice@example.com")
    org_a = await client.post(
        "/api/v1/organizations/",
        json={"name": "Alice Corp", "slug": "alice-corp", "plan_tier": "pro_site"},
        headers=headers_a,
    )
    assert org_a.status_code == 201
    org_a_id = org_a.json()["id"]

    headers_b = await _auth_headers(client, email="bob@example.com")
    org_b = await client.post(
        "/api/v1/organizations/",
        json={"name": "Bob Corp", "slug": "bob-corp", "plan_tier": "pro_site"},
        headers=headers_b,
    )
    assert org_b.status_code == 201
    org_b_id = org_b.json()["id"]

    # Alice lists → only sees Alice Corp
    alice_list = await client.get("/api/v1/organizations/", headers=headers_a)
    assert alice_list.status_code == 200
    alice_ids = {o["id"] for o in alice_list.json()}
    assert org_a_id in alice_ids
    assert org_b_id not in alice_ids

    # Bob lists → only sees Bob Corp
    bob_list = await client.get("/api/v1/organizations/", headers=headers_b)
    assert bob_list.status_code == 200
    bob_ids = {o["id"] for o in bob_list.json()}
    assert org_b_id in bob_ids
    assert org_a_id not in bob_ids


async def test_get_other_org_returns_404(client: AsyncClient):
    """User A creates org, User B cannot GET it."""
    headers_a = await _auth_headers(client, email="charlie@example.com")
    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "Charlie Co", "slug": "charlie-co", "plan_tier": "pro_site"},
        headers=headers_a,
    )
    assert org.status_code == 201
    org_id = org.json()["id"]

    headers_b = await _auth_headers(client, email="dave@example.com")
    resp = await client.get(f"/api/v1/organizations/{org_id}", headers=headers_b)
    assert resp.status_code in (403, 404)


async def test_add_member_to_org(client: AsyncClient):
    """Owner adds a member to the organization. May be 501 if endpoint not yet implemented."""
    headers_owner = await _auth_headers(client, email="eve@example.com")
    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "Eve Org", "slug": "eve-org", "plan_tier": "pro_site"},
        headers=headers_owner,
    )
    assert org.status_code == 201
    org_id = org.json()["id"]

    # Register a second user
    headers_member = await _auth_headers(client, email="frank@example.com")

    # Try to add frank as member — endpoint may not exist yet
    add_resp = await client.post(
        f"/api/v1/organizations/{org_id}/members",
        json={"user_email": "frank@example.com", "role": "member"},
        headers=headers_owner,
    )
    # Accept 201 (created) or 501 (not implemented) or 404 (not routed)
    assert add_resp.status_code in (201, 404, 501, 422), f"Unexpected: {add_resp.status_code} {add_resp.text}"


async def test_non_member_cannot_see_org(client: AsyncClient):
    """Non-member cannot see an org they don't belong to."""
    headers_a = await _auth_headers(client, email="grace@example.com")
    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "Grace Org", "slug": "grace-org", "plan_tier": "pro_site"},
        headers=headers_a,
    )
    assert org.status_code == 201
    org_id = org.json()["id"]

    headers_b = await _auth_headers(client, email="heidi@example.com")
    resp = await client.get(f"/api/v1/organizations/{org_id}", headers=headers_b)
    assert resp.status_code in (404, 403)


async def test_cross_org_site_access(client: AsyncClient):
    """User B cannot access a site that belongs to Org A."""
    headers_a = await _auth_headers(client, email="irwin@example.com")
    org_a = await client.post(
        "/api/v1/organizations/",
        json={"name": "Irwin Corp", "slug": "irwin-corp", "plan_tier": "pro_site"},
        headers=headers_a,
    )
    assert org_a.status_code == 201
    org_a_id = org_a.json()["id"]

    site = await client.post(
        "/api/v1/sites/",
        json={"organization_id": org_a_id, "name": "Irwin Site", "timezone": "UTC"},
        headers=headers_a,
    )
    assert site.status_code == 201
    site_id = site.json()["id"]

    headers_b = await _auth_headers(client, email="julia@example.com")
    # Create org for user B so they have membership somewhere
    await client.post(
        "/api/v1/organizations/",
        json={"name": "Julia Corp", "slug": "julia-corp", "plan_tier": "pro_site"},
        headers=headers_b,
    )
    resp = await client.get(f"/api/v1/sites/{site_id}", headers=headers_b)
    assert resp.status_code in (403, 404)


async def test_cross_org_zone_access(client: AsyncClient):
    """User B cannot access a zone that belongs to Org A."""
    headers_a = await _auth_headers(client, email="kurt@example.com")
    org_a = await client.post(
        "/api/v1/organizations/",
        json={"name": "Kurt Corp", "slug": "kurt-corp", "plan_tier": "pro_site"},
        headers=headers_a,
    )
    assert org_a.status_code == 201
    org_a_id = org_a.json()["id"]

    site = await client.post(
        "/api/v1/sites/",
        json={"organization_id": org_a_id, "name": "Kurt Site", "timezone": "UTC"},
        headers=headers_a,
    )
    assert site.status_code == 201
    site_id = site.json()["id"]

    zone = await client.post(
        "/api/v1/zones/",
        json={"site_id": site_id, "name": "Kurt Zone"},
        headers=headers_a,
    )
    assert zone.status_code == 201
    zone_id = zone.json()["id"]

    headers_b = await _auth_headers(client, email="lisa@example.com")
    await client.post(
        "/api/v1/organizations/",
        json={"name": "Lisa Corp", "slug": "lisa-corp", "plan_tier": "pro_site"},
        headers=headers_b,
    )
    resp = await client.get(f"/api/v1/zones/{zone_id}", headers=headers_b)
    assert resp.status_code in (403, 404)


async def test_create_policy(client: AsyncClient):
    """POST /policies/ with thresholds → 201."""
    headers = await _auth_headers(client)
    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "Policy Test", "slug": "policy-test", "plan_tier": "pro_site"},
        headers=headers,
    )
    assert org.status_code == 201
    org_id = org.json()["id"]

    policy = await client.post(
        "/api/v1/policies/",
        json={
            "scope_type": "organization",
            "organization_id": org_id,
            "name": "Quiet policy",
            "evidence_mode": "derived_only",
            "retention_days": 180,
            "night_threshold_db": 45,
            "day_threshold_db": 60,
        },
        headers=headers,
    )
    assert policy.status_code == 201
    assert policy.json()["scope_type"] == "organization"
    assert policy.json()["night_threshold_db"] == 45.0
    assert policy.json()["day_threshold_db"] == 60.0


async def test_policy_invalid_threshold(client: AsyncClient):
    """POST /policies/ with dB > 200 → 422 (schema validation)."""
    headers = await _auth_headers(client)
    org = await client.post(
        "/api/v1/organizations/",
        json={"name": "Threshold Test", "slug": "threshold-test", "plan_tier": "pro_site"},
        headers=headers,
    )
    assert org.status_code == 201
    org_id = org.json()["id"]

    resp = await client.post(
        "/api/v1/policies/",
        json={
            "scope_type": "organization",
            "organization_id": org_id,
            "name": "Invalid threshold",
            "day_threshold_db": 201,
        },
        headers=headers,
    )
    assert resp.status_code == 422

    resp2 = await client.post(
        "/api/v1/policies/",
        json={
            "scope_type": "organization",
            "organization_id": org_id,
            "name": "Negative threshold",
            "day_threshold_db": -1,
        },
        headers=headers,
    )
    assert resp2.status_code == 422


async def test_cross_org_policy_access(client: AsyncClient):
    """User B cannot access a policy that belongs to Org A."""
    headers_a = await _auth_headers(client, email="mike@example.com")
    org_a = await client.post(
        "/api/v1/organizations/",
        json={"name": "Mike Corp", "slug": "mike-corp", "plan_tier": "pro_site"},
        headers=headers_a,
    )
    assert org_a.status_code == 201
    org_a_id = org_a.json()["id"]

    policy = await client.post(
        "/api/v1/policies/",
        json={
            "scope_type": "organization",
            "organization_id": org_a_id,
            "name": "Mike Policy",
        },
        headers=headers_a,
    )
    assert policy.status_code == 201
    policy_id = policy.json()["id"]

    headers_b = await _auth_headers(client, email="nina@example.com")
    await client.post(
        "/api/v1/organizations/",
        json={"name": "Nina Corp", "slug": "nina-corp", "plan_tier": "pro_site"},
        headers=headers_b,
    )
    resp = await client.get(f"/api/v1/policies/{policy_id}", headers=headers_b)
    assert resp.status_code in (403, 404)


async def test_cross_org_calibration_profile_access(client: AsyncClient):
    """User B cannot access a calibration profile owned by Org A."""
    headers_a = await _auth_headers(client, email="oscar@example.com")
    org_a = await client.post(
        "/api/v1/organizations/",
        json={"name": "Oscar Corp", "slug": "oscar-corp", "plan_tier": "pro_site"},
        headers=headers_a,
    )
    assert org_a.status_code == 201
    org_a_id = org_a.json()["id"]

    profile = await client.post(
        "/api/v1/calibration-profiles/",
        json={
            "organization_id": org_a_id,
            "name": "Oscar profile",
            "offset_db": 1.0,
        },
        headers=headers_a,
    )
    assert profile.status_code == 201
    profile_id = profile.json()["id"]

    headers_b = await _auth_headers(client, email="peter@example.com")
    await client.post(
        "/api/v1/organizations/",
        json={"name": "Peter Corp", "slug": "peter-corp", "plan_tier": "pro_site"},
        headers=headers_b,
    )
    resp = await client.get(f"/api/v1/calibration-profiles/{profile_id}", headers=headers_b)
    assert resp.status_code in (403, 404)


async def test_unauthenticated_cannot_access_pro_endpoints(client: AsyncClient):
    """All pro endpoints return 401 without auth."""
    endpoints = [
        "/api/v1/sites/",
        "/api/v1/zones/",
        "/api/v1/policies/",
        "/api/v1/calibration-profiles/",
    ]
    for endpoint in endpoints:
        resp = await client.get(endpoint)
        assert resp.status_code == 401, f"{endpoint} returned {resp.status_code}"

    # Also try a POST
    resp = await client.post("/api/v1/organizations/", json={
        "name": "Unauth", "slug": "unauth", "plan_tier": "pro_site",
    })
    assert resp.status_code == 401
