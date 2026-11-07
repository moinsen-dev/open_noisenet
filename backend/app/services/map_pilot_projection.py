"""Prototype of a fixed-week projection, isolated from real data.

This module does not verify identities, validate acoustic measurements, seal
published results or handle withdrawal. It must not be connected to real data
until those protections and their operational controls have been completed.
"""
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from typing import Iterable, Literal


Band = Literal["low", "medium", "high"]
AREA = "hamburg-eimsbuettel"


@dataclass(frozen=True)
class PrototypeContribution:
    person: str
    day: date
    band: Band


def prototype_projection(
    records: Iterable[PrototypeContribution], week_start: date, now: datetime
) -> list[dict[str, str]]:
    """Return a synthetic weekly result without identifiers or contributor counts.

    IDs here are test inputs, not proof of distinct humans. Each synthetic
    person has one equally weighted vote: their most common daily band. A tie
    at either aggregation level suppresses the result rather than inventing one.
    """
    if week_start.weekday() != 0 or now.tzinfo is None or now.utcoffset() is None:
        raise ValueError("Expected a Monday and an aware timestamp")
    week_end = week_start + timedelta(days=7)
    if now < datetime.combine(week_end, time.min, tzinfo=UTC) + timedelta(hours=48):
        return []
    daily: dict[tuple[str, date], Band] = {}
    for record in records:
        if not record.person or record.band not in ("low", "medium", "high"):
            raise ValueError("Invalid prototype input")
        if not week_start <= record.day < week_end:
            continue
        key = (record.person, record.day)
        if key in daily and daily[key] != record.band:
            raise ValueError("Conflicting person-day")
        daily[key] = record.band
    if len({person for person, _ in daily}) < 5:
        return []
    person_bands: dict[str, list[Band]] = defaultdict(list)
    for (person, _), band in daily.items():
        person_bands[person].append(band)

    def winner(values: list[Band]) -> Band | None:
        counts = Counter(values).most_common()
        return counts[0][0] if len(counts) == 1 or counts[0][1] > counts[1][1] else None

    votes = [winner(bands) for bands in person_bands.values()]
    if any(vote is None for vote in votes):
        return []
    result = winner([vote for vote in votes if vote is not None])
    if result is None:
        return []
    return [{"area": AREA, "week_start": week_start.isoformat(), "band": result}]
