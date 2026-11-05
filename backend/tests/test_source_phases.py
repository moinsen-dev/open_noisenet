"""The private phase contract, retry semantics and erasure boundaries."""

import copy
import secrets
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.db.models.source_phase import SourcePhase
from app.schemas.source_phase import SourcePhaseUpload

pytestmark = pytest.mark.asyncio


def phase(**changes):
    return {
        "phase_id": str(uuid4()),
        "revision": 1,
        "algorithm": "source_phases_v1",
        "source_model": "yamnet_tflite_4d8b4a53",
        "family": "speech",
        "start_ms": 1000,
        "end_ms": 20000,
        "observed_until_ms": 21000,
        "active_ms": 19000,
        "pause_ms": 0,
        "activity": [{"start_ms": 1000, "end_ms": 20000}],
        "state": "open",
        "end_reason": "end_of_observations",
        **changes,
    }


async def register(client, name="phase-phone"):
    headers = {"X-Device-Key": secrets.token_urlsafe(32)}
    r = await client.post(
        "/api/v1/devices/register",
        headers=headers,
        json={"device_id": name, "name": "Phase test"},
    )
    assert r.status_code == 200
    return headers


async def test_continuations_retries_and_stale_updates(client, db_session):
    headers = await register(client)
    first = phase()
    url = f'/api/v1/source-phases/phase-phone/{first["phase_id"]}'
    receipt = await client.put(url, json=first, headers=headers)
    assert receipt.status_code == 200
    assert receipt.json()["digest"] == SourcePhaseUpload(**first).digest()
    assert (await client.put(url, json=first, headers=headers)).json() == receipt.json()
    second = copy.deepcopy(first)
    second.update(
        revision=3,
        end_ms=50000,
        observed_until_ms=51000,
        active_ms=39000,
        pause_ms=10000,
    )
    second["activity"].append({"start_ms": 30000, "end_ms": 50000})
    assert (await client.put(url, json=second, headers=headers)).status_code == 200
    assert (await client.put(url, json=first, headers=headers)).status_code == 409
    conflicting = {**second, "family": "traffic"}
    assert (await client.put(url, json=conflicting, headers=headers)).status_code == 409
    shortened = {**first, "revision": 4, "observed_until_ms": 51000}
    assert (await client.put(url, json=shortened, headers=headers)).status_code == 409
    final = {**second, "revision": 4, "state": "closed", "end_reason": "sensor_stopped"}
    assert (await client.put(url, json=final, headers=headers)).status_code == 200
    assert (await client.put(url, json=final, headers=headers)).status_code == 200
    assert (
        await client.put(url, json={**final, "revision": 5}, headers=headers)
    ).status_code == 409
    rows = (await db_session.execute(select(SourcePhase))).scalars().all()
    assert len(rows) == 1 and rows[0].payload == final


async def test_private_even_on_public_sensor_and_wrong_device_key(client):
    h = await register(client)
    other = await register(client, "other-phone")
    payload = phase()
    url = f'/api/v1/source-phases/phase-phone/{payload["phase_id"]}'
    assert (await client.put(url, json=payload)).status_code == 403
    assert (await client.put(url, json=payload, headers=other)).status_code == 403
    assert (await client.put(url, json=payload, headers=h)).status_code == 200
    assert (
        await client.put(
            "/api/v1/devices/phase-phone", json={"is_public": True}, headers=h
        )
    ).status_code == 200
    assert (await client.get("/api/v1/source-phases/phase-phone")).status_code == 404
    assert (
        await client.get("/api/v1/source-phases/phase-phone", headers=other)
    ).status_code == 404
    assert (await client.get("/api/v1/source-phases/phase-phone", headers=h)).json()[
        "items"
    ] == [payload]
    assert (await client.get("/api/v1/events/")).json()["total"] == 0
    assert (await client.get("/api/v1/map/events")).json()["features"] == []
    assert (await client.delete(url, headers=other)).status_code == 403


async def test_delete_erases_payload_and_prevents_delayed_resurrection(
    client, db_session
):
    h = await register(client)
    for uploaded in [False, True]:
        p = phase()
        url = f'/api/v1/source-phases/phase-phone/{p["phase_id"]}'
        if uploaded:
            assert (await client.put(url, json=p, headers=h)).status_code == 200
        assert (await client.delete(url, headers=h)).json()["status"] == "deleted"
        assert (await client.delete(url, headers=h)).status_code == 200
        assert (await client.put(url, json=p, headers=h)).status_code == 410
    assert (await client.get("/api/v1/source-phases/phase-phone", headers=h)).json()[
        "items"
    ] == []
    rows = (await db_session.execute(select(SourcePhase))).scalars().all()
    assert all(r.deleted and r.payload == {} and r.digest == "" for r in rows)


@pytest.mark.parametrize(
    "changes",
    [
        {"active_ms": 19001},
        {"pause_ms": 1},
        {"observed_until_ms": 19999},
        {
            "activity": [
                {"start_ms": 1000, "end_ms": 15000},
                {"start_ms": 14000, "end_ms": 20000},
            ]
        },
        {"state": "closed"},
        {"audio": "forbidden"},
        {"coordinates": [1, 2]},
        {"family": "confirmed_conversation"},
        {"revision": True},
        {"revision": 1.5},
    ],
)
async def test_rejects_bad_totals_and_non_contract_data(client, changes):
    h = await register(client)
    p = phase(**changes)
    r = await client.put(
        f'/api/v1/source-phases/phase-phone/{p["phase_id"]}', json=p, headers=h
    )
    assert r.status_code == 422


async def test_commit_failure_has_no_ack(client, db_session, monkeypatch):
    h = await register(client)
    p = phase()

    async def fail():
        raise RuntimeError("simulated commit failure")

    monkeypatch.setattr(db_session, "commit", fail)
    with pytest.raises(RuntimeError, match="simulated commit failure"):
        await client.put(
            f'/api/v1/source-phases/phase-phone/{p["phase_id"]}', json=p, headers=h
        )
    await db_session.rollback()
    assert (await db_session.execute(select(SourcePhase))).scalars().all() == []
