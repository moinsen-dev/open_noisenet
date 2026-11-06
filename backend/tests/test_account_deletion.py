from uuid import uuid4

import pytest
from sqlalchemy import func, select, text
from app.core.device_auth import device_key_hash
from app.db.models import Device, DeviceApiKey, Event, Organization, OrganizationMembership, SourcePhase, User

pytestmark = pytest.mark.asyncio
root = "/api/v1/auth/account-deletion"


async def make_account(client, db, name):
    body = {"email": f"{name}@example.org", "password": "synthetic-strong-password", "full_name": name}
    response = await client.post("/api/v1/auth/register", json=body)
    assert response.status_code == 201
    return await db.scalar(select(User).where(User.email == body["email"])), response.json(), body


async def test_delete_scope_and_wrong_password(client, db_session):
    db = db_session
    await db.execute(text("PRAGMA foreign_keys=ON"))
    user, tokens, account = await make_account(client, db, "owner")
    peer, _, _ = await make_account(client, db, "peer")
    orgs = [Organization(name=n, slug=n, created_by_id=user.id) for n in ("mine", "team")]
    devices = [Device(device_id=n, name=n, device_type="smartphone", owner_id=owner)
               for n, owner in (("mine", user.id), ("peer", peer.id), ("unassociated", None))]
    db.add_all(orgs + devices)
    await db.flush()
    db.add(OrganizationMembership(organization_id=orgs[1].id, user_id=peer.id))
    for d in devices:
        db.add(Event(device_id=d.id))
        db.add(DeviceApiKey(device_id=d.id, key_hash=device_key_hash("A"*43) if d.device_id=="mine" else str(uuid4())))
        db.add(SourcePhase(device_id=d.id, phase_uuid=uuid4(), revision=1, digest="d", payload={}))
    await db.flush()
    h = {"Authorization": "Bearer " + tokens["access_token"]}
    assert (await client.post(root, json={"password": "ignored"})).status_code == 401
    assert (await client.post(root, json={"password": "wrong"}, headers=h)).status_code == 403
    assert await db.scalar(select(func.count()).select_from(User)) == 2
    assert (await client.post(root, json={"password": account["password"]}, headers=h)).status_code == 204
    assert (await db.scalars(select(Device.device_id).order_by(Device.device_id))).all() == ["peer", "unassociated"]
    assert (await db.scalars(select(Organization.slug))).all() == ["team"]
    assert (await db.scalar(select(Organization.created_by_id))) is None
    for cls in [Event, DeviceApiKey, SourcePhase]:
        assert await db.scalar(select(func.count()).select_from(cls)) == 2
    assert await db.scalar(select(func.count()).select_from(OrganizationMembership)) == 1
    replay = await client.post("/api/v1/devices/register", headers={"X-Device-Key": "A"*43},
                               json={"device_id":"mine","name":"replay","device_type":"smartphone"})
    assert replay.status_code == 403
    assert (await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})).status_code == 401
    assert (await client.post(root, json={"password": account["password"]}, headers=h)).status_code == 401


async def test_web_delete_only_on_own_origin(client, db_session):
    user, _, body = await make_account(client, db_session, "webtest")
    r = await client.get(root + "/web")
    assert r.status_code == 200 and 'no-store' in r.headers['cache-control']
    form = {"email": body["email"], "password": body["password"], "confirm": "delete"}
    assert (await client.post(root+"/web", data=form, headers={"Origin":"https://other.example"})).status_code == 403
    assert (await client.post(root+"/web", data={**form, "confirm":"no"}, headers={"Origin":"http://test"})).status_code == 403
    assert (await client.post(root+"/web", data=form, headers={"Origin":"http://test"})).status_code == 200
    assert await db_session.scalar(select(User.id).where(User.email == body["email"])) is None
