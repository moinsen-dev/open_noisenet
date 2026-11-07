"""Credential and privacy boundaries for mobile sensors."""
import hashlib
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.db.models.device import Device, DeviceApiKey
from tests.factories import create_device, create_user

pytestmark = pytest.mark.asyncio
KEY = "A" * 43
OTHER = "B" * 43


async def test_key_protects_private_device_and_upload(client, db_session):
    registration = {"device_id": "private-phone", "name": "Private", "location_lat": 52.5, "location_lng": 13.4}
    assert (await client.post('/api/v1/devices/register', json=registration)).status_code == 401
    good = {"X-Device-Key": KEY}
    assert (await client.post('/api/v1/devices/register', json=registration, headers=good)).status_code == 200
    stored = (await db_session.execute(select(DeviceApiKey))).scalar_one()
    assert stored.key_hash == hashlib.sha256(KEY.encode()).hexdigest()
    assert stored.key_hash != KEY
    assert (await client.post('/api/v1/devices/register', json=registration, headers={"X-Device-Key": OTHER})).status_code == 403
    assert (await client.post('/api/v1/devices/register', json={"device_id": "other", "name": "Other"}, headers=good)).status_code == 409
    assert (await client.get('/api/v1/devices/private-phone')).status_code == 404
    assert (await client.get('/api/v1/devices/')).json() == []
    assert (await client.put('/api/v1/devices/private-phone', json={"name": "Taken"})).status_code == 403
    assert (await client.get('/api/v1/devices/private-phone', headers=good)).json()['name'] == 'Private'
    event = {"device_id": "private-phone", "event_uuid": "private-event", "timestamp_start": "2026-11-03T10:00:00Z", "timestamp_end": "2026-11-03T10:01:00Z", "leq_db": 60}
    assert (await client.post('/api/v1/events/', json=event, headers={"X-Device-Key": OTHER})).status_code == 403
    first = await client.post('/api/v1/events/', json=event, headers=good)
    retry = await client.post('/api/v1/events/', json=event, headers=good)
    assert first.status_code == retry.status_code == 200
    assert first.json()['server_event_id'] == retry.json()['server_event_id']
    assert (await client.get('/api/v1/events/')).json()['total'] == 0
    assert (await client.get('/api/v1/map/events')).json()['features'] == []
    assert (await client.get('/api/v1/events/status/private-event')).status_code == 404
    assert (await client.get('/api/v1/events/status/private-event', headers=good)).status_code == 200
    assert (await client.put('/api/v1/devices/private-phone', json={"is_public": True}, headers=good)).status_code == 200
    assert (await client.get('/api/v1/events/')).json()['total'] == 0
    assert (await client.get('/api/v1/events/', headers=good)).json()['total'] == 1


async def test_public_device_does_not_expose_location_free_events(client):
    headers = {"X-Device-Key": KEY}
    registration = {"device_id": "mixed-privacy-phone", "name": "Test"}
    assert (await client.post('/api/v1/devices/register', json=registration, headers=headers)).status_code == 200
    assert (await client.put('/api/v1/devices/mixed-privacy-phone', json={"is_public": True}, headers=headers)).status_code == 200
    now = datetime.now(timezone.utc)
    common = {
        "device_id": "mixed-privacy-phone",
        "timestamp_start": (now - timedelta(minutes=2)).isoformat(),
        "timestamp_end": (now - timedelta(minutes=1)).isoformat(),
        "leq_db": 60,
    }
    private = await client.post('/api/v1/events/', headers=headers,
                                json={**common, "event_uuid": "location-free"})
    public = await client.post('/api/v1/events/', headers=headers,
                               json={**common, "event_uuid": "with-location",
                                     "location_lat": 52.5, "location_lng": 13.4})
    assert private.status_code == public.status_code == 200
    private_id = private.json()['server_event_id']
    assert (await client.get(f'/api/v1/events/{private_id}')).status_code == 404
    assert (await client.get('/api/v1/events/status/location-free')).status_code == 404
    assert (await client.get(f'/api/v1/events/{private_id}', headers=headers)).status_code == 200
    assert (await client.get('/api/v1/events/status/location-free', headers=headers)).status_code == 200
    assert (await client.get('/api/v1/events/')).json()['total'] == 1
    assert (await client.get('/api/v1/events/', headers=headers)).json()['total'] == 2
    assert (await client.get('/api/v1/events/stats/')).json()['total_events'] == 1
    assert (await client.get('/api/v1/events/stats/', headers=headers)).json()['total_events'] == 2
    assert (await client.get('/api/v1/map/stats')).json()['total_events'] == 1
    assert len((await client.get('/api/v1/map/events')).json()['features']) == 1
    timeline_url = f"/api/v1/devices/mixed-privacy-phone/timeline?date={now.date().isoformat()}"
    assert len((await client.get(timeline_url)).json()['events']) == 1
    assert len((await client.get(timeline_url, headers=headers)).json()['events']) == 2


async def test_legacy_device_requires_proven_owner_to_enroll(client, db_session):
    owner = await create_user(db_session, email='legacy@example.org', password='legacy-password')
    owned = await create_device(db_session, device_id='legacy-owned', owner_id=owner.id)
    unowned = await create_device(db_session, device_id='legacy-unowned')
    for device in (owned, unowned):
        response = await client.post('/api/v1/devices/register', json={"device_id": device.device_id, "name": "Claim"}, headers={"X-Device-Key": KEY})
        assert response.status_code == 403
    login = await client.post('/api/v1/auth/login', json={"email": "legacy@example.org", "password": "legacy-password"})
    headers = {"X-Device-Key": KEY, "Authorization": f"Bearer {login.json()['access_token']}"}
    assert (await client.post('/api/v1/devices/register', json={"device_id": "legacy-owned", "name": "Owned"}, headers=headers)).status_code == 200
    assert (await client.post('/api/v1/devices/register', json={"device_id": "legacy-unowned", "name": "Claim"}, headers={"X-Device-Key": OTHER, "Authorization": headers['Authorization']})).status_code == 403
    assert (await db_session.execute(select(Device).where(Device.device_id == 'legacy-unowned'))).scalar_one().name == unowned.name


async def test_other_org_admin_cannot_reassign_private_device(client):
    owner = await client.post('/api/v1/auth/register', json={'email': 'device-owner@example.org', 'password': 'long-password', 'full_name': 'Owner'})
    owner_headers = {'Authorization': f"Bearer {owner.json()['access_token']}", 'X-Device-Key': KEY}
    assert (await client.post('/api/v1/devices/register', json={'device_id': 'do-not-steal', 'name': 'Owner phone'}, headers=owner_headers)).status_code == 200
    attacker = await client.post('/api/v1/auth/register', json={'email': 'other-admin@example.org', 'password': 'long-password', 'full_name': 'Other'})
    headers = {'Authorization': f"Bearer {attacker.json()['access_token']}"}
    org = await client.post('/api/v1/organizations/', json={'name': 'Other org', 'slug': 'other-org'}, headers=headers)
    site = await client.post('/api/v1/sites/', json={'organization_id': org.json()['id'], 'name': 'Other site', 'timezone': 'UTC'}, headers=headers)
    attempt = await client.put('/api/v1/sites/devices/do-not-steal/assignment', json={'site_id': site.json()['id']}, headers=headers)
    assert attempt.status_code == 404
    device = await client.get('/api/v1/devices/do-not-steal', headers=owner_headers)
    assert device.json()['site_id'] is None


@pytest.fixture(autouse=True)
def legacy_map_for_legacy_tests(monkeypatch):
    from app.core.config import settings
    monkeypatch.setattr(settings, "ENABLE_LEGACY_PUBLIC_MAP", True)
