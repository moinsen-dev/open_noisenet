"""Fail-closed publication primitives; no endpoint can enable or seal weeks.

The guard must be locked when sealing or withdrawing. Withdrawal stops the
entire pilot and permanently suppresses every saved week: rebuilding a changed
aggregate could reveal a participant. This does not retract third-party copies.
Independent identity and acoustic quality checks must precede any real sealing.
"""
from datetime import UTC, date, datetime, time, timedelta
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.db.models.map_pilot import MapPilotPublicationGuard, MapPilotPublishedWeek
from app.services.map_pilot_candidate import calculate_private_candidate


async def suppress_pilot_publication(db: AsyncSession) -> None:
    guard = await db.scalar(select(MapPilotPublicationGuard).where(
        MapPilotPublicationGuard.name == 'pilot').with_for_update())
    if guard:
        guard.enabled = False
    await db.execute(update(MapPilotPublishedWeek).values(suppressed=True))


async def seal_week(db: AsyncSession, week: date, band: str, now: datetime) -> bool:
    """Store once in the caller's transaction. Caller must establish eligibility.

    There is deliberately no route or worker calling this primitive yet.
    """
    if week.weekday() != 0 or band not in ('low', 'medium', 'high') or now.tzinfo is None or now.utcoffset() is None:
        raise ValueError('Invalid pilot week')
    ready = datetime.combine(week + timedelta(days=7), time.min, tzinfo=UTC) + timedelta(hours=48)
    if now < ready:
        return False
    guard = await db.scalar(select(MapPilotPublicationGuard).where(
        MapPilotPublicationGuard.name == 'pilot').with_for_update())
    if not guard or not guard.enabled:
        return False
    existing = await db.scalar(select(MapPilotPublishedWeek).where(MapPilotPublishedWeek.week_start == week))
    if existing:
        return False  # Never revise, even if a new value becomes available.
    db.add(MapPilotPublishedWeek(week_start=week, band=band, suppressed=False))
    await db.flush()
    return True


async def seal_eligible_week(db: AsyncSession, week: date, now: datetime, *,
                             quality_approved: bool = False) -> bool:
    """Atomically evaluate a candidate and seal it under the withdrawal lock.

    No route, worker, or production caller supplies quality_approved. The
    existing client bands have no verifiable provenance; passing True is for
    isolated synthetic testing only until a real quality gate is implemented.
    """
    if not quality_approved or settings.ENVIRONMENT != 'testing':
        return False
    guard = await db.scalar(select(MapPilotPublicationGuard).where(
        MapPilotPublicationGuard.name == 'pilot').with_for_update())
    if not guard or not guard.enabled:
        return False
    candidate = await calculate_private_candidate(db, week, now)
    if len(candidate) != 1:
        return False
    return await seal_week(db, week, candidate[0]['band'], now)
