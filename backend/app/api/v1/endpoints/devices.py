"""Device management endpoints."""

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
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
    current_user: User | None = Depends(get_current_user),
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
    current_user: User | None = Depends(get_current_user),
):
    """List devices. If authenticated, only returns user's own devices."""
    stmt = select(Device)
    if current_user:
        stmt = stmt.where(Device.owner_id == current_user.id)
    result = await db.execute(stmt)
    devices = result.scalars().all()
    return [DeviceResponse.model_validate(device) for device in devices]


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
