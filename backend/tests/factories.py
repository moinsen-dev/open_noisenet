"""Test factories — create domain objects with sensible defaults in one line."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import AsyncGenerator

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device, DeviceType
from app.db.models.event import Event
from app.db.models.pro_domain import (
    CalibrationProfile,
    Case,
    Episode,
    ExportJob,
    Organization,
    OrganizationMembership,
    Policy,
    Site,
    Zone,
)

from app.db.models.user import User

# ── helpers ──────────────────────────────────────────────────────────────────

def _uid() -> str:
    return uuid.uuid4().hex[:12]

def _now() -> datetime:
    return datetime.now(timezone.utc)

# ── user ─────────────────────────────────────────────────────────────────────

async def create_user(
    db: AsyncSession,
    *,
    email: str | None = None,
    password: str = "testpass123",
    full_name: str = "Test User",
) -> User:
    from app.core.security import get_password_hash

    user = User(
        email=email or f"{_uid()}@test.noisenet.org",
        hashed_password=get_password_hash(password),
        full_name=full_name,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


# ── device ───────────────────────────────────────────────────────────────────

async def create_device(
    db: AsyncSession,
    *,
    device_id: str | None = None,
    name: str = "Test Device",
    owner_id: str | None = None,
    **overrides,
) -> Device:
    device = Device(
        device_id=device_id or f"dev-{_uid()}",
        name=name,
        device_type=DeviceType.SMARTPHONE,
        owner_id=owner_id,
        **overrides,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return device


# ── event ────────────────────────────────────────────────────────────────────

def event_payload(**overrides) -> dict:
    """Return a valid event creation payload dict."""
    ts = _now().isoformat()
    return {
        "device_id": f"dev-{_uid()}",
        "timestamp_start": ts,
        "timestamp_end": ts,
        "leq_db": 68.5,
        "peak_db": 82.1,
        "pct_over": 0.42,
        "rule": "15min_Leq_over_65dBA",
        "latitude": 52.52,
        "longitude": 13.405,
        **overrides,
    }


async def create_event(
    db: AsyncSession,
    *,
    device: Device | None = None,
    **overrides,
) -> Event:
    if device is None:
        device = await create_device(db)
    ts = _now()
    event = Event(
        device_id=device.device_id,
        event_uuid=f"evt-{_uid()}",
        timestamp_start=ts,
        timestamp_end=ts,
        leq_db=68.5,
        peak_db=82.1,
        pct_over=0.42,
        rule_triggered="15min_Leq_over_65dBA",
        latitude=52.52,
        longitude=13.405,
        status="active",
        **overrides,
    )
    db.add(event)
    await db.flush()
    await db.refresh(event)
    return event


# ── organization ─────────────────────────────────────────────────────────────

async def create_organization(
    db: AsyncSession,
    *,
    name: str = "Test Org",
    owner: User | None = None,
    **overrides,
) -> Organization:
    org = Organization(
        name=name,
        slug=name.lower().replace(" ", "-"),
        owner_id=owner.id if owner else None,
        **overrides,
    )
    db.add(org)
    await db.flush()
    await db.refresh(org)
    return org


async def add_member(
    db: AsyncSession,
    org: Organization,
    user: User,
    role: str = "member",
) -> OrganizationMembership:
    member = OrganizationMembership(
        organization_id=org.id,
        user_id=user.id,
        role=role,
    )
    db.add(member)
    await db.flush()
    return member


# ── site ─────────────────────────────────────────────────────────────────────

async def create_site(
    db: AsyncSession,
    *,
    org: Organization,
    name: str = "Test Site",
    **overrides,
) -> Site:
    site = Site(
        organization_id=org.id,
        name=name,
        latitude=52.52,
        longitude=13.405,
        **overrides,
    )
    db.add(site)
    await db.flush()
    await db.refresh(site)
    return site


# ── zone ─────────────────────────────────────────────────────────────────────

async def create_zone(
    db: AsyncSession,
    *,
    site: Site,
    name: str = "Test Zone",
    **overrides,
) -> Zone:
    zone = Zone(
        site_id=site.id,
        name=name,
        **overrides,
    )
    db.add(zone)
    await db.flush()
    await db.refresh(zone)
    return zone


# ── policy ───────────────────────────────────────────────────────────────────

async def create_policy(
    db: AsyncSession,
    *,
    org: Organization,
    name: str = "Test Policy",
    day_threshold_db: float = 65.0,
    night_threshold_db: float = 55.0,
    **overrides,
) -> Policy:
    policy = Policy(
        organization_id=org.id,
        name=name,
        day_threshold_db=day_threshold_db,
        night_threshold_db=night_threshold_db,
        **overrides,
    )
    db.add(policy)
    await db.flush()
    await db.refresh(policy)
    return policy


# ── calibration profile ──────────────────────────────────────────────────────

async def create_calibration_profile(
    db: AsyncSession,
    *,
    org: Organization,
    name: str = "Test Calibration Profile",
    offset_db: float = 0.0,
    **overrides,
) -> CalibrationProfile:
    profile = CalibrationProfile(
        organization_id=org.id,
        name=name,
        offset_db=offset_db,
        **overrides,
    )
    db.add(profile)
    await db.flush()
    await db.refresh(profile)
    return profile


# ── episode ──────────────────────────────────────────────────────────────────

async def create_episode(
    db: AsyncSession,
    *,
    org: Organization,
    site: Site | None = None,
    events: list[Event] | None = None,
    **overrides,
) -> Episode:
    episode = Episode(
        organization_id=org.id,
        site_id=site.id if site else None,
        status="open",
        **overrides,
    )
    db.add(episode)
    await db.flush()
    if events:
        for event in events:
            event.episode_id = episode.id
            db.add(event)
        await db.flush()
    await db.refresh(episode)
    return episode


# ── case ─────────────────────────────────────────────────────────────────────

async def create_case(
    db: AsyncSession,
    *,
    org: Organization,
    episode: Episode | None = None,
    **overrides,
) -> Case:
    case = Case(
        organization_id=org.id,
        episode_id=episode.id if episode else None,
        status="open",
        **overrides,
    )
    db.add(case)
    await db.flush()
    await db.refresh(case)
    return case


# ── auth helper ──────────────────────────────────────────────────────────────

async def register_and_login(client: AsyncClient, **overrides) -> tuple[dict, str]:
    """Register a user and return (user_data, access_token)."""
    email = overrides.pop("email", f"{_uid()}@test.noisenet.org")
    password = overrides.pop("password", "testpass123")
    resp = await client.post("/api/v1/auth/register", json={
        "email": email,
        "password": password,
        "full_name": overrides.pop("full_name", "Test User"),
        **overrides,
    })
    assert resp.status_code == 201, resp.text
    data = resp.json()
    return data, data["access_token"]
