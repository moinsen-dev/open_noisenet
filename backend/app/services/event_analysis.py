"""Server-side event analysis helpers."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

from app.schemas.event import EventCreate


@dataclass(frozen=True)
class EventAnalysisResult:
    """Normalized analysis fields stored on the event."""

    analysis_state: str
    classification_label: Optional[str]
    classification_confidence: Optional[float]
    classification_source: Optional[str]
    segment_type: Optional[str]
    reportability_score: Optional[float]
    reportability_reason: Optional[str]
    peak_to_average_delta_db: Optional[float]
    variability_db: Optional[float]
    threshold_exceedance_ratio: Optional[float]
    analysis_updated_at: datetime

    def as_dict(self) -> dict:
        return {
            "analysis_state": self.analysis_state,
            "classification_label": self.classification_label,
            "classification_confidence": self.classification_confidence,
            "classification_source": self.classification_source,
            "segment_type": self.segment_type,
            "reportability_score": self.reportability_score,
            "reportability_reason": self.reportability_reason,
            "peak_to_average_delta_db": self.peak_to_average_delta_db,
            "variability_db": self.variability_db,
            "threshold_exceedance_ratio": self.threshold_exceedance_ratio,
            "analysis_updated_at": self.analysis_updated_at,
        }


def derive_event_analysis(event_data: EventCreate) -> EventAnalysisResult:
    """Normalize device-provided analysis or derive a server fallback."""
    analyzed_at = datetime.now(timezone.utc)
    fallback = _derive_server_rule_classification(event_data)
    has_device_analysis = any(
        value is not None
        for value in (
            event_data.classification_label,
            event_data.classification_confidence,
            event_data.classification_source,
            event_data.segment_type,
            event_data.reportability_score,
            event_data.reportability_reason,
            event_data.peak_to_average_delta_db,
            event_data.variability_db,
            event_data.threshold_exceedance_ratio,
        )
    )

    if has_device_analysis:
        return EventAnalysisResult(
            analysis_state="classified_on_device",
            classification_label=_coalesce(
                event_data.classification_label,
                fallback["classification_label"],
            ),
            classification_confidence=_coalesce(
                _clamp_unit_interval(event_data.classification_confidence),
                fallback["classification_confidence"],
            ),
            classification_source=event_data.classification_source
            or "device_rule_engine",
            segment_type=_coalesce(event_data.segment_type, fallback["segment_type"]),
            reportability_score=_coalesce(
                _clamp_unit_interval(event_data.reportability_score),
                fallback["reportability_score"],
            ),
            reportability_reason=_coalesce(
                event_data.reportability_reason,
                fallback["reportability_reason"],
            ),
            peak_to_average_delta_db=_coalesce(
                event_data.peak_to_average_delta_db,
                fallback["peak_to_average_delta_db"],
            ),
            variability_db=_coalesce(
                event_data.variability_db,
                fallback["variability_db"],
            ),
            threshold_exceedance_ratio=_coalesce(
                _clamp_unit_interval(event_data.threshold_exceedance_ratio),
                fallback["threshold_exceedance_ratio"],
            ),
            analysis_updated_at=analyzed_at,
        )

    return EventAnalysisResult(
        analysis_state="server_classified",
        classification_label=fallback["classification_label"],
        classification_confidence=fallback["classification_confidence"],
        classification_source="server_rule_engine",
        segment_type=fallback["segment_type"],
        reportability_score=fallback["reportability_score"],
        reportability_reason=fallback["reportability_reason"],
        peak_to_average_delta_db=fallback["peak_to_average_delta_db"],
        variability_db=fallback["variability_db"],
        threshold_exceedance_ratio=fallback["threshold_exceedance_ratio"],
        analysis_updated_at=analyzed_at,
    )


def _derive_server_rule_classification(event_data: EventCreate) -> dict:
    duration_seconds = max(
        (event_data.timestamp_end - event_data.timestamp_start).total_seconds(),
        0.0,
    )
    peak_to_average_delta = _optional_subtract(event_data.lmax_db, event_data.leq_db)
    variability_db = _optional_subtract(event_data.lmax_db, event_data.lmin_db)
    threshold_ratio = _clamp_unit_interval(
        None
        if event_data.exceedance_pct is None
        else event_data.exceedance_pct / 100.0
    )

    if duration_seconds >= 120 and (threshold_ratio or 0.0) >= 0.65:
        classification_label = "sustained_noise"
        segment_type = "sustained"
        reportability_reason = (
            "Sustained event exceeded the threshold for most of its duration."
        )
    elif duration_seconds <= 20 and (peak_to_average_delta or 0.0) >= 10.0:
        classification_label = "impulsive_noise"
        segment_type = "impulsive"
        reportability_reason = "Short event with a large peak-to-average delta."
    elif (variability_db or 0.0) >= 15.0:
        classification_label = "mixed_noise_event"
        segment_type = "fluctuating"
        reportability_reason = "High variability suggests a mixed or intermittent source."
    else:
        classification_label = "unclassified_noise_event"
        segment_type = "boundary"
        reportability_reason = "Baseline server-side classification without device semantics."

    intensity_score = _normalize_range(event_data.leq_db, baseline=55.0, span=25.0)
    duration_score = min(duration_seconds / 180.0, 1.0)
    threshold_score = threshold_ratio or 0.0
    peak_score = _normalize_range(peak_to_average_delta, baseline=3.0, span=12.0)
    reportability_score = round(
        (0.35 * duration_score)
        + (0.30 * threshold_score)
        + (0.20 * intensity_score)
        + (0.15 * peak_score),
        3,
    )

    confidence = round(
        min(
            0.45
            + (0.30 * threshold_score)
            + (0.15 * duration_score)
            + (0.10 * peak_score),
            0.92,
        ),
        3,
    )

    return {
        "classification_label": classification_label,
        "classification_confidence": confidence,
        "segment_type": segment_type,
        "reportability_score": reportability_score,
        "reportability_reason": reportability_reason,
        "peak_to_average_delta_db": peak_to_average_delta,
        "variability_db": variability_db,
        "threshold_exceedance_ratio": threshold_ratio,
    }


def _optional_subtract(left: Optional[float], right: Optional[float]) -> Optional[float]:
    if left is None or right is None:
        return None
    return round(left - right, 3)


def _normalize_range(
    value: Optional[float], *, baseline: float, span: float
) -> float:
    if value is None:
        return 0.0
    return _clamp_unit_interval((value - baseline) / span) or 0.0


def _clamp_unit_interval(value: Optional[float]) -> Optional[float]:
    if value is None:
        return None
    if value < 0:
        return 0.0
    if value > 1:
        return 1.0
    return round(value, 3)


def _coalesce(primary, fallback):
    return primary if primary is not None else fallback
