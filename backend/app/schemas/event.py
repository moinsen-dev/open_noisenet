"""Event-related schemas."""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List

from pydantic import BaseModel, Field

from app.db.models.event import EventStatus


class EventCreate(BaseModel):
    """Schema for creating new noise events."""

    event_uuid: Optional[str] = Field(
        None, description="Client-generated stable UUID for idempotent event submission"
    )
    device_id: str = Field(..., description="Device identifier that recorded this event")
    timestamp_start: datetime = Field(..., description="Event start timestamp")
    timestamp_end: datetime = Field(..., description="Event end timestamp")
    leq_db: float = Field(..., ge=0, le=200, description="Equivalent continuous sound level (dB)")
    lmax_db: Optional[float] = Field(None, ge=0, le=200, description="Maximum sound level (dB)")
    lmin_db: Optional[float] = Field(None, ge=0, le=200, description="Minimum sound level (dB)")
    laeq_db: Optional[float] = Field(None, ge=0, le=200, description="A-weighted equivalent level (dB)")
    exceedance_pct: Optional[float] = Field(None, ge=0, le=100, description="Percentage of time above threshold")
    samples_count: Optional[int] = Field(None, ge=0, description="Number of samples in measurement")
    rule_triggered: Optional[str] = Field(None, max_length=100, description="Rule that triggered this event")
    location_lat: Optional[float] = Field(None, ge=-90, le=90, description="Event latitude (overrides device location)")
    location_lng: Optional[float] = Field(None, ge=-180, le=180, description="Event longitude (overrides device location)")
    weather_conditions: Optional[Dict[str, Any]] = Field(None, description="Weather conditions during event")
    event_metadata: Optional[Dict[str, Any]] = Field(None, description="Additional event metadata")
    classification_label: Optional[str] = Field(
        None,
        max_length=100,
        description="Device-side event classification label",
    )
    classification_confidence: Optional[float] = Field(
        None,
        ge=0,
        le=1,
        description="Device-side classification confidence",
    )
    classification_source: Optional[str] = Field(
        None,
        max_length=64,
        description="Source of the event classification",
    )
    segment_type: Optional[str] = Field(
        None,
        max_length=64,
        description="Segment shape such as sustained or impulsive",
    )
    reportability_score: Optional[float] = Field(
        None,
        ge=0,
        le=1,
        description="Normalized score indicating whether the event should be reported",
    )
    reportability_reason: Optional[str] = Field(
        None,
        max_length=255,
        description="Short explanation for reportability decisions",
    )
    peak_to_average_delta_db: Optional[float] = Field(
        None,
        ge=0,
        le=200,
        description="Peak-to-average delta derived on device",
    )
    variability_db: Optional[float] = Field(
        None,
        ge=0,
        le=200,
        description="Difference between loudest and quietest portions of the event",
    )
    threshold_exceedance_ratio: Optional[float] = Field(
        None,
        ge=0,
        le=1,
        description="Share of event windows that exceeded the configured threshold",
    )


class EventResponse(BaseModel):
    """Schema for event API responses."""

    id: uuid.UUID = Field(..., description="Event internal ID")
    event_uuid: Optional[str] = Field(None, description="Client-generated stable event UUID")
    episode_id: Optional[uuid.UUID] = Field(None, description="Attached episode identifier")
    device_id: str = Field(..., description="Public device identifier")
    timestamp_start: datetime = Field(..., description="Event start timestamp")
    timestamp_end: datetime = Field(..., description="Event end timestamp")
    leq_db: float = Field(..., description="Equivalent continuous sound level (dB)")
    lmax_db: Optional[float] = Field(None, description="Maximum sound level (dB)")
    lmin_db: Optional[float] = Field(None, description="Minimum sound level (dB)")
    laeq_db: Optional[float] = Field(None, description="A-weighted equivalent level (dB)")
    exceedance_pct: Optional[float] = Field(None, description="Percentage of time above threshold")
    samples_count: Optional[int] = Field(None, description="Number of samples in measurement")
    rule_triggered: Optional[str] = Field(None, description="Rule that triggered this event")
    location_lat: Optional[float] = Field(None, description="Event latitude")
    location_lng: Optional[float] = Field(None, description="Event longitude")
    weather_conditions: Optional[Dict[str, Any]] = Field(None, description="Weather conditions")
    event_metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata")
    analysis_state: str = Field(..., description="Server-side analysis state")
    classification_label: Optional[str] = Field(
        None, description="Normalized event classification label"
    )
    classification_confidence: Optional[float] = Field(
        None, description="Classification confidence"
    )
    classification_source: Optional[str] = Field(
        None, description="Which subsystem produced the classification"
    )
    segment_type: Optional[str] = Field(
        None, description="Segment shape such as sustained or impulsive"
    )
    reportability_score: Optional[float] = Field(
        None, description="Normalized reportability score"
    )
    reportability_reason: Optional[str] = Field(
        None, description="Short explanation for reportability"
    )
    peak_to_average_delta_db: Optional[float] = Field(
        None, description="Peak-to-average delta in dB"
    )
    variability_db: Optional[float] = Field(
        None, description="Difference between maximum and minimum levels"
    )
    threshold_exceedance_ratio: Optional[float] = Field(
        None, description="Share of samples above the configured threshold"
    )
    analysis_updated_at: Optional[datetime] = Field(
        None, description="When analysis fields were last updated"
    )
    status: EventStatus = Field(..., description="Event processing status")
    created_at: datetime = Field(..., description="Event creation timestamp")
    updated_at: datetime = Field(..., description="Event last update timestamp")

    class Config:
        from_attributes = True


class EventListResponse(BaseModel):
    """Schema for event list API responses."""
    
    events: List[EventResponse] = Field(..., description="List of events")
    total: int = Field(..., ge=0, description="Total number of events")
    offset: int = Field(..., ge=0, description="Offset for pagination")
    limit: int = Field(..., ge=1, description="Limit for pagination")


class EventReceiptResponse(BaseModel):
    """Receipt returned after successful event ingestion."""

    event_uuid: str = Field(..., description="Stable client event UUID")
    server_event_id: str = Field(..., description="Server-side event identifier")
    episode_id: Optional[uuid.UUID] = Field(None, description="Attached episode identifier")
    device_id: str = Field(..., description="Public device identifier")
    status: str = Field(..., description="Ingestion lifecycle state")
    received_at: datetime = Field(..., description="When the backend received the event")
    acknowledged_at: datetime = Field(
        ..., description="When the backend acknowledged the event"
    )
    analysis_state: str = Field(
        default="not_started", description="Server-side analysis pipeline state"
    )
    classification_label: Optional[str] = Field(
        None, description="Current normalized event classification"
    )
    reportability_score: Optional[float] = Field(
        None, description="Current reportability score"
    )
    classification_source: Optional[str] = Field(
        None, description="Subsystem that produced the current classification"
    )


class EventStatusResponse(BaseModel):
    """Status payload used by devices to confirm sync and analysis."""

    event_uuid: str = Field(..., description="Stable client event UUID")
    server_event_id: str = Field(..., description="Server-side event identifier")
    episode_id: Optional[uuid.UUID] = Field(None, description="Attached episode identifier")
    device_id: str = Field(..., description="Public device identifier")
    lifecycle_state: str = Field(..., description="Current ingestion lifecycle state")
    analysis_state: str = Field(..., description="Current analysis lifecycle state")
    classification_label: Optional[str] = Field(
        None, description="Normalized event classification"
    )
    classification_confidence: Optional[float] = Field(
        None, description="Classification confidence"
    )
    classification_source: Optional[str] = Field(
        None, description="Classification source"
    )
    segment_type: Optional[str] = Field(
        None, description="Segment shape such as sustained or impulsive"
    )
    reportability_score: Optional[float] = Field(
        None, description="Normalized reportability score"
    )
    reportability_reason: Optional[str] = Field(
        None, description="Short explanation for reportability"
    )
    peak_to_average_delta_db: Optional[float] = Field(
        None, description="Peak-to-average delta in dB"
    )
    variability_db: Optional[float] = Field(
        None, description="Difference between maximum and minimum levels"
    )
    threshold_exceedance_ratio: Optional[float] = Field(
        None, description="Share of samples above the configured threshold"
    )
    received_at: datetime = Field(..., description="When the backend received the event")
    acknowledged_at: datetime = Field(
        ..., description="When the backend last acknowledged the event"
    )
    analysis_updated_at: Optional[datetime] = Field(
        None, description="When analysis fields were last updated"
    )


class EventFilter(BaseModel):
    """Schema for event filtering parameters."""
    
    device_id: Optional[str] = Field(None, description="Filter by device ID")
    start_time: Optional[datetime] = Field(None, description="Filter events after this time")
    end_time: Optional[datetime] = Field(None, description="Filter events before this time")
    min_leq_db: Optional[float] = Field(None, ge=0, description="Minimum sound level")
    max_leq_db: Optional[float] = Field(None, le=200, description="Maximum sound level")
    status: Optional[EventStatus] = Field(None, description="Filter by processing status")
    rule_triggered: Optional[str] = Field(None, description="Filter by rule name")
    limit: int = Field(default=100, ge=1, le=1000, description="Number of results to return")
    offset: int = Field(default=0, ge=0, description="Number of results to skip")


class EventStats(BaseModel):
    """Schema for event statistics."""
    
    total_events: int = Field(..., description="Total number of events")
    avg_leq_db: Optional[float] = Field(None, description="Average sound level")
    max_leq_db: Optional[float] = Field(None, description="Maximum sound level")
    min_leq_db: Optional[float] = Field(None, description="Minimum sound level")
    events_last_24h: int = Field(..., description="Events in last 24 hours")
    events_last_7d: int = Field(..., description="Events in last 7 days")
    devices_active: int = Field(..., description="Number of active devices")
