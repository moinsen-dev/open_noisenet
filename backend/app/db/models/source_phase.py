"""Private, versioned source activity; deliberately separate from public events."""

import uuid

from sqlalchemy import (
    JSON,
    Boolean,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class SourcePhase(Base):
    __tablename__ = "source_phases"
    __table_args__ = (
        UniqueConstraint("device_id", "phase_uuid", name="uq_source_phase_device_uuid"),
    )

    device_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("devices.id", ondelete="CASCADE"), index=True
    )
    phase_uuid: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    digest: Mapped[str] = mapped_column(String(64), nullable=False)
    payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    deleted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
