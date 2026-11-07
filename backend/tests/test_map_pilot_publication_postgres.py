"""Run only against an explicitly configured disposable migrated database."""
import asyncio
import os
from datetime import UTC, date, datetime

import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.models.map_pilot import MapPilotPublicationGuard, MapPilotPublishedWeek
from app.services.map_pilot_publication import seal_week, suppress_pilot_publication


@pytest.mark.asyncio
async def test_suppression_serializes_with_sealing():
    url = os.environ.get('MAP_PILOT_DISPOSABLE_POSTGRES_URL')
    if not url:
        pytest.skip('Requires isolated disposable PostgreSQL')
    assert url.endswith('/noisenet_pilot_disposable')
    engine = create_async_engine(url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    week, ready = date(2026, 10, 26), datetime(2026, 11, 4, tzinfo=UTC)
    try:
        async with factory() as setup:
            guard = await setup.scalar(select(MapPilotPublicationGuard).where(MapPilotPublicationGuard.name == 'pilot'))
            assert guard is not None
            guard.enabled = True
            await setup.commit()
        async with factory() as sealing, factory() as withdrawing:
            assert await seal_week(sealing, week, 'low', ready)
            task = asyncio.create_task(suppress_pilot_publication(withdrawing))
            try:
                with pytest.raises(asyncio.TimeoutError):
                    await asyncio.wait_for(asyncio.shield(task), 0.25)
                await sealing.commit()
                await asyncio.wait_for(task, 5)
                await withdrawing.commit()
            finally:
                if not task.done():
                    task.cancel()
                    await asyncio.gather(task, return_exceptions=True)
        async with factory() as check:
            guard = await check.scalar(select(MapPilotPublicationGuard))
            row = await check.scalar(select(MapPilotPublishedWeek))
            assert not guard.enabled and row.suppressed
            assert not await seal_week(check, date(2026, 10, 19), 'high', ready)
            guard.enabled = True  # Reset only this disposable test DB.
            await check.commit()
        async with factory() as withdrawing, factory() as sealing:
            await suppress_pilot_publication(withdrawing)
            task = asyncio.create_task(seal_week(sealing, date(2026, 10, 19), 'high', ready))
            try:
                with pytest.raises(asyncio.TimeoutError):
                    await asyncio.wait_for(asyncio.shield(task), 0.25)
                await withdrawing.commit()
                assert not await asyncio.wait_for(task, 5)
                await sealing.rollback()
            finally:
                if not task.done():
                    task.cancel()
                    await asyncio.gather(task, return_exceptions=True)
    finally:
        async with factory() as cleanup:
            await cleanup.execute(delete(MapPilotPublishedWeek))
            guard = await cleanup.scalar(select(MapPilotPublicationGuard))
            if guard:
                guard.enabled = False
            await cleanup.commit()
        await engine.dispose()
