"""Device-related schemas."""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any

from pydantic import BaseModel, Field

from app.db.models.device import DeviceType


class DeviceRegister(BaseModel):
    """Schema for device registration."""
    
    device_id: str = Field(..., min_length=1, max_length=255, description="Unique device identifier")
    name: str = Field(..., min_length=1, max_length=255, description="Device display name")
    device_type: DeviceType = Field(default=DeviceType.SMARTPHONE, description="Type of device")
    location_lat: Optional[float] = Field(None, ge=-90, le=90, description="Device latitude")
    location_lng: Optional[float] = Field(None, ge=-180, le=180, description="Device longitude")
    address: Optional[str] = Field(None, description="Human-readable address")
    firmware_version: Optional[str] = Field(None, max_length=50, description="Device firmware version")
    hardware_info: Optional[Dict[str, Any]] = Field(None, description="Additional hardware information")
    calibration_offset: float = Field(default=0.0, description="Calibration offset in dB")


class DeviceUpdate(BaseModel):
    """Schema for device updates."""
    
    name: Optional[str] = Field(None, min_length=1, max_length=255, description="Device display name")
    location_lat: Optional[float] = Field(None, ge=-90, le=90, description="Device latitude")
    location_lng: Optional[float] = Field(None, ge=-180, le=180, description="Device longitude")
    address: Optional[str] = Field(None, description="Human-readable address")
    firmware_version: Optional[str] = Field(None, max_length=50, description="Device firmware version")
    hardware_info: Optional[Dict[str, Any]] = Field(None, description="Additional hardware information")
    calibration_offset: Optional[float] = Field(None, description="Calibration offset in dB")
    is_active: Optional[bool] = Field(None, description="Whether device is active")
    is_public: Optional[bool] = Field(None, description="Whether device data is public")


class DeviceResponse(BaseModel):
    """Schema for device API responses."""
    
    id: uuid.UUID = Field(..., description="Device internal ID")
    device_id: str = Field(..., description="Device unique identifier")
    name: str = Field(..., description="Device display name")
    device_type: DeviceType = Field(..., description="Type of device")
    location_lat: Optional[float] = Field(None, description="Device latitude")
    location_lng: Optional[float] = Field(None, description="Device longitude")
    address: Optional[str] = Field(None, description="Human-readable address")
    firmware_version: Optional[str] = Field(None, description="Device firmware version")
    hardware_info: Optional[Dict[str, Any]] = Field(None, description="Additional hardware information")
    calibration_offset: float = Field(..., description="Calibration offset in dB")
    site_id: Optional[uuid.UUID] = Field(None, description="Assigned Pro site ID")
    zone_id: Optional[uuid.UUID] = Field(None, description="Assigned Pro zone ID")
    calibration_profile_id: Optional[uuid.UUID] = Field(
        None, description="Assigned calibration profile ID"
    )
    is_active: bool = Field(..., description="Whether device is active")
    is_public: bool = Field(..., description="Whether device data is public")
    created_at: datetime = Field(..., description="Device creation timestamp")
    updated_at: datetime = Field(..., description="Device last update timestamp")

    class Config:
        from_attributes = True


class HeartbeatRequest(BaseModel):
    """Schema for device heartbeat requests."""
    
    device_id: str = Field(..., description="Device identifier")
    timestamp: datetime = Field(..., description="Heartbeat timestamp")
    battery_level: Optional[float] = Field(None, ge=0, le=100, description="Battery level percentage")
    signal_strength: Optional[float] = Field(None, description="Signal strength")
    status: Optional[Dict[str, Any]] = Field(None, description="Additional device status information")
