# Backend MVP Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use moinsenpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring backend to 100% MVP, activate worker pipeline, ensure Mobile (Flutter) + Frontend (React) consume the API correctly.

**Architecture:** FastAPI async backend with PostgreSQL, Celery workers for realtime processing + aggregation, JWT user auth + device API-key auth. Map endpoints public read-only. Clients adapted to match API contract.

**Tech Stack:** Python/FastAPI, PostgreSQL+asyncpg, Celery+Redis, SQLAlchemy 2.0 async, pytest+httpx, Dart/Flutter (Dio), TypeScript/React (axios)

---

## Team Roles

| Role | Scope |
|---|---|
| **Team Lead** | Coordinates phases, defines API contract, reviews |
| **Backend Specialist** | Fix blockers, auth, map endpoints, worker integration |
| **Tester** | pytest infrastructure, unit + integration tests |
| **Frontend Specialist** | React + Flutter API client adaptation |

## Phase Dependencies

```
Phase 1 (Blockers) ──> Phase 2 (Auth) ──> Phase 3 (parallel: Map + Workers + Tests)
                                      ──> Phase 4 (parallel: Frontend Clients + More Tests)
                                      ──> Phase 5 (Verification)
```

---

## Task 1: Fix Critical Blockers

**Owner:** Backend Specialist
**Files:**
- Modify: `backend/app/core/logging.py:69` (add get_logger)
- Modify: `backend/app/services/threshold_detection_service.py:19` (fix import)
- Modify: `backend/app/services/geospatial_service.py:20` (fix import)
- Modify: `backend/app/workers/noise_processing_tasks.py:16` (fix async_session import)
- Modify: `backend/app/workers/data_aggregation_tasks.py:14` (fix async_session import)
- Test: `backend/tests/test_imports.py`

### Step 1: Write import test

```python
# backend/tests/test_imports.py
"""Verify all modules import without errors."""

def test_import_logging():
    from app.core.logging import get_logger, setup_logging
    logger = get_logger("test")
    assert logger is not None

def test_import_spl_service():
    from app.services.spl_calculation_service import SPLCalculationService
    svc = SPLCalculationService()
    assert svc is not None

def test_import_threshold_service():
    from app.services.threshold_detection_service import ThresholdDetectionService
    svc = ThresholdDetectionService()
    assert svc is not None

def test_import_geospatial_service():
    from app.services.geospatial_service import GeospatialService
    svc = GeospatialService()
    assert svc is not None

def test_import_main():
    from app.main import create_application
    app = create_application()
    assert app is not None
```

### Step 2: Run test to verify it fails

Run: `cd backend && python -m pytest tests/test_imports.py -v`
Expected: FAIL with `ImportError: cannot import name 'get_logger'`

### Step 3: Fix get_logger in logging.py

Add at end of `backend/app/core/logging.py`:

```python
def get_logger(name: str):
    """Get a structured logger instance."""
    return structlog.get_logger(name)
```

### Step 4: Fix NoiseEvent → Event in threshold_detection_service.py

In `backend/app/services/threshold_detection_service.py:19`, change:
```python
from app.db.models.noise_event import NoiseEvent
```
to:
```python
from app.db.models.event import Event
```

Note: This service doesn't actually use the model in its current methods (all placeholder queries), so just fixing the import is sufficient. The `NoiseEvent` reference is only in the import line.

### Step 5: Fix NoiseEvent → Event in geospatial_service.py

In `backend/app/services/geospatial_service.py:20`, change:
```python
from app.db.models.noise_event import NoiseEvent
```
to:
```python
from app.db.models.event import Event
```

Also replace all `NoiseEvent` references in the file with `Event`, and update field names to match actual model:
- `NoiseEvent.location` → use `Event.location_lat` / `Event.location_lng` (no PostGIS geometry column)
- `NoiseEvent.latitude` → `Event.location_lat`
- `NoiseEvent.longitude` → `Event.location_lng`
- `NoiseEvent.average_leq_db` → `Event.leq_db`
- `NoiseEvent.max_level_db` → `Event.lmax_db`
- `NoiseEvent.start_time` → `Event.timestamp_start`
- `NoiseEvent.end_time` → `Event.timestamp_end`
- `NoiseEvent.duration_seconds` → calculate from timestamps

Remove GeoAlchemy2 spatial query functions (`ST_DWithin`, `ST_Transform`, `ST_MakePoint`) since the model uses simple lat/lng columns. Replace with Haversine-based filtering using raw SQL or Python-side filtering.

### Step 6: Fix async_session import in workers

Both `noise_processing_tasks.py:16` and `data_aggregation_tasks.py:14` import:
```python
from app.db.session import async_session
```

But `session.py` exports `AsyncSessionLocal` and `get_session`. Change to:
```python
from app.db.session import AsyncSessionLocal as async_session
```

Or better, add an alias in `session.py`:
```python
# Alias for worker tasks
async_session = AsyncSessionLocal
```

### Step 7: Create pytest infrastructure

Create `backend/tests/conftest.py`:

```python
"""Shared test fixtures."""
import asyncio
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from app.core.config import settings
from app.db.base import Base
from app.db.session import get_session
from app.main import app


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session."""
    engine = create_async_engine(
        str(settings.DATABASE_URL),
        echo=False,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with session_factory() as session:
        yield session
        await session.rollback()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create test HTTP client with DB override."""
    async def override_get_session():
        yield db_session

    app.dependency_overrides[get_session] = override_get_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()
```

Create `backend/pyproject.toml` section or `backend/pytest.ini`:
```ini
# backend/pytest.ini
[pytest]
asyncio_mode = auto
testpaths = tests
```

### Step 8: Run test to verify it passes

Run: `cd backend && python -m pytest tests/test_imports.py -v`
Expected: All 5 tests PASS

### Step 9: Commit

```
feat: fix critical blockers - get_logger, model references, worker imports
```

---

## Task 2: Implement User Authentication (JWT)

**Owner:** Backend Specialist
**Files:**
- Create: `backend/app/core/security.py`
- Create: `backend/app/core/deps.py`
- Create: `backend/app/schemas/auth.py`
- Modify: `backend/app/api/v1/endpoints/auth.py`
- Test: `backend/tests/test_auth.py`

### Step 1: Write failing auth tests

```python
# backend/tests/test_auth.py
"""Test authentication endpoints."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_register_user(client: AsyncClient):
    response = await client.post("/api/v1/auth/register", json={
        "email": "test@example.com",
        "password": "securepassword123",
        "full_name": "Test User",
    })
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient):
    payload = {"email": "dupe@example.com", "password": "pass123456", "full_name": "Dupe"}
    await client.post("/api/v1/auth/register", json=payload)
    response = await client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_login(client: AsyncClient):
    # Register first
    await client.post("/api/v1/auth/register", json={
        "email": "login@example.com",
        "password": "securepassword123",
        "full_name": "Login User",
    })
    # Login
    response = await client.post("/api/v1/auth/login", json={
        "email": "login@example.com",
        "password": "securepassword123",
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient):
    await client.post("/api/v1/auth/register", json={
        "email": "wrong@example.com",
        "password": "correctpassword",
        "full_name": "Wrong",
    })
    response = await client.post("/api/v1/auth/login", json={
        "email": "wrong@example.com",
        "password": "wrongpassword",
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_refresh_token(client: AsyncClient):
    reg = await client.post("/api/v1/auth/register", json={
        "email": "refresh@example.com",
        "password": "securepassword123",
        "full_name": "Refresh User",
    })
    refresh_token = reg.json()["refresh_token"]
    response = await client.post("/api/v1/auth/refresh", json={
        "refresh_token": refresh_token,
    })
    assert response.status_code == 200
    assert "access_token" in response.json()


@pytest.mark.asyncio
async def test_protected_endpoint_without_token(client: AsyncClient):
    response = await client.delete("/api/v1/events/00000000-0000-0000-0000-000000000001")
    assert response.status_code == 401
```

### Step 2: Run tests to verify they fail

Run: `cd backend && python -m pytest tests/test_auth.py -v`
Expected: FAIL

### Step 3: Create security module

```python
# backend/app/core/security.py
"""JWT token creation and password hashing."""
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(subject: str, expires_delta: Optional[timedelta] = None) -> str:
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode = {"sub": subject, "exp": expire, "type": "access"}
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY or settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = {"sub": subject, "exp": expire, "type": "refresh"}
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY or settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, settings.JWT_SECRET_KEY or settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        return None
```

### Step 4: Create auth dependencies

```python
# backend/app/core/deps.py
"""FastAPI dependencies for authentication."""
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.models.user import User
from app.db.session import get_session

security = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_session),
) -> Optional[User]:
    """Get current user from JWT token. Returns None if no token."""
    if not credentials:
        return None

    payload = decode_token(credentials.credentials)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    result = await db.execute(select(User).where(User.id == UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    return user


async def require_user(
    user: Optional[User] = Depends(get_current_user),
) -> User:
    """Require authenticated user."""
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    return user


async def require_superuser(
    user: User = Depends(require_user),
) -> User:
    """Require superuser."""
    if not user.is_superuser:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Superuser required")
    return user
```

### Step 5: Create auth schemas

```python
# backend/app/schemas/auth.py
"""Authentication schemas."""
from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: str = Field(..., min_length=1, max_length=255)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
```

### Step 6: Implement auth endpoints

Replace `backend/app/api/v1/endpoints/auth.py`:

```python
"""Authentication endpoints."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token, create_refresh_token, decode_token,
    get_password_hash, verify_password,
)
from app.db.models.user import User
from app.db.session import get_session
from app.schemas.auth import LoginRequest, RegisterRequest, RefreshRequest, TokenResponse

router = APIRouter()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_session)):
    """Register a new user."""
    result = await db.execute(select(User).where(User.email == data.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        email=data.email,
        hashed_password=get_password_hash(data.password),
        full_name=data.full_name,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_session)):
    """User login."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled")

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(data: RefreshRequest, db: AsyncSession = Depends(get_session)):
    """Refresh access token."""
    payload = decode_token(data.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )
```

### Step 7: Add auth protection to delete endpoint

In `backend/app/api/v1/endpoints/events.py`, add `require_user` dependency to DELETE:

```python
from app.core.deps import require_user

@router.delete("/{event_id}")
async def delete_event(
    event_id: UUID,
    user: User = Depends(require_user),  # <-- add this
    db: AsyncSession = Depends(get_session),
):
```

### Step 8: Run auth tests

Run: `cd backend && python -m pytest tests/test_auth.py -v`
Expected: All PASS

### Step 9: Commit

```
feat: implement JWT user authentication with register/login/refresh
```

---

## Task 3: Implement Map Endpoints

**Owner:** Backend Specialist
**Files:**
- Modify: `backend/app/api/v1/endpoints/map.py`
- Create: `backend/app/schemas/map.py`
- Test: `backend/tests/test_map.py`

### Step 1: Write failing map tests

```python
# backend/tests/test_map.py
"""Test map endpoints."""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device, DeviceType
from app.db.models.event import Event, EventStatus


async def _seed_map_data(db: AsyncSession):
    """Seed test data for map tests."""
    device = Device(
        device_id="map-test-device",
        name="Map Test Device",
        device_type=DeviceType.SMARTPHONE,
        location_lat=52.520008,
        location_lng=13.404954,
        is_public=True,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)

    from datetime import datetime, timezone
    event = Event(
        device_id=device.id,
        timestamp_start=datetime.now(timezone.utc),
        timestamp_end=datetime.now(timezone.utc),
        leq_db=65.0,
        lmax_db=72.0,
        lmin_db=45.0,
        location_lat=52.520008,
        location_lng=13.404954,
        status=EventStatus.PROCESSED,
    )
    db.add(event)
    await db.flush()
    return device, event


@pytest.mark.asyncio
async def test_get_map_events_geojson(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get("/api/v1/map/events")
    assert response.status_code == 200
    data = response.json()
    assert data["type"] == "FeatureCollection"
    assert len(data["features"]) >= 1
    feature = data["features"][0]
    assert feature["type"] == "Feature"
    assert feature["geometry"]["type"] == "Point"


@pytest.mark.asyncio
async def test_get_map_events_with_bbox(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get("/api/v1/map/events", params={
        "min_lat": 52.0, "max_lat": 53.0, "min_lng": 13.0, "max_lng": 14.0,
    })
    assert response.status_code == 200
    assert len(response.json()["features"]) >= 1


@pytest.mark.asyncio
async def test_get_heatmap_data(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get("/api/v1/map/heatmap", params={
        "min_lat": 52.0, "max_lat": 53.0, "min_lng": 13.0, "max_lng": 14.0,
    })
    assert response.status_code == 200
    data = response.json()
    assert "points" in data


@pytest.mark.asyncio
async def test_get_map_stats(client: AsyncClient, db_session: AsyncSession):
    await _seed_map_data(db_session)
    response = await client.get("/api/v1/map/stats")
    assert response.status_code == 200
    data = response.json()
    assert "total_events" in data
    assert "total_devices" in data
```

### Step 2: Run tests to verify they fail

Run: `cd backend && python -m pytest tests/test_map.py -v`
Expected: FAIL (endpoints return TODO stubs)

### Step 3: Create map schemas

```python
# backend/app/schemas/map.py
"""Map visualization schemas."""
from typing import List, Optional, Any, Dict
from datetime import datetime

from pydantic import BaseModel, Field


class MapEventFeature(BaseModel):
    """GeoJSON Feature for a noise event."""
    type: str = "Feature"
    geometry: Dict[str, Any]
    properties: Dict[str, Any]


class GeoJSONResponse(BaseModel):
    """GeoJSON FeatureCollection."""
    type: str = "FeatureCollection"
    features: List[MapEventFeature]


class HeatmapPoint(BaseModel):
    lat: float
    lng: float
    intensity: float
    event_count: int


class HeatmapResponse(BaseModel):
    points: List[HeatmapPoint]
    min_intensity: Optional[float] = None
    max_intensity: Optional[float] = None


class MapStats(BaseModel):
    total_events: int
    total_devices: int
    avg_leq_db: Optional[float] = None
    max_leq_db: Optional[float] = None
    active_devices_24h: int
    events_24h: int
```

### Step 4: Implement map endpoints

Replace `backend/app/api/v1/endpoints/map.py`:

```python
"""Map data endpoints — public, no auth required."""
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device
from app.db.models.event import Event
from app.db.session import get_session
from app.schemas.map import GeoJSONResponse, MapEventFeature, HeatmapResponse, HeatmapPoint, MapStats

router = APIRouter()


@router.get("/events", response_model=GeoJSONResponse)
async def get_map_events(
    min_lat: Optional[float] = Query(None, ge=-90, le=90),
    max_lat: Optional[float] = Query(None, ge=-90, le=90),
    min_lng: Optional[float] = Query(None, ge=-180, le=180),
    max_lng: Optional[float] = Query(None, ge=-180, le=180),
    hours: int = Query(default=24, ge=1, le=720),
    limit: int = Query(default=500, ge=1, le=5000),
    db: AsyncSession = Depends(get_session),
):
    """Get noise events as GeoJSON for map display. Public endpoint."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    stmt = (
        select(Event)
        .where(Event.timestamp_start >= cutoff)
        .where(Event.location_lat.is_not(None))
        .where(Event.location_lng.is_not(None))
    )

    if min_lat is not None and max_lat is not None:
        stmt = stmt.where(Event.location_lat.between(min_lat, max_lat))
    if min_lng is not None and max_lng is not None:
        stmt = stmt.where(Event.location_lng.between(min_lng, max_lng))

    stmt = stmt.order_by(Event.timestamp_start.desc()).limit(limit)
    result = await db.execute(stmt)
    events = result.scalars().all()

    features = []
    for event in events:
        features.append(MapEventFeature(
            geometry={
                "type": "Point",
                "coordinates": [float(event.location_lng), float(event.location_lat)],
            },
            properties={
                "id": str(event.id),
                "leq_db": float(event.leq_db),
                "lmax_db": float(event.lmax_db) if event.lmax_db else None,
                "timestamp": event.timestamp_start.isoformat(),
                "rule_triggered": event.rule_triggered,
                "status": event.status.value,
            },
        ))

    return GeoJSONResponse(features=features)


@router.get("/heatmap", response_model=HeatmapResponse)
async def get_heatmap_data(
    min_lat: float = Query(..., ge=-90, le=90),
    max_lat: float = Query(..., ge=-90, le=90),
    min_lng: float = Query(..., ge=-180, le=180),
    max_lng: float = Query(..., ge=-180, le=180),
    hours: int = Query(default=24, ge=1, le=720),
    db: AsyncSession = Depends(get_session),
):
    """Get aggregated heatmap data for a bounding box. Public endpoint."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    stmt = (
        select(Event)
        .where(Event.timestamp_start >= cutoff)
        .where(Event.location_lat.between(min_lat, max_lat))
        .where(Event.location_lng.between(min_lng, max_lng))
        .where(Event.location_lat.is_not(None))
    )

    result = await db.execute(stmt)
    events = result.scalars().all()

    points = []
    for event in events:
        points.append(HeatmapPoint(
            lat=float(event.location_lat),
            lng=float(event.location_lng),
            intensity=float(event.leq_db),
            event_count=1,
        ))

    min_i = min((p.intensity for p in points), default=None)
    max_i = max((p.intensity for p in points), default=None)

    return HeatmapResponse(points=points, min_intensity=min_i, max_intensity=max_i)


@router.get("/stats", response_model=MapStats)
async def get_map_statistics(db: AsyncSession = Depends(get_session)):
    """Get global map statistics. Public endpoint."""
    now = datetime.now(timezone.utc)

    total_events = (await db.execute(select(func.count(Event.id)))).scalar() or 0
    total_devices = (await db.execute(select(func.count(Device.id)))).scalar() or 0

    stats_result = await db.execute(
        select(func.avg(Event.leq_db), func.max(Event.leq_db))
    )
    stats = stats_result.first()

    events_24h = (await db.execute(
        select(func.count(Event.id)).where(Event.timestamp_start >= now - timedelta(hours=24))
    )).scalar() or 0

    active_devices_24h = (await db.execute(
        select(func.count(func.distinct(Event.device_id)))
        .where(Event.timestamp_start >= now - timedelta(hours=24))
    )).scalar() or 0

    return MapStats(
        total_events=total_events,
        total_devices=total_devices,
        avg_leq_db=float(stats[0]) if stats[0] else None,
        max_leq_db=float(stats[1]) if stats[1] else None,
        active_devices_24h=active_devices_24h,
        events_24h=events_24h,
    )
```

### Step 5: Run map tests

Run: `cd backend && python -m pytest tests/test_map.py -v`
Expected: All PASS

### Step 6: Commit

```
feat: implement map endpoints with GeoJSON events, heatmap, and stats
```

---

## Task 4: Wire Worker Pipeline (Realtime + Aggregation)

**Owner:** Backend Specialist
**Files:**
- Modify: `backend/app/api/v1/endpoints/events.py` (trigger worker on event creation)
- Modify: `backend/app/workers/data_aggregation_tasks.py` (implement real DB queries)
- Modify: `backend/app/workers/noise_processing_tasks.py` (fix imports, implement store)
- Modify: `backend/app/db/session.py` (add async_session alias)
- Test: `backend/tests/test_workers.py`

### Step 1: Write failing worker unit tests

```python
# backend/tests/test_workers.py
"""Test worker task logic (unit tests, no Celery broker needed)."""
import pytest
from datetime import datetime, timezone

from app.services.spl_calculation_service import SPLCalculationService
from app.services.threshold_detection_service import ThresholdDetectionService


def test_spl_leq_calculation():
    svc = SPLCalculationService()
    leq = svc.calculate_leq([60.0, 70.0, 65.0])
    assert 60.0 < leq < 75.0  # Leq should be between min and max (energy-weighted)


def test_spl_noise_statistics():
    svc = SPLCalculationService()
    stats = svc.calculate_noise_statistics([40.0, 50.0, 60.0, 70.0, 80.0])
    assert stats["lmin"] == 40.0
    assert stats["lmax"] == 80.0
    assert stats["sample_count"] == 5
    assert stats["l50"] > 0  # Median


def test_spl_a_weighting():
    svc = SPLCalculationService()
    # Very quiet sounds get more correction
    quiet = svc.apply_a_weighting_broadband(25.0)
    loud = svc.apply_a_weighting_broadband(95.0)
    assert quiet < 25.0  # Should be reduced
    assert loud == 95.0  # Minimal correction for loud


def test_threshold_time_restrictions():
    svc = ThresholdDetectionService()
    rule = svc.default_rules[0]  # WHO Day Limit (07:00-19:00)

    day_time = datetime(2026, 3, 11, 12, 0, tzinfo=timezone.utc)
    night_time = datetime(2026, 3, 11, 2, 0, tzinfo=timezone.utc)

    assert svc._check_time_restrictions(rule, day_time) is True
    assert svc._check_time_restrictions(rule, night_time) is False


def test_threshold_night_wrap_around():
    svc = ThresholdDetectionService()
    night_rule = svc.default_rules[2]  # WHO Night Limit (23:00-07:00)

    late_night = datetime(2026, 3, 11, 1, 0, tzinfo=timezone.utc)
    before_midnight = datetime(2026, 3, 11, 23, 30, tzinfo=timezone.utc)
    afternoon = datetime(2026, 3, 11, 15, 0, tzinfo=timezone.utc)

    assert svc._check_time_restrictions(night_rule, late_night) is True
    assert svc._check_time_restrictions(night_rule, before_midnight) is True
    assert svc._check_time_restrictions(night_rule, afternoon) is False


def test_noise_level_categories():
    svc = SPLCalculationService()
    assert svc.get_noise_level_category(30.0) == "very_quiet"
    assert svc.get_noise_level_category(55.0) == "loud"
    assert svc.get_noise_level_category(90.0) == "dangerous"


def test_regulatory_compliance():
    svc = SPLCalculationService()
    compliant = svc.check_regulatory_compliance(40.0, "night", "WHO")
    assert compliant["status"] == "compliant"

    violation = svc.check_regulatory_compliance(70.0, "night", "WHO")
    assert violation["status"] == "severe_violation"
```

### Step 2: Run tests

Run: `cd backend && python -m pytest tests/test_workers.py -v`
Expected: All PASS (these test existing service logic)

### Step 3: Add async_session alias to session.py

Add at end of `backend/app/db/session.py`:

```python
# Alias for worker tasks
async_session = AsyncSessionLocal
```

### Step 4: Trigger worker on event creation

In `backend/app/api/v1/endpoints/events.py`, after creating the event, queue a Celery task:

```python
# Add at top:
from app.core.config import settings

# In create_event(), after db.refresh(new_event):
    # Queue background processing (non-blocking, fire-and-forget)
    try:
        from app.workers.noise_processing_tasks import process_real_time_measurement
        process_real_time_measurement.delay(
            device.device_id,
            {
                "spl_db": event_data.leq_db,
                "timestamp": event_data.timestamp_start.isoformat(),
                "location": {
                    "latitude": event_data.location_lat,
                    "longitude": event_data.location_lng,
                },
            },
        )
    except Exception:
        pass  # Don't fail event creation if worker queue unavailable
```

### Step 5: Implement real DB queries in aggregation helpers

Replace placeholder functions in `data_aggregation_tasks.py`:

```python
async def _get_active_devices(db) -> List[str]:
    """Get list of active device IDs."""
    from app.db.models.device import Device
    result = await db.execute(
        select(Device.device_id).where(Device.is_active == True)
    )
    return [row[0] for row in result.all()]


async def _get_device_measurements(
    device_id: str, start_time: datetime, end_time: datetime, db
) -> List[Dict]:
    """Get events for a device in time range (events serve as measurements)."""
    from app.db.models.event import Event
    from app.db.models.device import Device

    result = await db.execute(
        select(Event)
        .join(Device)
        .where(Device.device_id == device_id)
        .where(Event.timestamp_start >= start_time)
        .where(Event.timestamp_start < end_time)
    )
    events = result.scalars().all()
    return [
        {
            "spl_db": float(e.leq_db),
            "timestamp": e.timestamp_start,
            "device_id": device_id,
        }
        for e in events
    ]


async def _get_device_events(
    device_id: str, start_time: datetime, end_time: datetime, db
) -> List[Dict]:
    """Get events with rule_triggered for a device."""
    from app.db.models.event import Event
    from app.db.models.device import Device

    result = await db.execute(
        select(Event)
        .join(Device)
        .where(Device.device_id == device_id)
        .where(Event.timestamp_start >= start_time)
        .where(Event.timestamp_start < end_time)
        .where(Event.rule_triggered.is_not(None))
    )
    events = result.scalars().all()
    return [
        {
            "rule_triggered": e.rule_triggered,
            "peak_level_db": float(e.lmax_db) if e.lmax_db else float(e.leq_db),
            "start_time": e.timestamp_start,
            "duration_seconds": (e.timestamp_end - e.timestamp_start).total_seconds(),
        }
        for e in events
    ]


async def _store_hourly_device_stats(stats: Dict[str, Any], db):
    """Store as EventAggregation."""
    from app.db.models.event import EventAggregation
    from app.db.models.device import Device
    from datetime import timedelta

    device_result = await db.execute(
        select(Device).where(Device.device_id == stats["device_id"])
    )
    device = device_result.scalar_one_or_none()
    if not device:
        return

    agg = EventAggregation(
        device_id=device.id,
        time_bucket=datetime.fromisoformat(stats["hour_start"]),
        bucket_duration=timedelta(hours=1),
        avg_leq_db=stats["statistics"]["leq"],
        max_leq_db=stats["statistics"]["lmax"],
        min_leq_db=stats["statistics"]["lmin"],
        event_count=stats["event_count"],
        exceedance_count=stats["event_count"],  # simplified
    )
    db.add(agg)
    await db.flush()
```

### Step 6: Commit

```
feat: wire worker pipeline with real DB queries and event-triggered processing
```

---

## Task 5: Service Unit + Integration Tests

**Owner:** Tester
**Files:**
- Create: `backend/tests/test_services.py`
- Create: `backend/tests/test_events_api.py`
- Create: `backend/tests/test_devices_api.py`

### Step 1: Write service unit tests

```python
# backend/tests/test_services.py
"""Unit tests for backend services."""
import pytest
import math

from app.services.spl_calculation_service import SPLCalculationService


class TestSPLCalculationService:
    def setup_method(self):
        self.svc = SPLCalculationService()

    def test_rms_empty_returns_zero(self):
        assert self.svc.calculate_rms([]) == 0.0

    def test_rms_single_value(self):
        assert self.svc.calculate_rms([1.0]) == 1.0

    def test_spl_from_rms_zero_returns_zero(self):
        assert self.svc.calculate_spl_from_rms(0.0) == 0.0

    def test_spl_from_rms_reference(self):
        # At reference pressure (20 µPa), SPL should be 0 dB
        spl = self.svc.calculate_spl_from_rms(2e-5)
        assert abs(spl) < 0.1

    def test_leq_empty_returns_zero(self):
        assert self.svc.calculate_leq([]) == 0.0

    def test_leq_single_value(self):
        assert abs(self.svc.calculate_leq([60.0]) - 60.0) < 0.1

    def test_leq_energy_averaging(self):
        # 60 dB + 60 dB = ~63 dB (energy doubles = +3dB)
        # But Leq averages, so two equal values = same value
        leq = self.svc.calculate_leq([60.0, 60.0])
        assert abs(leq - 60.0) < 0.1

    def test_leq_dominated_by_loud(self):
        # 90 dB dominates over 50 dB in energy averaging
        leq = self.svc.calculate_leq([50.0, 90.0])
        assert leq > 85.0  # Should be close to 90

    def test_noise_statistics_percentiles(self):
        values = list(range(30, 81))  # 30-80 dB
        stats = self.svc.calculate_noise_statistics(values)
        assert stats["lmin"] == 30.0
        assert stats["lmax"] == 80.0
        assert stats["l90"] < stats["l50"] < stats["l10"]

    def test_threshold_detection(self):
        from datetime import datetime, timedelta
        now = datetime.utcnow()
        measurements = [
            {"spl_db": 70.0, "timestamp": now - timedelta(seconds=i)}
            for i in range(60)
        ]
        assert self.svc.detect_threshold_exceedance(measurements, 65.0, 30) is True
        assert self.svc.detect_threshold_exceedance(measurements, 75.0, 30) is False

    def test_compliance_who_day_compliant(self):
        result = self.svc.check_regulatory_compliance(50.0, "day", "WHO")
        assert result["status"] == "compliant"

    def test_compliance_who_night_violation(self):
        result = self.svc.check_regulatory_compliance(55.0, "night", "WHO")
        assert result["status"] == "severe_violation"
```

### Step 2: Write API integration tests

```python
# backend/tests/test_events_api.py
"""Integration tests for events API."""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device, DeviceType


async def _create_device(db: AsyncSession) -> Device:
    device = Device(
        device_id="test-device-001",
        name="Test Device",
        device_type=DeviceType.SMARTPHONE,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return device


@pytest.mark.asyncio
async def test_create_event(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    response = await client.post("/api/v1/events/", json={
        "device_id": "test-device-001",
        "timestamp_start": "2026-03-11T10:00:00Z",
        "timestamp_end": "2026-03-11T10:15:00Z",
        "leq_db": 65.0,
        "lmax_db": 72.0,
        "lmin_db": 45.0,
    })
    assert response.status_code == 200
    data = response.json()
    assert data["leq_db"] == 65.0
    assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_create_event_auto_creates_device(client: AsyncClient):
    response = await client.post("/api/v1/events/", json={
        "device_id": "auto-created-device",
        "timestamp_start": "2026-03-11T10:00:00Z",
        "timestamp_end": "2026-03-11T10:15:00Z",
        "leq_db": 55.0,
    })
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_list_events_pagination(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    # Create 3 events
    for i in range(3):
        await client.post("/api/v1/events/", json={
            "device_id": "test-device-001",
            "timestamp_start": f"2026-03-11T{10+i}:00:00Z",
            "timestamp_end": f"2026-03-11T{10+i}:15:00Z",
            "leq_db": 60.0 + i,
        })

    response = await client.get("/api/v1/events/", params={"limit": 2})
    assert response.status_code == 200
    data = response.json()
    assert len(data["events"]) == 2
    assert data["total"] == 3


@pytest.mark.asyncio
async def test_get_event_stats(client: AsyncClient, db_session: AsyncSession):
    await _create_device(db_session)
    await client.post("/api/v1/events/", json={
        "device_id": "test-device-001",
        "timestamp_start": "2026-03-11T10:00:00Z",
        "timestamp_end": "2026-03-11T10:15:00Z",
        "leq_db": 65.0,
    })
    response = await client.get("/api/v1/events/stats/")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] >= 1
```

```python
# backend/tests/test_devices_api.py
"""Integration tests for devices API."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_register_device(client: AsyncClient):
    response = await client.post("/api/v1/devices/register", json={
        "device_id": "my-phone-001",
        "name": "My Phone",
        "device_type": "smartphone",
        "location_lat": 52.52,
        "location_lng": 13.405,
    })
    assert response.status_code == 200
    data = response.json()
    assert data["device_id"] == "my-phone-001"


@pytest.mark.asyncio
async def test_get_device(client: AsyncClient):
    await client.post("/api/v1/devices/register", json={
        "device_id": "get-test-001",
        "name": "Get Test",
    })
    response = await client.get("/api/v1/devices/get-test-001")
    assert response.status_code == 200
    assert response.json()["name"] == "Get Test"


@pytest.mark.asyncio
async def test_device_heartbeat(client: AsyncClient):
    await client.post("/api/v1/devices/register", json={
        "device_id": "heartbeat-001",
        "name": "Heartbeat Device",
    })
    response = await client.post("/api/v1/devices/heartbeat-001/heartbeat", json={
        "device_id": "heartbeat-001",
        "timestamp": "2026-03-11T10:00:00Z",
        "battery_level": 85.5,
    })
    assert response.status_code == 200
```

### Step 3: Run all tests

Run: `cd backend && python -m pytest tests/ -v`
Expected: All PASS

### Step 4: Commit

```
test: add service unit tests and API integration tests
```

---

## Task 6: Adapt React Frontend API Client

**Owner:** Frontend Specialist
**Files:**
- Modify: `frontend/src/services/api.ts`

### Step 1: Add auth and map types/methods to React client

Add to `frontend/src/services/api.ts`:

```typescript
// Add auth types
export interface LoginRequest {
  email: string
  password: string
}

export interface RegisterRequest {
  email: string
  password: string
  full_name: string
}

export interface AuthTokens {
  access_token: string
  refresh_token: string
  token_type: string
  expires_in: number
}

// Map types
export interface GeoJSONFeature {
  type: 'Feature'
  geometry: { type: 'Point'; coordinates: [number, number] }
  properties: {
    id: string
    leq_db: number
    lmax_db?: number
    timestamp: string
    rule_triggered?: string
    status: string
  }
}

export interface GeoJSONResponse {
  type: 'FeatureCollection'
  features: GeoJSONFeature[]
}

export interface HeatmapPoint {
  lat: number
  lng: number
  intensity: number
  event_count: number
}

export interface HeatmapResponse {
  points: HeatmapPoint[]
  min_intensity?: number
  max_intensity?: number
}

export interface MapStats {
  total_events: number
  total_devices: number
  avg_leq_db?: number
  max_leq_db?: number
  active_devices_24h: number
  events_24h: number
}

// Add token storage helper
const TOKEN_KEY = 'noisenet_access_token'

function setAuthToken(token: string | null) {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token)
    apiClient.defaults.headers.common['Authorization'] = `Bearer ${token}`
  } else {
    localStorage.removeItem(TOKEN_KEY)
    delete apiClient.defaults.headers.common['Authorization']
  }
}

// Restore token on load
const storedToken = localStorage.getItem(TOKEN_KEY)
if (storedToken) {
  apiClient.defaults.headers.common['Authorization'] = `Bearer ${storedToken}`
}
```

Add to `api` object:

```typescript
  // Auth API
  auth: {
    login: (data: LoginRequest) =>
      apiClient.post<AuthTokens>('/auth/login', data).then(res => {
        setAuthToken(res.data.access_token)
        return res.data
      }),

    register: (data: RegisterRequest) =>
      apiClient.post<AuthTokens>('/auth/register', data).then(res => {
        setAuthToken(res.data.access_token)
        return res.data
      }),

    logout: () => {
      setAuthToken(null)
    },
  },

  // Map API (public, no auth)
  map: {
    events: (params?: { min_lat?: number; max_lat?: number; min_lng?: number; max_lng?: number; hours?: number }) =>
      apiClient.get<GeoJSONResponse>('/map/events', { params }).then(res => res.data),

    heatmap: (params: { min_lat: number; max_lat: number; min_lng: number; max_lng: number; hours?: number }) =>
      apiClient.get<HeatmapResponse>('/map/heatmap', { params }).then(res => res.data),

    stats: () =>
      apiClient.get<MapStats>('/map/stats').then(res => res.data),
  },
```

### Step 2: Fix health check URL

The current health check hits `/health` at root, not under `/api/v1`. Fix:

```typescript
  health: () => {
    const rootUrl = API_BASE_URL.replace('/api/v1', '')
    return axios.get(`${rootUrl}/health`).then(res => res.data)
  },
```

### Step 3: Commit

```
feat: add auth + map endpoints to React API client
```

---

## Task 7: Adapt Flutter API Client

**Owner:** Frontend Specialist
**Files:**
- Modify: `mobile/lib/services/api_client_service.dart`
- Modify: `mobile/lib/core/models/api_models.dart`

### Step 1: Add map methods to Flutter ApiClientService

Add to `ApiClientService` class in `api_client_service.dart`:

```dart
  // Map endpoints (public, no auth required)
  Future<Map<String, dynamic>> getMapEvents({
    double? minLat, double? maxLat,
    double? minLng, double? maxLng,
    int hours = 24,
    int limit = 500,
  }) async {
    try {
      final queryParams = <String, dynamic>{'hours': hours, 'limit': limit};
      if (minLat != null) queryParams['min_lat'] = minLat;
      if (maxLat != null) queryParams['max_lat'] = maxLat;
      if (minLng != null) queryParams['min_lng'] = minLng;
      if (maxLng != null) queryParams['max_lng'] = maxLng;

      final response = await _dio.get('/map/events', queryParameters: queryParams);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Failed to get map events', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMapHeatmap({
    required double minLat, required double maxLat,
    required double minLng, required double maxLng,
    int hours = 24,
  }) async {
    try {
      final response = await _dio.get('/map/heatmap', queryParameters: {
        'min_lat': minLat, 'max_lat': maxLat,
        'min_lng': minLng, 'max_lng': maxLng,
        'hours': hours,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Failed to get heatmap data', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMapStats() async {
    try {
      final response = await _dio.get('/map/stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Failed to get map stats', e);
      rethrow;
    }
  }
```

### Step 2: Fix listEvents response parsing

Current Flutter `listEvents` parses response as `List<dynamic>` but backend returns `EventListResponse` with `events` key:

```dart
  Future<List<NoiseEventModel>> listEvents({...}) async {
    // ...
    final response = await _dio.get('/events/', queryParameters: queryParams);
    // FIX: Backend returns {events: [...], total: N, offset: N, limit: N}
    final data = response.data as Map<String, dynamic>;
    final List<dynamic> eventList = data['events'] as List<dynamic>;
    return eventList.map((json) => NoiseEventModel.fromJson(json as Map<String, dynamic>)).toList();
  }
```

### Step 3: Commit

```
feat: add map endpoints and fix listEvents response parsing in Flutter client
```

---

## Task 8: Verification

**Owner:** Team Lead
**Files:** None (verification only)

### Step 1: Docker-Compose smoke test

```bash
cd /Users/udi/work/moinsen/ideas/open_noisenet
docker-compose up -d backend postgres redis
# Wait for healthy
docker-compose exec backend python -c "from app.main import app; print('App OK')"
```

### Step 2: Run full test suite

```bash
cd backend && python -m pytest tests/ -v --tb=short
```

### Step 3: Verify API docs

```bash
curl http://localhost:8100/docs  # Should show Swagger UI
curl http://localhost:8100/api/v1/openapi.json | python -m json.tool | head -50
```

### Step 4: Manual API contract verification

```bash
# Health check
curl http://localhost:8100/health

# Register user
curl -X POST http://localhost:8100/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"testpass123","full_name":"Test"}'

# Create event
curl -X POST http://localhost:8100/api/v1/events/ \
  -H "Content-Type: application/json" \
  -d '{"device_id":"curl-test","timestamp_start":"2026-03-11T10:00:00Z","timestamp_end":"2026-03-11T10:15:00Z","leq_db":65.0,"location_lat":52.52,"location_lng":13.405}'

# Map events
curl http://localhost:8100/api/v1/map/events

# Map stats
curl http://localhost:8100/api/v1/map/stats
```

### Step 5: Commit all remaining changes

```
chore: backend MVP completion verified
```
