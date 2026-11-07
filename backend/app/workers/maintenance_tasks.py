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


async def _run_pilot_retention(session_factory=None):
    from datetime import UTC, datetime, timedelta
    from sqlalchemy import delete
    from app.db.models.map_pilot import MapPilotRetentionRun
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
    from sqlalchemy.pool import NullPool
    from app.core.config import settings
    from app.services.map_pilot_retention import erase_contributions_before_retention_cutoff

    # Celery invokes asyncio.run on each task. A pooled asyncpg connection from
    # the previous run belongs to a closed event loop and must never be reused.
    engine = None
    if session_factory is None:
        engine = create_async_engine(settings.DATABASE_URL, poolclass=NullPool)
        session_factory = async_sessionmaker(engine, expire_on_commit=False)
    try:
        async with session_factory() as db:
            try:
                count = await erase_contributions_before_retention_cutoff(db, today=datetime.now(UTC).date())
                now = datetime.now(UTC)
                await db.execute(delete(MapPilotRetentionRun).where(MapPilotRetentionRun.completed_at < now - timedelta(days=7)))
                db.add(MapPilotRetentionRun(completed_at=now))
                await db.commit()
                return count
            except Exception:
                await db.rollback()
                raise
    finally:
        if engine is not None:
            await engine.dispose()


@celery_app.task(name="app.workers.maintenance_tasks.map_pilot_retention", ignore_result=False)
def map_pilot_retention():
    """Delete only pilot data; raise on failure and report success after commit."""
    import asyncio
    import logging
    from app.core.config import settings

    if (not settings.ENABLE_MAP_PILOT_RETENTION or not settings.ENABLE_MAP_PILOT_INTAKE
            or not settings.ENABLE_BACKGROUND_TASKS or settings.ENABLE_LEGACY_PUBLIC_MAP):
        raise RuntimeError("Map pilot retention is not enabled in an isolated pilot")
    try:
        deleted = asyncio.run(_run_pilot_retention())
    except Exception:
        logging.getLogger(__name__).error("Map pilot retention failed")
        raise
    logging.getLogger(__name__).info("Map pilot retention completed: %d contributions deleted", deleted)
    return {"status": "committed", "deleted": deleted}
