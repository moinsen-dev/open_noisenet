"""Synthetic-only feasibility check. Never connect this to a public API.

Five account identifiers are not proof of five people and a threshold is not
an anonymisation guarantee. Real publication additionally needs independent
enrolment, measurement validation and protection against differencing.
"""
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from typing import Iterable


@dataclass(frozen=True)
class SyntheticContribution:
    participant: str
    day: date


def synthetic_week_available(
    contributions: Iterable[SyntheticContribution], week_start: date, now: datetime
) -> bool:
    """Check one fixed UTC week; no counts or individual data are returned."""
    if week_start.weekday() != 0 or now.tzinfo is None or now.utcoffset() is None:
        raise ValueError("Expected a Monday and a timezone-aware clock")
    week_end = week_start + timedelta(days=7)
    ready = datetime.combine(week_end, time.min, tzinfo=UTC) + timedelta(hours=48)
    if now < ready:
        return False
    participants = {
        item.participant for item in contributions
        if item.participant and week_start <= item.day < week_end
    }
    return len(participants) >= 5
