"""Device management endpoints."""

from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user, require_user
from app.db.models.user import User
from app.db.session import get_session
from app.db.models.device import Device
from app.schemas.device import DeviceRegister, DeviceUpdate, DeviceResponse, HeartbeatRequest

router = APIRouter()


@router.post("/register", response_model=DeviceResponse)
async def register_device(
    device_data: DeviceRegister,
    db: AsyncSession = Depends(get_session)
):
    """Register a new device or update existing one."""
    
    # Check if device already exists
    stmt = select(Device).where(Device.device_id == device_data.device_id)
    result = await db.execute(stmt)
    existing_device = result.scalar_one_or_none()
    
    if existing_device:
        # Update existing device
        for field, value in device_data.model_dump(exclude_unset=True).items():
            setattr(existing_device, field, value)
        
        await db.flush()
        await db.refresh(existing_device)
        return DeviceResponse.model_validate(existing_device)
    else:
        # Create new device
        new_device = Device(**device_data.model_dump())
        db.add(new_device)
        await db.flush()
        await db.refresh(new_device)
        return DeviceResponse.model_validate(new_device)


@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: str,
    db: AsyncSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    """Get device information by device_id. Only returns if user owns the device."""
    result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    if current_user and device.owner_id and str(device.owner_id) != str(current_user.id):
        raise HTTPException(status_code=404, detail="Device not found")
    return DeviceResponse.model_validate(device)


@router.put("/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: str,
    device_data: DeviceUpdate,
    db: AsyncSession = Depends(get_session)
):
    """Update device information."""
    
    stmt = select(Device).where(Device.device_id == device_id)
    result = await db.execute(stmt)
    device = result.scalar_one_or_none()
    
    if not device:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
    
    # Update device with provided data
    for field, value in device_data.model_dump(exclude_unset=True).items():
        setattr(device, field, value)
    
    await db.flush()
    await db.refresh(device)
    return DeviceResponse.model_validate(device)


@router.post("/{device_id}/heartbeat")
async def device_heartbeat(
    device_id: str,
    heartbeat_data: HeartbeatRequest,
    db: AsyncSession = Depends(get_session)
):
    """Device heartbeat endpoint to update last seen timestamp."""
    
    stmt = select(Device).where(Device.device_id == device_id)
    result = await db.execute(stmt)
    device = result.scalar_one_or_none()
    
    if not device:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")

    # Update device last seen timestamp
    device.last_heartbeat = heartbeat_data.timestamp
    device.last_seen = heartbeat_data.timestamp
    hardware_info = dict(device.hardware_info or {})
    if heartbeat_data.battery_level is not None:
        hardware_info['battery_level'] = heartbeat_data.battery_level
    if heartbeat_data.signal_strength is not None:
        hardware_info['signal_strength'] = heartbeat_data.signal_strength
    if heartbeat_data.status:
        hardware_info['last_runtime_status'] = heartbeat_data.status
        hardware_info['last_runtime_status_at'] = (
            heartbeat_data.timestamp.isoformat()
        )
    device.hardware_info = hardware_info

    await db.flush()

    return {"message": f"Heartbeat received for device {device_id}", "timestamp": heartbeat_data.timestamp}


@router.get("/", response_model=List[DeviceResponse])
async def list_devices(
    db: AsyncSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    """List devices. If authenticated, only returns user's own devices."""
    stmt = select(Device)
    if current_user:
        stmt = stmt.where(Device.owner_id == current_user.id)
    result = await db.execute(stmt)
    devices = result.scalars().all()
    return [DeviceResponse.model_validate(device) for device in devices]


@router.get("/{device_id}/timeline")
async def device_timeline(
    device_id: str,
    date: Optional[str] = Query(None, description="Date in YYYY-MM-DD format"),
    db: AsyncSession = Depends(get_session),
):
    """Get daily noise timeline for a device including episodes and events."""
    from datetime import date as date_type, datetime, timedelta, timezone
    from app.db.models.event import Event
    from app.db.models.pro_domain import Episode

    # Resolve device
    stmt = select(Device).where(Device.device_id == device_id)
    result = await db.execute(stmt)
    dev = result.scalar_one_or_none()
    if not dev:
        raise HTTPException(status_code=404, detail="Device not found")

    # Default to today
    target_date = date_type.today()
    if date:
        target_date = date_type.fromisoformat(date)

    day_start = datetime(target_date.year, target_date.month, target_date.day, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    # Get events for this device on this day
    event_stmt = (
        select(Event)
        .where(
            Event.device_id == dev.id,
            Event.timestamp_start >= day_start,
            Event.timestamp_start < day_end,
        )
        .order_by(Event.timestamp_start.asc())
    )
    event_result = await db.execute(event_stmt)
    events = event_result.scalars().all()

    # Get episodes linked to these events
    episode_ids = {e.episode_id for e in events if e.episode_id}
    episodes = []
    if episode_ids:
        ep_stmt = select(Episode).where(Episode.id.in_(episode_ids))
        ep_result = await db.execute(ep_stmt)
        episodes = ep_result.scalars().all()

    # Build response
    episode_map = {ep.id: ep for ep in episodes}

    return {
        "device_id": device_id,
        "date": target_date.isoformat(),
        "events": [
            {
                "id": str(e.id),
                "timestamp_start": e.timestamp_start.isoformat() if e.timestamp_start else None,
                "leq_db": e.leq_db,
                "lmax_db": e.lmax_db,
                "classification_label": e.classification_label,
                "status": e.status,
                "episode_id": str(e.episode_id) if e.episode_id else None,
            }
            for e in events
        ],
        "episodes": [
            {
                "id": str(ep.id),
                "primary_class": ep.primary_class,
                "class_family": ep.class_family,
                "label_de": _get_german_label(ep.primary_class),
                "started_at": ep.started_at.isoformat() if ep.started_at else None,
                "ended_at": ep.ended_at.isoformat() if ep.ended_at else None,
                "severity": ep.severity,
                "nuisance_score": ep.nuisance_score,
                "event_count": ep.event_count,
                "quiet_hours_triggered": ep.quiet_hours_triggered,
                "avg_leq_db": ep.review_metadata.get("avg_leq_db") if ep.review_metadata else None,
            }
            for ep in episodes
        ],
        "summary": _build_timeline_summary(events, episodes),
    }
def _get_german_label(primary_class: str) -> str:
    labels = {
        "construction_noise": "Baustellenlärm",
        "traffic_noise": "Verkehrslärm",
        "conversation_dispute": "Lautes Gespräch / Streit",
        "music_party": "Musik / Party",
        "mechanical_hvac": "Maschinen- / Klimaanlagenlärm",
        "animal_barking": "Hundegebell / Tierlaute",
        "alarm_siren": "Alarm / Sirene",
        "impulsive_noise": "Impulsiver Lärm",
        "sustained_noise": "Dauerschall",
    }
    return labels.get(primary_class, primary_class.replace("_", " ").title())
def _build_timeline_summary(events, episodes):
    """Build a human-readable summary of the day's noise."""
    if not episodes:
        # If no episodes, check if there's any sustained noise
        sustained = [e for e in events if e.leq_db and e.leq_db > 55]
        if sustained:
            avg = sum(e.leq_db for e in sustained) / len(sustained)
            return f"Durchgehend erhöhter Pegel: {len(sustained)} Events, ø {avg:.0f} dB"
        return "Keine nennenswerten Lärmereignisse"
    parts = []
    for ep in sorted(episodes, key=lambda e: e.started_at):
        label = _get_german_label(ep.primary_class)
        start = ep.started_at.strftime("%H:%M") if ep.started_at else "?"
        end = ep.ended_at.strftime("%H:%M") if ep.ended_at else "?"
        avg = ep.review_metadata.get("avg_leq_db") if ep.review_metadata else "?"
        parts.append(f"{start}–{end}: {label} ({ep.event_count} Events, ø {avg} dB)")
    return " | ".join(parts)


@router.delete("/{device_id}", status_code=204)


@router.delete("/{device_id}", status_code=204)
async def delete_device(
    device_id: str,
    db: AsyncSession = Depends(get_session),
    current_user: User = Depends(require_user),
):
    """Delete a device. Only the owner can delete it."""
    result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    if device.owner_id and str(device.owner_id) != str(current_user.id):
        raise HTTPException(status_code=404, detail="Device not found")
    await db.delete(device)
    await db.commit()
