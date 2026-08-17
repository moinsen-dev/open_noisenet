"""Episode detection background tasks."""
from __future__ import annotations

from celery import shared_task
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.services.anonymous_episode_engine import detect_episodes_for_device

# Create async engine for Celery tasks
_engine = create_async_engine(settings.DATABASE_URL, echo=False)
_async_session = sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)


async def _detect_episodes(device_id: str) -> int:
    """Run episode detection for a specific device. Returns number of episodes created."""
    async with _async_session() as db:
        episodes = await detect_episodes_for_device(db, device_id)
        await db.commit()
        return len(episodes)


@shared_task(name="detect_episodes", bind=True, max_retries=3)
def detect_episodes_task(self, device_id: str):
    """Celery task: detect and classify episodes for a device."""
    import asyncio
    try:
        return asyncio.run(_detect_episodes(device_id))
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60)


@shared_task(name="detect_all_episodes", bind=True, max_retries=2)
def detect_all_episodes_task(self):
    """Celery task: detect episodes for all devices with unassigned events."""
    import asyncio
    from sqlalchemy import select, distinct

    async def _run():
        async with _async_session() as db:
            # Get public device_id strings for devices with unassigned events
            # (Event.device_id is the UUID FK; detect_episodes_for_device needs the public string)
            stmt = (
                select(distinct(Device.device_id))
                .join(Event, Event.device_id == Device.id)
                .where(Event.episode_id.is_(None))
            )
            result = await db.execute(stmt)
            device_ids = [row[0] for row in result.fetchall()]

            total = 0
            for did in device_ids:
                episodes = await detect_episodes_for_device(db, did)
                total += len(episodes)

            await db.commit()
            return {"devices_processed": len(device_ids), "episodes_created": total}

    try:
        return asyncio.run(_run())
    except Exception as exc:
        raise self.retry(exc=exc, countdown=120)


# Need this import at module level for the Celery task
from app.db.models.event import Event  # noqa: E402, F811
from app.db.models.device import Device  # noqa: E402, F811
