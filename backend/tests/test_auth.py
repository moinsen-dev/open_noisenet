"""Tests for authentication endpoints."""

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, create_refresh_token
from app.db.models.user import User

pytestmark = pytest.mark.asyncio

REGISTER_URL = "/api/v1/auth/register"
LOGIN_URL = "/api/v1/auth/login"
REFRESH_URL = "/api/v1/auth/refresh"


# ---------- Registration ----------


async def test_register_user(client: AsyncClient):
    """POST /register returns 201 with access_token and refresh_token."""
    resp = await client.post(
        REGISTER_URL,
        json={
            "email": "alice@example.com",
            "password": "strongpass123",
            "full_name": "Alice Example",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert "access_token" in body
    assert "refresh_token" in body
    assert body["token_type"] == "bearer"
    assert body["expires_in"] > 0


async def test_register_duplicate_email(client: AsyncClient):
    """Registering with the same email twice returns 409."""
    payload = {
        "email": "dup@example.com",
        "password": "strongpass123",
        "full_name": "Dup User",
    }
    resp1 = await client.post(REGISTER_URL, json=payload)
    assert resp1.status_code == 201

    resp2 = await client.post(REGISTER_URL, json=payload)
    assert resp2.status_code == 409


# ---------- Login ----------


async def test_login(client: AsyncClient):
    """POST /login returns 200 with access_token."""
    # Register first
    await client.post(
        REGISTER_URL,
        json={
            "email": "bob@example.com",
            "password": "bobpass1234",
            "full_name": "Bob Example",
        },
    )

    resp = await client.post(
        LOGIN_URL,
        json={"email": "bob@example.com", "password": "bobpass1234"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body
    assert "refresh_token" in body


async def test_login_wrong_password(client: AsyncClient):
    """POST /login with wrong password returns 401."""
    await client.post(
        REGISTER_URL,
        json={
            "email": "carol@example.com",
            "password": "correct_pass1",
            "full_name": "Carol Example",
        },
    )

    resp = await client.post(
        LOGIN_URL,
        json={"email": "carol@example.com", "password": "wrong_pass"},
    )
    assert resp.status_code == 401


# ---------- Refresh ----------


async def test_refresh_token(client: AsyncClient):
    """POST /refresh returns 200 with new access_token."""
    reg = await client.post(
        REGISTER_URL,
        json={
            "email": "dave@example.com",
            "password": "davepass1234",
            "full_name": "Dave Example",
        },
    )
    refresh = reg.json()["refresh_token"]

    resp = await client.post(REFRESH_URL, json={"refresh_token": refresh})
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body
    assert "refresh_token" in body


# ---------- Protected endpoint ----------


async def test_protected_endpoint_without_token(client: AsyncClient):
    """DELETE /events/{id} without auth returns 401."""
    import uuid

    fake_id = str(uuid.uuid4())
    resp = await client.delete(f"/api/v1/events/{fake_id}")
    assert resp.status_code == 401


# ---------- Refresh edge cases ----------


async def test_refresh_with_tampered_token(client: AsyncClient):
    """POST /refresh with a tampered token returns 401 or 422."""
    reg = await client.post(
        REGISTER_URL,
        json={
            "email": "tamper@example.com",
            "password": "tamperpass123",
            "full_name": "Tamper User",
        },
    )
    refresh = reg.json()["refresh_token"]
    tampered = refresh[:-1] + ("A" if refresh[-1] != "A" else "B")
    resp = await client.post(REFRESH_URL, json={"refresh_token": tampered})
    assert resp.status_code in (401, 422)


async def test_refresh_with_access_token_as_refresh(client: AsyncClient):
    """POST /refresh with access_token as refresh_token returns 401."""
    reg = await client.post(
        REGISTER_URL,
        json={
            "email": "accrefresh@example.com",
            "password": "accpass1234",
            "full_name": "AccRefresh User",
        },
    )
    access = reg.json()["access_token"]
    resp = await client.post(REFRESH_URL, json={"refresh_token": access})
    assert resp.status_code == 401


# ---------- Rate limiting ----------


async def test_login_rate_limit(client: AsyncClient):
    """Rapid-fire 7 login attempts → first 5 get 401, 6th+7th get 429."""
    payload = {"email": "ratelimit@example.com", "password": "wrongpassword"}

    for i in range(5):
        resp = await client.post(LOGIN_URL, json=payload)
        assert resp.status_code == 401, f"Attempt {i + 1}: expected 401, got {resp.status_code}"

    resp6 = await client.post(LOGIN_URL, json=payload)
    assert resp6.status_code == 429, f"Attempt 6: expected 429, got {resp6.status_code}"
    resp7 = await client.post(LOGIN_URL, json=payload)
    assert resp7.status_code == 429, f"Attempt 7: expected 429, got {resp7.status_code}"
