"""
SPL (Sound Pressure Level) calculation service with A-weighting.
Implements standard acoustic calculations for environmental noise monitoring.
"""

import math
import numpy as np
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import logging

from app.core.logging import get_logger

logger = get_logger(__name__)


class SPLCalculationService:
    """Service for calculating A-weighted SPL and equivalent continuous sound levels."""

    # A-weighting filter coefficients based on IEC 61672-1 standard
    A_WEIGHTING_TABLE = {
        10.0: -70.4,
        12.5: -63.4,
        16.0: -56.7,
        20.0: -50.5,
        25.0: -44.7,
        31.5: -39.4,
        40.0: -34.6,
        50.0: -30.2,
        63.0: -26.2,
        80.0: -22.5,
        100.0: -19.1,
        125.0: -16.1,
        160.0: -13.4,
        200.0: -10.9,
        250.0: -8.6,
        315.0: -6.6,
        400.0: -4.8,
        500.0: -3.2,
        630.0: -1.9,
        800.0: -0.8,
        1000.0: 0.0,  # Reference frequency
        1250.0: 0.6,
        1600.0: 1.0,
        2000.0: 1.2,
        2500.0: 1.3,
        3150.0: 1.2,
        4000.0: 1.0,
        5000.0: 0.5,
        6300.0: -0.1,
        8000.0: -1.1,
        10000.0: -2.5,
        12500.0: -4.3,
        16000.0: -6.6,
        20000.0: -9.3,
    }

    @staticmethod
    def calculate_rms(audio_samples: List[float]) -> float:
        """Calculate Root Mean Square of audio samples."""
        if not audio_samples:
            return 0.0

        sum_squares = sum(sample**2 for sample in audio_samples)
        return math.sqrt(sum_squares / len(audio_samples))

    @staticmethod
    def calculate_spl_from_rms(rms: float, reference_pressure: float = 2e-5) -> float:
        """
        Calculate SPL in dB from RMS value.

        Args:
            rms: Root mean square of the audio signal
            reference_pressure: Reference pressure (20 µPa for air)

        Returns:
            SPL in dB
        """
        if rms <= 0:
            return 0.0

        spl_db = 20 * math.log10(rms / reference_pressure)
        return max(0.0, min(spl_db, 140.0))  # Clamp to realistic range

    @staticmethod
    def apply_a_weighting_broadband(raw_spl_db: float) -> float:
        """
        Apply approximate A-weighting for broadband environmental noise.

        This is a simplified approach for real-time processing without FFT.
        For precise measurements, frequency-domain A-weighting should be used.
        """
        if raw_spl_db < 30:
            # Very quiet - likely low frequency dominant
            return raw_spl_db - 8.0
        elif raw_spl_db < 50:
            # Quiet - typical background noise
            return raw_spl_db - 4.0
        elif raw_spl_db < 70:
            # Moderate - speech, distant traffic
            return raw_spl_db - 2.0
        elif raw_spl_db < 90:
            # Loud - traffic, machinery
            return raw_spl_db - 1.0
        else:
            # Very loud - minimal correction needed
            return raw_spl_db

    @staticmethod
    def calculate_leq(
        spl_values: List[float], time_window_seconds: Optional[float] = None
    ) -> float:
        """
        Calculate equivalent continuous sound level (Leq).

        Args:
            spl_values: List of SPL measurements in dB
            time_window_seconds: Time window for calculation (optional)

        Returns:
            Leq in dB
        """
        if not spl_values:
            return 0.0

        try:
            # Convert dB to energy (power)
            energy_sum = sum(10 ** (spl / 10) for spl in spl_values)

            # Calculate mean energy and convert back to dB
            mean_energy = energy_sum / len(spl_values)
            leq = 10 * math.log10(mean_energy)

            return max(0.0, min(leq, 140.0))  # Clamp to realistic range

        except (ValueError, OverflowError) as e:
            logger.warning(f"Error calculating Leq: {e}")
            return spl_values[0] if spl_values else 0.0

    @staticmethod
    def calculate_leq_time_window(
        measurements: List[Dict[str, Any]], window_minutes: int = 15
    ) -> float:
        """
        Calculate Leq over a specific time window (e.g., Leq15 for regulations).

        Args:
            measurements: List of measurement dicts with 'timestamp' and 'spl_db'
            window_minutes: Time window in minutes

        Returns:
            Leq for the time window in dB
        """
        if not measurements:
            return 0.0

        # Filter measurements to the specified time window
        cutoff_time = datetime.utcnow() - timedelta(minutes=window_minutes)
        recent_measurements = [
            m for m in measurements if m.get("timestamp", datetime.min) >= cutoff_time
        ]

        if not recent_measurements:
            return 0.0

        spl_values = [m.get("spl_db", 0.0) for m in recent_measurements]
        return SPLCalculationService.calculate_leq(spl_values)

    @staticmethod
    def calculate_noise_statistics(spl_values: List[float]) -> Dict[str, float]:
        """
        Calculate comprehensive noise statistics.

        Returns:
            Dictionary with Leq, Lmin, Lmax, L10, L50, L90, L95, L99
        """
        if not spl_values:
            return {
                "leq": 0.0,
                "lmin": 0.0,
                "lmax": 0.0,
                "l10": 0.0,
                "l50": 0.0,
                "l90": 0.0,
                "l95": 0.0,
                "l99": 0.0,
                "sample_count": 0,
            }

        sorted_values = sorted(spl_values)
        count = len(sorted_values)

        def get_percentile(percentile: float) -> float:
            """Get percentile value (percentile is 1-based, e.g., 90 for L90)."""
            index = int((count - 1) * (1.0 - percentile / 100))
            return sorted_values[max(0, min(index, count - 1))]

        return {
            "leq": SPLCalculationService.calculate_leq(spl_values),
            "lmin": sorted_values[0],
            "lmax": sorted_values[-1],
            "l10": get_percentile(10),  # Exceeded 10% of time
            "l50": get_percentile(50),  # Median (L50)
            "l90": get_percentile(90),  # Exceeded 90% of time
            "l95": get_percentile(95),  # Exceeded 95% of time
            "l99": get_percentile(99),  # Exceeded 99% of time
            "sample_count": count,
        }

    @staticmethod
    def detect_threshold_exceedance(
        measurements: List[Dict[str, Any]],
        threshold_db: float,
        min_duration_seconds: int = 30,
    ) -> bool:
        """
        Detect if noise threshold has been exceeded for minimum duration.

        Args:
            measurements: Recent measurements with timestamp and spl_db
            threshold_db: Threshold level in dB
            min_duration_seconds: Minimum duration for event detection

        Returns:
            True if threshold exceedance detected
        """
        if not measurements:
            return False

        # Filter to recent measurements within the minimum duration
        cutoff_time = datetime.utcnow() - timedelta(seconds=min_duration_seconds)
        recent_measurements = [
            m for m in measurements if m.get("timestamp", datetime.min) >= cutoff_time
        ]

        if not recent_measurements:
            return False

        # Check if majority of recent samples exceed threshold
        exceeding_samples = sum(
            1 for m in recent_measurements if m.get("spl_db", 0.0) >= threshold_db
        )

        exceedance_ratio = exceeding_samples / len(recent_measurements)
        return exceedance_ratio > 0.8  # 80% of samples must exceed threshold

    @staticmethod
    def get_noise_level_category(spl_db: float) -> str:
        """Get noise level category based on SPL value."""
        if spl_db < 35:
            return "very_quiet"
        elif spl_db < 50:
            return "quiet"
        elif spl_db < 55:
            return "moderate"
        elif spl_db < 65:
            return "loud"
        elif spl_db < 75:
            return "very_loud"
        elif spl_db < 85:
            return "harmful"
        else:
            return "dangerous"

    @staticmethod
    def check_regulatory_compliance(
        leq_db: float, time_of_day: str, regulation_standard: str = "WHO"
    ) -> Dict[str, Any]:
        """
        Check compliance with noise regulations.

        Args:
            leq_db: Equivalent continuous sound level
            time_of_day: 'day', 'evening', or 'night'
            regulation_standard: 'WHO', 'EPA', or custom

        Returns:
            Compliance status and details
        """
        # WHO Environmental Noise Guidelines 2018
        if regulation_standard == "WHO":
            limits = {
                "day": 55.0,  # 07:00-19:00
                "evening": 50.0,  # 19:00-23:00
                "night": 40.0,  # 23:00-07:00
            }
        else:
            # Default/EPA-style limits
            limits = {"day": 65.0, "evening": 55.0, "night": 45.0}

        limit = limits.get(time_of_day, limits["day"])
        exceedance = leq_db - limit

        if exceedance <= 0:
            status = "compliant"
        elif exceedance <= 5:
            status = "marginal"
        elif exceedance <= 10:
            status = "violation"
        else:
            status = "severe_violation"

        return {
            "status": status,
            "limit_db": limit,
            "measured_db": leq_db,
            "exceedance_db": max(0, exceedance),
            "regulation": regulation_standard,
            "time_period": time_of_day,
        }

    @staticmethod
    def calculate_exposure_metrics(
        measurements: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Calculate noise exposure metrics for health assessment.

        Returns:
            Various exposure metrics and health risk indicators
        """
        if not measurements:
            return {"error": "No measurements provided"}

        spl_values = [m.get("spl_db", 0.0) for m in measurements]
        stats = SPLCalculationService.calculate_noise_statistics(spl_values)

        # Calculate day-night average sound level (DNL/Ldn)
        # This would require time-of-day information in real implementation
        ldn_estimate = stats["leq"] + 3.0  # Simplified estimate

        # Noise pollution level (NPL) - accounts for variability
        npl = stats["leq"] + (stats["l10"] - stats["l90"])

        # Equivalent noise level for community annoyance
        community_noise_equivalent_level = stats["leq"] + 2 * math.log10(
            max(1, stats["sample_count"] / 3600)  # Rough time adjustment
        )

        return {
            "statistics": stats,
            "ldn_estimate": ldn_estimate,
            "noise_pollution_level": npl,
            "community_noise_equivalent_level": community_noise_equivalent_level,
            "total_samples": len(measurements),
            "measurement_duration_hours": len(measurements)
            / 3600,  # Assuming 1Hz sampling
            "health_risk_assessment": SPLCalculationService._assess_health_risk(
                stats["leq"]
            ),
        }

    @staticmethod
    def _assess_health_risk(leq_db: float) -> Dict[str, str]:
        """Assess health risk based on noise exposure level."""
        if leq_db < 45:
            risk = "minimal"
            description = "Generally acceptable for all activities"
        elif leq_db < 55:
            risk = "low"
            description = "May cause mild annoyance"
        elif leq_db < 65:
            risk = "moderate"
            description = "May interfere with communication and cause annoyance"
        elif leq_db < 75:
            risk = "high"
            description = "Likely to cause significant annoyance and stress"
        else:
            risk = "very_high"
            description = "May cause hearing damage with prolonged exposure"

        return {
            "risk_level": risk,
            "description": description,
            "recommendation": SPLCalculationService._get_risk_recommendation(risk),
        }

    @staticmethod
    def _get_risk_recommendation(risk_level: str) -> str:
        """Get recommendation based on risk level."""
        recommendations = {
            "minimal": "No action required",
            "low": "Monitor for trends, consider source identification",
            "moderate": "Document patterns, consider noise complaint if persistent",
            "high": "File noise complaint, document evidence, consider hearing protection",
            "very_high": "Immediate action required - file complaint, avoid prolonged exposure",
        }
        return recommendations.get(risk_level, "Consult noise regulations")
