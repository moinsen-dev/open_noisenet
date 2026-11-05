"""Commercial episode engine built on top of ingested events."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device
from app.db.models.event import Event
from app.db.models.pro_domain import (
    Episode,
    EpisodeLifecycleState,
    EpisodeReviewState,
    EpisodeSeverity,
    EvidenceMode,
    Policy,
    Site,
    Zone,
)


@dataclass(frozen=True)
class EpisodePolicyContext:
    """Resolved policy inputs used for scoring and evidence decisions."""

    policy_id: Optional[uuid.UUID]
    evidence_mode: str
    day_threshold_db: float
    night_threshold_db: float
    quiet_hours_start: Optional[str]
    quiet_hours_end: Optional[str]


async def sync_event_to_episode(
    db: AsyncSession,
    event: Event,
) -> Optional[Episode]:
    """Create or extend a commercial episode for one event when Pro context exists."""

    device = await db.get(Device, event.device_id)
    if not device or not device.site_id:
        return None

    site = await db.get(Site, device.site_id)
    if not site:
        return None

    zone = await db.get(Zone, device.zone_id) if device.zone_id else None
    policy = await _resolve_policy_context(
        db,
        organization_id=site.organization_id,
        site_id=site.id,
        zone_id=zone.id if zone else None,
    )

    quiet_hours = _is_quiet_hours(
        _as_utc(event.timestamp_start or event.created_at),
        site.timezone,
        policy.quiet_hours_start or (zone.quiet_hours_start if zone else None),
        policy.quiet_hours_end or (zone.quiet_hours_end if zone else None),
    )
    severity_score = await _calculate_nuisance_score(
        db,
        site_id=site.id,
        primary_class=_normalized_class_label(event.classification_label),
        event=event,
        quiet_hours=quiet_hours,
        policy=policy,
    )
    severity = _severity_from_score(severity_score)
    primary_class = _normalized_class_label(event.classification_label)
    class_family = _class_family(primary_class, event.segment_type)
    effective_confidence = event.classification_confidence or 0.0
    if effective_confidence < 0.5:
        primary_class = "unknown_noise"
        class_family = "unknown"

    merge_candidate = await _find_merge_candidate(
        db,
        site_id=site.id,
        zone_id=zone.id if zone else None,
        device_id=device.id,
        primary_class=primary_class,
        class_family=class_family,
        event_start=_as_utc(event.timestamp_start or event.created_at),
        gap=_merge_gap(event.segment_type, class_family),
    )

    if merge_candidate:
        previous_started_at = _as_utc(merge_candidate.started_at)
        previous_ended_at = _as_utc(merge_candidate.ended_at)
        previous_event_count = merge_candidate.event_count
        merge_candidate.ended_at = max(
            previous_ended_at,
            _as_utc(event.timestamp_end or event.created_at),
        )
        merge_candidate.started_at = min(
            previous_started_at,
            _as_utc(event.timestamp_start or event.created_at),
        )
        merge_candidate.event_count += 1
        merge_candidate.nuisance_score = round(
            max(merge_candidate.nuisance_score, severity_score), 2
        )
        merge_candidate.severity = _max_severity(merge_candidate.severity, severity)
        merge_candidate.classification_confidence = max(
            merge_candidate.classification_confidence or 0.0,
            effective_confidence,
        )
        merge_candidate.quiet_hours_triggered = (
            merge_candidate.quiet_hours_triggered or quiet_hours
        )
        merge_candidate.review_metadata = _extended_continuity_metadata(
            merge_candidate,
            event,
            previous_started_at=previous_started_at,
            previous_ended_at=previous_ended_at,
            previous_event_count=previous_event_count,
        )
        merge_candidate.lifecycle_state = EpisodeLifecycleState.EXTENDED.value
        event.episode_id = merge_candidate.id
        return merge_candidate

    episode = Episode(
        organization_id=site.organization_id,
        site_id=site.id,
        zone_id=zone.id if zone else None,
        device_id=device.id,
        policy_id=policy.policy_id,
        primary_class=primary_class,
        class_family=class_family,
        classification_confidence=effective_confidence or None,
        severity=severity,
        nuisance_score=round(severity_score, 2),
        quiet_hours_triggered=quiet_hours,
        evidence_mode=policy.evidence_mode,
        review_state=EpisodeReviewState.PENDING_REVIEW.value,
        lifecycle_state=EpisodeLifecycleState.CLOSED.value,
        started_at=_as_utc(event.timestamp_start or event.created_at),
        ended_at=_as_utc(event.timestamp_end or event.created_at),
        event_count=1,
        review_metadata=_initial_continuity_metadata(event),
        model_bundle_id=_model_bundle_id_from_event(event),
    )
    db.add(episode)
    await db.flush()
    event.episode_id = episode.id
    return episode


async def _resolve_policy_context(
    db: AsyncSession,
    *,
    organization_id,
    site_id,
    zone_id,
) -> EpisodePolicyContext:
    stmt = (
        select(Policy)
        .where(Policy.is_active.is_(True))
        .where(
            (Policy.zone_id == zone_id)
            | (Policy.site_id == site_id)
            | (Policy.organization_id == organization_id)
        )
        .order_by(
            Policy.zone_id.is_(None),
            Policy.site_id.is_(None),
            Policy.organization_id.is_(None),
            Policy.created_at.desc(),
        )
    )
    result = await db.execute(stmt)
    policy = result.scalars().first()
    if not policy:
        return EpisodePolicyContext(
            policy_id=None,
            evidence_mode=EvidenceMode.DERIVED_ONLY.value,
            day_threshold_db=65.0,
            night_threshold_db=55.0,
            quiet_hours_start=None,
            quiet_hours_end=None,
        )

    return EpisodePolicyContext(
            policy_id=policy.id,
        evidence_mode=policy.evidence_mode,
        day_threshold_db=policy.day_threshold_db or 65.0,
        night_threshold_db=policy.night_threshold_db or 55.0,
        quiet_hours_start=policy.quiet_hours_start,
        quiet_hours_end=policy.quiet_hours_end,
    )


async def _calculate_nuisance_score(
    db: AsyncSession,
    *,
    site_id,
    primary_class: str,
    event: Event,
    quiet_hours: bool,
    policy: EpisodePolicyContext,
) -> float:
    threshold = policy.night_threshold_db if quiet_hours else policy.day_threshold_db
    loudness_score = _normalize(max((event.leq_db or 0.0) - threshold, 0.0), 20.0)
    duration_seconds = max(
        (
            _as_utc(event.timestamp_end or event.created_at)
            - _as_utc(event.timestamp_start or event.created_at)
        ).total_seconds(),
        0.0,
    )
    duration_score = _normalize(duration_seconds, 600.0)
    quiet_hours_score = 1.0 if quiet_hours else 0.0

    repetition_stmt = select(func.count(Episode.id)).where(
        Episode.site_id == site_id,
        Episode.primary_class == primary_class,
        Episode.started_at
        >= _as_utc(event.timestamp_start or event.created_at) - timedelta(days=7),
    )
    repetition_result = await db.execute(repetition_stmt)
    repetition_count = repetition_result.scalar_one() or 0
    repetition_score = _normalize(float(repetition_count), 5.0)

    class_impact_score = _class_impact(primary_class)
    raw_score = (
        (0.30 * loudness_score)
        + (0.25 * duration_score)
        + (0.20 * quiet_hours_score)
        + (0.15 * repetition_score)
        + (0.10 * class_impact_score)
    )
    return max(0.0, min(raw_score * 100.0, 100.0))


async def _find_merge_candidate(
    db: AsyncSession,
    *,
    site_id,
    zone_id,
    device_id,
    primary_class: str,
    class_family: str,
    event_start: datetime,
    gap: timedelta,
) -> Optional[Episode]:
    stmt = (
        select(Episode)
        .where(Episode.site_id == site_id, Episode.device_id == device_id)
        .where(Episode.ended_at >= event_start - gap)
        .where(Episode.lifecycle_state != EpisodeLifecycleState.EXPORTED.value)
        .order_by(Episode.ended_at.desc())
        .limit(5)
    )
    if zone_id:
        stmt = stmt.where(Episode.zone_id == zone_id)
    else:
        stmt = stmt.where(Episode.zone_id.is_(None))

    result = await db.execute(stmt)
    for episode in result.scalars().all():
        if episode.primary_class == primary_class:
            return episode
        if episode.class_family and class_family and episode.class_family == class_family:
            return episode
    return None


def _normalized_class_label(label: Optional[str]) -> str:
    return (label or "unknown_noise").strip().lower().replace(" ", "_")


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _event_duration_seconds(event: Event) -> float:
    start = _as_utc(event.timestamp_start or event.created_at)
    end = _as_utc(event.timestamp_end or event.created_at)
    return max((end - start).total_seconds(), 0.0)


def _initial_continuity_metadata(event: Event) -> dict:
    duration = _event_duration_seconds(event)
    return {
        "detection_method": "incremental_source_family_v2",
        "avg_leq_db": round(event.leq_db or 0.0, 1),
        "max_level_db": round(event.lmax_db or event.leq_db or 0.0, 1),
        "continuity": {
            "merge_basis": "single_event",
            "continuous_noise_claimed": False,
            "episode_span_seconds": round(duration, 1),
            "observed_event_duration_seconds": round(duration, 1),
            "inter_event_gaps": [],
            "timing_bases": ["event_threshold_interval"],
        },
    }


def _extended_continuity_metadata(
    episode: Episode,
    event: Event,
    *,
    previous_started_at: datetime,
    previous_ended_at: datetime,
    previous_event_count: int,
) -> dict:
    metadata = dict(episode.review_metadata or {})
    continuity = dict(metadata.get("continuity") or {})
    gaps = list(continuity.get("inter_event_gaps") or [])
    event_start = _as_utc(event.timestamp_start or event.created_at)
    event_end = _as_utc(event.timestamp_end or event.created_at)
    gap_seconds = max((event_start - previous_ended_at).total_seconds(), 0.0)
    if gap_seconds > 0:
        gaps.append(
            {
                "start": previous_ended_at.isoformat(),
                "end": event_start.isoformat(),
                "duration_seconds": round(gap_seconds, 1),
                "evidence_state": "no_threshold_event",
            }
        )

    previous_observed = float(
        continuity.get("observed_event_duration_seconds") or 0.0
    )
    previous_avg = float(metadata.get("avg_leq_db") or 0.0)
    event_count = previous_event_count + 1
    metadata.update(
        {
            "detection_method": "incremental_source_family_v2",
            "avg_leq_db": round(
                ((previous_avg * previous_event_count) + (event.leq_db or 0.0))
                / event_count,
                1,
            ),
            "max_level_db": round(
                max(
                    float(metadata.get("max_level_db") or 0.0),
                    event.lmax_db or event.leq_db or 0.0,
                ),
                1,
            ),
            "continuity": {
                **continuity,
                "merge_basis": "same_source_family_within_gap",
                "continuous_noise_claimed": False,
                "episode_span_seconds": round(
                    (max(previous_ended_at, event_end) - min(previous_started_at, event_start)).total_seconds(),
                    1,
                ),
                "observed_event_duration_seconds": round(
                    previous_observed + _event_duration_seconds(event),
                    1,
                ),
                "inter_event_gaps": gaps,
                "timing_bases": ["event_threshold_interval"],
            },
        }
    )
    return metadata


def _class_family(primary_class: str, segment_type: Optional[str]) -> str:
    if primary_class in {
        "conversation",
        "short_shout_or_call",
        "crowd",
        "loud_conversation",
        "shouting_or_dispute",
    }:
        return "speech"
    if primary_class in {
        "traffic",
        "construction",
        "music",
        "siren",
        "animal",
        "party_or_music_with_people",
        "television_or_music",
        "drilling",
        "hammering",
        "sawing",
        "construction_other",
        "household_appliance",
        "road_traffic",
        "animals",
    }:
        return "environmental"
    if primary_class in {
        "impulsive_noise",
        "glass_break",
        "forced_entry_impact",
        "furniture_movement",
        "footsteps_or_impact_noise",
        "door_or_impact",
    }:
        return "impulsive"
    if segment_type in {
        "sustained",
        "fluctuating",
        "continuous",
        "background_elevation",
    }:
        return "continuous"
    return "unknown"


def _merge_gap(segment_type: Optional[str], class_family: str) -> timedelta:
    if class_family == "speech":
        return timedelta(minutes=15)
    if class_family == "impulsive":
        return timedelta(seconds=45)
    if segment_type in {
        "sustained",
        "fluctuating",
        "continuous",
        "background_elevation",
    } or class_family == "continuous":
        return timedelta(minutes=10)
    return timedelta(minutes=3)


def _is_quiet_hours(
    moment: datetime,
    timezone_name: str,
    quiet_start: Optional[str],
    quiet_end: Optional[str],
) -> bool:
    if not quiet_start or not quiet_end:
        return False
    local_time = moment.astimezone(ZoneInfo(timezone_name or "UTC")).time()
    start_hour, start_minute = [int(part) for part in quiet_start.split(":")]
    end_hour, end_minute = [int(part) for part in quiet_end.split(":")]
    start_minutes = (start_hour * 60) + start_minute
    end_minutes = (end_hour * 60) + end_minute
    current_minutes = (local_time.hour * 60) + local_time.minute

    if start_minutes == end_minutes:
        return True
    if start_minutes < end_minutes:
        return start_minutes <= current_minutes < end_minutes
    return current_minutes >= start_minutes or current_minutes < end_minutes


def _severity_from_score(score: float) -> str:
    if score >= 85:
        return EpisodeSeverity.CRITICAL.value
    if score >= 70:
        return EpisodeSeverity.HIGH.value
    if score >= 50:
        return EpisodeSeverity.MEDIUM.value
    if score >= 25:
        return EpisodeSeverity.LOW.value
    return EpisodeSeverity.INFORMATIONAL.value


def _max_severity(left: str, right: str) -> str:
    ordering = {
        EpisodeSeverity.INFORMATIONAL.value: 0,
        EpisodeSeverity.LOW.value: 1,
        EpisodeSeverity.MEDIUM.value: 2,
        EpisodeSeverity.HIGH.value: 3,
        EpisodeSeverity.CRITICAL.value: 4,
    }
    return left if ordering.get(left, 0) >= ordering.get(right, 0) else right


def _class_impact(primary_class: str) -> float:
    impact_map = {
        "conversation": 0.40,
        "short_shout_or_call": 0.72,
        "crowd": 0.68,
        "traffic": 0.62,
        "construction": 0.78,
        "music": 0.58,
        "siren": 0.85,
        "animal": 0.46,
        "sustained_noise": 0.72,
        "impulsive_noise": 0.80,
        "mixed_noise_event": 0.67,
        "unclassified_noise_event": 0.30,
        "unknown_noise": 0.22,
        "loud_conversation": 0.45,
        "shouting_or_dispute": 0.75,
        "party_or_music_with_people": 0.72,
        "television_or_music": 0.58,
        "drilling": 0.82,
        "hammering": 0.84,
        "sawing": 0.80,
        "construction_other": 0.78,
        "furniture_movement": 0.66,
        "footsteps_or_impact_noise": 0.62,
        "door_or_impact": 0.72,
        "household_appliance": 0.52,
        "road_traffic": 0.62,
        "animals": 0.46,
        "unknown_sound_source": 0.22,
    }
    return impact_map.get(primary_class, 0.30)


def _normalize(value: float, max_value: float) -> float:
    if max_value <= 0:
        return 0.0
    return max(0.0, min(value / max_value, 1.0))


def _model_bundle_id_from_event(event: Event) -> Optional[str]:
    metadata = event.event_metadata or {}
    bundle = metadata.get("model_bundle_id")
    if isinstance(bundle, str):
        return bundle
    return None
