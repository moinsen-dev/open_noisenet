"""Run only against an explicitly configured disposable migrated database."""
import asyncio
import os
import base64
import uuid
from datetime import UTC, date, datetime

import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.models.map_pilot import MapPilotPublicationGuard, MapPilotPublishedWeek
from app.services.map_pilot_publication import seal_week, suppress_pilot_publication
from app.services.map_pilot_cipher import (ensure_database_key, PilotCipherUnavailable, encrypt_payload,
                                           decrypt_payload, rotate_database_key)
from app.core.config import settings
from app.db.models.map_pilot import MapPilotKeyState
from app.db.models.map_pilot import MapPilotContribution
from app.db.models.user import User
from pydantic import SecretStr


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


@pytest.mark.asyncio
async def test_first_key_wins_over_concurrent_changed_key(monkeypatch):
    url = os.environ.get('MAP_PILOT_DISPOSABLE_POSTGRES_URL')
    if not url:
        pytest.skip('Requires isolated disposable PostgreSQL')
    assert url.endswith('/noisenet_pilot_disposable')
    engine = create_async_engine(url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    try:
        async with factory() as setup:
            state = await setup.scalar(select(MapPilotKeyState))
            assert state is not None and state.key_check is None
        async with factory() as first, factory() as second:
            monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b'a'*32).decode()))
            await ensure_database_key(first)
            monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b'b'*32).decode()))
            task = asyncio.create_task(ensure_database_key(second))
            try:
                with pytest.raises(asyncio.TimeoutError):
                    await asyncio.wait_for(asyncio.shield(task), 0.25)
                await first.commit()
                with pytest.raises(PilotCipherUnavailable):
                    await asyncio.wait_for(task, 5)
                await second.rollback()
            finally:
                if not task.done():
                    task.cancel()
                    await asyncio.gather(task, return_exceptions=True)
    finally:
        async with factory() as cleanup:
            state = await cleanup.scalar(select(MapPilotKeyState))
            if state:
                state.key_check = None
            await cleanup.commit()
        await engine.dispose()


@pytest.mark.asyncio
async def test_key_rotation_round_trip_on_postgres(monkeypatch):
    url = os.environ.get('MAP_PILOT_DISPOSABLE_POSTGRES_URL')
    if not url:
        pytest.skip('Requires isolated disposable PostgreSQL')
    assert url.endswith('/noisenet_pilot_disposable')
    engine = create_async_engine(url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    uid = uuid.uuid4()
    try:
        monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b'a'*32).decode()))
        async with factory() as setup:
            await ensure_database_key(setup)
            setup.add(User(id=uid, email=f'{uid}@example.org', hashed_password='synthetic', full_name='Synthetic', is_active=True, is_superuser=False, is_verified=False))
            await setup.flush()
            day = date(2026, 10, 27)
            nonce, ciphertext = encrypt_payload(uid, day, 'hamburg-eimsbuettel', 'low')
            setup.add(MapPilotContribution(user_id=uid, day=day, payload_nonce=nonce, payload_ciphertext=ciphertext))
            await setup.commit()
        async with factory() as rotation:
            await rotate_database_key(rotation, b'b'*32)
            await rotation.commit()
        monkeypatch.setattr(settings, 'MAP_PILOT_ENCRYPTION_KEY', SecretStr(base64.b64encode(b'b'*32).decode()))
        async with factory() as check:
            await ensure_database_key(check)
            row = await check.scalar(select(MapPilotContribution).where(MapPilotContribution.user_id == uid))
            assert decrypt_payload(uid, row.day, row.payload_nonce, row.payload_ciphertext)['level_band'] == 'low'
    finally:
        async with factory() as cleanup:
            await cleanup.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == uid))
            await cleanup.execute(delete(User).where(User.id == uid))
            state = await cleanup.scalar(select(MapPilotKeyState))
            if state:
                state.key_check = None
            await cleanup.commit()
        await engine.dispose()
