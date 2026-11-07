"""Optional real PostgreSQL race test, run only against an isolated disposable DB."""
import asyncio
import os
import uuid
from datetime import UTC, datetime, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from app.core.config import settings
from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution
from app.db.models.user import User
from app.api.v1.endpoints.map_pilot import Contribution, contribute, locked_consent


@pytest.mark.asyncio
async def test_withdraw_serializes_with_queued_upload_on_postgres(monkeypatch):
    url = os.environ.get('MAP_PILOT_DISPOSABLE_POSTGRES_URL')
    if not url:
        pytest.skip('Requires an explicitly provided isolated disposable PostgreSQL database')
    engine = create_async_engine(url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    uid, generation = uuid.uuid4(), uuid.uuid4()
    monkeypatch.setattr(settings, 'MAP_PILOT_ALLOWED_CELLS', ['test-area'])
    try:
        async with factory() as setup:
            user = User(id=uid, email=f'{uid}@example.org', hashed_password='synthetic', full_name='Synthetic', is_active=True, is_superuser=False, is_verified=False)
            setup.add(user)
            await setup.flush()
            setup.add(MapPilotConsent(user_id=uid, enabled=True, generation=generation, consented_at=datetime.now(UTC)-timedelta(days=3), notice_version='pilot-draft-2026-11-07'))
            await setup.commit()
        async with factory() as withdrawal, factory() as upload:
            row = await locked_consent(withdrawal, uid)
            candidate = Contribution(generation=generation, day=datetime.now(UTC).date()-timedelta(days=1), cell_id='test-area', level_band='low')
            task = asyncio.create_task(contribute(candidate, upload, user))
            try:
                with pytest.raises(asyncio.TimeoutError):
                    await asyncio.wait_for(asyncio.shield(task), timeout=0.25)
                row.enabled = False
                row.generation = uuid.uuid4()
                await withdrawal.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == uid))
                await withdrawal.commit()
                with pytest.raises(HTTPException) as exc:
                    await asyncio.wait_for(task, timeout=5)
                assert exc.value.status_code == 403
                await upload.rollback()
                assert (await upload.scalars(select(MapPilotContribution).where(MapPilotContribution.user_id == uid))).all() == []
            finally:
                if not task.done():
                    task.cancel()
                    await asyncio.gather(task, return_exceptions=True)
    finally:
        async with factory() as cleanup:
            await cleanup.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == uid))
            await cleanup.execute(delete(MapPilotConsent).where(MapPilotConsent.user_id == uid))
            await cleanup.execute(delete(User).where(User.id == uid))
            await cleanup.commit()
        await engine.dispose()


@pytest.mark.asyncio
async def test_scheduled_retention_commits_in_postgres(monkeypatch):
    """Real worker task and DB, isolated synthetic database only."""
    from datetime import date
    from app.workers.celery_app import celery_app
    from app.db.models.map_pilot import MapPilotRetentionRun
    url = os.environ.get('MAP_PILOT_DISPOSABLE_POSTGRES_URL')
    if not url:
        pytest.skip('Requires an explicitly provided isolated disposable PostgreSQL database')
    assert url == str(settings.DATABASE_URL)
    engine = create_async_engine(url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    uid = uuid.uuid4()
    for key, value in [('ENABLE_MAP_PILOT_RETENTION', True), ('ENABLE_MAP_PILOT_INTAKE', True), ('ENABLE_BACKGROUND_TASKS', True), ('ENABLE_LEGACY_PUBLIC_MAP', False)]:
        monkeypatch.setattr(settings, key, value)
    try:
        async with factory() as setup:
            setup.add(User(id=uid, email=f'{uid}@example.org', hashed_password='synthetic', full_name='Synthetic', is_active=True, is_superuser=False, is_verified=False))
            await setup.flush()
            for age in (31, 30):
                setup.add(MapPilotContribution(user_id=uid, day=datetime.now(UTC).date()-timedelta(days=age), cell_id='test-area', level_band='low'))
            await setup.commit()
        task = celery_app.tasks['app.workers.maintenance_tasks.map_pilot_retention']
        outcome = await asyncio.to_thread(lambda: task.apply(throw=True).get())
        assert outcome == {'status': 'committed', 'deleted': 1}
        async with factory() as check:
            remaining = (await check.scalars(select(MapPilotContribution).where(MapPilotContribution.user_id == uid))).all()
            assert len(remaining) == 1 and remaining[0].day == datetime.now(UTC).date()-timedelta(days=30)
            assert len((await check.scalars(select(MapPilotRetentionRun))).all()) == 1
    finally:
        async with factory() as cleanup:
            await cleanup.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == uid))
            await cleanup.execute(delete(User).where(User.id == uid))
            await cleanup.commit()
        await engine.dispose()
