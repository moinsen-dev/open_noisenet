"""Noise event endpoints."""

from typing import List, Optional
from uuid import UUID
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.core.deps import require_user
from app.db.session import get_session
from app.db.models.event import Event, EventStatus
from app.db.models.device import Device, DeviceType
from app.db.models.user import User
from app.schemas.event import (
    EventCreate,
    EventReceiptResponse,
    EventResponse,
    EventStatusResponse,
    EventListResponse,
    EventFilter,
    EventStats,
)
from app.services.background_processing import queue_realtime_measurement
from app.services.event_analysis import derive_event_analysis
from app.services.episode_engine import sync_event_to_episode

router = APIRouter()


def _serialize_event(event: Event) -> EventResponse:
    return EventResponse(
        id=event.id,
        event_uuid=event.event_uuid,
        episode_id=event.episode_id,
        device_id=event.device.device_id if event.device else str(event.device_id),
        timestamp_start=event.timestamp_start,
        timestamp_end=event.timestamp_end,
        leq_db=event.leq_db,
        lmax_db=event.lmax_db,
        lmin_db=event.lmin_db,
        laeq_db=event.laeq_db,
        exceedance_pct=event.exceedance_pct,
        samples_count=event.samples_count,
        rule_triggered=event.rule_triggered,
        location_lat=event.location_lat,
        location_lng=event.location_lng,
        weather_conditions=event.weather_conditions,
        event_metadata=event.event_metadata,
        analysis_state=event.analysis_state,
        classification_label=event.classification_label,
        classification_confidence=event.classification_confidence,
        classification_source=event.classification_source,
        segment_type=event.segment_type,
        reportability_score=event.reportability_score,
        reportability_reason=event.reportability_reason,
        peak_to_average_delta_db=event.peak_to_average_delta_db,
        variability_db=event.variability_db,
        threshold_exceedance_ratio=event.threshold_exceedance_ratio,
        analysis_updated_at=event.analysis_updated_at,
        status=event.status,
        created_at=event.created_at,
        updated_at=event.updated_at,
    )


def _serialize_event_receipt(event: Event) -> EventReceiptResponse:
    acknowledged_at = event.updated_at or event.created_at

    return EventReceiptResponse(
        event_uuid=event.event_uuid or str(event.id),
        server_event_id=str(event.id),
        episode_id=event.episode_id,
        device_id=event.device.device_id if event.device else str(event.device_id),
        status="acknowledged_by_server",
        received_at=event.created_at,
        acknowledged_at=acknowledged_at,
        analysis_state=event.analysis_state,
        classification_label=event.classification_label,
        reportability_score=event.reportability_score,
        classification_source=event.classification_source,
    )


def _serialize_event_status(event: Event) -> EventStatusResponse:
    acknowledged_at = event.updated_at or event.created_at

    return EventStatusResponse(
        event_uuid=event.event_uuid or str(event.id),
        server_event_id=str(event.id),
        episode_id=event.episode_id,
        device_id=event.device.device_id if event.device else str(event.device_id),
        lifecycle_state="acknowledged_by_server",
        analysis_state=event.analysis_state,
        classification_label=event.classification_label,
        classification_confidence=event.classification_confidence,
        classification_source=event.classification_source,
        segment_type=event.segment_type,
        reportability_score=event.reportability_score,
        reportability_reason=event.reportability_reason,
        peak_to_average_delta_db=event.peak_to_average_delta_db,
        variability_db=event.variability_db,
        threshold_exceedance_ratio=event.threshold_exceedance_ratio,
        received_at=event.created_at,
        acknowledged_at=acknowledged_at,
        analysis_updated_at=event.analysis_updated_at,
    )


def _normalize_json_payload(value: Optional[dict]) -> Optional[dict]:
    return value or None


def _normalize_datetime(value: Optional[datetime]) -> Optional[datetime]:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _float_matches(left: Optional[float], right: Optional[float], *, tolerance: float = 1e-4) -> bool:
    if left is None or right is None:
        return left is right
    return abs(left - right) <= tolerance


def _event_matches_payload(event: Event, event_data: EventCreate) -> bool:
    return (
        (event.device.device_id if event.device else None) == event_data.device_id
        and _normalize_datetime(event.timestamp_start)
        == _normalize_datetime(event_data.timestamp_start)
        and _normalize_datetime(event.timestamp_end)
        == _normalize_datetime(event_data.timestamp_end)
        and _float_matches(event.leq_db, event_data.leq_db)
        and _float_matches(event.lmax_db, event_data.lmax_db)
        and _float_matches(event.lmin_db, event_data.lmin_db)
        and _float_matches(event.laeq_db, event_data.laeq_db)
        and _float_matches(event.exceedance_pct, event_data.exceedance_pct)
        and event.samples_count == event_data.samples_count
        and event.rule_triggered == event_data.rule_triggered
        and _float_matches(event.location_lat, event_data.location_lat)
        and _float_matches(event.location_lng, event_data.location_lng)
        and _normalize_json_payload(event.weather_conditions)
        == _normalize_json_payload(event_data.weather_conditions)
        and _normalize_json_payload(event.event_metadata)
        == _normalize_json_payload(event_data.event_metadata)
        and (
            event_data.classification_label is None
            or event.classification_label == event_data.classification_label
        )
        and (
            event_data.classification_confidence is None
            or _float_matches(
                event.classification_confidence,
                event_data.classification_confidence,
            )
        )
        and (
            event_data.classification_source is None
            or event.classification_source == event_data.classification_source
        )
        and (
            event_data.segment_type is None
            or event.segment_type == event_data.segment_type
        )
        and (
            event_data.reportability_score is None
            or _float_matches(
                event.reportability_score,
                event_data.reportability_score,
            )
        )
        and (
            event_data.reportability_reason is None
            or event.reportability_reason == event_data.reportability_reason
        )
        and (
            event_data.peak_to_average_delta_db is None
            or _float_matches(
                event.peak_to_average_delta_db,
                event_data.peak_to_average_delta_db,
            )
        )
        and (
            event_data.variability_db is None
            or _float_matches(event.variability_db, event_data.variability_db)
        )
        and (
            event_data.threshold_exceedance_ratio is None
            or _float_matches(
                event.threshold_exceedance_ratio,
                event_data.threshold_exceedance_ratio,
            )
        )
    )


@router.post("/", response_model=EventReceiptResponse)
async def create_event(
    event_data: EventCreate,
    db: AsyncSession = Depends(get_session)
):
    """Create a new noise event."""

    incoming_event_uuid = event_data.event_uuid or str(uuid4())

    existing_event_stmt = (
        select(Event)
        .options(selectinload(Event.device))
        .where(Event.event_uuid == incoming_event_uuid)
    )
    existing_event_result = await db.execute(existing_event_stmt)
    existing_event = existing_event_result.scalar_one_or_none()

    if existing_event:
        if not _event_matches_payload(existing_event, event_data):
            raise HTTPException(
                status_code=409,
                detail=(
                    "Conflicting payload for existing event_uuid "
                    f"{incoming_event_uuid}"
                ),
            )
        return _serialize_event_receipt(existing_event)

    # First, find or create the device
    device_stmt = select(Device).where(Device.device_id == event_data.device_id)
    device_result = await db.execute(device_stmt)
    device = device_result.scalar_one_or_none()

    if not device:
        # Auto-create device if it doesn't exist (for anonymous submissions)
        device = Device(
            device_id=event_data.device_id,
            name=f"Device {event_data.device_id[:8]}",
            device_type=DeviceType.SMARTPHONE,  # Default to smartphone
        )
        db.add(device)
        await db.flush()
        await db.refresh(device)
    
    # Create the event
    analysis = derive_event_analysis(event_data)
    event_dict = event_data.model_dump(
        exclude={
            "device_id",
            "event_uuid",
            "classification_label",
            "classification_confidence",
            "classification_source",
            "segment_type",
            "reportability_score",
            "reportability_reason",
            "peak_to_average_delta_db",
            "variability_db",
            "threshold_exceedance_ratio",
        }
    )
    event_dict["event_uuid"] = incoming_event_uuid
    event_dict["device_id"] = device.id
    event_dict.update(analysis.as_dict())

    new_event = Event(**event_dict)
    db.add(new_event)
    await db.flush()
    await sync_event_to_episode(db, new_event)
    await db.flush()
    await db.refresh(new_event)

    # Background processing is optional in the MVP. Event ingestion must succeed
    # even when Redis/Celery is not running.
    queue_realtime_measurement(
        device_id=device.device_id,
        leq_db=event_data.leq_db,
        timestamp_start=event_data.timestamp_start,
        location_lat=event_data.location_lat,
        location_lng=event_data.location_lng,
    )

    event_stmt = (
        select(Event)
        .options(selectinload(Event.device))
        .where(Event.id == new_event.id)
    )
    event_result = await db.execute(event_stmt)
    created_event = event_result.scalar_one()

    return _serialize_event_receipt(created_event)


@router.get("/status/{event_uuid}", response_model=EventStatusResponse)
async def get_event_status(
    event_uuid: str,
    db: AsyncSession = Depends(get_session),
):
    """Get the latest lifecycle and analysis state for a submitted event."""

    stmt = (
        select(Event)
        .options(selectinload(Event.device))
        .where(Event.event_uuid == event_uuid)
    )
    result = await db.execute(stmt)
    event = result.scalar_one_or_none()

    if not event:
        raise HTTPException(status_code=404, detail=f"Event {event_uuid} not found")

    return _serialize_event_status(event)


@router.get("/", response_model=EventListResponse)
async def list_events(
    device_id: Optional[str] = Query(None, description="Filter by device ID"),
    start_time: Optional[datetime] = Query(None, description="Filter events after this time"),
    end_time: Optional[datetime] = Query(None, description="Filter events before this time"),
    min_leq_db: Optional[float] = Query(None, description="Minimum sound level"),
    max_leq_db: Optional[float] = Query(None, description="Maximum sound level"),
    status: Optional[EventStatus] = Query(None, description="Filter by processing status"),
    rule_triggered: Optional[str] = Query(None, description="Filter by rule name"),
    limit: int = Query(default=100, ge=1, le=1000, description="Number of results to return"),
    offset: int = Query(default=0, ge=0, description="Number of results to skip"),
    db: AsyncSession = Depends(get_session)
):
    """List noise events with filtering and pagination."""
    
    # Build the query
    stmt = select(Event).options(selectinload(Event.device))
    
    # Apply filters
    if device_id:
        # Join with device to filter by device_id string
        stmt = stmt.join(Device).where(Device.device_id == device_id)
    
    if start_time:
        stmt = stmt.where(Event.timestamp_start >= start_time)
    
    if end_time:
        stmt = stmt.where(Event.timestamp_end <= end_time)
    
    if min_leq_db is not None:
        stmt = stmt.where(Event.leq_db >= min_leq_db)
    
    if max_leq_db is not None:
        stmt = stmt.where(Event.leq_db <= max_leq_db)
    
    if status is not None:
        stmt = stmt.where(Event.status == status)
    
    if rule_triggered:
        stmt = stmt.where(Event.rule_triggered == rule_triggered)
    
    # Get total count for pagination
    count_stmt = select(func.count(Event.id))
    if device_id:
        count_stmt = count_stmt.join(Device).where(Device.device_id == device_id)
    if start_time:
        count_stmt = count_stmt.where(Event.timestamp_start >= start_time)
    if end_time:
        count_stmt = count_stmt.where(Event.timestamp_end <= end_time)
    if min_leq_db is not None:
        count_stmt = count_stmt.where(Event.leq_db >= min_leq_db)
    if max_leq_db is not None:
        count_stmt = count_stmt.where(Event.leq_db <= max_leq_db)
    if status is not None:
        count_stmt = count_stmt.where(Event.status == status)
    if rule_triggered:
        count_stmt = count_stmt.where(Event.rule_triggered == rule_triggered)
    
    count_result = await db.execute(count_stmt)
    total = count_result.scalar()
    
    # Apply pagination and ordering
    stmt = stmt.order_by(Event.timestamp_start.desc()).offset(offset).limit(limit)
    
    result = await db.execute(stmt)
    events = result.scalars().all()
    
    return EventListResponse(
        events=[_serialize_event(event) for event in events],
        total=total,
        offset=offset,
        limit=limit
    )


@router.get("/stats/", response_model=EventStats)
async def get_event_stats(
    start_time: Optional[datetime] = Query(None, description="Stats after this time"),
    end_time: Optional[datetime] = Query(None, description="Stats before this time"),
    db: AsyncSession = Depends(get_session)
):
    """Get event statistics."""

    # Total events
    total_stmt = select(func.count(Event.id))
    if start_time:
        total_stmt = total_stmt.where(Event.timestamp_start >= start_time)
    if end_time:
        total_stmt = total_stmt.where(Event.timestamp_end <= end_time)

    total_result = await db.execute(total_stmt)
    total_events = total_result.scalar() or 0

    # Aggregate stats
    if total_events > 0:
        stats_stmt = select(
            func.avg(Event.leq_db).label('avg_leq'),
            func.max(Event.leq_db).label('max_leq'),
            func.min(Event.leq_db).label('min_leq')
        )
        if start_time:
            stats_stmt = stats_stmt.where(Event.timestamp_start >= start_time)
        if end_time:
            stats_stmt = stats_stmt.where(Event.timestamp_end <= end_time)

        stats_result = await db.execute(stats_stmt)
        stats = stats_result.first()
        avg_leq = float(stats.avg_leq) if stats.avg_leq else None
        max_leq = float(stats.max_leq) if stats.max_leq else None
        min_leq = float(stats.min_leq) if stats.min_leq else None
    else:
        avg_leq = max_leq = min_leq = None

    # Events in last 24h and 7d
    now = datetime.now(timezone.utc)
    from datetime import timedelta

    events_24h_stmt = select(func.count(Event.id)).where(
        Event.timestamp_start >= now - timedelta(hours=24)
    )
    events_7d_stmt = select(func.count(Event.id)).where(
        Event.timestamp_start >= now - timedelta(days=7)
    )

    events_24h_result = await db.execute(events_24h_stmt)
    events_7d_result = await db.execute(events_7d_stmt)

    events_last_24h = events_24h_result.scalar() or 0
    events_last_7d = events_7d_result.scalar() or 0

    # Active devices count
    devices_stmt = select(func.count(func.distinct(Event.device_id))).where(
        Event.timestamp_start >= now - timedelta(days=7)
    )

    devices_result = await db.execute(devices_stmt)
    devices_active = devices_result.scalar() or 0

    return EventStats(
        total_events=total_events,
        avg_leq_db=avg_leq,
        max_leq_db=max_leq,
        min_leq_db=min_leq,
        events_last_24h=events_last_24h,
        events_last_7d=events_last_7d,
        devices_active=devices_active
    )


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: UUID,
    db: AsyncSession = Depends(get_session)
):
    """Get specific event details by UUID."""

    stmt = select(Event).options(selectinload(Event.device)).where(Event.id == event_id)
    result = await db.execute(stmt)
    event = result.scalar_one_or_none()

    if not event:
        raise HTTPException(status_code=404, detail=f"Event {event_id} not found")

    return _serialize_event(event)


@router.delete("/{event_id}")
async def delete_event(
    event_id: UUID,
    user: User = Depends(require_user),
    db: AsyncSession = Depends(get_session),
):
    """Delete a noise event."""

    stmt = select(Event).where(Event.id == event_id)
    result = await db.execute(stmt)
    event = result.scalar_one_or_none()

    if not event:
        raise HTTPException(status_code=404, detail=f"Event {event_id} not found")

    await db.delete(event)
    await db.flush()

    return {"message": f"Event {event_id} deleted successfully"}
