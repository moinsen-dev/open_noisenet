"""Self-service deletion on the server that actually holds the account."""
from html import escape
from typing import Annotated
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field, SecretStr
from sqlalchemy import delete, exists, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_user
from app.core.device_auth import retirement_fingerprint
from app.db.models.device import DeviceApiKey, RevokedDeviceKey
from app.db.models.map_pilot import MapPilotConsent, MapPilotContribution
from app.core.rate_limit import login_rate_limiter
from app.core.security import verify_password
from app.db.models import Case, CaseEpisodeLink, Device, Episode, ExportJob, Organization, OrganizationMembership, User
from app.db.session import get_session

router = APIRouter()
DB = Annotated[AsyncSession, Depends(get_session, scope="function")]


class Confirmation(BaseModel):
    password: SecretStr = Field(min_length=1, max_length=256)


async def erase(db, user_id, password):
    # Serialize competing operations. Never accept a user ID from the request.
    user = await db.scalar(select(User).where(User.id == user_id).with_for_update())
    if not user or not user.is_active or not verify_password(password, user.hashed_password):
        raise HTTPException(403, "Account or password incorrect")
    devices = select(Device.id).where(Device.owner_id == user.id)
    episodes = select(Episode.id).where(Episode.device_id.in_(devices))
    cases = select(CaseEpisodeLink.case_id).where(CaseEpisodeLink.episode_id.in_(episodes))
    # Shared work may contain identifiers outside the relational foreign keys.
    touched_cases = set()
    reviewed = list((await db.scalars(select(Episode).where(Episode.reviewed_by_id == user.id).with_for_update())).all())
    for row in reviewed:
        row.review_metadata = None
        row.review_notes = None
        row.reviewed_by_id = None
        touched_cases.update(await db.scalars(select(CaseEpisodeLink.case_id).where(CaseEpisodeLink.episode_id == row.id)))
    for case in (await db.scalars(select(Case).where(Case.audit_history.is_not(None)).with_for_update())).all():
        old = case.audit_history or []
        new = [entry for entry in old if entry.get("actor_id") != str(user.id) and entry.get("actor_email") != user.email]
        if len(new) != len(old):
            case.audit_history = new
            touched_cases.add(case.id)
    if touched_cases:
        await db.execute(delete(ExportJob).where(ExportJob.case_id.in_(touched_cases)))
    # Invalidate generated snapshots before the links that identify them disappear.
    await db.execute(delete(ExportJob).where((ExportJob.created_by_id == user.id) | ExportJob.case_id.in_(cases)))
    await db.execute(delete(Episode).where(Episode.device_id.in_(devices)))
    for key_hash in await db.scalars(select(DeviceApiKey.key_hash).where(DeviceApiKey.device_id.in_(devices))):
        db.add(RevokedDeviceKey(fingerprint=retirement_fingerprint(key_hash)))
    await db.execute(delete(Device).where(Device.owner_id == user.id))
    others = exists(select(OrganizationMembership.id).where(
        OrganizationMembership.organization_id == Organization.id,
        OrganizationMembership.user_id != user.id))
    await db.execute(delete(Organization).where(Organization.created_by_id == user.id, ~others))
    await db.execute(update(Organization).where(Organization.created_by_id == user.id).values(created_by_id=None))
    await db.execute(delete(MapPilotContribution).where(MapPilotContribution.user_id == user.id))
    await db.execute(delete(MapPilotConsent).where(MapPilotConsent.user_id == user.id))
    await db.delete(user)
    await db.flush()


@router.get("/account-deletion/capability")
async def capability():
    return {"account_deletion": 1}


@router.post("/account-deletion", status_code=204, dependencies=[Depends(login_rate_limiter)])
async def remove_self(body: Confirmation, db: DB, user: Annotated[User, Depends(require_user)]):
    await erase(db, user.id, body.password.get_secret_value())


HEADERS = {"Cache-Control": "no-store", "Referrer-Policy": "no-referrer",
           "X-Frame-Options": "DENY", "X-Content-Type-Options": "nosniff",
           "Content-Security-Policy": "default-src 'none'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"}


def page(message="", done=False, status=200):
    form = "" if done else """
<p>Du löschst dein Konto auf diesem Server, die zugehörigen Geräte, Ereignisse und Geräuschphasen.
Gemeinsam genutzte Organisationen und das lokale Tagebuch bleiben erhalten.</p>
<form method="post"><p><label>E-Mail <input required type="email" name="email" autocomplete="username"></label></p>
<p><label>Passwort <input required type="password" name="password" autocomplete="current-password"></label></p>
<p><label><input required type="checkbox" name="confirm" value="delete"> Ich möchte mein Konto endgültig löschen.</label></p>
<button type="submit">Konto und Serverdaten löschen</button></form>"""
    return HTMLResponse('<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OpenNoiseNet · Konto löschen</title><main><h1>OpenNoiseNet · Konto löschen</h1><p>'+escape(message)+'</p>'+form+'</main></html>', status_code=status, headers=HEADERS)


@router.get("/account-deletion/web", response_class=HTMLResponse)
async def web_form():
    return page()


@router.post("/account-deletion/web", response_class=HTMLResponse, dependencies=[Depends(login_rate_limiter)])
async def web_delete(request: Request, db: DB, email: Annotated[str, Form(max_length=255)],
                     password: Annotated[str, Form(max_length=256)], confirm: Annotated[str, Form()]):
    origin = urlsplit(request.headers.get("origin", ""))
    if origin.netloc != request.url.netloc or origin.scheme != request.url.scheme or confirm != "delete":
        return page("Bestätigung oder Herkunft ungültig.", status=403)
    user = await db.scalar(select(User.id).where(User.email == email.strip()))
    try:
        await erase(db, user, password)
    except HTTPException as err:
        return page("Keine Löschung bestätigt. Bitte prüfe deine Zugangsdaten.", status=err.status_code)
    return page("Dein Konto und die zugehörigen Daten wurden auf diesem Server gelöscht.", done=True)
