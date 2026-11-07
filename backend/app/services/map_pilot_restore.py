"""Fail-closed sanitation primitive for a quarantined, restored pilot database.

Not wired to normal startup. An operator must first isolate the restored instance
from all public and device traffic. Never call this on the live database.
"""
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.map_pilot import (MapPilotConsent, MapPilotContribution, MapPilotRetentionRun,
                                     MapPilotPublishedWeek, MapPilotVerifiedParticipant)
from app.services.map_pilot_publication import suppress_pilot_publication


async def sanitize_restored_pilot(db: AsyncSession) -> None:
    """Remove *all* pilot data in caller's transaction; preserve other product data.

    Discarding all restored pilot data is deliberate: a database backup by itself
    cannot know which users withdrew after it was taken. New opt-in gets a new
    generation; delayed uploads bearing old generations are rejected.
    No acknowledgment until the caller commits, and no release from quarantine
    until the new state and operational safeguards are independently checked.
    """
    await suppress_pilot_publication(db)
    await db.execute(delete(MapPilotPublishedWeek))
    await db.execute(delete(MapPilotVerifiedParticipant))
    await db.execute(delete(MapPilotContribution))
    await db.execute(delete(MapPilotConsent))
    await db.execute(delete(MapPilotRetentionRun))
    for model in (MapPilotPublishedWeek, MapPilotVerifiedParticipant, MapPilotContribution, MapPilotConsent, MapPilotRetentionRun):
        if await db.scalar(select(func.count()).select_from(model)):
            raise RuntimeError('Pilot restore sanitation incomplete')
    await db.flush()
