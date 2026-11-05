"""Private device/owner source-phase storage. Never projected to public maps."""

from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.device_auth import can_access_device, require_device_key
from app.db.models.device import Device
from app.db.models.source_phase import SourcePhase
from app.db.session import get_session
from app.schemas.source_phase import SourcePhaseUpload

router = APIRouter()


async def device_for(db, device_id, key, user=None, *, write=False):
    # A per-device PostgreSQL row lock also serializes first insert vs deletion.
    query = select(Device).where(Device.device_id == device_id)
    if write:
        query = query.with_for_update()
    device = (await db.execute(query)).scalar_one_or_none()
    if not device:
        raise HTTPException(404, "Device not found")
    if write:
        await require_device_key(db, device, key)
    elif not await can_access_device(db, device, user, key):
        raise HTTPException(404, "Device not found")
    return device


async def phase_for(db, device, phase_id):
    return (
        await db.execute(
            select(SourcePhase).where(
                SourcePhase.device_id == device.id, SourcePhase.phase_uuid == phase_id
            )
        )
    ).scalar_one_or_none()


def receipt(row, device_id):
    return {
        "phase_id": str(row.phase_uuid),
        "device_id": device_id,
        "revision": row.revision,
        "digest": row.digest,
        "status": "deleted" if row.deleted else "acknowledged_by_server",
    }


def extends(old, new):
    if any(
        old[k] != new[k] for k in ("family", "algorithm", "source_model", "start_ms")
    ):
        return False
    if new["observed_until_ms"] < old["observed_until_ms"]:
        return False
    # A later snapshot can extend or unite intervals, never erase prior evidence.
    parts = iter(new["activity"])
    candidate = next(parts, None)
    for prior in old["activity"]:
        while candidate and candidate["end_ms"] < prior["end_ms"]:
            candidate = next(parts, None)
        if not candidate or candidate["start_ms"] > prior["start_ms"]:
            return False
    return True


@router.put("/{device_id}/{phase_id}")
async def upload_phase(
    device_id: str,
    phase_id: UUID,
    body: SourcePhaseUpload,
    db: AsyncSession = Depends(get_session),
    device_key: str | None = Header(None, alias="X-Device-Key"),
):
    if phase_id != body.phase_id:
        raise HTTPException(422, "Phase identity mismatch")
    device = await device_for(db, device_id, device_key, write=True)
    row = await phase_for(db, device, phase_id)
    digest, payload = body.digest(), body.payload()
    if row:
        if row.deleted:
            raise HTTPException(410, "Phase was deleted")
        if row.revision == body.revision and row.digest == digest:
            await db.commit()
            return receipt(row, device_id)
        if (
            body.revision <= row.revision
            or row.payload["state"] != "open"
            or not extends(row.payload, payload)
        ):
            raise HTTPException(409, "Conflicting or stale phase revision")
        row.revision, row.digest, row.payload = body.revision, digest, payload
        row.updated_at = datetime.now(UTC)
    else:
        row = SourcePhase(
            device_id=device.id,
            phase_uuid=phase_id,
            revision=body.revision,
            digest=digest,
            payload=payload,
        )
        db.add(row)
    # Persist before any ACK; callers may safely retry after a lost response.
    await db.commit()
    return receipt(row, device_id)


@router.get("/{device_id}")
async def list_phases(
    device_id: str,
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_session),
    user=Depends(get_current_user),
    device_key: str | None = Header(None, alias="X-Device-Key"),
):
    device = await device_for(db, device_id, device_key, user)
    rows = (
        await db.execute(
            select(SourcePhase)
            .where(SourcePhase.device_id == device.id, SourcePhase.deleted.is_(False))
            .order_by(SourcePhase.created_at, SourcePhase.id)
            .offset(offset)
            .limit(limit)
        )
    ).scalars()
    return {"items": [row.payload for row in rows], "offset": offset, "limit": limit}


@router.delete("/{device_id}/{phase_id}")
async def delete_phase(
    device_id: str,
    phase_id: UUID,
    db: AsyncSession = Depends(get_session),
    device_key: str | None = Header(None, alias="X-Device-Key"),
):
    device = await device_for(db, device_id, device_key, write=True)
    row = await phase_for(db, device, phase_id)
    if row is None:
        row = SourcePhase(
            device_id=device.id,
            phase_uuid=phase_id,
            revision=0,
            digest="",
            payload={},
            deleted=True,
        )
        db.add(row)
    else:
        row.deleted, row.payload, row.digest = True, {}, ""
    # A content-free tombstone prevents delayed requests resurrecting content.
    await db.commit()
    return receipt(row, device_id)
