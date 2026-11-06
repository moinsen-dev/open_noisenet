"""Device credentials for anonymous sensors and authenticated owners."""

import hashlib
import re
from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import false, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device, DeviceApiKey

_KEY_PATTERN = re.compile(r"^[A-Za-z0-9_-]{43}$")


def retirement_fingerprint(key_hash: str) -> str:
    # The original device key has 256 bits of entropy.
    return hashlib.sha256(("retired-opennoisenet:" + key_hash).encode("ascii")).hexdigest()


def device_key_hash(key: Optional[str]) -> str:
    if not key or not _KEY_PATTERN.fullmatch(key):
        raise HTTPException(status_code=401, detail="Valid device key required")
    return hashlib.sha256(key.encode("ascii")).hexdigest()


async def matching_device_key(db: AsyncSession, device: Device, key: Optional[str]) -> bool:
    if not key or not _KEY_PATTERN.fullmatch(key):
        return False
    result = await db.execute(
        select(DeviceApiKey.id).where(
            DeviceApiKey.device_id == device.id,
            DeviceApiKey.key_hash == device_key_hash(key),
            DeviceApiKey.is_active.is_(True),
            or_(DeviceApiKey.expires_at.is_(None), DeviceApiKey.expires_at > datetime.now(timezone.utc)),
        )
    )
    return result.scalar_one_or_none() is not None


async def require_device_key(db: AsyncSession, device: Device, key: Optional[str]) -> None:
    if not await matching_device_key(db, device, key):
        raise HTTPException(status_code=403, detail="Device credential not accepted")


async def can_access_device(db: AsyncSession, device: Device, user, key: Optional[str]) -> bool:
    return bool(
        (user and device.owner_id and user.id == device.owner_id)
        or await matching_device_key(db, device, key)
    )


def visible_device_ids(user, key: Optional[str], *, include_public: bool = True):
    """Devices visible through public publication, user ownership or a device key."""
    conditions = [Device.is_public.is_(True)] if include_public else []
    if user:
        conditions.append(Device.owner_id == user.id)
    if key and _KEY_PATTERN.fullmatch(key):
        conditions.append(Device.id.in_(select(DeviceApiKey.device_id).where(
            DeviceApiKey.key_hash == device_key_hash(key),
            DeviceApiKey.is_active.is_(True),
            or_(DeviceApiKey.expires_at.is_(None), DeviceApiKey.expires_at > datetime.now(timezone.utc)),
        )))
    return select(Device.id).where(or_(*conditions) if conditions else false())
