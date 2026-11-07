"""Private candidate with synthetic accounts; these are not actual people."""
import base64
import uuid
from datetime import UTC, date, datetime

import pytest
from pydantic import SecretStr
from sqlalchemy import delete, select

from app.core.config import settings
from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution, MapPilotVerifiedParticipant
from app.db.models.user import User
from app.services.map_pilot_candidate import calculate_private_candidate
from app.services.map_pilot_cipher import PilotCipherUnavailable, encrypt_payload


@pytest.mark.asyncio
async def test_only_new_opted_in_and_attested_people_contribute(db_session, monkeypatch):
    monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b's'*32).decode()))
    week, day = date(2026, 10, 26), date(2026, 10, 27)
    now = datetime(2026, 11, 4, tzinfo=UTC)
    ids = [uuid.uuid4() for _ in range(5)]
    for uid in ids:
        db_session.add(User(id=uid, email=f'{uid}@example.org', hashed_password='synthetic', full_name='Synthetic', is_active=True, is_superuser=False, is_verified=False))
        await db_session.flush()
        db_session.add(MapPilotConsent(user_id=uid, enabled=True, generation=uuid.uuid4(), consented_at=datetime(2026, 10, 25, tzinfo=UTC), notice_version='pilot-draft-2026-11-07'))
        db_session.add(MapPilotVerifiedParticipant(user_id=uid, verified_at=datetime(2026, 10, 26, tzinfo=UTC)))
        nonce, cipher = encrypt_payload(uid, day, 'hamburg-eimsbuettel', 'medium')
        db_session.add(MapPilotContribution(user_id=uid, day=day, payload_nonce=nonce, payload_ciphertext=cipher))
    await db_session.commit()
    result = await calculate_private_candidate(db_session, week, now)
    assert result == [{'area':'hamburg-eimsbuettel', 'week_start':'2026-10-26', 'band':'medium'}]
    await db_session.execute(delete(MapPilotVerifiedParticipant).where(MapPilotVerifiedParticipant.user_id == ids[0]))
    assert await calculate_private_candidate(db_session, week, now) == []
    db_session.add(MapPilotVerifiedParticipant(user_id=ids[0], verified_at=datetime(2026, 10, 27, tzinfo=UTC)))
    await db_session.flush()
    assert await calculate_private_candidate(db_session, week, now) == []  # No retroactive history.
    verification = await db_session.scalar(select(MapPilotVerifiedParticipant).where(MapPilotVerifiedParticipant.user_id == ids[0]))
    verification.verified_at = datetime(2026, 10, 26, tzinfo=UTC)
    await db_session.flush()
    row = await db_session.scalar(select(MapPilotContribution).where(MapPilotContribution.user_id == ids[0]))
    row.payload_ciphertext = b'corrupted'
    await db_session.flush()
    with pytest.raises(PilotCipherUnavailable):
        await calculate_private_candidate(db_session, week, now)
