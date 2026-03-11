"""
Celery tasks for AI-powered noise analysis.
"""

import asyncio
from datetime import datetime
from typing import Dict, Any, List, Optional
import json
import logging

from app.workers.celery_app import celery_app
from app.workers.noise_processing_tasks import AsyncTask
from app.core.logging import get_logger
from app.db.session import async_session

logger = get_logger(__name__)


@celery_app.task(bind=True, base=AsyncTask, name="analyze_noise_event")
async def analyze_noise_event(self, device_id: str, event_data: Dict[str, Any]):
    """
    Analyze a noise event using AI classification.

    Args:
        device_id: ID of the device that detected the event
        event_data: Event data including SPL levels, duration, etc.
    """
    try:
        logger.info(f"Starting AI analysis for noise event from device {device_id}")

        # Extract event details
        event_id = event_data.get("event_id")
        start_time = datetime.fromisoformat(event_data.get("start_time"))
        peak_level_db = event_data.get("peak_level_db", 0.0)
        average_level_db = event_data.get("average_level_db", 0.0)
        duration_seconds = event_data.get("duration_seconds", 0.0)
        rule_triggered = event_data.get("rule_triggered", "unknown")
        location = event_data.get("location", {})

        # Determine time of day for context
        hour = start_time.hour
        if 6 <= hour < 12:
            time_of_day = "morning"
        elif 12 <= hour < 18:
            time_of_day = "afternoon"
        elif 18 <= hour < 22:
            time_of_day = "evening"
        else:
            time_of_day = "night"

        # Prepare analysis context
        analysis_context = {
            "peak_level_db": peak_level_db,
            "average_level_db": average_level_db,
            "duration_seconds": duration_seconds,
            "time_of_day": time_of_day,
            "rule_triggered": rule_triggered,
            "location_type": _classify_location_type(location),
            "weekday": start_time.weekday() < 5,
        }

        # Perform AI classification
        classification_result = await _classify_noise_event(analysis_context)

        # Generate detailed analysis
        detailed_analysis = await _generate_detailed_analysis(
            classification_result, analysis_context
        )

        # Calculate confidence and quality scores
        confidence_score = _calculate_confidence_score(
            classification_result, analysis_context
        )

        # Prepare final result
        ai_analysis_result = {
            "event_id": event_id,
            "device_id": device_id,
            "analysis_timestamp": datetime.utcnow().isoformat(),
            "classification": classification_result,
            "detailed_analysis": detailed_analysis,
            "confidence_score": confidence_score,
            "context": analysis_context,
            "recommendations": _generate_recommendations(
                classification_result, analysis_context
            ),
        }

        # Store AI analysis result
        async with async_session() as db:
            # This would save to ai_analysis_results table
            pass

        # Trigger follow-up actions based on classification
        await _trigger_follow_up_actions(device_id, ai_analysis_result)

        logger.info(
            f"AI analysis completed for event {event_id}: {classification_result['primary_category']}"
        )

        return ai_analysis_result

    except Exception as e:
        logger.error(f"Error in AI noise event analysis for device {device_id}: {e}")
        self.retry(countdown=120, max_retries=2)


async def _classify_noise_event(context: Dict[str, Any]) -> Dict[str, Any]:
    """
    Classify noise event using rule-based AI (placeholder for actual AI model).
    In production, this would use the mobile app's AI classification results
    or run server-side AI models.
    """

    peak_db = context["peak_level_db"]
    duration = context["duration_seconds"]
    time_of_day = context["time_of_day"]
    location_type = context["location_type"]

    # Rule-based classification logic
    primary_category = "unknown"
    secondary_categories = []
    confidence = 0.5

    # Traffic noise detection
    if (
        65 <= peak_db <= 85
        and duration > 300
        and location_type in ["urban", "suburban"]
    ):
        primary_category = "traffic_noise"
        confidence = 0.8
        if time_of_day in ["morning", "evening"]:
            secondary_categories.append("rush_hour_traffic")

    # Construction activity
    elif (
        peak_db > 70 and time_of_day in ["morning", "afternoon"] and context["weekday"]
    ):
        if duration > 600:  # Sustained construction
            primary_category = "construction_activity"
            secondary_categories.append("heavy_machinery")
            confidence = 0.85
        elif duration < 120:  # Brief construction sounds
            primary_category = "construction_activity"
            secondary_categories.append("impulsive_construction")
            confidence = 0.75

    # Aircraft noise
    elif 75 <= peak_db <= 95 and 30 <= duration <= 180:
        primary_category = "aircraft_noise"
        confidence = 0.7
        if location_type == "near_airport":
            confidence = 0.9
            secondary_categories.append("commercial_aircraft")

    # Industrial noise
    elif peak_db > 70 and duration > 900 and location_type == "industrial":
        primary_category = "industrial_noise"
        secondary_categories.append("continuous_machinery")
        confidence = 0.8

    # Human activity / events
    elif 60 <= peak_db <= 80 and time_of_day == "evening":
        primary_category = "human_activity"
        if duration > 3600:  # Long event
            secondary_categories.append("outdoor_event")
        else:
            secondary_categories.append("social_gathering")
        confidence = 0.6

    # Emergency vehicles
    elif peak_db > 85 and duration < 300:
        primary_category = "emergency_vehicle"
        secondary_categories.append("siren")
        confidence = 0.75

    # Natural sounds (low confidence without audio analysis)
    elif peak_db < 60 and time_of_day in ["morning", "evening"]:
        primary_category = "natural_sounds"
        secondary_categories.append("ambient_environment")
        confidence = 0.4

    # HVAC / Building systems
    elif 45 <= peak_db <= 65 and duration > 1800:
        primary_category = "building_systems"
        secondary_categories.append("hvac")
        confidence = 0.6

    return {
        "primary_category": primary_category,
        "secondary_categories": secondary_categories,
        "confidence": confidence,
        "acoustic_features": _extract_acoustic_features(context),
        "environmental_factors": _analyze_environmental_factors(context),
    }


def _classify_location_type(location: Dict[str, Any]) -> str:
    """Classify location type based on coordinates and metadata."""
    # This would use GIS data to classify location
    # For now, return a placeholder
    return location.get("type", "urban")


def _extract_acoustic_features(context: Dict[str, Any]) -> List[str]:
    """Extract acoustic features from measurement context."""
    features = []

    peak_db = context["peak_level_db"]
    average_db = context["average_level_db"]
    duration = context["duration_seconds"]

    # Level characteristics
    if peak_db - average_db > 10:
        features.append("high_peak_to_average_ratio")
    elif peak_db - average_db < 3:
        features.append("steady_level")

    # Duration characteristics
    if duration < 30:
        features.append("brief_event")
    elif duration > 1800:
        features.append("sustained_event")
    else:
        features.append("moderate_duration")

    # Level ranges
    if peak_db > 85:
        features.append("very_loud")
    elif peak_db > 70:
        features.append("loud")
    elif peak_db < 50:
        features.append("quiet")

    return features


def _analyze_environmental_factors(context: Dict[str, Any]) -> Dict[str, Any]:
    """Analyze environmental factors affecting the noise event."""
    return {
        "time_category": context["time_of_day"],
        "day_type": "weekday" if context["weekday"] else "weekend",
        "location_category": context["location_type"],
        "regulatory_period": _get_regulatory_period(context["time_of_day"]),
    }


def _get_regulatory_period(time_of_day: str) -> str:
    """Get regulatory time period for noise limits."""
    if time_of_day in ["morning", "afternoon"]:
        return "day"
    elif time_of_day == "evening":
        return "evening"
    else:
        return "night"


async def _generate_detailed_analysis(
    classification: Dict[str, Any], context: Dict[str, Any]
) -> Dict[str, Any]:
    """Generate detailed analysis report."""

    primary_category = classification["primary_category"]
    confidence = classification["confidence"]
    peak_db = context["peak_level_db"]
    duration = context["duration_seconds"]

    # Health impact assessment
    health_impact = "minimal"
    if peak_db > 85:
        health_impact = "high"
    elif peak_db > 70:
        health_impact = "moderate"
    elif peak_db > 55:
        health_impact = "low"

    # Regulatory compliance assessment
    regulatory_period = _get_regulatory_period(context["time_of_day"])
    who_limits = {"day": 55, "evening": 50, "night": 40}
    limit = who_limits.get(regulatory_period, 55)

    compliance_status = (
        "compliant" if context["average_level_db"] <= limit else "violation"
    )
    exceedance_db = max(0, context["average_level_db"] - limit)

    # Impact assessment
    impact_score = min(10, (peak_db - 40) / 5)  # Scale 0-10

    return {
        "health_impact": health_impact,
        "compliance": {
            "status": compliance_status,
            "applicable_limit_db": limit,
            "exceedance_db": exceedance_db,
            "regulatory_period": regulatory_period,
        },
        "impact_assessment": {
            "impact_score": impact_score,
            "annoyance_potential": "high"
            if impact_score > 7
            else "moderate"
            if impact_score > 4
            else "low",
            "sleep_disruption_risk": "high"
            if regulatory_period == "night" and peak_db > 45
            else "low",
            "communication_interference": "yes" if peak_db > 60 else "no",
        },
        "source_characteristics": {
            "likely_distance": _estimate_source_distance(peak_db, primary_category),
            "temporal_pattern": _analyze_temporal_pattern(duration),
            "predictability": _assess_predictability(primary_category, context),
        },
    }


def _estimate_source_distance(peak_db: float, category: str) -> str:
    """Estimate distance to noise source."""
    if category == "traffic_noise":
        if peak_db > 75:
            return "<50m"
        elif peak_db > 65:
            return "50-200m"
        else:
            return ">200m"
    elif category == "aircraft_noise":
        return "500-5000m"
    elif category == "construction_activity":
        if peak_db > 80:
            return "<100m"
        else:
            return "100-500m"
    else:
        return "unknown"


def _analyze_temporal_pattern(duration: float) -> str:
    """Analyze temporal pattern of the event."""
    if duration < 60:
        return "impulsive"
    elif duration < 600:
        return "intermittent"
    else:
        return "continuous"


def _assess_predictability(category: str, context: Dict[str, Any]) -> str:
    """Assess predictability of noise source."""
    predictable_sources = ["traffic_noise", "aircraft_noise", "building_systems"]
    if category in predictable_sources:
        return "predictable"
    elif category == "construction_activity" and context["weekday"]:
        return "partially_predictable"
    else:
        return "unpredictable"


def _calculate_confidence_score(
    classification: Dict[str, Any], context: Dict[str, Any]
) -> float:
    """Calculate overall confidence score for the analysis."""
    base_confidence = classification["confidence"]

    # Adjust based on data quality
    if context["peak_level_db"] > 0 and context["duration_seconds"] > 0:
        data_quality_bonus = 0.1
    else:
        data_quality_bonus = -0.2

    # Adjust based on context richness
    context_bonus = 0.05 if context["location_type"] != "unknown" else 0

    final_confidence = min(
        1.0, max(0.1, base_confidence + data_quality_bonus + context_bonus)
    )

    return round(final_confidence, 2)


def _generate_recommendations(
    classification: Dict[str, Any], context: Dict[str, Any]
) -> List[str]:
    """Generate actionable recommendations based on analysis."""
    recommendations = []

    category = classification["primary_category"]
    peak_db = context["peak_level_db"]
    time_of_day = context["time_of_day"]

    # General recommendations based on noise level
    if peak_db > 85:
        recommendations.append(
            "Consider using hearing protection if exposure continues"
        )
        recommendations.append("Document this event for potential noise complaint")

    # Category-specific recommendations
    if category == "traffic_noise":
        recommendations.append("Monitor for patterns during rush hours")
        if peak_db > 70:
            recommendations.append(
                "Contact local authorities about traffic noise mitigation"
            )

    elif category == "construction_activity":
        recommendations.append("Check if construction is within permitted hours")
        recommendations.append("Document dates and times for potential complaint")

    elif category == "aircraft_noise":
        recommendations.append("Check flight patterns and airport noise maps")
        recommendations.append("Consider contacting airport noise office if frequent")

    elif category == "emergency_vehicle":
        recommendations.append("No action needed - emergency response has priority")

    # Time-specific recommendations
    if time_of_day == "night" and peak_db > 45:
        recommendations.append("Consider sleep disruption - may warrant complaint")
        recommendations.append("Use white noise or earplugs for better sleep")

    # Regulatory compliance recommendations
    if context["average_level_db"] > 55:  # WHO day limit
        recommendations.append("Noise levels exceed WHO guidelines")
        recommendations.append("Monitor for health impacts and consider action")

    return recommendations


async def _trigger_follow_up_actions(device_id: str, analysis_result: Dict[str, Any]):
    """Trigger follow-up actions based on AI analysis results."""

    classification = analysis_result["classification"]
    confidence = analysis_result["confidence_score"]

    # High-confidence, high-impact events
    if confidence > 0.8 and analysis_result["context"]["peak_level_db"] > 80:
        # Trigger notification
        from app.workers.notification_tasks import send_ai_analysis_notification

        send_ai_analysis_notification.delay(device_id, analysis_result)

    # Pattern detection for recurring events
    if classification["primary_category"] in ["traffic_noise", "construction_activity"]:
        detect_noise_patterns.delay(device_id, classification["primary_category"])


@celery_app.task(bind=True, base=AsyncTask, name="detect_noise_patterns")
async def detect_noise_patterns(self, device_id: str, noise_category: str):
    """
    Detect recurring noise patterns for a specific category.

    Args:
        device_id: ID of the device
        noise_category: Category of noise to analyze
    """
    try:
        logger.info(f"Detecting patterns for {noise_category} on device {device_id}")

        # This would analyze historical data to detect patterns
        # For now, return a placeholder result

        pattern_result = {
            "device_id": device_id,
            "noise_category": noise_category,
            "patterns_detected": False,
            "analysis_timestamp": datetime.utcnow().isoformat(),
        }

        return pattern_result

    except Exception as e:
        logger.error(f"Error detecting noise patterns: {e}")
        return {"status": "error", "message": str(e)}
