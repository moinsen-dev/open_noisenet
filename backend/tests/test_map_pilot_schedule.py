"""The optional worker must never fabricate a successful deletion."""
from types import SimpleNamespace
from unittest.mock import AsyncMock
import pytest
from app.core.config import settings
from app.workers.celery_app import celery_app, pilot_retention_schedule
from app.workers import maintenance_tasks


def config(**updates):
    values = dict(ENABLE_MAP_PILOT_RETENTION=False, ENABLE_MAP_PILOT_INTAKE=False,
                  ENABLE_BACKGROUND_TASKS=False, ENABLE_LEGACY_PUBLIC_MAP=False)
    values.update(updates)
    return SimpleNamespace(**values)


def test_schedule_is_opt_in_and_incompatible_with_legacy():
    assert pilot_retention_schedule(config()) == {}
    assert pilot_retention_schedule(config(ENABLE_MAP_PILOT_RETENTION=True)) == {}
    permitted = dict(ENABLE_MAP_PILOT_RETENTION=True, ENABLE_MAP_PILOT_INTAKE=True, ENABLE_BACKGROUND_TASKS=True)
    assert pilot_retention_schedule(config(**permitted, ENABLE_LEGACY_PUBLIC_MAP=True)) == {}
    assert pilot_retention_schedule(config(**permitted))['map-pilot-retention']['schedule'] == 3600.0


def enable(monkeypatch):
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_RETENTION', True)
    monkeypatch.setattr(settings, 'ENABLE_MAP_PILOT_INTAKE', True)
    monkeypatch.setattr(settings, 'ENABLE_BACKGROUND_TASKS', True)
    monkeypatch.setattr(settings, 'ENABLE_LEGACY_PUBLIC_MAP', False)


def test_task_reports_only_completed_work(monkeypatch):
    task = celery_app.tasks['app.workers.maintenance_tasks.map_pilot_retention']
    with pytest.raises(RuntimeError):
        task.apply(throw=True)
    enable(monkeypatch)
    monkeypatch.setattr(maintenance_tasks, '_run_pilot_retention', AsyncMock(return_value=3))
    assert task.apply(throw=True).get() == {'status': 'committed', 'deleted': 3}
    monkeypatch.setattr(maintenance_tasks, '_run_pilot_retention', AsyncMock(side_effect=RuntimeError('database unavailable')))
    with pytest.raises(RuntimeError, match='database unavailable'):
        task.apply(throw=True)


@pytest.mark.asyncio
async def test_database_failure_rolls_back_without_success_heartbeat(monkeypatch):
    from unittest.mock import MagicMock
    from app.services import map_pilot_retention as retention
    db = MagicMock()
    db.rollback = AsyncMock()
    db.commit = AsyncMock()
    manager = MagicMock()
    manager.__aenter__ = AsyncMock(return_value=db)
    manager.__aexit__ = AsyncMock(return_value=False)
    monkeypatch.setattr(retention, 'erase_contributions_before_retention_cutoff', AsyncMock(side_effect=RuntimeError('synthetic failure')))
    with pytest.raises(RuntimeError, match='synthetic failure'):
        await maintenance_tasks._run_pilot_retention(session_factory=lambda: manager)
    db.rollback.assert_awaited_once()
    db.commit.assert_not_awaited()
    db.add.assert_not_called()
