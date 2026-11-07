"""Private candidate calculation, not an authority to publish measurements.

An attestation means an operator claimed to have met a distinct person; it
does not cryptographically prove uniqueness. Existing level bands are not yet
validated measurements. No HTTP handler or background task calls this module.
"""
from datetime import UTC, date, datetime, timedelta
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution, MapPilotVerifiedParticipant
from app.db.models.user import User
from app.services.map_pilot_cipher import decrypt_payload
from app.services.map_pilot_projection import AREA, PrototypeContribution, prototype_projection


def _utc_date(value: datetime) -> date:
    # SQLite synthetic test sessions can return naive UTC timestamps.
    return (value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)).date()


async def calculate_private_candidate(db: AsyncSession, week: date, now: datetime) -> list[dict[str, str]]:
    """Calculate only from currently consenting, manually attested accounts.

    A contribution must follow both opt-in and attestation. Decryption or
    malformed payload errors abort the calculation; no partial result is used.
    """
    if week.weekday() != 0 or now.tzinfo is None or now.utcoffset() is None:
        raise ValueError('Expected a UTC week and an aware clock')
    query = (select(MapPilotContribution, MapPilotConsent, MapPilotVerifiedParticipant)
             .join(MapPilotConsent, MapPilotConsent.user_id == MapPilotContribution.user_id)
             .join(MapPilotVerifiedParticipant, MapPilotVerifiedParticipant.user_id == MapPilotContribution.user_id)
             .join(User, User.id == MapPilotContribution.user_id)
             .where(User.is_active.is_(True), MapPilotConsent.enabled.is_(True), MapPilotContribution.day >= week,
                    MapPilotContribution.day < week + timedelta(days=7)))
    records = []
    for contribution, consent, verified in (await db.execute(query)).all():
        if contribution.day <= max(_utc_date(consent.consented_at), _utc_date(verified.verified_at)):
            continue
        payload = decrypt_payload(contribution.user_id, contribution.day, contribution.payload_nonce, contribution.payload_ciphertext)
        if payload.get('cell_id') != AREA:
            continue
        band = payload.get('level_band')
        if band not in ('low', 'medium', 'high'):
            raise ValueError('Invalid pilot payload')
        records.append(PrototypeContribution(str(contribution.user_id), contribution.day, band))
    return prototype_projection(records, week, now)
