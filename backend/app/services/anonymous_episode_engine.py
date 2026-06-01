"""Episode detection for anonymous/public events — no Pro context required."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional, List
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


async def detect_episodes_for_device(
    db: AsyncSession,
    device_id: str,
    *,
    merge_gap_minutes: int = 5,
    min_event_count: int = 2,
) -> List[Episode]:
    # Resolve string device_id to UUID
    stmt = select(DeviceModel).where(DeviceModel.device_id == device_id)
    result = await db.execute(stmt)
    dev = result.scalar_one_or_none()
    if not dev:
        return []
    device_uuid = dev.id

    # Get unassigned events
    stmt = (
        select(Event)
        .where(
            Event.device_id == device_uuid,
            Event.episode_id.is_(None),
            Event.timestamp_start.isnot(None),
        )
        .order_by(Event.timestamp_start.asc())
    )
    result = await db.execute(stmt)
    events: List[Event] = result.scalars().all()

    if len(events) < min_event_count:
        return []

    # Group events into temporal clusters
    clusters: List[List[Event]] = []
    current_cluster: List[Event] = [events[0]]

    for event in events[1:]:
        gap = (event.timestamp_start - current_cluster[-1].timestamp_end).total_seconds()
        if gap <= merge_gap_minutes * 60:
            current_cluster.append(event)
        else:
            clusters.append(current_cluster)
            current_cluster = [event]
    clusters.append(current_cluster)

    # Resolve default org+site for anonymous episodes
    org = await _get_or_create_default_org(db)
    site = await _get_or_create_default_site(db, org)

    episodes: List[Episode] = []
    for cluster in clusters:
        if len(cluster) < min_event_count:
            continue

        started_at = min(e.timestamp_start for e in cluster)
        ended_at = max(e.timestamp_end or e.timestamp_start for e in cluster)
        avg_leq = sum(e.leq_db for e in cluster if e.leq_db) / len(cluster)
        max_leq = max(e.leq_db for e in cluster if e.leq_db)
        best_rule = _classify_episode_pattern(cluster, started_at, ended_at)

        episode = Episode(
            organization_id=org.id,
            site_id=site.id,
            primary_class=best_rule["name"] if best_rule else "unknown_noise",
            class_family=_pattern_to_family(best_rule),
            classification_confidence=0.7 if best_rule else 0.3,
            severity=_compute_severity(avg_leq, max_leq, started_at.hour),
            nuisance_score=round(min(avg_leq * 1.5, 100), 1),
            quiet_hours_triggered=started_at.hour >= 22 or started_at.hour < 6,
            review_state=EpisodeReviewState.PENDING_REVIEW.value,
            lifecycle_state=EpisodeLifecycleState.CLOSED.value,
            started_at=started_at,
            ended_at=ended_at,
            event_count=len(cluster),
            review_metadata={
                "detection_method": "temporal_clustering",
                "avg_leq_db": round(avg_leq, 1),
                "max_leq_db": round(max_leq, 1),
                "merge_gap_minutes": merge_gap_minutes,
                "loudness_profile": _compute_loudness_profile(cluster),
                "classification": best_rule,
            },
        )
        db.add(episode)
        await db.flush()

        for event in cluster:
            event.episode_id = episode.id
            db.add(event)

        episodes.append(episode)

    await db.flush()
    return episodes


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
    db_values = sorted([e.leq_db for e in events if e.leq_db])
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
    first_half_avg = sum(db_values[:half]) / max(half, 1)
    second_half_avg = sum(db_values[half:]) / max(n - half, 1)

    if second_half_avg > first_half_avg * 1.1:
        trend = "steigend (wird lauter)"
    elif first_half_avg > second_half_avg * 1.1:
        trend = "fallend (wird leiser)"
    elif db_values[-1] - db_values[0] < 5:
        trend = "konstant"
    else:
        trend = "schwankend"

    # Peak density: events above P90 per minute
    timestamps = [e.timestamp_start for e in events if e.timestamp_start]
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