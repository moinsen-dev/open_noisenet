"""Production hardening tests: error handling, CORS, security headers, health check."""

import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


# ---------- Error Handling ----------


async def test_all_error_responses_are_json(client: AsyncClient):
    """Verify that error responses (404, 401, 422) all return JSON with 'detail' key, not HTML."""

    # 404 — valid UUID format but nonexistent event
    resp = await client.get("/api/v1/events/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404
    body = resp.json()
    assert "detail" in body
    assert "text/html" not in resp.headers.get("content-type", "")

    # 422 — empty body on validation-required endpoint
    resp = await client.post("/api/v1/auth/login")
    assert resp.status_code == 422
    body = resp.json()
    assert "detail" in body
    assert "text/html" not in resp.headers.get("content-type", "")

    # 401 — unauthenticated access to protected endpoint
    resp = await client.delete("/api/v1/devices/nonexistent")
    assert resp.status_code == 401
    body = resp.json()
    assert "detail" in body
    assert "text/html" not in resp.headers.get("content-type", "")


async def test_422_validation_error_format(client: AsyncClient):
    """Submit invalid event payload → 422, verify detail is an array with 'loc' and 'msg' fields."""

    resp = await client.post(
        "/api/v1/events/",
        json={
            "device_id": "dev-test",
            # missing required timestamp_start, timestamp_end, leq_db
            "extra_unknown_field": "should be ignored",
        },
    )
    assert resp.status_code == 422
    body = resp.json()
    detail = body["detail"]
    assert isinstance(detail, list)
    assert len(detail) > 0
    for error in detail:
        assert "loc" in error
        assert "msg" in error


# ---------- CORS + Security Headers ----------


async def test_cors_preflight(client: AsyncClient):
    """OPTIONS request to /api/v1/events/ → 200 with Access-Control-Allow-Origin header."""

    resp = await client.options(
        "/api/v1/events/",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert resp.status_code == 200
    assert resp.headers.get("access-control-allow-origin") is not None


async def test_security_headers(client: AsyncClient):
    """GET /health → response includes X-Content-Type-Options header."""

    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.headers.get("x-content-type-options") == "nosniff"


# ---------- Health Check Depth ----------


async def test_health_returns_200(client: AsyncClient):
    """GET /health → 200 with status=healthy."""

    resp = await client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "healthy"


async def test_health_includes_db_check(client: AsyncClient):
    """GET /health → response includes database status field."""

    resp = await client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert "database" in body
    assert body["database"] in ("connected", "disconnected")
