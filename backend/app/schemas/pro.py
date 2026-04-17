"""Schemas for the Pro domain foundation and operator workflows."""

import uuid
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, model_validator

from app.db.models.pro_domain import (
    CaseStatus,
    EpisodeLifecycleState,
    EpisodeReviewState,
    EpisodeSeverity,
    EvidenceMode,
    ExportFormat,
    ExportStatus,
    MembershipRole,
    OrganizationPlan,
    OrganizationStatus,
    PolicyScope,
)


class OrganizationCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    slug: str = Field(..., min_length=3, max_length=255)
    plan_tier: OrganizationPlan = Field(default=OrganizationPlan.PRO_SITE)


class OrganizationResponse(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    plan_tier: str
    status: str
    billing_state: str
    created_by_id: uuid.UUID
    current_user_role: str
    created_at: datetime
    updated_at: datetime


class SiteCreate(BaseModel):
    organization_id: uuid.UUID
    name: str = Field(..., min_length=1, max_length=255)
    timezone: str = Field(default="UTC", min_length=1, max_length=64)
    address: Optional[str] = None
    location_lat: Optional[float] = Field(None, ge=-90, le=90)
    location_lng: Optional[float] = Field(None, ge=-180, le=180)
    is_public: bool = False


class SiteResponse(BaseModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    name: str
    timezone: str
    address: Optional[str]
    location_lat: Optional[float]
    location_lng: Optional[float]
    is_public: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ZoneCreate(BaseModel):
    site_id: uuid.UUID
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    quiet_hours_start: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    quiet_hours_end: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    is_public: bool = False


class ZoneResponse(BaseModel):
    id: uuid.UUID
    site_id: uuid.UUID
    name: str
    description: Optional[str]
    quiet_hours_start: Optional[str]
    quiet_hours_end: Optional[str]
    is_public: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class PolicyCreate(BaseModel):
    scope_type: PolicyScope
    organization_id: Optional[uuid.UUID] = None
    site_id: Optional[uuid.UUID] = None
    zone_id: Optional[uuid.UUID] = None
    name: str = Field(..., min_length=1, max_length=255)
    evidence_mode: EvidenceMode = Field(default=EvidenceMode.DERIVED_ONLY)
    retention_days: int = Field(default=365, ge=1, le=3650)
    quiet_hours_start: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    quiet_hours_end: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    day_threshold_db: Optional[float] = Field(None, ge=0, le=200)
    night_threshold_db: Optional[float] = Field(None, ge=0, le=200)
    is_active: bool = True

    @model_validator(mode="after")
    def validate_scope_fields(self):
        scope_map = {
            PolicyScope.ORGANIZATION: self.organization_id,
            PolicyScope.SITE: self.site_id,
            PolicyScope.ZONE: self.zone_id,
        }
        expected = scope_map[self.scope_type]
        if expected is None:
            raise ValueError("scope_type must match exactly one scope identifier")
        provided = sum(value is not None for value in [self.organization_id, self.site_id, self.zone_id])
        if provided != 1:
            raise ValueError("provide exactly one of organization_id, site_id, or zone_id")
        return self


class PolicyResponse(BaseModel):
    id: uuid.UUID
    scope_type: str
    organization_id: Optional[uuid.UUID]
    site_id: Optional[uuid.UUID]
    zone_id: Optional[uuid.UUID]
    name: str
    evidence_mode: str
    retention_days: int
    quiet_hours_start: Optional[str]
    quiet_hours_end: Optional[str]
    day_threshold_db: Optional[float]
    night_threshold_db: Optional[float]
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CalibrationProfileCreate(BaseModel):
    organization_id: uuid.UUID
    site_id: Optional[uuid.UUID] = None
    name: str = Field(..., min_length=1, max_length=255)
    offset_db: float = Field(default=0.0, ge=-50, le=50)
    method: Optional[str] = Field(None, max_length=255)
    confidence: Optional[float] = Field(None, ge=0, le=1)
    notes: Optional[str] = None
    is_active: bool = True


class CalibrationProfileResponse(BaseModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    site_id: Optional[uuid.UUID]
    name: str
    offset_db: float
    method: Optional[str]
    confidence: Optional[float]
    notes: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class DeviceAssignmentUpdate(BaseModel):
    site_id: uuid.UUID
    zone_id: Optional[uuid.UUID] = None
    calibration_profile_id: Optional[uuid.UUID] = None


class DeviceAssignmentResponse(BaseModel):
    device_id: str
    site_id: uuid.UUID
    zone_id: Optional[uuid.UUID]
    calibration_profile_id: Optional[uuid.UUID]
    updated_at: datetime


class SiteDeviceResponse(BaseModel):
    id: uuid.UUID
    device_id: str
    name: str
    device_type: str
    site_id: Optional[uuid.UUID]
    zone_id: Optional[uuid.UUID]
    calibration_profile_id: Optional[uuid.UUID]
    is_active: bool
    last_seen: Optional[datetime]
    updated_at: datetime

    class Config:
        from_attributes = True


class EpisodeResponse(BaseModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    site_id: uuid.UUID
    zone_id: Optional[uuid.UUID]
    device_id: Optional[uuid.UUID]
    device_public_id: str
    policy_id: Optional[uuid.UUID]
    primary_class: str
    effective_label: str
    class_family: Optional[str]
    review_label: Optional[str]
    classification_confidence: Optional[float]
    severity: str
    effective_severity: str
    reviewed_severity: Optional[str]
    nuisance_score: float
    quiet_hours_triggered: bool
    evidence_mode: str
    review_state: str
    lifecycle_state: str
    started_at: datetime
    ended_at: datetime
    event_count: int
    review_notes: Optional[str]
    model_bundle_id: Optional[str]
    reviewed_by_id: Optional[uuid.UUID]
    reviewed_at: Optional[datetime]
    exported_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime


class EpisodeListResponse(BaseModel):
    episodes: List[EpisodeResponse]
    total: int


class EpisodeReviewRequest(BaseModel):
    review_state: EpisodeReviewState = Field(default=EpisodeReviewState.CONFIRMED)
    review_label: Optional[str] = Field(None, max_length=128)
    severity: Optional[EpisodeSeverity] = None
    notes: Optional[str] = None


class CaseCreate(BaseModel):
    organization_id: uuid.UUID
    site_id: uuid.UUID
    zone_id: Optional[uuid.UUID] = None
    title: str = Field(..., min_length=3, max_length=255)
    summary: Optional[str] = None
    episode_ids: List[uuid.UUID] = Field(..., min_length=1)


class CaseResponse(BaseModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    site_id: uuid.UUID
    zone_id: Optional[uuid.UUID]
    opened_by_id: Optional[uuid.UUID]
    status: str
    title: str
    summary: Optional[str]
    opened_at: datetime
    closed_at: Optional[datetime]
    episode_ids: List[uuid.UUID]
    episode_count: int
    created_at: datetime
    updated_at: datetime


class ExportCreate(BaseModel):
    case_id: uuid.UUID
    format: ExportFormat = Field(default=ExportFormat.JSON)


class ExportResponse(BaseModel):
    id: uuid.UUID
    case_id: uuid.UUID
    created_by_id: Optional[uuid.UUID]
    format: str
    status: str
    file_name: str
    content_type: str
    output_encoding: str
    preview: Optional[str]
    exported_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime
