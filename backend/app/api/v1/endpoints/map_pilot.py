"""Quarantined pilot intake. The public projection deliberately publishes nothing.

No independence verification, safe differencing or restore-safe deletion exists yet.
This is not an operational public map and must not be enabled for real participants.
"""
import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import delete, exists, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import require_user, require_superuser
from app.core.config import settings
from app.db.models.map_pilot import (MapPilotConsent, MapPilotContribution, MapPilotRetentionRun,
                                     MapPilotPublicationGuard, MapPilotPublishedWeek, MapPilotVerifiedParticipant)
from app.db.models.user import User
from app.db.session import get_session
from app.services.map_pilot_cipher import PilotCipherUnavailable, ensure_key_available, ensure_database_key, encrypt_payload, decrypt_payload
from app.services.map_pilot_publication import suppress_pilot_publication

def require_isolated_pilot():
    if not settings.ENABLE_MAP_PILOT_INTAKE or settings.ENABLE_LEGACY_PUBLIC_MAP:
        raise HTTPException(404, "Not found")


def require_pilot_key():
    try:
        ensure_key_available()
    except PilotCipherUnavailable:
        raise HTTPException(503, "Pilot storage unavailable") from None


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
    # Only server-allowlisted identifiers; no arbitrary coordinate channel.
    cell_id: str = Field(strict=True, min_length=1, max_length=32, pattern=r"^[a-z0-9_-]+$")
    level_band: Literal["low", "medium", "high"]


class ParticipantAttestation(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: uuid.UUID
    # The operator must perform the separately documented personal check.
    personally_confirmed_distinct: Literal[True]


class PublicAreaWeek(BaseModel):
    # An explicit output allowlist; never serialize contribution rows directly.
    model_config = ConfigDict(extra="forbid")
    area: Literal["hamburg-eimsbuettel"]
    week_start: date
    band: Literal["low", "medium", "high"]

    @field_validator("week_start")
    @classmethod
    def require_monday(cls, value: date) -> date:
        if value.weekday() != 0:
            raise ValueError("Expected a UTC calendar week")
        return value


async def public_snapshot(db: DB) -> list[PublicAreaWeek]:
    # Two independent gates: default-off configuration and a locked DB guard.
    # There is no route to enable the guard or write snapshots. Operational and
    # quality gates must be verified before either can be enabled for real data.
    if not settings.ENABLE_MAP_PILOT_PUBLICATION:
        return []
    guard_open = exists(select(MapPilotPublicationGuard.id).where(
        MapPilotPublicationGuard.name == 'pilot', MapPilotPublicationGuard.enabled.is_(True)))
    rows = (await db.scalars(select(MapPilotPublishedWeek).where(
        MapPilotPublishedWeek.suppressed.is_(False), guard_open
    ).order_by(MapPilotPublishedWeek.week_start))).all()
    now = datetime.now(UTC)
    result = []
    for row in rows:
        ready = datetime.combine(row.week_start + timedelta(days=9), datetime.min.time(), tzinfo=UTC)
        if now < ready:
            continue
        try:
            result.append(PublicAreaWeek(area='hamburg-eimsbuettel', week_start=row.week_start, band=row.band))
        except ValueError:
            raise HTTPException(503, 'Pilot publication unavailable') from None
    return result


async def locked_consent(db, user_id):
    # Lock the parent even on the first opt-in, serializing opt-in/revoke/upload.
    await db.execute(select(User.id).where(User.id == user_id).with_for_update())
    return await db.scalar(select(MapPilotConsent).where(MapPilotConsent.user_id == user_id).with_for_update())


@router.post('/admin/attest-participant', status_code=204)
async def attest_participant(body: ParticipantAttestation, db: DB,
                             operator: Annotated[User, Depends(require_superuser)]):
    # An administrator's statement is an operational control, not proof that
    # separate accounts belong to separate people. Never auto-attest accounts.
    del operator
    row = await locked_consent(db, body.user_id)
    if not row or not row.enabled:
        raise HTTPException(409, 'Active pilot consent required')
    verified = await db.scalar(select(MapPilotVerifiedParticipant).where(
        MapPilotVerifiedParticipant.user_id == body.user_id))
    if verified is None:
        db.add(MapPilotVerifiedParticipant(user_id=body.user_id, verified_at=datetime.now(UTC)))
    await db.commit()
    return Response(status_code=204, headers={'Cache-Control': 'no-store'})


@router.get("/consent")
async def consent_status(db: DB, user: Annotated[User, Depends(require_user)], response: Response):
    response.headers["Cache-Control"] = "no-store"
    row = await db.scalar(select(MapPilotConsent).where(MapPilotConsent.user_id == user.id))
    if not row or not row.enabled:
        return {"enabled": False}
    return {"enabled": True, "generation": str(row.generation), "notice_version": row.notice_version}


@router.post("/consent", dependencies=[Depends(require_pilot_key)])
async def opt_in(body: ConsentRequest, db: DB, user: Annotated[User, Depends(require_user)], response: Response):
    response.headers["Cache-Control"] = "no-store"
    row = await locked_consent(db, user.id)
    try:
        await ensure_database_key(db)
    except PilotCipherUnavailable:
        raise HTTPException(503, 'Pilot storage unavailable') from None
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
        # Serialize with any future snapshot sealing before deleting evidence.
        await suppress_pilot_publication(db)
        row.enabled = False
        row.generation = uuid.uuid4()  # invalidate delayed requests, including after opt-in again
    await db.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == user.id))
    await db.execute(delete(MapPilotVerifiedParticipant).where(MapPilotVerifiedParticipant.user_id == user.id))
    await db.commit()
    return Response(status_code=204, headers={"Cache-Control": "no-store"})


@router.put("/contribution", status_code=204, dependencies=[Depends(require_pilot_key)])
async def contribute(body: Contribution, db: DB, user: Annotated[User, Depends(require_user)]):
    row = await locked_consent(db, user.id)
    if not row or not row.enabled or row.generation != body.generation:
        raise HTTPException(403, "Pilot consent is absent or outdated")
    try:
        await ensure_database_key(db)
    except PilotCipherUnavailable:
        raise HTTPException(503, 'Pilot storage unavailable') from None
    if body.cell_id not in settings.MAP_PILOT_ALLOWED_CELLS:
        raise HTTPException(422, "Unknown pilot area")
    today = datetime.now(UTC).date()
    if body.day >= today or body.day < today - timedelta(days=30) or body.day <= row.consented_at.date():
        raise HTTPException(422, "Only completed days after consent and within 30 days are accepted")
    prior = await db.scalar(select(MapPilotContribution).where(MapPilotContribution.user_id == user.id, MapPilotContribution.day == body.day))
    try:
        if prior:
            current = decrypt_payload(user.id, body.day, prior.payload_nonce, prior.payload_ciphertext)
            if current != {"cell_id": body.cell_id, "level_band": body.level_band}:
                raise HTTPException(409, "Contribution already recorded for this day")
        else:
            nonce, ciphertext = encrypt_payload(user.id, body.day, body.cell_id, body.level_band)
            db.add(MapPilotContribution(user_id=user.id, day=body.day, payload_nonce=nonce, payload_ciphertext=ciphertext))
    except PilotCipherUnavailable:
        raise HTTPException(503, "Pilot storage unavailable") from None
    await db.commit()
    return Response(status_code=204, headers={"Cache-Control": "no-store"})


@router.get("/public")
async def public_projection(response: Response, areas: Annotated[list[PublicAreaWeek], Depends(public_snapshot)]):
    # Fail closed by default even at k>=5; accounts do not prove distinct people.
    response.headers["Cache-Control"] = "no-store"
    return {"areas": [area.model_dump(mode="json") for area in areas], "status": "available" if areas else "not_available"}


@router.get("/admin/retention-health")
async def retention_health(db: DB, response: Response, user: Annotated[User, Depends(require_superuser)]):
    response.headers["Cache-Control"] = "no-store"
    if not settings.ENABLE_MAP_PILOT_RETENTION or not settings.ENABLE_BACKGROUND_TASKS:
        return {"status": "disabled"}
    last = await db.scalar(select(func.max(MapPilotRetentionRun.completed_at)))
    if last is None:
        return {"status": "missing"}
    if last.tzinfo is None:  # SQLite in synthetic tests does not preserve timezone.
        last = last.replace(tzinfo=UTC)
    now = datetime.now(UTC)
    if last > now + timedelta(minutes=5):
        return {"status": "clock_error", "last_success": last.isoformat()}
    return {"status": "stale" if now - last > timedelta(hours=2) else "ok", "last_success": last.isoformat()}
