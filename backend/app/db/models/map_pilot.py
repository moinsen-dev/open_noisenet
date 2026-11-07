"""Private, separately consented pilot data; never queried by legacy maps."""
import uuid
from datetime import date, datetime
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base


class MapPilotConsent(Base):
    __tablename__ = "map_pilot_consents"
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    generation: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), nullable=False, default=uuid.uuid4)
    consented_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    notice_version: Mapped[str] = mapped_column(String(32), nullable=False)


class MapPilotContribution(Base):
    __tablename__ = "map_pilot_contributions"
    __table_args__ = (UniqueConstraint("user_id", "day", name="uq_map_pilot_user_day"),)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    day: Mapped[date] = mapped_column(Date, nullable=False)
    cell_x: Mapped[int] = mapped_column(Integer, nullable=False)
    cell_y: Mapped[int] = mapped_column(Integer, nullable=False)
    level_band: Mapped[str] = mapped_column(String(16), nullable=False)
