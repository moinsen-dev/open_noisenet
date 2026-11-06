"""Isolated store-review entrypoint. Never run against an existing database."""
import json
import os
import secrets
from pathlib import Path

from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints import auth, account_deletion, devices, events, source_phases
from app.core.deps import require_user
from app.core.rate_limit import login_rate_limiter
from app.db.session import get_session
from app.schemas.auth import RegisterRequest


def create_app():
    # Explicit opt-in and a separate DB; a missing secret must prevent startup.
    from sqlalchemy.engine import make_url
    from app.core.config import settings
    if make_url(settings.DATABASE_URL).database != "opennoisenet_store_review":
        raise RuntimeError("A dedicated review database is required")
    accounts = json.loads(Path(os.environ["REVIEW_ACCOUNTS_FILE"]).read_text())
    if len(accounts) != 2 or any(not mail.endswith("@example.org") or len(pw) < 24
                                 for mail, pw in accounts.items()):
        raise RuntimeError("Configure two distinct synthetic reviewer accounts")
    app = FastAPI(openapi_url=None, docs_url=None, redoc_url=None)

    @app.get("/health")
    async def health(db: AsyncSession = Depends(get_session, scope="function")):
        await db.execute(text("SELECT 1"))
        return {"status": "healthy"}

    @app.post("/api/v1/auth/register", status_code=201, dependencies=[Depends(login_rate_limiter)])
    async def register(body: RegisterRequest, db: AsyncSession = Depends(get_session, scope="function")):
        expected = accounts.get(str(body.email))
        if expected is None or not secrets.compare_digest(body.password.encode(), expected.encode()):
            raise HTTPException(403, "Store review accounts only")
        return await auth.register(body, db)

    # Reuse the release backend endpoints, selecting each method explicitly.
    # Deliberately omit public maps, general signups, snippets, admin and third-party reads.
    def include(router, prefix, allow, protected=False):
        from fastapi import APIRouter
        selected = APIRouter()
        selected.routes.extend(r for r in router.routes if
                               any((m, r.path) in allow for m in r.methods))
        app.include_router(selected, prefix="/api/v1/" + prefix,
                           dependencies=[Depends(require_user)] if protected else [])

    include(auth.router, "auth", {("POST", "/login"), ("POST", "/refresh")})
    app.include_router(account_deletion.router, prefix="/api/v1/auth")
    include(devices.router, "devices", {("POST", "/register"), ("GET", "/{device_id}"),
            ("POST", "/{device_id}/heartbeat")}, True)
    include(events.router, "events", {("POST", "/"), ("GET", "/status/{event_uuid}")}, True)
    include(source_phases.router, "source-phases", {("PUT", "/{device_id}/{phase_id}"),
            ("DELETE", "/{device_id}/{phase_id}"), ("GET", "/{device_id}")}, True)
    return app
