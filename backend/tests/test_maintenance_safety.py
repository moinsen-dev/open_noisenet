"""Unimplemented operations must fail explicitly rather than report fake success."""
import pytest

from app.workers.celery_app import celery_app


@pytest.mark.parametrize('task_name', [
    'cleanup_old_data', 'system_health_check', 'generate_daily_reports',
    'generate_weekly_reports', 'optimize_database',
])
def test_unimplemented_maintenance_fails_when_run(task_name):
    task = celery_app.tasks[task_name]
    with pytest.raises(NotImplementedError, match='not implemented'):
        task.apply(throw=True)


def test_unimplemented_maintenance_is_not_scheduled():
    assert celery_app.conf.beat_schedule == {}
