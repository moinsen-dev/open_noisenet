"""Noise event endpoints."""

from typing import List, Optional
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.db.session import get_session
from app.db.models.event import Event, EventStatus
from app.db.models.device import Device, DeviceType
from app.schemas.event import EventCreate, EventResponse, EventListResponse, EventFilter, EventStats

router = APIRouter()


@router.post("/", response_model=EventResponse)
async def create_event(
    event_data: EventCreate,
    db: AsyncSession = Depends(get_session)
):
    """Create a new noise event."""
    
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
    event_dict = event_data.model_dump(exclude={'device_id'})
    event_dict['device_id'] = device.id  # Use internal UUID
    
    new_event = Event(**event_dict)
    db.add(new_event)
    await db.flush()
    await db.refresh(new_event)
    
    return EventResponse.model_validate(new_event)


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
    stmt = select(Event)
    
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
        events=[EventResponse.model_validate(event) for event in events],
        total=total,
        offset=offset,
        limit=limit
    )


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: UUID,
    db: AsyncSession = Depends(get_session)
):
    """Get specific event details by UUID."""
    
    stmt = select(Event).where(Event.id == event_id)
    result = await db.execute(stmt)
    event = result.scalar_one_or_none()
    
    if not event:
        raise HTTPException(status_code=404, detail=f"Event {event_id} not found")
    
    return EventResponse.model_validate(event)


@router.delete("/{event_id}")
async def delete_event(
    event_id: UUID,
    db: AsyncSession = Depends(get_session)
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


@router.get("/stats/", response_model=EventStats)
async def get_event_stats(
    start_time: Optional[datetime] = Query(None, description="Stats after this time"),
    end_time: Optional[datetime] = Query(None, description="Stats before this time"),
    db: AsyncSession = Depends(get_session)
):
    """Get event statistics."""
    
    # Base query for events
    base_stmt = select(Event)
    if start_time:
        base_stmt = base_stmt.where(Event.timestamp_start >= start_time)
    if end_time:
        base_stmt = base_stmt.where(Event.timestamp_end <= end_time)
    
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
    now = datetime.utcnow()
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
    devices_stmt = select(func.count(func.distinct(Device.id))).select_from(
        Device.join(Event, Device.id == Event.device_id)
    ).where(Event.timestamp_start >= now - timedelta(days=7))
    
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