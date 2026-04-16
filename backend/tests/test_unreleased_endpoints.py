"""Verify unreleased surfaces fail explicitly instead of returning TODO payloads."""

import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_admin_surface_returns_not_implemented(client: AsyncClient):
    response = await client.get("/api/v1/admin/stats")
    assert response.status_code == 501
    assert "current MVP" in response.json()["detail"]


async def test_snippets_surface_returns_not_implemented(client: AsyncClient):
    response = await client.post("/api/v1/snippets/upload")
    assert response.status_code == 501
    assert "current MVP" in response.json()["detail"]
