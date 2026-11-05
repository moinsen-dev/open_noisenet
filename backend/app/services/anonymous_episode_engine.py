"""Episode detection for anonymous/public events — no Pro context required."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from math import log10
from typing import Any, Optional, List
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash
from app.db.models.device import Device as DeviceModel
from app.db.models.event import Event
from app.db.models.pro_domain import (
    Episode,
    EpisodeLifecycleState,
    EpisodeReviewState,
    EvidenceMode,
    Organization,
    Site,
)
from app.db.models.user import User

# ── Classification patterns ───────────────────────────────────────────────────

CLASSIFICATION_RULES: List[dict] = [
    {
        "name": "construction_noise",
        "label_de": "Baustellenlaerm",
        "label_en": "Construction noise",
        "min_duration_min": 30,
        "typical_duration_h": (2, 10),
        "db_range": (60, 95),
        "variability": "low",
        "time_pattern": "daytime",
        "peak_pattern": "occasional_impacts",
    },
    {
        "name": "traffic_noise",
        "label_de": "Verkehrslaerm",
        "label_en": "Traffic noise",
        "min_duration_min": 5,
        "typical_duration_h": (0.1, 24),
        "db_range": (55, 85),
        "variability": "medium",
        "time_pattern": "anytime",
        "peak_pattern": "intermittent_spikes",
    },
    {
        "name": "conversation_dispute",
        "label_de": "Lautes Gespraech / Streit",
        "label_en": "Loud conversation / Dispute",
        "min_duration_min": 5,
        "typical_duration_h": (0.1, 2),
        "db_range": (55, 80),
        "variability": "high",
        "time_pattern": "evening_night",
        "peak_pattern": "irregular_spikes",
    },
    {
        "name": "music_party",
        "label_de": "Musik / Party",
        "label_en": "Music / Party",
        "min_duration_min": 15,
        "typical_duration_h": (0.5, 6),
        "db_range": (60, 100),
        "variability": "medium",
        "time_pattern": "evening_night",
        "peak_pattern": "rhythmic_pattern",
    },
    {
        "name": "mechanical_hvac",
        "label_de": "Maschinen- / Klimaanlagenlaerm",
        "label_en": "Mechanical / HVAC noise",
        "min_duration_min": 30,
        "typical_duration_h": (1, 24),
        "db_range": (45, 70),
        "variability": "very_low",
        "time_pattern": "anytime",
        "peak_pattern": "none",
    },
    {
        "name": "animal_barking",
        "label_de": "Hundegebell / Tierlaute",
        "label_en": "Dog barking / Animal sounds",
        "min_duration_min": 5,
        "typical_duration_h": (0.1, 1),
        "db_range": (55, 90),
        "variability": "high",
        "time_pattern": "anytime",
        "peak_pattern": "repeated_impulsive",
    },
    {
        "name": "alarm_siren",
        "label_de": "Alarm / Sirene",
        "label_en": "Alarm / Siren",
        "min_duration_min": 1,
        "typical_duration_h": (0.02, 0.5),
        "db_range": (70, 120),
        "variability": "low",
        "time_pattern": "anytime",
        "peak_pattern": "sustained_high",
    },
]


_CLASS_FAMILIES = {
    "speech": {
        "conversation",
        "conversation_dispute",
        "short_shout_or_call",
        "crowd",
        "loud_conversation",
        "shouting_or_dispute",
    },
    "music": {
        "music",
        "music_party",
        "party_or_music_with_people",
        "television_or_music",
    },
    "construction": {
        "construction",
        "construction_noise",
        "drilling",
        "hammering",
        "sawing",
        "construction_other",
    },
    "traffic": {"traffic", "traffic_noise", "road_traffic"},
    "mechanical": {
        "mechanical_hvac",
        "household_appliance",
        "sustained_noise",
    },
    "animal": {"animal", "animal_barking", "animals"},
    "impulsive": {
        "impulsive_noise",
        "glass_break",
        "forced_entry_impact",
        "furniture_movement",
        "footsteps_or_impact_noise",
        "door_or_impact",
    },
    "alert": {"alarm_siren", "siren"},
}

_FAMILY_MERGE_GAPS = {
    # Meetings and parties contain natural pauses. A merge remains a hypothesis
    # until review and never turns the pause into measured continuous noise.
    "speech": timedelta(minutes=15),
    "music": timedelta(minutes=15),
    "construction": timedelta(minutes=10),
    "mechanical": timedelta(minutes=10),
    "traffic": timedelta(minutes=5),
    "animal": timedelta(minutes=2),
    "alert": timedelta(minutes=2),
    "impulsive": timedelta(seconds=45),
    "continuous": timedelta(minutes=10),
    "unknown": timedelta(minutes=3),
}


@dataclass(frozen=True)
class EventEvidence:
    """Normalized evidence used for episode continuity decisions."""

    event: Event
    start: datetime
    end: datetime
    primary_class: str
    class_family: str
    confidence: float
    timing_basis: str
    source_duration_seconds: float


def _normalize_label(value: Optional[str]) -> str:
    return (value or "unknown_noise").strip().lower().replace(" ", "_")


def _class_family(label: str, segment_type: Optional[str] = None) -> str:
    normalized = _normalize_label(label)
    for family, labels in _CLASS_FAMILIES.items():
        if normalized in labels:
            return family
    if segment_type in {
        "sustained",
        "fluctuating",
        "continuous",
        "background_elevation",
    }:
        return "continuous"
    return "unknown"


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _parse_iso_datetime(value: Any) -> Optional[datetime]:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        return _as_utc(datetime.fromisoformat(value.replace("Z", "+00:00")))
    except ValueError:
        return None


def _source_segments(event: Event, class_family: str) -> List[tuple[datetime, datetime]]:
    metadata = event.event_metadata if isinstance(event.event_metadata, dict) else {}
    source_activity = metadata.get("source_activity")
    if not isinstance(source_activity, dict):
        return []
    raw_segments = source_activity.get("segments")
    if not isinstance(raw_segments, list):
        return []

    segments: List[tuple[datetime, datetime]] = []
    for raw_segment in raw_segments:
        if not isinstance(raw_segment, dict):
            continue
        category = _normalize_label(raw_segment.get("category"))
        segment_family = _class_family(category)
        if class_family != "unknown" and segment_family != class_family:
            continue
        start = _parse_iso_datetime(raw_segment.get("start"))
        end = _parse_iso_datetime(raw_segment.get("end"))
        if start is None or end is None or end <= start:
            continue
        if end - start > timedelta(hours=24):
            continue
        segments.append((start, end))
    return segments


def _union_duration_seconds(
    intervals: List[tuple[datetime, datetime]],
) -> float:
    if not intervals:
        return 0.0
    ordered = sorted(intervals, key=lambda interval: interval[0])
    total = 0.0
    current_start, current_end = ordered[0]
    for start, end in ordered[1:]:
        if start <= current_end:
            current_end = max(current_end, end)
            continue
        total += (current_end - current_start).total_seconds()
        current_start, current_end = start, end
    total += (current_end - current_start).total_seconds()
    return max(total, 0.0)


def _event_evidence(event: Event) -> EventEvidence:
    primary_class = _normalize_label(event.classification_label)
    class_family = _class_family(primary_class, event.segment_type)
    event_start = _as_utc(event.timestamp_start or event.created_at)
    event_end = _as_utc(event.timestamp_end or event.timestamp_start or event.created_at)
    if event_end < event_start:
        event_end = event_start

    segments = _source_segments(event, class_family)
    if segments:
        start = min(segment[0] for segment in segments)
        end = max(segment[1] for segment in segments)
        timing_basis = "source_activity_segments"
        source_duration_seconds = _union_duration_seconds(segments)
    else:
        start = event_start
        end = event_end
        timing_basis = "event_threshold_interval"
        source_duration_seconds = 0.0

    return EventEvidence(
        event=event,
        start=start,
        end=end,
        primary_class=primary_class,
        class_family=class_family,
        confidence=float(event.classification_confidence or 0.0),
        timing_basis=timing_basis,
        source_duration_seconds=source_duration_seconds,
    )


def _merge_gap_for_family(
    family: str,
    override_minutes: Optional[int] = None,
) -> timedelta:
    if override_minutes is not None:
        return timedelta(minutes=max(0, override_minutes))
    return _FAMILY_MERGE_GAPS.get(family, _FAMILY_MERGE_GAPS["unknown"])


def _can_merge(
    left: EventEvidence,
    right: EventEvidence,
    override_minutes: Optional[int] = None,
) -> bool:
    if left.class_family != right.class_family:
        return False
    if left.class_family == "unknown" and left.primary_class != right.primary_class:
        return False
    if right.end < left.start:
        gap = left.start - right.end
    elif right.start > left.end:
        gap = right.start - left.end
    else:
        gap = timedelta(0)
    return gap <= _merge_gap_for_family(
        right.class_family,
        override_minutes,
    )


def _dominant_class(evidence: List[EventEvidence]) -> str:
    weights: dict[str, float] = {}
    for item in evidence:
        duration = max((item.end - item.start).total_seconds(), 1.0)
        confidence = max(item.confidence, 0.1)
        weights[item.primary_class] = (
            weights.get(item.primary_class, 0.0) + duration * confidence
        )
    return max(weights, key=weights.get) if weights else "unknown_noise"


def _energy_average_leq(evidence: List[EventEvidence]) -> float:
    weighted_energy = 0.0
    total_duration = 0.0
    for item in evidence:
        if item.event.leq_db is None:
            continue
        duration = max(
            (
                _as_utc(item.event.timestamp_end or item.event.created_at)
                - _as_utc(item.event.timestamp_start or item.event.created_at)
            ).total_seconds(),
            1.0,
        )
        weighted_energy += duration * (10 ** (item.event.leq_db / 10.0))
        total_duration += duration
    if total_duration <= 0:
        return 0.0
    return 10.0 * log10(weighted_energy / total_duration)


def _continuity_metadata(evidence: List[EventEvidence]) -> dict:
    ordered = sorted(evidence, key=lambda item: item.start)
    gaps = []
    for previous, current in zip(ordered, ordered[1:]):
        gap_seconds = max((current.start - previous.end).total_seconds(), 0.0)
        if gap_seconds <= 0:
            continue
        gaps.append(
            {
                "start": previous.end.isoformat(),
                "end": current.start.isoformat(),
                "duration_seconds": round(gap_seconds, 1),
                "evidence_state": "no_threshold_event_or_source_segment",
            }
        )

    raw_intervals = [
        (
            _as_utc(item.event.timestamp_start or item.event.created_at),
            _as_utc(item.event.timestamp_end or item.event.created_at),
        )
        for item in ordered
    ]
    episode_span = max((ordered[-1].end - ordered[0].start).total_seconds(), 0.0)
    return {
        "merge_basis": "same_source_family_within_gap",
        "source_family": ordered[0].class_family,
        "continuous_noise_claimed": False,
        "episode_span_seconds": round(episode_span, 1),
        "observed_event_duration_seconds": round(
            _union_duration_seconds(raw_intervals),
            1,
        ),
        "source_activity_duration_seconds": round(
            sum(item.source_duration_seconds for item in ordered),
            1,
        ),
        "inter_event_gaps": gaps,
        "timing_bases": sorted({item.timing_basis for item in ordered}),
    }


async def _get_or_create_system_user(db: AsyncSession) -> User:
    stmt = select(User).where(User.email == "system@noisenet.internal")
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    if user:
        return user
    user = User(
        id=uuid4(),
        email="system@noisenet.internal",
        hashed_password=get_password_hash(uuid4().hex),
        full_name="System",
    )
    db.add(user)
    await db.flush()
    return user


async def _get_or_create_default_org(db: AsyncSession) -> Organization:
    stmt = select(Organization).where(Organization.slug == "public-anonymous")
    result = await db.execute(stmt)
    org = result.scalar_one_or_none()
    if org:
        return org
    sys_user = await _get_or_create_system_user(db)
    org = Organization(
        id=uuid4(),
        name="OpenNoiseNet Public",
        slug="public-anonymous",
        plan_tier="free",
        created_by_id=sys_user.id,
    )
    db.add(org)
    await db.flush()
    return org


async def _get_or_create_default_site(db: AsyncSession, org: Organization) -> Site:
    stmt = select(Site).where(
        Site.organization_id == org.id,
        Site.name == "Public Anonymous Site",
    )
    result = await db.execute(stmt)
    site = result.scalar_one_or_none()
    if site:
        return site
    site = Site(
        id=uuid4(), organization_id=org.id, name="Public Anonymous Site",
    )
    db.add(site)
    await db.flush()
    return site


def _classify_episode_pattern(
    events: List[Event],
    started_at: datetime,
    ended_at: datetime,
) -> Optional[dict]:
    if not events:
        return None

    duration_h = (ended_at - started_at).total_seconds() / 3600
    db_values = [e.leq_db for e in events if e.leq_db]
    peak_values = [e.lmax_db for e in events if e.lmax_db]
    # ── Loudness profile ─────────────────────────────────────────────────
    profile = _compute_loudness_profile(events)

    if not db_values:
        return CLASSIFICATION_RULES[0]

    avg_db = sum(db_values) / len(db_values)
    max_db = max(db_values)
    min_db = min(db_values)
    db_variability = max_db - min_db if len(db_values) > 1 else 0

    hour = started_at.hour
    is_night = hour >= 22 or hour < 6
    is_evening = 20 <= hour < 22
    peak_count = len(peak_values) if peak_values else 0
    event_density = len(events) / max(duration_h, 0.01)

    best_rule = None
    best_score = -1

    for rule in CLASSIFICATION_RULES:
        score = 0
        lo, hi = rule.get("db_range", (0, 200))
        if lo <= avg_db <= hi:
            score += 3
        elif abs(avg_db - (lo + hi) / 2) < 10:
            score += 1

        dur_lo, dur_hi = rule.get("typical_duration_h", (0, 100))
        if dur_lo <= duration_h <= dur_hi:
            score += 3
        elif duration_h >= rule.get("min_duration_min", 0) / 60:
            score += 1

        if is_night and rule["time_pattern"] in ("evening_night", "anytime"):
            score += 2
        elif is_evening and rule["time_pattern"] in ("evening_night", "anytime"):
            score += 1

        var = rule["variability"]
        if var == "very_low" and db_variability < 5:
            score += 2
        elif var == "low" and db_variability < 10:
            score += 2
        elif var == "medium" and 5 <= db_variability <= 20:
            score += 1
        elif var == "high" and db_variability > 15:
            score += 2

        peak = rule["peak_pattern"]
        if peak == "occasional_impacts" and peak_count > 0 and event_density < 60:
            score += 1
        elif peak == "intermittent_spikes" and peak_count > 0:
            score += 1
        elif peak == "irregular_spikes" and peak_count > 0 and db_variability > 10:
            score += 1
        elif peak == "none" and peak_count == 0:
            score += 1
        elif peak == "sustained_high" and max_db > 90:
            score += 1

        # ── Profile-based scoring ────────────────────────────────────────
        if profile:
            trend = profile.get("trend", "")
            silence = profile.get("silence_ratio_pct", 0)
            peak_density = profile.get("peak_density_per_min", 0)

            # Conversation has high silence ratio (natural pauses)
            if rule["name"] == "conversation_dispute" and silence > 20:
                score += 2
            # Mechanical has very low silence (always on)
            if rule["name"] == "mechanical_hvac" and silence < 5:
                score += 2
            # Construction has occasional impacts (medium peak density)
            if rule["name"] == "construction_noise" and 0.5 < peak_density < 5:
                score += 1
            # Traffic has intermittent spikes
            if rule["name"] == "traffic_noise" and peak_density > 3:
                score += 1
            # Alarm is sustained high
            if rule["name"] == "alarm_siren" and trend == "konstant" and silence < 5:
                score += 2
            # Music has rhythmic pattern (medium peak density + low silence)
            if rule["name"] == "music_party" and 1 < peak_density < 10 and silence < 10:
                score += 1

        if score > best_score:
            best_score = score
            best_rule = rule

    return best_rule


def _model_bundle_id(event: Event) -> Optional[str]:
    metadata = event.event_metadata if isinstance(event.event_metadata, dict) else {}
    value = metadata.get("model_bundle_id")
    return value if isinstance(value, str) and value else None


def _weighted_confidence(evidence: List[EventEvidence]) -> Optional[float]:
    weighted = 0.0
    total = 0.0
    for item in evidence:
        if item.confidence <= 0:
            continue
        duration = max((item.end - item.start).total_seconds(), 1.0)
        weighted += item.confidence * duration
        total += duration
    return weighted / total if total > 0 else None


async def _episode_events(db: AsyncSession, episode_id) -> List[Event]:
    result = await db.execute(
        select(Event)
        .where(Event.episode_id == episode_id)
        .order_by(Event.timestamp_start.asc())
    )
    return list(result.scalars().all())


async def _find_episode_candidate(
    db: AsyncSession,
    *,
    device_id,
    site_id,
    evidence: EventEvidence,
    merge_gap_minutes: Optional[int],
) -> Optional[Episode]:
    result = await db.execute(
        select(Episode)
        .where(
            Episode.device_id == device_id,
            Episode.site_id == site_id,
            Episode.review_state == EpisodeReviewState.PENDING_REVIEW.value,
            Episode.lifecycle_state != EpisodeLifecycleState.EXPORTED.value,
        )
        .order_by(Episode.ended_at.desc())
        .limit(10)
    )
    for episode in result.scalars().all():
        episode_family = episode.class_family or "unknown"
        if episode_family != evidence.class_family:
            continue
        if episode_family == "unknown" and episode.primary_class != evidence.primary_class:
            continue
        episode_start = _as_utc(episode.started_at)
        episode_end = _as_utc(episode.ended_at)
        if evidence.end < episode_start:
            gap = episode_start - evidence.end
        elif evidence.start > episode_end:
            gap = evidence.start - episode_end
        else:
            gap = timedelta(0)
        if gap <= _merge_gap_for_family(episode_family, merge_gap_minutes):
            return episode
    return None


def _apply_episode_evidence(
    episode: Episode,
    evidence: List[EventEvidence],
    *,
    merge_gap_minutes: Optional[int],
) -> None:
    ordered = sorted(evidence, key=lambda item: item.start)
    primary_class = _dominant_class(ordered)
    class_family = _class_family(primary_class, ordered[0].event.segment_type)
    avg_leq = _energy_average_leq(ordered)
    max_level = max(
        (
            item.event.lmax_db
            if item.event.lmax_db is not None
            else item.event.leq_db or 0.0
        )
        for item in ordered
    )
    continuity = _continuity_metadata(ordered)
    events = [item.event for item in ordered]
    existing_metadata = (
        dict(episode.review_metadata)
        if isinstance(episode.review_metadata, dict)
        else {}
    )

    episode.primary_class = primary_class
    episode.class_family = class_family
    episode.classification_confidence = _weighted_confidence(ordered)
    episode.severity = _compute_severity(avg_leq, max_level, ordered[0].start.hour)
    episode.nuisance_score = round(min(avg_leq * 1.5, 100), 1)
    episode.quiet_hours_triggered = (
        ordered[0].start.hour >= 22 or ordered[0].start.hour < 6
    )
    episode.started_at = ordered[0].start
    episode.ended_at = max(item.end for item in ordered)
    episode.event_count = len(ordered)
    episode.lifecycle_state = (
        EpisodeLifecycleState.EXTENDED.value
        if len(ordered) > 1
        else EpisodeLifecycleState.CLOSED.value
    )
    episode.model_bundle_id = next(
        (
            bundle
            for bundle in (_model_bundle_id(item.event) for item in ordered)
            if bundle
        ),
        None,
    )
    episode.review_metadata = {
        **existing_metadata,
        "detection_method": "source_aware_temporal_clustering_v2",
        "avg_leq_db": round(avg_leq, 1),
        "max_level_db": round(max_level, 1),
        "merge_gap_minutes": round(
            _merge_gap_for_family(class_family, merge_gap_minutes).total_seconds()
            / 60.0,
            2,
        ),
        "loudness_profile": _compute_loudness_profile(events),
        "classification": {
            "name": primary_class,
            "family": class_family,
            "source": "device_classification",
        },
        "continuity": continuity,
    }


async def sync_anonymous_event_to_episode(
    db: AsyncSession,
    event: Event,
    *,
    device: Optional[DeviceModel] = None,
    merge_gap_minutes: Optional[int] = None,
) -> tuple[Episode, bool]:
    """Attach one anonymous event to a source-aware episode immediately."""

    resolved_device = device or await db.get(DeviceModel, event.device_id)
    if resolved_device is None:
        raise ValueError("event device does not exist")

    org = await _get_or_create_default_org(db)
    site = await _get_or_create_default_site(db, org)
    evidence = _event_evidence(event)
    episode = await _find_episode_candidate(
        db,
        device_id=resolved_device.id,
        site_id=site.id,
        evidence=evidence,
        merge_gap_minutes=merge_gap_minutes,
    )
    created = episode is None
    if episode is None:
        episode = Episode(
            organization_id=org.id,
            site_id=site.id,
            device_id=resolved_device.id,
            primary_class=evidence.primary_class,
            class_family=evidence.class_family,
            severity="informational",
            nuisance_score=0.0,
            quiet_hours_triggered=False,
            evidence_mode=EvidenceMode.DERIVED_ONLY.value,
            review_state=EpisodeReviewState.PENDING_REVIEW.value,
            lifecycle_state=EpisodeLifecycleState.CLOSED.value,
            started_at=evidence.start,
            ended_at=evidence.end,
            event_count=1,
        )
        db.add(episode)
        await db.flush()
        existing_events: List[Event] = []
    else:
        existing_events = await _episode_events(db, episode.id)

    event.episode_id = episode.id
    combined_events = [*existing_events]
    if all(existing.id != event.id for existing in combined_events):
        combined_events.append(event)
    _apply_episode_evidence(
        episode,
        [_event_evidence(item) for item in combined_events],
        merge_gap_minutes=merge_gap_minutes,
    )
    await db.flush()
    return episode, created


async def detect_episodes_for_device(
    db: AsyncSession,
    device_id: str,
    *,
    merge_gap_minutes: Optional[int] = None,
    min_event_count: int = 1,
) -> List[Episode]:
    """Backfill all currently unassigned events for one public device ID."""

    result = await db.execute(
        select(DeviceModel).where(DeviceModel.device_id == device_id)
    )
    device = result.scalar_one_or_none()
    if not device:
        return []

    result = await db.execute(
        select(Event).where(
            Event.device_id == device.id,
            Event.episode_id.is_(None),
            Event.timestamp_start.isnot(None),
        )
    )
    events = list(result.scalars().all())
    evidence = sorted((_event_evidence(event) for event in events), key=lambda item: item.start)
    if len(evidence) < max(min_event_count, 1):
        return []

    created_episodes: List[Episode] = []
    for item in evidence:
        episode, created = await sync_anonymous_event_to_episode(
            db,
            item.event,
            device=device,
            merge_gap_minutes=merge_gap_minutes,
        )
        if created:
            created_episodes.append(episode)

    await db.flush()
    return created_episodes


def _pattern_to_family(rule: Optional[dict]) -> str:
    if not rule:
        return "unknown"
    name = rule["name"]
    if "conversation" in name or "dispute" in name:
        return "speech"
    if "construction" in name or "mechanical" in name:
        return "mechanical"
    if "traffic" in name:
        return "environmental"
    if "music" in name or "party" in name:
        return "music"
    if "barking" in name or "animal" in name:
        return "environmental"
    if "alarm" in name or "siren" in name:
        return "alert"
    return "unknown"


def _compute_severity(avg_db: float, max_db: float, hour: int) -> str:
    is_night = hour >= 22 or hour < 6
    if is_night:
        if avg_db > 65 or max_db > 85:
            return "critical"
        if avg_db > 55:
            return "high"
        if avg_db > 45:
            return "moderate"
    else:
        if avg_db > 80 or max_db > 100:
            return "critical"
        if avg_db > 65:
            return "high"
        if avg_db > 55:
            return "moderate"
    return "informational"


def _compute_loudness_profile(events: List[Event]) -> dict:
    """Compute detailed loudness profile for an episode.

    Returns statistics about the noise intensity distribution within the block:
    - quartiles (P25, P50, P75, P90)
    - trend (rising, falling, steady, fluctuating)
    - peak density (peaks per minute)
    - silence ratio (% of time below threshold)
    """
    ordered_events = sorted(
        [event for event in events if event.timestamp_start],
        key=lambda event: _as_utc(event.timestamp_start),
    )
    chronological_values = [
        event.leq_db for event in ordered_events if event.leq_db is not None
    ]
    db_values = sorted(chronological_values)
    if not db_values:
        return {}

    n = len(db_values)

    def percentile(p):
        idx = int(n * p / 100)
        return round(db_values[min(idx, n - 1)], 1)

    # Quartile analysis
    p25 = percentile(25)
    p50 = percentile(50)
    p75 = percentile(75)
    p90 = percentile(90)

    # Trend detection: compare first half vs second half
    half = n // 2
    first_half_avg = sum(chronological_values[:half]) / max(half, 1)
    second_half_avg = sum(chronological_values[half:]) / max(n - half, 1)

    if second_half_avg > first_half_avg * 1.1:
        trend = "steigend (wird lauter)"
    elif first_half_avg > second_half_avg * 1.1:
        trend = "fallend (wird leiser)"
    elif db_values[-1] - db_values[0] < 5:
        trend = "konstant"
    else:
        trend = "schwankend"

    # Peak density: events above P90 per minute
    timestamps = [_as_utc(event.timestamp_start) for event in ordered_events]
    if len(timestamps) >= 2:
        duration_min = max((timestamps[-1] - timestamps[0]).total_seconds() / 60, 0.1)
        peak_threshold = p90 if n >= 10 else p75
        peaks = [v for v in db_values if v >= peak_threshold]
        peak_density = round(len(peaks) / duration_min, 1)
    else:
        peak_density = 0.0

    # Silence ratio: % of values below typical background (45 dB)
    silent = sum(1 for v in db_values if v < 45)
    silence_ratio = round(silent / n * 100, 1)

    return {
        "p25_db": p25,
        "p50_db": p50,
        "p75_db": p75,
        "p90_db": p90,
        "trend": trend,
        "peak_density_per_min": peak_density,
        "silence_ratio_pct": silence_ratio,
        "sample_count": n,
    }
