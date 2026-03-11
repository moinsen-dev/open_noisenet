"""
Event model for noise events.
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from sqlalchemy import Float, String, DateTime, Integer, JSON, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class EventStatus(str, Enum):
    """Processing status of a noise event."""

    ACTIVE = "active"
    PROCESSED = "processed"
    ARCHIVED = "archived"
    INVALID = "invalid"


class Event(Base):
    """Noise event recorded by a monitoring device."""

    __tablename__ = "event"

    device_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    timestamp_start: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    timestamp_end: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    leq_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lmax_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lmin_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    laeq_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    exceedance_pct: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    samples_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    rule_triggered: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    location_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    weather_conditions: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    event_metadata: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    status: Mapped[Optional[str]] = mapped_column(
        String(32), nullable=True, default="active"
    )
