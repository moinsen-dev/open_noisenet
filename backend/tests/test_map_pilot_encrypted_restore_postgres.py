"""Opt-in disposable PostgreSQL + age drill. Never target real backups or devices."""
import os
import shutil
import subprocess
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.api.v1.endpoints.map_pilot import Contribution, contribute
from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution
from app.db.models.user import User
from app.services.map_pilot_restore import sanitize_restored_pilot


@pytest.mark.asyncio
async def test_encrypted_backup_restore_never_resurrects_withdrawal(tmp_path):
    url = os.environ.get('MAP_PILOT_DISPOSABLE_POSTGRES_URL')
    container = os.environ.get('MAP_PILOT_DISPOSABLE_CONTAINER')
    if not url or not container or not shutil.which('age') or not shutil.which('age-keygen'):
        pytest.skip('Requires explicit disposable local PostgreSQL container and age')
    parsed = make_url(url)
    assert parsed.host == '127.0.0.1' and parsed.database == 'noisenet_pilot_disposable'
    assert container.startswith('noisenet-pilot-restore-drill-')
    target = 'restore_drill_' + uuid.uuid4().hex
    target_url = parsed.set(database=target)
    source_engine = create_async_engine(url)
    source_sessions = async_sessionmaker(source_engine, expire_on_commit=False)
    uid, generation = uuid.uuid4(), uuid.uuid4()
    backup = tmp_path / 'synthetic.pg.age'
    key = tmp_path / 'synthetic-age-key.txt'
    target_created = False
    try:
        generated = subprocess.run(['age-keygen', '-o', str(key)], check=True, capture_output=True)
        del generated
        os.chmod(key, 0o600)
        recipient = subprocess.run(['age-keygen', '-y', str(key)], check=True, capture_output=True, text=True).stdout.strip()
        async with source_sessions() as source:
            source.add(User(id=uid, email=f'{uid}@example.org', full_name='synthetic', hashed_password='synthetic', is_active=True, is_superuser=False, is_verified=False))
            await source.flush()
            source.add(MapPilotConsent(user_id=uid, enabled=True, generation=generation, consented_at=datetime.now(UTC)-timedelta(days=3), notice_version='pilot-draft-2026-11-07'))
            source.add(MapPilotContribution(user_id=uid, day=datetime.now(UTC).date()-timedelta(days=1), payload_nonce=b'synthetic', payload_ciphertext=b'synthetic'))
            await source.commit()
        dump = subprocess.run(['docker', 'exec', container, 'pg_dump', '-U', 'synthetic', '-Fc', 'noisenet_pilot_disposable'], check=True, capture_output=True).stdout
        encrypted = subprocess.run(['age', '-r', recipient], input=dump, check=True, capture_output=True).stdout
        backup.write_bytes(encrypted)
        os.chmod(backup, 0o600)
        assert dump not in encrypted and encrypted.startswith(b'age-encryption.org/')
        # A real withdrawal after the backup: the restore must not revive it.
        async with source_sessions() as source:
            await source.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == uid))
            await source.execute(delete(MapPilotConsent).where(MapPilotConsent.user_id == uid))
            await source.commit()
        subprocess.run(['docker', 'exec', container, 'createdb', '-U', 'synthetic', target], check=True, capture_output=True)
        target_created = True
        restored_dump = subprocess.run(['age', '-d', '-i', str(key), str(backup)], check=True, capture_output=True).stdout
        subprocess.run(['docker', 'exec', '-i', container, 'pg_restore', '-U', 'synthetic', '--exit-on-error', '-d', target], input=restored_dump, check=True, capture_output=True)
        target_engine = create_async_engine(target_url)
        target_sessions = async_sessionmaker(target_engine, expire_on_commit=False)
        try:
            async with target_sessions() as restored:
                assert await restored.scalar(select(MapPilotConsent).where(MapPilotConsent.user_id == uid))
                await sanitize_restored_pilot(restored)
                await restored.commit()
                assert await restored.scalar(select(MapPilotConsent).where(MapPilotConsent.user_id == uid)) is None
                assert await restored.scalar(select(MapPilotContribution).where(MapPilotContribution.user_id == uid)) is None
                user = await restored.get(User, uid)
                assert user is not None
                queued = Contribution(generation=generation, day=datetime.now(UTC).date()-timedelta(days=1), cell_id='hamburg-eimsbuettel', level_band='low')
                with pytest.raises(HTTPException) as rejected:
                    await contribute(queued, restored, user)
                assert rejected.value.status_code == 403
        finally:
            await target_engine.dispose()
    finally:
        if target_created:
            subprocess.run(['docker', 'exec', container, 'dropdb', '-U', 'synthetic', '--if-exists', target], check=True, capture_output=True)
        async with source_sessions() as source:
            await source.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == uid))
            await source.execute(delete(MapPilotConsent).where(MapPilotConsent.user_id == uid))
            await source.execute(delete(User).where(User.id == uid))
            await source.commit()
        await source_engine.dispose()
