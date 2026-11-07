"""Behavioral privacy boundaries for the quarantined map pilot."""
from datetime import UTC, datetime, timedelta
import pytest
from sqlalchemy import select
from app.core.config import settings
from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution


@pytest.mark.asyncio
async def test_closed_by_default_and_legacy_routes_closed(client):
    assert not settings.ENABLE_MAP_PILOT_INTAKE
    assert not settings.ENABLE_LEGACY_PUBLIC_MAP
    assert (await client.get('/api/v1/map-pilot/public')).status_code == 404
    assert (await client.get('/api/v1/map/events')).status_code == 404
    assert (await client.get('/api/v1/map/heatmap', params={'min_lat': 0, 'max_lat': 1, 'min_lng': 0, 'max_lng': 1})).status_code == 404


@pytest.mark.asyncio
async def test_opt_in_upload_revoke_reconsent_and_stale_queue(auth_client, db_session, monkeypatch):
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'MAP_PILOT_ALLOWED_CELLS', ['test-area', 'other-area'])
    path = '/api/v1/map-pilot'
    body = {'generation': '00000000-0000-0000-0000-000000000001', 'day': (datetime.now(UTC).date() - timedelta(days=1)).isoformat(), 'cell_id': 'test-area', 'level_band': 'medium'}
    assert (await auth_client.put(path+'/contribution', json=body)).status_code == 403
    assert (await auth_client.get(path+'/consent')).json() == {'enabled': False}
    assert (await auth_client.post(path+'/consent', json={'notice_version':'pilot-draft-2026-11-07', 'accepted':False})).status_code == 422
    grant = await auth_client.post(path+'/consent', json={'notice_version':'pilot-draft-2026-11-07', 'accepted':True})
    assert grant.status_code == 200
    status = await auth_client.get(path+'/consent')
    assert status.headers['cache-control'] == 'no-store'
    assert status.json()['generation'] == grant.json()['generation']
    body['generation'] = grant.json()['generation']
    consent = await db_session.scalar(select(MapPilotConsent))
    consent.consented_at = datetime.now(UTC) - timedelta(days=3)
    await db_session.commit()
    assert (await auth_client.put(path+'/contribution', json={**body, 'latitude':53.5})).status_code == 422
    assert (await auth_client.put(path+'/contribution', json={**body, 'cell_id':'custom-location'})).status_code == 422
    assert (await auth_client.put(path+'/contribution', json=body)).status_code == 204
    assert (await auth_client.put(path+'/contribution', json=body)).status_code == 204
    assert (await auth_client.put(path+'/contribution', json={**body, 'cell_id':'other-area'})).status_code == 409
    assert (await auth_client.get(path+'/public')).json() == {'areas': [], 'status':'not_available'}
    assert (await auth_client.delete(path+'/consent')).status_code == 204
    assert (await auth_client.get(path+'/consent')).json() == {'enabled': False}
    assert (await db_session.scalars(select(MapPilotContribution))).all() == []
    assert (await auth_client.put(path+'/contribution', json=body)).status_code == 403
    renewed = await auth_client.post(path+'/consent', json={'notice_version':'pilot-draft-2026-11-07', 'accepted':True})
    assert renewed.json()['generation'] != body['generation']
    assert (await auth_client.put(path+'/contribution', json=body)).status_code == 403


@pytest.mark.asyncio
async def test_pilot_requires_authentication(client, monkeypatch):
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    assert (await client.post('/api/v1/map-pilot/consent', json={'notice_version':'pilot-draft-2026-11-07','accepted':True})).status_code == 401
    assert (await client.delete('/api/v1/map-pilot/consent')).status_code == 401


@pytest.mark.asyncio
async def test_legacy_public_device_and_event_do_not_bypass_closed_map(client, db_session):
    from app.db.models.device import Device
    from app.db.models.event import Event
    device = Device(device_id='legacy-public', name='test', device_type='smartphone', is_public=True, location_lat=53.5, location_lng=10.0)
    db_session.add(device)
    await db_session.flush()
    event = Event(device_id=device.id, timestamp_start=datetime.now(UTC), location_lat=53.5, location_lng=10.0)
    db_session.add(event)
    await db_session.flush()
    assert (await client.get('/api/v1/devices/legacy-public')).status_code == 404
    assert (await client.get('/api/v1/devices/legacy-public/timeline')).status_code == 404
    assert (await client.get('/api/v1/devices/')).json() == []
    assert (await client.get(f'/api/v1/events/{event.id}')).status_code == 404
    result = await client.get('/api/v1/events/')
    assert result.status_code == 200 and result.json()['events'] == []


@pytest.mark.asyncio
async def test_account_deletion_removes_only_own_pilot_data(auth_client, db_session, monkeypatch):
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'MAP_PILOT_ALLOWED_CELLS', ['test-area'])
    grant = await auth_client.post('/api/v1/map-pilot/consent', json={'notice_version':'pilot-draft-2026-11-07','accepted':True})
    assert grant.status_code == 200
    consent = await db_session.scalar(select(MapPilotConsent))
    consent.consented_at = datetime.now(UTC) - timedelta(days=3)
    await db_session.commit()
    body = {'generation': grant.json()['generation'], 'day': (datetime.now(UTC).date() - timedelta(days=1)).isoformat(), 'cell_id': 'test-area', 'level_band': 'low'}
    assert (await auth_client.put('/api/v1/map-pilot/contribution', json=body)).status_code == 204
    assert (await auth_client.post('/api/v1/auth/account-deletion', json={'password':'wrong'})).status_code == 403
    assert len((await db_session.scalars(select(MapPilotContribution))).all()) == 1
    assert (await auth_client.post('/api/v1/auth/account-deletion', json={'password':'testpass123'})).status_code == 204
    assert (await db_session.scalars(select(MapPilotContribution))).all() == []
    assert (await db_session.scalars(select(MapPilotConsent))).all() == []


@pytest.mark.asyncio
async def test_pilot_refuses_unsafe_legacy_configuration(client, monkeypatch):
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'ENABLE_LEGACY_PUBLIC_MAP', True)
    assert (await client.get('/api/v1/map-pilot/public')).status_code == 404


@pytest.mark.asyncio
async def test_five_accounts_still_do_not_prove_independent_participants(client, db_session, monkeypatch):
    from uuid import uuid4
    from app.db.models.user import User
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    for i in range(5):
        user = User(id=uuid4(), email=f'fake{i}@example.org', full_name='synthetic', hashed_password='none', is_active=True, is_superuser=False, is_verified=False)
        db_session.add(user)
        await db_session.flush()
        db_session.add(MapPilotContribution(user_id=user.id, day=datetime.now(UTC).date()-timedelta(days=1), cell_id="test-area", level_band='high'))
    await db_session.commit()
    r = await client.get('/api/v1/map-pilot/public')
    assert r.status_code == 200 and r.json() == {'areas': [], 'status':'not_available'}
    assert r.headers['cache-control'] == 'no-store'


@pytest.mark.asyncio
async def test_retention_purges_only_expired_contributions_and_requires_commit(db_session):
    from datetime import date
    from uuid import uuid4
    from app.db.models.user import User
    from app.services.map_pilot_retention import erase_contributions_before_retention_cutoff
    today = date(2026, 11, 7)
    user = User(id=uuid4(), email='retention@example.org', full_name='synthetic', hashed_password='none', is_active=True, is_superuser=False, is_verified=False)
    db_session.add(user)
    await db_session.flush()
    for age in (31, 30, 1):
        db_session.add(MapPilotContribution(user_id=user.id, day=today-timedelta(days=age), cell_id='test-area', level_band='low'))
    await db_session.commit()
    assert await erase_contributions_before_retention_cutoff(db_session, today=today) == 1
    await db_session.rollback()
    assert len((await db_session.scalars(select(MapPilotContribution))).all()) == 3
    assert await erase_contributions_before_retention_cutoff(db_session, today=today) == 1
    await db_session.commit()
    assert sorted((today-d).days for d in (await db_session.scalars(select(MapPilotContribution.day))).all()) == [1, 30]


@pytest.mark.asyncio
async def test_retention_health_is_private_and_reports_missing_stale_ok(auth_client, client, db_session, monkeypatch):
    from app.db.models.map_pilot import MapPilotRetentionRun
    from app.db.models.user import User
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_RETENTION', True)
    monkeypatch.setattr(settings, 'ENABLE_BACKGROUND_TASKS', True)
    path = '/api/v1/map-pilot/admin/retention-health'
    auth = client.headers.pop('Authorization')
    assert (await client.get(path)).status_code == 401
    client.headers['Authorization'] = auth
    assert (await auth_client.get(path)).status_code == 403
    user = await db_session.scalar(select(User).where(User.email == 'authed@test.noisenet.org'))
    user.is_superuser = True
    await db_session.commit()
    assert (await auth_client.get(path)).json() == {'status': 'missing'}
    db_session.add(MapPilotRetentionRun(completed_at=datetime.now(UTC)-timedelta(hours=3)))
    await db_session.commit()
    assert (await auth_client.get(path)).json()['status'] == 'stale'
    db_session.add(MapPilotRetentionRun(completed_at=datetime.now(UTC)))
    await db_session.commit()
    r = await auth_client.get(path)
    assert r.json()['status'] == 'ok' and r.headers['cache-control'] == 'no-store'
    db_session.add(MapPilotRetentionRun(completed_at=datetime.now(UTC)+timedelta(hours=1)))
    await db_session.commit()
    assert (await auth_client.get(path)).json()['status'] == 'clock_error'
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_RETENTION', False)
    assert (await auth_client.get(path)).json() == {'status': 'disabled'}
