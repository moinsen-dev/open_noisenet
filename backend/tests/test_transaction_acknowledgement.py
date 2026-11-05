"""An HTTP acknowledgement must not precede transaction completion."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import get_session
from app.main import app


@pytest.mark.asyncio
async def test_commit_failure_does_not_return_success(db_session):
    async def session_with_failing_commit():
        yield db_session
        raise RuntimeError('simulated commit failure')

    app.dependency_overrides[get_session] = session_with_failing_commit
    try:
        transport = ASGITransport(app=app, raise_app_exceptions=False)
        async with AsyncClient(transport=transport, base_url='http://test') as client:
            response = await client.post('/api/v1/devices/register', headers={'X-Device-Key': 'A' * 43}, json={
                'device_id': 'commit-failure-test', 'name': 'Synthetic device',
            })
        assert response.status_code == 500
    finally:
        app.dependency_overrides.pop(get_session, None)
