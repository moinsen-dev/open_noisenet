"""Explicitly unavailable maintenance jobs.

The former jobs returned fabricated metrics and deletion counts.  They are not
safe to schedule or to report as successful until real implementations and a
retention policy have been approved and validated.
"""

from app.workers.celery_app import celery_app


def _unavailable(task: str):
    raise NotImplementedError(f"{task} is not implemented; no maintenance was performed")


@celery_app.task(name="cleanup_old_data")
def cleanup_old_data():
    return _unavailable("Data retention cleanup")


@celery_app.task(name="system_health_check")
def system_health_check():
    return _unavailable("Background health monitoring")


@celery_app.task(name="generate_daily_reports")
def generate_daily_reports():
    return _unavailable("Daily report generation")


@celery_app.task(name="generate_weekly_reports")
def generate_weekly_reports():
    return _unavailable("Weekly report generation")


@celery_app.task(name="optimize_database")
def optimize_database():
    return _unavailable("Database optimization")
