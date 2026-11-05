"""Device management endpoints."""

from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import or_, select
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.core.device_auth import can_access_device, device_key_hash, require_device_key, visible_device_ids
from app.db.models.user import User
from app.db.session import get_session
from app.db.models.device import Device, DeviceApiKey
from app.schemas.device import DeviceRegister, DeviceUpdate, DeviceResponse, HeartbeatRequest

router = APIRouter()


def _public_device_response(device: Device) -> DeviceResponse:
    return DeviceResponse.model_validate(device).model_copy(update={
        "address": None, "hardware_info": None, "site_id": None, "zone_id": None,
        "calibration_profile_id": None,
    })


@router.post("/register", response_model=DeviceResponse)
async def register_device(
    device_data: DeviceRegister,
    db: AsyncSession = Depends(get_session, scope="function"),
    device_key: Optional[str] = Header(default=None, alias="X-Device-Key"),
    current_user: Optional[User] = Depends(get_current_user),
):
    """Register a new device or update existing one."""
    
    key_hash = device_key_hash(device_key)
    stmt = select(Device).where(Device.device_id == device_data.device_id)
    result = await db.execute(stmt)
    existing_device = result.scalar_one_or_none()
    key_owner = await db.execute(select(DeviceApiKey.device_id).where(DeviceApiKey.key_hash == key_hash))
    key_device_id = key_owner.scalar_one_or_none()
    if key_device_id is not None and (existing_device is None or key_device_id != existing_device.id):
        raise HTTPException(status_code=409, detail="Device key is already registered")
    
    if existing_device:
        keys = await db.execute(select(DeviceApiKey.id).where(DeviceApiKey.device_id == existing_device.id))
        has_key = keys.first() is not None
        if not has_key and current_user and existing_device.owner_id == current_user.id:
            # Only an authenticated owner can enroll an existing legacy device.
            db.add(DeviceApiKey(device_id=existing_device.id, key_hash=key_hash))
        else:
            await require_device_key(db, existing_device, device_key)
        # Update existing device
        for field, value in device_data.model_dump(exclude_unset=True).items():
            setattr(existing_device, field, value)
        
        await db.flush()
        await db.refresh(existing_device)
        return DeviceResponse.model_validate(existing_device)
    else:
        # Create new device
        new_device = Device(**device_data.model_dump(), owner_id=current_user.id if current_user else None)
        db.add(new_device)
        await db.flush()
        db.add(DeviceApiKey(device_id=new_device.id, key_hash=key_hash))
        await db.flush()
        await db.refresh(new_device)
        return DeviceResponse.model_validate(new_device)


@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: str,
    db: AsyncSession = Depends(get_session, scope="function"),
    current_user: Optional[User] = Depends(get_current_user),
    device_key: Optional[str] = Header(default=None, alias="X-Device-Key"),
):
    """Get device information by device_id. Only returns if user owns the device."""
    result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    if await can_access_device(db, device, current_user, device_key):
        return DeviceResponse.model_validate(device)
    if not device.is_public:
        raise HTTPException(status_code=404, detail="Device not found")
    return _public_device_response(device)


@router.put("/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: str,
    device_data: DeviceUpdate,
    db: AsyncSession = Depends(get_session, scope="function"),
    device_key: Optional[str] = Header(default=None, alias="X-Device-Key"),
):
    """Update device information."""
    
    stmt = select(Device).where(Device.device_id == device_id)
    result = await db.execute(stmt)
    device = result.scalar_one_or_none()
    
    if not device:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
    await require_device_key(db, device, device_key)
    
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
    db: AsyncSession = Depends(get_session, scope="function"),
    device_key: Optional[str] = Header(default=None, alias="X-Device-Key"),
):
    """Device heartbeat endpoint to update last seen timestamp."""
    
    stmt = select(Device).where(Device.device_id == device_id)
    result = await db.execute(stmt)
    device = result.scalar_one_or_none()
    
    if not device:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
    await require_device_key(db, device, device_key)
    if heartbeat_data.device_id != device_id:
        raise HTTPException(status_code=400, detail="Device identifier mismatch")

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
    db: AsyncSession = Depends(get_session, scope="function"),
    current_user: Optional[User] = Depends(get_current_user),
    device_key: Optional[str] = Header(default=None, alias="X-Device-Key"),
):
    """List devices. If authenticated, only returns user's own devices."""
    stmt = select(Device)
    stmt = stmt.where(Device.id.in_(visible_device_ids(current_user, device_key)))
    result = await db.execute(stmt)
    devices = result.scalars().all()
    return [
        DeviceResponse.model_validate(device)
        if await can_access_device(db, device, current_user, device_key)
        else _public_device_response(device)
        for device in devices
    ]


@router.get("/{device_id}/timeline")
async def device_timeline(
    device_id: str,
    date: Optional[str] = Query(None, description="Date in YYYY-MM-DD format"),
    timezone_name: str = Query(
        default="UTC",
        alias="timezone",
        description="IANA timezone used for day boundaries and display times",
    ),
    db: AsyncSession = Depends(get_session, scope="function"),
    current_user: Optional[User] = Depends(get_current_user),
    device_key: Optional[str] = Header(default=None, alias="X-Device-Key"),
):
    """Get daily noise timeline for a device including episodes and events."""
    from datetime import date as date_type, datetime, timedelta, timezone
    from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
    from app.db.models.event import Event
    from app.db.models.pro_domain import Episode

    # Resolve device
    stmt = select(Device).where(Device.device_id == device_id)
    result = await db.execute(stmt)
    dev = result.scalar_one_or_none()
    if not dev:
        raise HTTPException(status_code=404, detail="Device not found")
    authorized = await can_access_device(db, dev, current_user, device_key)
    if not dev.is_public and not authorized:
        raise HTTPException(status_code=404, detail="Device not found")

    # Default to today
    target_date = date_type.today()
    if date:
        target_date = date_type.fromisoformat(date)

    try:
        display_timezone = ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError as exc:
        raise HTTPException(status_code=400, detail="Invalid IANA timezone") from exc

    local_day_start = datetime(
        target_date.year,
        target_date.month,
        target_date.day,
        tzinfo=display_timezone,
    )
    local_day_end = local_day_start + timedelta(days=1)
    day_start = local_day_start.astimezone(timezone.utc)
    day_end = local_day_end.astimezone(timezone.utc)

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
    if not authorized:
        event_stmt = event_stmt.where(
            Event.location_lat.is_not(None), Event.location_lng.is_not(None)
        )
    event_result = await db.execute(event_stmt)
    events = event_result.scalars().all()

    # Get episodes linked to these events
    episode_ids = {e.episode_id for e in events if e.episode_id}
    episodes = []
    if episode_ids and authorized:
        ep_stmt = select(Episode).where(Episode.id.in_(episode_ids))
        ep_result = await db.execute(ep_stmt)
        episodes = ep_result.scalars().all()

    # Build response
    episode_map = {ep.id: ep for ep in episodes}

    return {
        "device_id": device_id,
        "date": target_date.isoformat(),
        "timezone": timezone_name,
        "events": [
            {
                "id": str(e.id),
                "timestamp_start": e.timestamp_start.isoformat() if e.timestamp_start else None,
                "leq_db": e.leq_db,
                "lmax_db": e.lmax_db,
                "classification_label": e.classification_label,
                "status": e.status,
                "episode_id": str(e.episode_id) if e.episode_id and authorized else None,
            }
            for e in events
        ],
        "episodes": [
            {
                "id": str(ep.id),
                "primary_class": ep.primary_class,
                "effective_label": ep.review_label or ep.primary_class,
                "class_family": ep.class_family,
                "label_de": _get_german_label(ep.review_label or ep.primary_class),
                "started_at": ep.started_at.isoformat() if ep.started_at else None,
                "ended_at": ep.ended_at.isoformat() if ep.ended_at else None,
                "local_started_at": _in_timezone(
                    ep.started_at,
                    display_timezone,
                ).isoformat()
                if ep.started_at
                else None,
                "local_ended_at": _in_timezone(
                    ep.ended_at,
                    display_timezone,
                ).isoformat()
                if ep.ended_at
                else None,
                "severity": ep.severity,
                "effective_severity": ep.reviewed_severity or ep.severity,
                "review_state": ep.review_state,
                "nuisance_score": ep.nuisance_score,
                "event_count": ep.event_count,
                "quiet_hours_triggered": ep.quiet_hours_triggered,
                "avg_leq_db": ep.review_metadata.get("avg_leq_db") if ep.review_metadata else None,
                "observed_duration_seconds": int(
                    _observed_episode_duration(
                        [event for event in events if event.episode_id == ep.id],
                        ep,
                    )
                ),
                "continuity": ep.review_metadata.get("continuity")
                if ep.review_metadata
                else None,
                "context_annotation": ep.review_metadata.get("context_annotation")
                if ep.review_metadata
                else None,
            }
            for ep in episodes
        ],
        "noise_duration": _compute_noise_duration(events, episodes),
        "summary": _build_timeline_summary(
            events,
            episodes,
            display_timezone=display_timezone,
        ),
    }


def _observed_episode_duration(events, episode):
    """Return measured event time without treating episode gaps as noise."""
    intervals = sorted(
        [
            (event.timestamp_start, event.timestamp_end or event.timestamp_start)
            for event in events
            if event.timestamp_start
        ],
        key=lambda interval: interval[0],
    )
    if not intervals:
        if episode.started_at and episode.ended_at:
            return max((episode.ended_at - episode.started_at).total_seconds(), 0)
        return 0

    total = 0.0
    current_start, current_end = intervals[0]
    for start, end in intervals[1:]:
        if start <= current_end:
            current_end = max(current_end, end)
            continue
        total += max((current_end - current_start).total_seconds(), 0)
        current_start, current_end = start, end
    total += max((current_end - current_start).total_seconds(), 0)
    return total


def _in_timezone(value, display_timezone):
    """Treat database-naive timestamps as UTC, matching storage semantics."""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(display_timezone)


def _compute_noise_duration(events, episodes):
    # An episode describes one real-world occurrence, but pauses and coverage
    # gaps inside it are not measured noise. Sum linked event intervals.
    total_noise_seconds = 0
    target_noise_seconds = 0
    excluded_local_seconds = 0
    night_noise_seconds = 0
    by_threshold = {"55dB": 0, "65dB": 0, "75dB": 0}
    for ep in episodes:
        linked_events = [event for event in events if event.episode_id == ep.id]
        duration = _observed_episode_duration(linked_events, ep)
        total_noise_seconds += duration
        if ep.review_state == "suppressed":
            excluded_local_seconds += duration
        else:
            target_noise_seconds += duration
        if ep.quiet_hours_triggered:
            night_noise_seconds += duration
        avg_db = ep.review_metadata.get("avg_leq_db") if ep.review_metadata else 0
        if avg_db >= 75:
            by_threshold["75dB"] += duration
        elif avg_db >= 65:
            by_threshold["65dB"] += duration
        else:
            by_threshold["55dB"] += duration
    def fmt(seconds):
        if seconds < 60:
            return f"{int(seconds)}s"
        if seconds < 3600:
            return f"{int(seconds // 60)}min"
        h = int(seconds // 3600)
        m = int((seconds % 3600) // 60)
        return f"{h}h {m}min" if m > 0 else f"{h}h"
    return {
        "total": fmt(total_noise_seconds),
        "total_seconds": int(total_noise_seconds),
        "target": fmt(target_noise_seconds),
        "target_seconds": int(target_noise_seconds),
        "excluded_local": fmt(excluded_local_seconds),
        "excluded_local_seconds": int(excluded_local_seconds),
        "night": fmt(night_noise_seconds),
        "night_seconds": int(night_noise_seconds),
        "episode_count": len(episodes),
        "by_threshold": {k: fmt(v) for k, v in by_threshold.items()},
        "by_threshold_seconds": by_threshold,
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
        "loud_conversation": "Laute Unterhaltung",
        "shouting_or_dispute": "Streit oder Rufen",
        "party_or_music_with_people": "Party / Musik mit Personen",
        "television_or_music": "Fernsehen oder Musik",
        "drilling": "Bohren",
        "hammering": "Hämmern",
        "sawing": "Sägen",
        "construction_other": "Sonstige Baustelle",
        "furniture_movement": "Möbelrücken",
        "footsteps_or_impact_noise": "Schritte / Trittschall",
        "door_or_impact": "Tür- oder Aufprallgeräusch",
        "household_appliance": "Haushaltsgerät",
        "road_traffic": "Straßenverkehr",
        "animals": "Tiere",
        "unknown_sound_source": "Unbekannte Geräuschquelle",
        "known_local_activity": "Bekannte lokale Aktivität",
        "teams_meeting": "Teams-Meeting",
    }
    return labels.get(primary_class, primary_class.replace("_", " ").title())
def _build_timeline_summary(events, episodes, *, display_timezone=None):
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
        annotation = (
            ep.review_metadata.get("context_annotation")
            if ep.review_metadata
            else None
        )
        label = _get_german_label(ep.review_label or ep.primary_class)
        if isinstance(annotation, dict) and annotation.get("display_label"):
            label = annotation["display_label"]
        start_at = (
            _in_timezone(ep.started_at, display_timezone)
            if ep.started_at and display_timezone
            else ep.started_at
        )
        end_at = (
            _in_timezone(ep.ended_at, display_timezone)
            if ep.ended_at and display_timezone
            else ep.ended_at
        )
        start = start_at.strftime("%H:%M") if start_at else "?"
        end = end_at.strftime("%H:%M") if end_at else "?"
        avg = ep.review_metadata.get("avg_leq_db") if ep.review_metadata else "?"
        prefix = "Lokale Aktivität" if ep.review_state == "suppressed" else label
        detail = f": {label}" if ep.review_state == "suppressed" else ""
        parts.append(
            f"{start}–{end}: {prefix}{detail} "
            f"({ep.event_count} Events, ø {avg} dB)"
        )
    return " | ".join(parts)


@router.delete("/{device_id}", status_code=204)
async def delete_device(
    device_id: str,
    db: AsyncSession = Depends(get_session, scope="function"),
    current_user: Optional[User] = Depends(get_current_user),
    device_key: Optional[str] = Header(default=None, alias="X-Device-Key"),
):
    """Delete a device. Only the owner can delete it."""
    result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    if not await can_access_device(db, device, current_user, device_key):
        raise HTTPException(status_code=404, detail="Device not found")
    await db.delete(device)
    await db.commit()
