"""Helpers for optional background processing in MVP flows."""

from datetime import datetime
from typing import Optional

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


def _enqueue_realtime_measurement(
    *,
    device_id: str,
    leq_db: float,
    timestamp_start: datetime,
    location_lat: Optional[float],
    location_lng: Optional[float],
) -> None:
    """Send a realtime processing job to Celery."""
    from app.workers.noise_processing_tasks import process_real_time_measurement

    process_real_time_measurement.delay(
        device_id,
        {
            "spl_db": leq_db,
            "timestamp": timestamp_start.isoformat(),
            "location": {
                "latitude": location_lat,
                "longitude": location_lng,
            },
        },
    )


def queue_realtime_measurement(
    *,
    device_id: str,
    leq_db: float,
    timestamp_start: datetime,
    location_lat: Optional[float],
    location_lng: Optional[float],
) -> bool:
    """Queue realtime measurement processing when background tasks are enabled."""
    if not settings.ENABLE_BACKGROUND_TASKS:
        return False

    try:
        _enqueue_realtime_measurement(
            device_id=device_id,
            leq_db=leq_db,
            timestamp_start=timestamp_start,
            location_lat=location_lat,
            location_lng=location_lng,
        )
        return True
    except Exception as exc:  # pragma: no cover - defensive logging path
        logger.warning(
            "Skipping realtime processing dispatch for %s because the background worker is unavailable: %s",
            device_id,
            exc,
        )
        return False
