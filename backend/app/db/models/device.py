"""
Device model for noise monitoring devices.
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from sqlalchemy import Float, String, DateTime, Boolean, JSON, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class DeviceType(str, Enum):
    """Types of monitoring devices."""

    ESP32 = "esp32"
    RASPBERRY_PI = "raspberry_pi"
    SMARTPHONE = "smartphone"
    CUSTOM = "custom"


class Device(Base):
    """A noise monitoring device registered in the system."""

    __tablename__ = "device"

    name: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    device_type: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    firmware_version: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    location_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_seen: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    owner_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    device_metadata: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    calibration_offset: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True, default=0.0
    )
