"""Publication primitives, tested in SQLite; PostgreSQL locking needs separate tests."""
from datetime import UTC, date, datetime

import pytest
from sqlalchemy import select

from app.core.config import settings
from app.db.models.map_pilot import MapPilotPublicationGuard, MapPilotPublishedWeek, MapPilotConsent, MapPilotVerifiedParticipant
from app.services.map_pilot_publication import seal_week, suppress_pilot_publication

WEEK = date(2026, 10, 26)
READY = datetime(2026, 11, 4, tzinfo=UTC)


@pytest.mark.asyncio
async def test_guard_closed_and_sealed_week_cannot_be_replaced(db_session):
    assert not await seal_week(db_session, WEEK, 'low', READY)
    guard = MapPilotPublicationGuard(name='pilot', enabled=False)
    db_session.add(guard)
    await db_session.flush()
    assert not await seal_week(db_session, WEEK, 'low', READY)
    guard.enabled = True
    await db_session.flush()
    assert not await seal_week(db_session, WEEK, 'low', datetime(2026, 11, 3, tzinfo=UTC))
    assert await seal_week(db_session, WEEK, 'low', READY)
    assert not await seal_week(db_session, WEEK, 'high', READY)
    row = await db_session.scalar(select(MapPilotPublishedWeek))
    assert row.band == 'low' and not row.suppressed
    await suppress_pilot_publication(db_session)
    await db_session.flush()
    await db_session.refresh(row)
    assert row.suppressed and not guard.enabled
    guard.enabled = True  # Even accidental reopening cannot rewrite that week.
    await db_session.flush()
    assert not await seal_week(db_session, WEEK, 'high', READY)
    assert row.suppressed


@pytest.mark.asyncio
async def test_withdrawal_suppresses_in_same_commit(auth_client, db_session, monkeypatch):
    from pydantic import SecretStr
    import base64
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b's'*32).decode()))
    db_session.add(MapPilotPublicationGuard(name='pilot', enabled=True))
    db_session.add(MapPilotPublishedWeek(week_start=WEEK, band='low', suppressed=False))
    await db_session.commit()
    result = await auth_client.post('/api/v1/map-pilot/consent', json={'notice_version':'pilot-draft-2026-11-07', 'accepted': True})
    assert result.status_code == 200
    consent = await db_session.scalar(select(MapPilotConsent))
    db_session.add(MapPilotVerifiedParticipant(user_id=consent.user_id, verified_at=READY))
    await db_session.commit()
    assert (await auth_client.delete('/api/v1/map-pilot/consent')).status_code == 204
    db_session.expire_all()
    assert not (await db_session.scalar(select(MapPilotPublicationGuard))).enabled
    assert (await db_session.scalar(select(MapPilotPublishedWeek))).suppressed
    assert (await db_session.scalars(select(MapPilotVerifiedParticipant))).all() == []
    assert (await auth_client.get('/api/v1/map-pilot/public')).json()['areas'] == []


@pytest.mark.asyncio
async def test_database_backed_publication_requires_both_gates_and_stops_on_withdrawal(auth_client, db_session, monkeypatch):
    from pydantic import SecretStr
    import base64
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b's'*32).decode()))
    guard = MapPilotPublicationGuard(name='pilot', enabled=True)
    db_session.add(guard)
    db_session.add(MapPilotPublishedWeek(week_start=date(2020, 1, 6), band='medium', suppressed=False))
    await db_session.commit()
    path = '/api/v1/map-pilot'
    assert (await auth_client.get(path+'/public')).json()['areas'] == []
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_PUBLICATION', True)
    result = await auth_client.get(path+'/public')
    assert result.json()['areas'] == [{'area':'hamburg-eimsbuettel', 'week_start':'2020-01-06', 'band':'medium'}]
    assert result.headers['cache-control'] == 'no-store'
    for params in ({'area': 'other'}, {'week_start': '2020-01-07'}, {'min_lat': '53.5'}, {'device': 'synthetic-person'}):
        repeated = await auth_client.get(path+'/public', params=params)
        assert repeated.json() == result.json()  # No user-defined windows or areas.
        assert repeated.headers['cache-control'] == 'no-store'
    assert (await auth_client.post(path+'/consent', json={'notice_version':'pilot-draft-2026-11-07', 'accepted': True})).status_code == 200
    assert (await auth_client.delete(path+'/consent')).status_code == 204
    assert (await auth_client.get(path+'/public')).json() == {'areas': [], 'status': 'not_available'}
    after = await auth_client.get(path+'/public', params={'week_start': '2020-01-06'})
    assert after.json() == {'areas': [], 'status': 'not_available'}
    assert after.headers['cache-control'] == 'no-store'


@pytest.mark.asyncio
async def test_account_deletion_suppresses_and_bad_password_does_not(auth_client, db_session, monkeypatch):
    from pydantic import SecretStr
    import base64
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b's'*32).decode()))
    db_session.add(MapPilotPublicationGuard(name='pilot', enabled=True))
    db_session.add(MapPilotPublishedWeek(week_start=WEEK, band='low', suppressed=False))
    await db_session.commit()
    assert (await auth_client.post('/api/v1/map-pilot/consent', json={'notice_version':'pilot-draft-2026-11-07', 'accepted': True})).status_code == 200
    assert (await auth_client.post('/api/v1/auth/account-deletion', json={'password':'wrong'})).status_code == 403
    assert (await db_session.scalar(select(MapPilotPublicationGuard))).enabled
    assert (await auth_client.post('/api/v1/auth/account-deletion', json={'password':'testpass123'})).status_code == 204
    db_session.expire_all()
    assert not (await db_session.scalar(select(MapPilotPublicationGuard))).enabled
    assert (await db_session.scalar(select(MapPilotPublishedWeek))).suppressed


@pytest.mark.asyncio
async def test_restore_sanitation_cannot_restore_a_published_week(db_session):
    from app.services.map_pilot_restore import sanitize_restored_pilot
    db_session.add(MapPilotPublicationGuard(name='pilot', enabled=True))
    db_session.add(MapPilotPublishedWeek(week_start=WEEK, band='high', suppressed=False))
    await db_session.commit()
    await sanitize_restored_pilot(db_session)
    await db_session.commit()
    assert not (await db_session.scalar(select(MapPilotPublicationGuard))).enabled
    assert (await db_session.scalars(select(MapPilotPublishedWeek))).all() == []
