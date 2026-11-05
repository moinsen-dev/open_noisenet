"""Exercise tenant isolation across nested Pro resources and mixed scopes."""
import pytest

pytestmark = pytest.mark.asyncio


async def _user(client, email):
    response = await client.post('/api/v1/auth/register', json={
        'email': email, 'password': 'long-test-password', 'full_name': 'Test operator',
    })
    assert response.status_code == 201
    return {'Authorization': f"Bearer {response.json()['access_token']}"}


async def test_foreign_nested_resources_are_inaccessible(client):
    owner = await _user(client, 'tenant-owner@example.org')
    outsider = await _user(client, 'tenant-outsider@example.org')
    org = await client.post('/api/v1/organizations/', headers=owner,
                            json={'name': 'Owner', 'slug': 'owner-pro'})
    org_id = org.json()['id']
    site = await client.post('/api/v1/sites/', headers=owner,
                             json={'organization_id': org_id, 'name': 'Private site', 'timezone': 'UTC'})
    site_id = site.json()['id']
    zone = await client.post('/api/v1/zones/', headers=owner,
                             json={'site_id': site_id, 'name': 'Private zone'})
    zone_id = zone.json()['id']
    policy = await client.post('/api/v1/policies/', headers=owner,
                               json={'scope_type': 'zone', 'zone_id': zone_id, 'name': 'Private rule'})
    profile = await client.post('/api/v1/calibration-profiles/', headers=owner,
                                json={'organization_id': org_id, 'site_id': site_id, 'name': 'Private calibration'})
    assert all(response.status_code == 201 for response in (org, site, zone, policy, profile))
    paths = [
        f'/api/v1/organizations/{org_id}', f'/api/v1/sites/{site_id}',
        f'/api/v1/sites/{site_id}/devices', f'/api/v1/zones/{zone_id}',
        f'/api/v1/policies/{policy.json()["id"]}', f'/api/v1/calibration-profiles/{profile.json()["id"]}',
        f'/api/v1/sites/?organization_id={org_id}', f'/api/v1/zones/?site_id={site_id}',
        f'/api/v1/policies/?zone_id={zone_id}', f'/api/v1/calibration-profiles/?organization_id={org_id}',
    ]
    for path in paths:
        assert (await client.get(path, headers=owner)).status_code == 200, path
        assert (await client.get(path, headers=outsider)).status_code in (403, 404), path
    assert (await client.post('/api/v1/zones/', headers=outsider, json={'site_id': site_id, 'name': 'Intruder'})).status_code in (403, 404)
    assert (await client.post('/api/v1/policies/', headers=outsider, json={'scope_type': 'zone', 'zone_id': zone_id, 'name': 'Intruder'})).status_code in (403, 404)
    assert (await client.post('/api/v1/calibration-profiles/', headers=outsider, json={'organization_id': org_id, 'name': 'Intruder'})).status_code in (403, 404)


async def test_policy_scope_cannot_mix_owned_and_foreign_resources(client):
    owner = await _user(client, 'scope-owner@example.org')
    outsider = await _user(client, 'scope-outsider@example.org')
    org_a = await client.post('/api/v1/organizations/', headers=owner, json={'name': 'A', 'slug': 'scope-a'})
    org_b = await client.post('/api/v1/organizations/', headers=outsider, json={'name': 'B', 'slug': 'scope-b'})
    site = await client.post('/api/v1/sites/', headers=outsider,
                             json={'organization_id': org_b.json()['id'], 'name': 'Site B', 'timezone': 'UTC'})
    response = await client.post('/api/v1/policies/', headers=owner, json={
        'scope_type': 'organization', 'organization_id': org_a.json()['id'],
        'site_id': site.json()['id'], 'name': 'Mixed scope',
    })
    assert response.status_code == 422
    response = await client.post('/api/v1/calibration-profiles/', headers=owner, json={
        'organization_id': org_a.json()['id'], 'site_id': site.json()['id'], 'name': 'Mixed calibration',
    })
    assert response.status_code == 400
