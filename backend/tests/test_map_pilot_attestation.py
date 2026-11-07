"""Administrator controls only; tests never attest an actual person."""
import base64
import uuid

import pytest
from pydantic import SecretStr
from sqlalchemy import select

from app.core.config import settings
from app.db.models.map_pilot import MapPilotVerifiedParticipant
from app.db.models.user import User


@pytest.mark.asyncio
async def test_attestation_requires_admin_consent_and_explicit_confirmation(auth_client, db_session, monkeypatch):
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b's'*32).decode()))
    user = await db_session.scalar(select(User))
    path = '/api/v1/map-pilot/admin/attest-participant'
    body = {'user_id': str(user.id), 'personally_confirmed_distinct': True}
    assert (await auth_client.post(path, json=body)).status_code == 403
    user.is_superuser = True
    await db_session.commit()
    assert (await auth_client.post(path, json={**body, 'personally_confirmed_distinct': False})).status_code == 422
    assert (await auth_client.post(path, json={'user_id': str(uuid.uuid4()), 'personally_confirmed_distinct': True})).status_code == 409
    assert (await auth_client.post(path, json=body)).status_code == 409
    assert (await auth_client.post('/api/v1/map-pilot/consent', json={'notice_version':'pilot-draft-2026-11-07', 'accepted':True})).status_code == 200
    assert (await auth_client.post(path, json=body)).status_code == 204
    first = await db_session.scalar(select(MapPilotVerifiedParticipant))
    timestamp = first.verified_at
    assert (await auth_client.post(path, json=body)).status_code == 204
    assert len((await db_session.scalars(select(MapPilotVerifiedParticipant))).all()) == 1
    assert first.verified_at == timestamp
    assert (await auth_client.delete('/api/v1/map-pilot/consent')).status_code == 204
    assert (await db_session.scalars(select(MapPilotVerifiedParticipant))).all() == []
