"""Retention primitive for the isolated pilot, not an automatic scheduler.

A production operator must independently schedule and monitor this task, review
backup retention and verify that storage deletion actually took effect.
"""
from datetime import date, timedelta
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.map_pilot import MapPilotContribution


async def erase_contributions_before_retention_cutoff(db: AsyncSession, *, today: date) -> int:
    """Delete contributions whose day is strictly more than 30 days old.

    Caller controls the transaction and must commit before acknowledging success.
    """
    result = await db.execute(delete(MapPilotContribution).where(
        MapPilotContribution.day < today - timedelta(days=30)
    ))
    return result.rowcount
