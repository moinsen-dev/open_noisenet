"""Commercial Pro domain models."""

import uuid
from datetime import datetime
from enum import Enum
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class OrganizationPlan(str, Enum):
    """Commercial plan tier for an organization."""

    PRO_SITE = "pro_site"
    PORTFOLIO = "portfolio"


class OrganizationStatus(str, Enum):
    """Lifecycle status for an organization."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    PILOT = "pilot"


class MembershipRole(str, Enum):
    """Role of a user within an organization."""

    OWNER = "owner"
    ADMIN = "admin"
    MEMBER = "member"


class PolicyScope(str, Enum):
    """Supported policy scope levels."""

    ORGANIZATION = "organization"
    SITE = "site"
    ZONE = "zone"


class EvidenceMode(str, Enum):
    """Evidence retention posture for Pro workflows."""

    DERIVED_ONLY = "derived_only"
    ENCRYPTED_BUFFER = "encrypted_buffer"
    REDACTED_SNIPPET = "redacted_snippet"


class EpisodeSeverity(str, Enum):
    """Severity band for a commercial incident."""

    INFORMATIONAL = "informational"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class EpisodeReviewState(str, Enum):
    """Human-review state of an episode."""

    PENDING_REVIEW = "pending_review"
    CONFIRMED = "confirmed"
    OVERRIDDEN = "overridden"
    SUPPRESSED = "suppressed"


class EpisodeLifecycleState(str, Enum):
    """Engine lifecycle for episodes."""

    OPEN = "open"
    EXTENDED = "extended"
    CLOSED = "closed"
    EXPORTED = "exported"


class CaseStatus(str, Enum):
    """Operator status for a case."""

    OPEN = "open"
    IN_REVIEW = "in_review"
    CLOSED = "closed"


class ExportFormat(str, Enum):
    """Supported export formats."""

    JSON = "json"
    CSV = "csv"
    PDF = "pdf"


class ExportStatus(str, Enum):
    """Lifecycle status for an export job."""

    READY = "ready"
    FAILED = "failed"


class Organization(Base):
    """Tenant boundary for Pro customers."""

    __tablename__ = "organizations"

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    plan_tier: Mapped[str] = mapped_column(
        String(32), nullable=False, default=OrganizationPlan.PRO_SITE.value
    )
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=OrganizationStatus.PILOT.value
    )
    billing_state: Mapped[str] = mapped_column(String(32), nullable=False, default="trial")
    created_by_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )


class OrganizationMembership(Base):
    """Membership and role binding for organization access."""

    __tablename__ = "organization_memberships"
    __table_args__ = (
        UniqueConstraint("organization_id", "user_id", name="uq_org_membership_org_user"),
    )

    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(
        String(32), nullable=False, default=MembershipRole.MEMBER.value
    )


class Site(Base):
    """Physical site under an organization."""

    __tablename__ = "sites"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), nullable=False, default="UTC")
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    location_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    is_public: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class Zone(Base):
    """Sub-area inside a site."""

    __tablename__ = "zones"
    __table_args__ = (UniqueConstraint("site_id", "name", name="uq_zone_site_name"),)

    site_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("sites.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    quiet_hours_start: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)
    quiet_hours_end: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)
    is_public: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class Policy(Base):
    """Policy envelope for evidence and threshold behavior."""

    __tablename__ = "policies"

    organization_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    site_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("sites.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    zone_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("zones.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    scope_type: Mapped[str] = mapped_column(String(32), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    evidence_mode: Mapped[str] = mapped_column(
        String(32), nullable=False, default=EvidenceMode.DERIVED_ONLY.value
    )
    retention_days: Mapped[int] = mapped_column(nullable=False, default=365)
    quiet_hours_start: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)
    quiet_hours_end: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)
    day_threshold_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    night_threshold_db: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class CalibrationProfile(Base):
    """Reusable calibration profile for one organization or site."""

    __tablename__ = "calibration_profiles"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    site_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("sites.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    offset_db: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    method: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    confidence: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Episode(Base):
    """Primary commercial incident object derived from one or more events."""

    __tablename__ = "episodes"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    site_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("sites.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    zone_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("zones.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    device_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    policy_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("policies.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    primary_class: Mapped[str] = mapped_column(String(128), nullable=False)
    class_family: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    review_label: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    classification_confidence: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    severity: Mapped[str] = mapped_column(
        String(32), nullable=False, default=EpisodeSeverity.LOW.value
    )
    reviewed_severity: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    nuisance_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    quiet_hours_triggered: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    evidence_mode: Mapped[str] = mapped_column(
        String(32), nullable=False, default=EvidenceMode.DERIVED_ONLY.value
    )
    review_state: Mapped[str] = mapped_column(
        String(32), nullable=False, default=EpisodeReviewState.PENDING_REVIEW.value
    )
    lifecycle_state: Mapped[str] = mapped_column(
        String(32), nullable=False, default=EpisodeLifecycleState.CLOSED.value
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    event_count: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    review_notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    review_metadata: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    model_bundle_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    reviewed_by_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    exported_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class Case(Base):
    """Operator-managed incident container that groups episodes."""

    __tablename__ = "cases"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    site_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("sites.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    zone_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("zones.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    opened_by_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=CaseStatus.OPEN.value
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    opened_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    closed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class CaseEpisodeLink(Base):
    """Many-to-many link between cases and episodes."""

    __tablename__ = "case_episode_links"
    __table_args__ = (
        UniqueConstraint("case_id", "episode_id", name="uq_case_episode_link"),
    )

    case_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    episode_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("episodes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )


class ExportJob(Base):
    """Export metadata and generated inline content for operator handoff."""

    __tablename__ = "export_jobs"

    case_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    created_by_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    format: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=ExportStatus.READY.value
    )
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    content_type: Mapped[str] = mapped_column(String(128), nullable=False)
    output_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    output_encoding: Mapped[str] = mapped_column(
        String(32), nullable=False, default="utf-8"
    )
    exported_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
