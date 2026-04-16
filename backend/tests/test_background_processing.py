"""Unit tests for optional background task dispatch."""

from datetime import datetime, timezone

from app.core.config import settings
from app.services import background_processing


def test_queue_realtime_measurement_skips_when_disabled(monkeypatch):
    monkeypatch.setattr(settings, "ENABLE_BACKGROUND_TASKS", False)

    called = False

    def fake_enqueue(**kwargs):
        nonlocal called
        called = True

    monkeypatch.setattr(
        background_processing,
        "_enqueue_realtime_measurement",
        fake_enqueue,
    )

    queued = background_processing.queue_realtime_measurement(
        device_id="device-123",
        leq_db=62.5,
        timestamp_start=datetime(2026, 4, 16, 12, 0, tzinfo=timezone.utc),
        location_lat=52.52,
        location_lng=13.40,
    )

    assert queued is False
    assert called is False


def test_queue_realtime_measurement_swallows_worker_errors(monkeypatch):
    monkeypatch.setattr(settings, "ENABLE_BACKGROUND_TASKS", True)

    def fake_enqueue(**kwargs):
        raise RuntimeError("broker unavailable")

    monkeypatch.setattr(
        background_processing,
        "_enqueue_realtime_measurement",
        fake_enqueue,
    )

    queued = background_processing.queue_realtime_measurement(
        device_id="device-123",
        leq_db=62.5,
        timestamp_start=datetime(2026, 4, 16, 12, 0, tzinfo=timezone.utc),
        location_lat=52.52,
        location_lng=13.40,
    )

    assert queued is False


def test_queue_realtime_measurement_dispatches_when_enabled(monkeypatch):
    monkeypatch.setattr(settings, "ENABLE_BACKGROUND_TASKS", True)

    captured = {}

    def fake_enqueue(**kwargs):
        captured.update(kwargs)

    monkeypatch.setattr(
        background_processing,
        "_enqueue_realtime_measurement",
        fake_enqueue,
    )

    timestamp = datetime(2026, 4, 16, 12, 0, tzinfo=timezone.utc)
    queued = background_processing.queue_realtime_measurement(
        device_id="device-123",
        leq_db=62.5,
        timestamp_start=timestamp,
        location_lat=52.52,
        location_lng=13.40,
    )

    assert queued is True
    assert captured == {
        "device_id": "device-123",
        "leq_db": 62.5,
        "timestamp_start": timestamp,
        "location_lat": 52.52,
        "location_lng": 13.40,
    }
