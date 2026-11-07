"""Private, separately consented pilot data; never queried by legacy maps."""
import uuid
from datetime import date, datetime
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, LargeBinary, String, UniqueConstraint, Uuid
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
    payload_nonce: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    payload_ciphertext: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)


class MapPilotRetentionRun(Base):
    """Health heartbeat with no participant identifiers or measurement data."""
    __tablename__ = "map_pilot_retention_runs"
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class MapPilotPublicationGuard(Base):
    """Single serialization point. Disabled if absent or after a withdrawal."""
    __tablename__ = "map_pilot_publication_guard"
    name: Mapped[str] = mapped_column(String(16), unique=True, nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class MapPilotPublishedWeek(Base):
    """A fixed aggregate only. No participants, devices, coordinates or counts."""
    __tablename__ = "map_pilot_published_weeks"
    week_start: Mapped[date] = mapped_column(Date, unique=True, nullable=False)
    band: Mapped[str] = mapped_column(String(6), nullable=False)
    suppressed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class MapPilotVerifiedParticipant(Base):
    """Operator attestation, not an identity document or proof of uniqueness."""
    __tablename__ = "map_pilot_verified_participants"
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), unique=True, nullable=False)
    verified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class MapPilotKeyState(Base):
    """Key check only; the 256-bit key itself remains outside the database."""
    __tablename__ = 'map_pilot_key_state'
    name: Mapped[str] = mapped_column(String(16), unique=True, nullable=False)
    key_check: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
