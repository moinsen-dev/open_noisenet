"""Regression tests for the anonymous episode detection sweep."""

from uuid import UUID

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.pro_domain import Episode, EpisodeReviewState


pytestmark = pytest.mark.asyncio


@pytest.fixture(autouse=True)
def device_key(client: AsyncClient):
    client.headers["X-Device-Key"] = "A" * 43


@pytest_asyncio.fixture(autouse=True)
async def administrative_repair_access(client: AsyncClient, db_session: AsyncSession):
    from tests.factories import create_user
    user = await create_user(db_session, email="repair@example.org", password="repair-password")
    user.is_superuser = True
    await db_session.flush()
    login = await client.post("/api/v1/auth/login", json={"email": user.email, "password": "repair-password"})
    client.headers["Authorization"] = f"Bearer {login.json()['access_token']}"


def _event_payload(device_id: str, event_uuid: str, start: str, end: str) -> dict:
    return {
        "event_uuid": event_uuid,
        "device_id": device_id,
        "timestamp_start": start,
        "timestamp_end": end,
        "leq_db": 70.0,
        "lmax_db": 82.0,
        "lmin_db": 58.0,
        "classification_label": "traffic_noise",
        "classification_confidence": 0.9,
        "classification_source": "device_rule_engine",
        "segment_type": "sustained",
        "reportability_score": 0.8,
        "reportability_reason": "Persistent elevated levels",
        "threshold_exceedance_ratio": 0.6,
    }


async def test_event_ingestion_builds_episode_and_all_device_sweep_is_idempotent(
    client: AsyncClient,
):
    """Anonymous ingestion groups immediately; the repair sweep is a no-op."""
    device = await client.post(
        "/api/v1/devices/register",
        json={"device_id": "anon-phone-001", "name": "Anon Phone"},
    )
    assert device.status_code == 200

    episode_ids = []
    for i in range(2):
        resp = await client.post(
            "/api/v1/events/",
            json=_event_payload(
                "anon-phone-001",
                f"evt-anon-{i}",
                f"2026-08-17T10:0{i}:00Z",
                f"2026-08-17T10:0{i}:04Z",
            ),
        )
        assert resp.status_code == 200
        episode_ids.append(resp.json()["episode_id"])

    assert episode_ids[0] is not None
    assert episode_ids[0] == episode_ids[1]

    response = await client.post("/api/v1/events/detect-episodes")
    assert response.status_code == 200
    data = response.json()
    assert data["devices_processed"] == 0
    assert data["episodes_created"] == 0

    # Events should now be attached to the created episode
    events = await client.get("/api/v1/events/")
    assert events.status_code == 200
    for ev in events.json()["events"]:
        assert ev["episode_id"] is not None


async def test_single_device_repair_endpoint_is_idempotent_after_ingestion(
    client: AsyncClient,
):
    """The explicit public-ID repair path does not duplicate episodes."""
    device = await client.post(
        "/api/v1/devices/register",
        json={"device_id": "anon-phone-002", "name": "Anon Phone 2"},
    )
    assert device.status_code == 200

    for i in range(2):
        resp = await client.post(
            "/api/v1/events/",
            json=_event_payload(
                "anon-phone-002",
                f"evt-anon2-{i}",
                f"2026-08-17T11:0{i}:00Z",
                f"2026-08-17T11:0{i}:04Z",
            ),
        )
        assert resp.status_code == 200

    response = await client.post(
        "/api/v1/events/detect-episodes", params={"device_id": "anon-phone-002"}
    )
    assert response.status_code == 200
    assert response.json()["episodes_created"] == 0
    assert response.json()["device_id"] == "anon-phone-002"


async def test_late_upload_does_not_merge_across_a_distant_past_gap(
    client: AsyncClient,
):
    """Out-of-order delivery must not turn an old event into current activity."""
    device_id = "late-upload-phone-001"
    device = await client.post(
        "/api/v1/devices/register",
        json={"device_id": device_id, "name": "Late Upload Phone"},
    )
    assert device.status_code == 200

    newer = _event_payload(
        device_id,
        "evt-late-upload-newer",
        "2026-08-18T20:00:00Z",
        "2026-08-18T20:10:00Z",
    )
    newer.update(
        {
            "classification_label": "loud_conversation",
            "classification_confidence": 0.8,
        }
    )
    newer_response = await client.post("/api/v1/events/", json=newer)
    assert newer_response.status_code == 200

    older = _event_payload(
        device_id,
        "evt-late-upload-older",
        "2026-08-18T18:00:00Z",
        "2026-08-18T18:10:00Z",
    )
    older.update(
        {
            "classification_label": "loud_conversation",
            "classification_confidence": 0.8,
        }
    )
    older_response = await client.post("/api/v1/events/", json=older)
    assert older_response.status_code == 200

    assert older_response.json()["episode_id"] != newer_response.json()["episode_id"]


async def test_detect_episodes_merges_meeting_parts_using_source_evidence(
    client: AsyncClient,
    db_session: AsyncSession,
):
    """One real activity may contain pauses and a legacy event-clock error.

    The source-segment timestamps are the best available observation clock in
    this fixture. The two threshold events belong to one speech episode, while
    the gap remains represented in episode metadata instead of being called
    continuous noise.
    """
    device_id = "meeting-phone-001"
    device = await client.post(
        "/api/v1/devices/register",
        json={"device_id": device_id, "name": "Meeting Phone"},
    )
    assert device.status_code == 200

    first = _event_payload(
        device_id,
        "evt-meeting-001",
        # Legacy client clock: these fields are two hours ahead.
        "2026-08-18T18:09:41.163902Z",
        "2026-08-18T18:18:47.567051Z",
    )
    first.update(
        {
            "leq_db": 68.17478,
            "lmax_db": 90.30913,
            "classification_label": "loud_conversation",
            "classification_confidence": 0.716,
            "classification_source": "device_yamnet_taxonomy_v1",
            "segment_type": "repeated_impulses",
            "event_metadata": {
                "source_activity": {
                    "timing_basis": "yamnet_frame_hysteresis_v1",
                    "segments": [
                        {
                            "start": "2026-08-18T16:08:30.245450Z",
                            "end": "2026-08-18T16:18:47.540450Z",
                            "category": "loud_conversation",
                            "duration_ms": 617295,
                        }
                    ],
                }
            },
        }
    )

    second = _event_payload(
        device_id,
        "evt-meeting-002",
        "2026-08-18T16:28:31.643813Z",
        "2026-08-18T16:30:02.440838Z",
    )
    second.update(
        {
            "leq_db": 69.05821,
            "lmax_db": 82.83096,
            "classification_label": "loud_conversation",
            "classification_confidence": 0.704,
            "classification_source": "device_yamnet_taxonomy_v1",
            "segment_type": "repeated_impulses",
            "event_metadata": {
                "source_activity": {
                    "timing_basis": "yamnet_frame_hysteresis_v1",
                    "segments": [
                        {
                            "start": "2026-08-18T16:28:31.109200Z",
                            "end": "2026-08-18T16:30:01.844200Z",
                            "category": "loud_conversation",
                            "duration_ms": 90735,
                        }
                    ],
                }
            },
        }
    )

    receipts = []
    for payload in (first, second):
        response = await client.post("/api/v1/events/", json=payload)
        assert response.status_code == 200
        receipts.append(response.json())

    assert receipts[0]["episode_id"] == receipts[1]["episode_id"]

    response = await client.post(
        "/api/v1/events/detect-episodes", params={"device_id": device_id}
    )
    assert response.status_code == 200
    assert response.json()["episodes_created"] == 0

    timeline = await client.get(
        f"/api/v1/devices/{device_id}/timeline", params={"date": "2026-08-18"}
    )
    assert timeline.status_code == 200
    timeline_payload = timeline.json()
    assert len(timeline_payload["episodes"]) == 1
    episode = timeline_payload["episodes"][0]
    assert episode["primary_class"] == "loud_conversation"
    assert episode["event_count"] == 2
    assert episode["started_at"].startswith("2026-08-18T16:08:30.245450")
    assert episode["ended_at"].startswith("2026-08-18T16:30:01.844200")
    assert episode["continuity"]["merge_basis"] == "same_source_family_within_gap"
    assert episode["continuity"]["inter_event_gaps"][0][
        "duration_seconds"
    ] == pytest.approx(583.6, abs=0.1)
    assert episode["continuity"]["continuous_noise_claimed"] is False
    assert timeline_payload["noise_duration"]["episode_count"] == 1
    # Sum of the two measured threshold intervals, not the whole episode span.
    assert timeline_payload["noise_duration"]["total_seconds"] == 637

    stored_episode = await db_session.get(Episode, UUID(receipts[0]["episode_id"]))
    assert stored_episode is not None
    stored_episode.review_state = EpisodeReviewState.SUPPRESSED.value
    stored_episode.review_label = "known_local_activity"
    stored_episode.reviewed_severity = "informational"
    stored_episode.review_metadata = {
        **stored_episode.review_metadata,
        "context_annotation": {
            "kind": "known_local_activity",
            "label": "teams_meeting",
            "display_label": "Teams meeting",
            "source": "user_confirmation",
        },
    }
    await db_session.flush()

    reviewed_timeline = await client.get(
        f"/api/v1/devices/{device_id}/timeline", params={"date": "2026-08-18"}
    )
    reviewed_payload = reviewed_timeline.json()
    assert reviewed_payload["episodes"][0]["primary_class"] == "loud_conversation"
    assert reviewed_payload["episodes"][0]["effective_label"] == (
        "known_local_activity"
    )
    assert reviewed_payload["noise_duration"]["target_seconds"] == 0
    assert reviewed_payload["noise_duration"]["excluded_local_seconds"] == 637

    local_timeline = await client.get(
        f"/api/v1/devices/{device_id}/timeline",
        params={"date": "2026-08-18", "timezone": "Europe/Berlin"},
    )
    assert local_timeline.status_code == 200
    local_payload = local_timeline.json()
    assert local_payload["timezone"] == "Europe/Berlin"
    assert local_payload["episodes"][0]["local_started_at"].startswith(
        "2026-08-18T18:08:30.245450+02:00"
    )
    assert local_payload["episodes"][0]["local_ended_at"].startswith(
        "2026-08-18T18:30:01.844200+02:00"
    )
    assert local_payload["summary"].startswith("18:08–18:30")
