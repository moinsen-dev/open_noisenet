"""Synthetic restore sanitation; never touches a user's backup or device."""
from datetime import UTC, datetime, timedelta
import uuid
import pytest
from sqlalchemy import select
from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution, MapPilotRetentionRun
from app.db.models.user import User
from app.services.map_pilot_restore import sanitize_restored_pilot


@pytest.mark.asyncio
async def test_restored_pilot_is_erased_transactionally_without_deleting_accounts(db_session):
    user = User(id=uuid.uuid4(), email='synthetic-restore@example.org', full_name='test', hashed_password='not-a-password', is_active=True, is_superuser=False, is_verified=False)
    user_id = user.id
    db_session.add(user)
    await db_session.flush()
    db_session.add(MapPilotConsent(user_id=user.id, enabled=True, generation=uuid.uuid4(), consented_at=datetime.now(UTC)-timedelta(days=3), notice_version='pilot-draft-2026-11-07'))
    db_session.add(MapPilotContribution(user_id=user.id, day=datetime.now(UTC).date()-timedelta(days=1), payload_nonce=b'synthetic', payload_ciphertext=b'synthetic'))
    db_session.add(MapPilotRetentionRun(completed_at=datetime.now(UTC)))
    await db_session.commit()
    await sanitize_restored_pilot(db_session)
    await db_session.rollback()
    assert len((await db_session.scalars(select(MapPilotContribution))).all()) == 1
    await sanitize_restored_pilot(db_session)
    await db_session.commit()
    for cls in (MapPilotConsent, MapPilotContribution, MapPilotRetentionRun):
        assert (await db_session.scalars(select(cls))).all() == []
    assert await db_session.get(User, user_id) is not None
    await sanitize_restored_pilot(db_session)
    await db_session.commit()
    assert (await db_session.scalars(select(MapPilotContribution))).all() == []
