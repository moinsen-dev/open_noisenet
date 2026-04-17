"""
Event model for noise events.
"""

import uuid
from datetime import datetime
from enum import Enum
from typing import Optional

from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Uuid,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class EventStatus(str, Enum):
    """Processing status of a noise event."""

    ACTIVE = "active"
    PROCESSED = "processed"
    ARCHIVED = "archived"
    INVALID = "invalid"


class Event(Base):
    """Noise event recorded by a monitoring device."""

    __tablename__ = "events"

    event_uuid: Mapped[Optional[str]] = mapped_column(
        String(36), nullable=True, unique=True, index=True
    )
    device_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("devices.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    episode_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("episodes.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
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
    analysis_state: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="not_started",
        server_default=text("'not_started'"),
    )
    classification_label: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True
    )
    classification_confidence: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    classification_source: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True
    )
    segment_type: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    reportability_score: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    reportability_reason: Mapped[Optional[str]] = mapped_column(
        String(255), nullable=True
    )
    peak_to_average_delta_db: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    variability_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    threshold_exceedance_ratio: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    analysis_updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="active")
    device: Mapped["Device"] = relationship("Device")


class EventAggregation(Base):
    """Aggregated noise statistics for a device over a time bucket."""

    __tablename__ = "event_aggregations"

    device_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("devices.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    time_bucket: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    bucket_duration: Mapped[Optional[str]] = mapped_column(
        String(32), nullable=True
    )
    avg_leq_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    max_leq_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    min_leq_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    event_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    exceedance_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
