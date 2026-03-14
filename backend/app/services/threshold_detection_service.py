"""
Threshold detection service for noise event identification.
Implements configurable rules engine for noise exceedance detection.
"""

import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Callable
import json
import logging
from dataclasses import dataclass, asdict
from enum import Enum

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc

from app.core.logging import get_logger
from app.db.models.device import Device
from app.db.models.event import Event
from app.services.spl_calculation_service import SPLCalculationService

logger = get_logger(__name__)


class ThresholdType(Enum):
    """Types of noise thresholds."""

    ABSOLUTE = "absolute"  # Simple dB threshold
    RELATIVE = "relative"  # Relative to background level
    PERCENTILE = "percentile"  # Based on statistical percentiles
    TIME_WEIGHTED = "time_weighted"  # Time-weighted average
    ADAPTIVE = "adaptive"  # Adaptive based on location/time


class EventSeverity(Enum):
    """Event severity levels."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass
class ThresholdRule:
    """Configuration for a noise threshold rule."""

    id: str
    name: str
    description: str
    threshold_type: ThresholdType
    threshold_value: float
    min_duration_seconds: int
    max_duration_seconds: Optional[int] = None
    time_restrictions: Optional[Dict[str, Any]] = None  # e.g., night hours only
    location_restrictions: Optional[Dict[str, Any]] = None
    severity: EventSeverity = EventSeverity.MEDIUM
    enabled: bool = True

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for storage."""
        result = asdict(self)
        result["threshold_type"] = self.threshold_type.value
        result["severity"] = self.severity.value
        return result

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ThresholdRule":
        """Create from dictionary."""
        data["threshold_type"] = ThresholdType(data["threshold_type"])
        data["severity"] = EventSeverity(data["severity"])
        return cls(**data)


@dataclass
class NoiseEventDetection:
    """Result of noise event detection."""

    device_id: str
    rule_triggered: str
    start_time: datetime
    end_time: Optional[datetime]
    peak_level_db: float
    average_level_db: float
    duration_seconds: float
    severity: EventSeverity
    metadata: Dict[str, Any]


class ThresholdDetectionService:
    """Service for detecting noise threshold exceedances and triggering events."""

    def __init__(self):
        self.spl_service = SPLCalculationService()
        self.active_detections: Dict[str, NoiseEventDetection] = {}
        self.default_rules = self._create_default_rules()
        self.custom_rules: Dict[str, List[ThresholdRule]] = {}  # device_id -> rules

    def _create_default_rules(self) -> List[ThresholdRule]:
        """Create default threshold rules based on WHO/EPA guidelines."""
        return [
            # WHO Guidelines - Day time
            ThresholdRule(
                id="who_day_55db",
                name="WHO Day Limit",
                description="WHO Environmental Noise Guidelines - Day time limit",
                threshold_type=ThresholdType.ABSOLUTE,
                threshold_value=55.0,
                min_duration_seconds=900,  # 15 minutes
                time_restrictions={"hours": [7, 19]},  # 07:00-19:00
                severity=EventSeverity.MEDIUM,
            ),
            # WHO Guidelines - Evening
            ThresholdRule(
                id="who_evening_50db",
                name="WHO Evening Limit",
                description="WHO Environmental Noise Guidelines - Evening limit",
                threshold_type=ThresholdType.ABSOLUTE,
                threshold_value=50.0,
                min_duration_seconds=900,
                time_restrictions={"hours": [19, 23]},  # 19:00-23:00
                severity=EventSeverity.HIGH,
            ),
            # WHO Guidelines - Night
            ThresholdRule(
                id="who_night_40db",
                name="WHO Night Limit",
                description="WHO Environmental Noise Guidelines - Night time limit",
                threshold_type=ThresholdType.ABSOLUTE,
                threshold_value=40.0,
                min_duration_seconds=600,  # 10 minutes
                time_restrictions={"hours": [23, 7]},  # 23:00-07:00
                severity=EventSeverity.CRITICAL,
            ),
            # Sudden loud events
            ThresholdRule(
                id="sudden_loud_75db",
                name="Sudden Loud Event",
                description="Sudden loud noise event detection",
                threshold_type=ThresholdType.ABSOLUTE,
                threshold_value=75.0,
                min_duration_seconds=10,
                max_duration_seconds=300,
                severity=EventSeverity.HIGH,
            ),
            # Construction noise
            ThresholdRule(
                id="construction_70db_day",
                name="Construction Noise",
                description="Potential construction activity",
                threshold_type=ThresholdType.ABSOLUTE,
                threshold_value=70.0,
                min_duration_seconds=300,  # 5 minutes
                time_restrictions={"hours": [7, 18]},
                severity=EventSeverity.MEDIUM,
            ),
            # Hearing damage risk
            ThresholdRule(
                id="hearing_damage_85db",
                name="Hearing Damage Risk",
                description="Sound levels that may cause hearing damage",
                threshold_type=ThresholdType.ABSOLUTE,
                threshold_value=85.0,
                min_duration_seconds=60,
                severity=EventSeverity.CRITICAL,
            ),
        ]

    async def process_measurement(
        self, device_id: str, measurement: Dict[str, Any], db: AsyncSession
    ) -> List[NoiseEventDetection]:
        """
        Process a new measurement and detect threshold exceedances.

        Args:
            device_id: ID of the device
            measurement: Measurement data with spl_db, timestamp, etc.
            db: Database session

        Returns:
            List of detected events
        """
        detected_events = []

        try:
            # Get recent measurements for context
            recent_measurements = await self._get_recent_measurements(device_id, db)
            recent_measurements.append(measurement)

            # Get rules for this device
            rules = await self._get_rules_for_device(device_id, db)

            # Process each rule
            for rule in rules:
                if not rule.enabled:
                    continue

                # Check time restrictions
                if not self._check_time_restrictions(rule, measurement["timestamp"]):
                    continue

                # Check if threshold is exceeded
                event = await self._check_threshold(
                    device_id, rule, measurement, recent_measurements
                )

                if event:
                    detected_events.append(event)
                    logger.info(
                        f"Noise event detected: {rule.name} for device {device_id}"
                    )

        except Exception as e:
            logger.error(f"Error processing measurement for device {device_id}: {e}")

        return detected_events

    async def _get_recent_measurements(
        self, device_id: str, db: AsyncSession, hours: int = 1
    ) -> List[Dict[str, Any]]:
        """Get recent measurements for a device."""
        # This would query the measurements table
        # For now, return empty list as placeholder
        return []

    async def _get_rules_for_device(
        self, device_id: str, db: AsyncSession
    ) -> List[ThresholdRule]:
        """Get threshold rules for a specific device."""
        # Start with default rules
        rules = self.default_rules.copy()

        # Add custom rules for this device
        if device_id in self.custom_rules:
            rules.extend(self.custom_rules[device_id])

        return rules

    def _check_time_restrictions(
        self, rule: ThresholdRule, timestamp: datetime
    ) -> bool:
        """Check if current time matches rule restrictions."""
        if not rule.time_restrictions:
            return True

        current_hour = timestamp.hour

        if "hours" in rule.time_restrictions:
            start_hour, end_hour = rule.time_restrictions["hours"]

            if start_hour <= end_hour:
                # Normal time range (e.g., 9-17)
                return start_hour <= current_hour < end_hour
            else:
                # Wrap-around range (e.g., 23-7)
                return current_hour >= start_hour or current_hour < end_hour

        if "weekdays_only" in rule.time_restrictions:
            if rule.time_restrictions["weekdays_only"]:
                return timestamp.weekday() < 5  # Monday = 0, Friday = 4

        return True

    async def _check_threshold(
        self,
        device_id: str,
        rule: ThresholdRule,
        current_measurement: Dict[str, Any],
        recent_measurements: List[Dict[str, Any]],
    ) -> Optional[NoiseEventDetection]:
        """Check if a threshold rule is triggered."""
        current_spl = current_measurement.get("spl_db", 0.0)
        current_time = current_measurement.get("timestamp", datetime.utcnow())

        detection_key = f"{device_id}_{rule.id}"

        if rule.threshold_type == ThresholdType.ABSOLUTE:
            return await self._check_absolute_threshold(
                device_id,
                rule,
                current_spl,
                current_time,
                recent_measurements,
                detection_key,
            )
        elif rule.threshold_type == ThresholdType.RELATIVE:
            return await self._check_relative_threshold(
                device_id,
                rule,
                current_spl,
                current_time,
                recent_measurements,
                detection_key,
            )
        # Add other threshold types as needed

        return None

    async def _check_absolute_threshold(
        self,
        device_id: str,
        rule: ThresholdRule,
        current_spl: float,
        current_time: datetime,
        recent_measurements: List[Dict[str, Any]],
        detection_key: str,
    ) -> Optional[NoiseEventDetection]:
        """Check absolute threshold exceedance."""

        if current_spl >= rule.threshold_value:
            # Threshold exceeded
            if detection_key not in self.active_detections:
                # Start new detection
                self.active_detections[detection_key] = NoiseEventDetection(
                    device_id=device_id,
                    rule_triggered=rule.id,
                    start_time=current_time,
                    end_time=None,
                    peak_level_db=current_spl,
                    average_level_db=current_spl,
                    duration_seconds=0.0,
                    severity=rule.severity,
                    metadata={
                        "rule_name": rule.name,
                        "threshold": rule.threshold_value,
                    },
                )
            else:
                # Update existing detection
                detection = self.active_detections[detection_key]
                detection.peak_level_db = max(detection.peak_level_db, current_spl)
                detection.duration_seconds = (
                    current_time - detection.start_time
                ).total_seconds()

                # Recalculate average level
                relevant_measurements = [
                    m
                    for m in recent_measurements
                    if m.get("timestamp", datetime.min) >= detection.start_time
                ]
                if relevant_measurements:
                    spl_values = [m.get("spl_db", 0.0) for m in relevant_measurements]
                    detection.average_level_db = self.spl_service.calculate_leq(
                        spl_values
                    )
        else:
            # Threshold not exceeded
            if detection_key in self.active_detections:
                # End detection if minimum duration met
                detection = self.active_detections[detection_key]
                detection.end_time = current_time
                detection.duration_seconds = (
                    current_time - detection.start_time
                ).total_seconds()

                if detection.duration_seconds >= rule.min_duration_seconds:
                    # Valid event - remove from active and return
                    del self.active_detections[detection_key]
                    return detection
                else:
                    # Too short - discard
                    del self.active_detections[detection_key]

        return None

    async def _check_relative_threshold(
        self,
        device_id: str,
        rule: ThresholdRule,
        current_spl: float,
        current_time: datetime,
        recent_measurements: List[Dict[str, Any]],
        detection_key: str,
    ) -> Optional[NoiseEventDetection]:
        """Check relative threshold (compared to background level)."""

        # Calculate background level (e.g., L90 over last hour)
        if len(recent_measurements) < 60:  # Need sufficient data
            return None

        spl_values = [
            m.get("spl_db", 0.0) for m in recent_measurements[-3600:]
        ]  # Last hour
        stats = self.spl_service.calculate_noise_statistics(spl_values)
        background_level = stats["l90"]  # Background level

        relative_threshold = background_level + rule.threshold_value

        # Use the absolute threshold logic with calculated relative threshold
        modified_rule = ThresholdRule(
            id=rule.id,
            name=rule.name,
            description=rule.description,
            threshold_type=ThresholdType.ABSOLUTE,
            threshold_value=relative_threshold,
            min_duration_seconds=rule.min_duration_seconds,
            max_duration_seconds=rule.max_duration_seconds,
            severity=rule.severity,
        )

        return await self._check_absolute_threshold(
            device_id,
            modified_rule,
            current_spl,
            current_time,
            recent_measurements,
            detection_key,
        )

    async def add_custom_rule(self, device_id: str, rule: ThresholdRule) -> bool:
        """Add a custom threshold rule for a device."""
        try:
            if device_id not in self.custom_rules:
                self.custom_rules[device_id] = []

            # Remove existing rule with same ID
            self.custom_rules[device_id] = [
                r for r in self.custom_rules[device_id] if r.id != rule.id
            ]

            # Add new rule
            self.custom_rules[device_id].append(rule)

            logger.info(f"Added custom rule {rule.id} for device {device_id}")
            return True

        except Exception as e:
            logger.error(f"Error adding custom rule: {e}")
            return False

    async def remove_custom_rule(self, device_id: str, rule_id: str) -> bool:
        """Remove a custom threshold rule for a device."""
        try:
            if device_id in self.custom_rules:
                self.custom_rules[device_id] = [
                    r for r in self.custom_rules[device_id] if r.id != rule_id
                ]

            logger.info(f"Removed custom rule {rule_id} for device {device_id}")
            return True

        except Exception as e:
            logger.error(f"Error removing custom rule: {e}")
            return False

    async def get_active_detections(
        self, device_id: Optional[str] = None
    ) -> List[NoiseEventDetection]:
        """Get currently active detections."""
        if device_id:
            return [
                detection
                for key, detection in self.active_detections.items()
                if detection.device_id == device_id
            ]
        else:
            return list(self.active_detections.values())

    async def cleanup_stale_detections(self, max_age_hours: int = 24):
        """Clean up stale detections that haven't been updated."""
        cutoff_time = datetime.utcnow() - timedelta(hours=max_age_hours)

        stale_keys = [
            key
            for key, detection in self.active_detections.items()
            if detection.start_time < cutoff_time
        ]

        for key in stale_keys:
            del self.active_detections[key]

        if stale_keys:
            logger.info(f"Cleaned up {len(stale_keys)} stale detections")

    def get_rule_statistics(self) -> Dict[str, Any]:
        """Get statistics about rule performance."""
        total_rules = len(self.default_rules)
        total_custom_rules = sum(len(rules) for rules in self.custom_rules.values())
        active_detections_count = len(self.active_detections)

        return {
            "default_rules_count": total_rules,
            "custom_rules_count": total_custom_rules,
            "active_detections_count": active_detections_count,
            "devices_with_custom_rules": len(self.custom_rules),
            "rule_types": [rule.threshold_type.value for rule in self.default_rules],
        }
