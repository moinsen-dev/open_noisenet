"""Map data endpoints."""

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device
from app.db.models.event import Event
from app.db.session import get_session
from app.schemas.map import (
    GeoJSONResponse,
    HeatmapPoint,
    HeatmapResponse,
    MapEventFeature,
    MapStats,
)

router = APIRouter()


@router.get("/events", response_model=GeoJSONResponse)
async def get_map_events(
    min_lat: Optional[float] = Query(None),
    max_lat: Optional[float] = Query(None),
    min_lng: Optional[float] = Query(None),
    max_lng: Optional[float] = Query(None),
    hours: int = Query(24, ge=1, le=720),
    limit: int = Query(500, ge=1, le=5000),
    db: AsyncSession = Depends(get_session),
) -> GeoJSONResponse:
    """Get events in GeoJSON format for map display."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    stmt = select(Event).where(
        Event.location_lat.is_not(None),
        Event.location_lng.is_not(None),
        Event.timestamp_start >= cutoff,
    )

    if min_lat is not None:
        stmt = stmt.where(Event.location_lat >= min_lat)
    if max_lat is not None:
        stmt = stmt.where(Event.location_lat <= max_lat)
    if min_lng is not None:
        stmt = stmt.where(Event.location_lng >= min_lng)
    if max_lng is not None:
        stmt = stmt.where(Event.location_lng <= max_lng)

    stmt = stmt.order_by(Event.timestamp_start.desc()).limit(limit)

    result = await db.execute(stmt)
    events = result.scalars().all()

    features = []
    for ev in events:
        feature = MapEventFeature(
            geometry={
                "type": "Point",
                "coordinates": [float(ev.location_lng), float(ev.location_lat)],
            },
            properties={
                "id": str(ev.id),
                "device_id": str(ev.device_id),
                "leq_db": float(ev.leq_db) if ev.leq_db is not None else None,
                "lmax_db": float(ev.lmax_db) if ev.lmax_db is not None else None,
                "lmin_db": float(ev.lmin_db) if ev.lmin_db is not None else None,
                "timestamp_start": ev.timestamp_start.isoformat()
                if ev.timestamp_start
                else None,
                "status": ev.status,
            },
        )
        features.append(feature)

    return GeoJSONResponse(features=features)


@router.get("/heatmap", response_model=HeatmapResponse)
async def get_heatmap_data(
    min_lat: float = Query(...),
    max_lat: float = Query(...),
    min_lng: float = Query(...),
    max_lng: float = Query(...),
    hours: int = Query(24, ge=1, le=720),
    db: AsyncSession = Depends(get_session),
) -> HeatmapResponse:
    """Get aggregated data for heatmap visualization."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    stmt = select(Event).where(
        Event.location_lat.is_not(None),
        Event.location_lng.is_not(None),
        Event.location_lat >= min_lat,
        Event.location_lat <= max_lat,
        Event.location_lng >= min_lng,
        Event.location_lng <= max_lng,
        Event.timestamp_start >= cutoff,
    )

    result = await db.execute(stmt)
    events = result.scalars().all()

    points = []
    for ev in events:
        intensity = float(ev.leq_db) if ev.leq_db is not None else 0.0
        points.append(
            HeatmapPoint(
                lat=float(ev.location_lat),
                lng=float(ev.location_lng),
                intensity=intensity,
                event_count=1,
            )
        )

    min_intensity = min((p.intensity for p in points), default=None)
    max_intensity = max((p.intensity for p in points), default=None)

    return HeatmapResponse(
        points=points,
        min_intensity=min_intensity,
        max_intensity=max_intensity,
    )


@router.get("/stats", response_model=MapStats)
async def get_map_statistics(
    db: AsyncSession = Depends(get_session),
) -> MapStats:
    """Get general statistics for map display."""
    cutoff_24h = datetime.now(timezone.utc) - timedelta(hours=24)

    # Total events
    total_events_result = await db.execute(select(func.count(Event.id)))
    total_events = total_events_result.scalar() or 0

    # Total devices
    total_devices_result = await db.execute(select(func.count(Device.id)))
    total_devices = total_devices_result.scalar() or 0

    # Average and max leq_db
    agg_result = await db.execute(
        select(func.avg(Event.leq_db), func.max(Event.leq_db)).where(
            Event.leq_db.is_not(None)
        )
    )
    agg_row = agg_result.one_or_none()
    avg_leq_db = float(agg_row[0]) if agg_row and agg_row[0] is not None else None
    max_leq_db = float(agg_row[1]) if agg_row and agg_row[1] is not None else None

    # Active devices in last 24h (devices that have events in last 24h)
    active_devices_result = await db.execute(
        select(func.count(func.distinct(Event.device_id))).where(
            Event.timestamp_start >= cutoff_24h
        )
    )
    active_devices_24h = active_devices_result.scalar() or 0

    # Events in last 24h
    events_24h_result = await db.execute(
        select(func.count(Event.id)).where(Event.timestamp_start >= cutoff_24h)
    )
    events_24h = events_24h_result.scalar() or 0

    return MapStats(
        total_events=total_events,
        total_devices=total_devices,
        avg_leq_db=avg_leq_db,
        max_leq_db=max_leq_db,
        active_devices_24h=active_devices_24h,
        events_24h=events_24h,
    )
