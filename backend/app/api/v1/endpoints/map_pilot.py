"""Quarantined pilot intake. The public projection deliberately publishes nothing.

No independence verification, safe differencing or restore-safe deletion exists yet.
This is not an operational public map and must not be enabled for real participants.
"""
import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import require_user
from app.core.config import settings
from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution
from app.db.models.user import User
from app.db.session import get_session

def require_isolated_pilot():
    if not settings.ENABLE_MAP_PILOT_INTAKE or settings.ENABLE_LEGACY_PUBLIC_MAP:
        raise HTTPException(404, "Not found")


router = APIRouter(dependencies=[Depends(require_isolated_pilot)])
DB = Annotated[AsyncSession, Depends(get_session, scope="function")]
NOTICE = "pilot-draft-2026-11-07"


class ConsentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    notice_version: Literal["pilot-draft-2026-11-07"]
    accepted: Literal[True]


class Contribution(BaseModel):
    model_config = ConfigDict(extra="forbid")
    generation: uuid.UUID
    day: date
    # Fixed integer cell indices, not lat/lon. The grid definition is not approved.
    cell_x: int = Field(strict=True, ge=-20000, le=20000)
    cell_y: int = Field(strict=True, ge=-10000, le=10000)
    level_band: Literal["low", "medium", "high"]


async def locked_consent(db, user_id):
    # Lock the parent even on the first opt-in, serializing opt-in/revoke/upload.
    await db.execute(select(User.id).where(User.id == user_id).with_for_update())
    return await db.scalar(select(MapPilotConsent).where(MapPilotConsent.user_id == user_id).with_for_update())


@router.post("/consent")
async def opt_in(body: ConsentRequest, db: DB, user: Annotated[User, Depends(require_user)], response: Response):
    response.headers["Cache-Control"] = "no-store"
    row = await locked_consent(db, user.id)
    if row and row.enabled:
        return {"enabled": True, "generation": str(row.generation), "notice_version": row.notice_version}
    now = datetime.now(UTC)
    if row is None:
        row = MapPilotConsent(user_id=user.id, enabled=True, generation=uuid.uuid4(), consented_at=now, notice_version=NOTICE)
        db.add(row)
    else:
        row.enabled, row.generation, row.consented_at, row.notice_version = True, uuid.uuid4(), now, NOTICE
    await db.commit()
    return {"enabled": True, "generation": str(row.generation), "notice_version": row.notice_version}


@router.delete("/consent", status_code=204)
async def withdraw(db: DB, user: Annotated[User, Depends(require_user)]):
    row = await locked_consent(db, user.id)
    if row:
        row.enabled = False
        row.generation = uuid.uuid4()  # invalidate delayed requests, including after opt-in again
    await db.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == user.id))
    await db.commit()
    return Response(status_code=204, headers={"Cache-Control": "no-store"})


@router.put("/contribution", status_code=204)
async def contribute(body: Contribution, db: DB, user: Annotated[User, Depends(require_user)]):
    row = await locked_consent(db, user.id)
    if not row or not row.enabled or row.generation != body.generation:
        raise HTTPException(403, "Pilot consent is absent or outdated")
    today = datetime.now(UTC).date()
    if body.day >= today or body.day < today - timedelta(days=30) or body.day <= row.consented_at.date():
        raise HTTPException(422, "Only completed days after consent and within 30 days are accepted")
    prior = await db.scalar(select(MapPilotContribution).where(MapPilotContribution.user_id == user.id, MapPilotContribution.day == body.day))
    if prior:
        if (prior.cell_x, prior.cell_y, prior.level_band) != (body.cell_x, body.cell_y, body.level_band):
            raise HTTPException(409, "Contribution already recorded for this day")
    else:
        db.add(MapPilotContribution(user_id=user.id, day=body.day, cell_x=body.cell_x, cell_y=body.cell_y, level_band=body.level_band))
    await db.commit()
    return Response(status_code=204, headers={"Cache-Control": "no-store"})


@router.get("/public")
async def public_projection(response: Response):
    # Fail closed even at k>=5; accounts and devices do not prove independent people.
    response.headers["Cache-Control"] = "no-store"
    return {"areas": [], "status": "not_available"}
