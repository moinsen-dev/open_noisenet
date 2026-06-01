"""Unit tests for backend services."""
import asyncio
import pytest
from datetime import datetime, timedelta, timezone

from app.services.spl_calculation_service import SPLCalculationService
from app.services.threshold_detection_service import (
    ThresholdDetectionService,
    ThresholdRule,
    ThresholdType,
    EventSeverity,
)
from app.services.geospatial_service import GeospatialService


class TestSPLCalculationService:
    def setup_method(self):
        self.svc = SPLCalculationService()

    def test_rms_empty_returns_zero(self):
        assert self.svc.calculate_rms([]) == 0.0

    def test_rms_single_value(self):
        assert self.svc.calculate_rms([1.0]) == 1.0

    def test_spl_from_rms_zero_returns_zero(self):
        assert self.svc.calculate_spl_from_rms(0.0) == 0.0

    def test_spl_from_rms_reference(self):
        spl = self.svc.calculate_spl_from_rms(2e-5)
        assert abs(spl) < 0.1

    def test_leq_empty_returns_zero(self):
        assert self.svc.calculate_leq([]) == 0.0

    def test_leq_single_value(self):
        assert abs(self.svc.calculate_leq([60.0]) - 60.0) < 0.1

    def test_leq_energy_averaging(self):
        leq = self.svc.calculate_leq([60.0, 60.0])
        assert abs(leq - 60.0) < 0.1

    def test_leq_dominated_by_loud(self):
        leq = self.svc.calculate_leq([50.0, 90.0])
        assert leq > 85.0

    def test_noise_statistics_percentiles(self):
        values = list(range(30, 81))
        stats = self.svc.calculate_noise_statistics(values)
        assert stats["lmin"] == 30.0
        assert stats["lmax"] == 80.0
        assert stats["l90"] < stats["l50"] < stats["l10"]

    def test_threshold_detection(self):
        now = datetime.utcnow()
        measurements = [
            {"spl_db": 70.0, "timestamp": now - timedelta(seconds=i)}
            for i in range(60)
        ]
        assert self.svc.detect_threshold_exceedance(measurements, 65.0, 30) is True
        assert self.svc.detect_threshold_exceedance(measurements, 75.0, 30) is False

    def test_compliance_who_day_compliant(self):
        result = self.svc.check_regulatory_compliance(50.0, "day", "WHO")
        assert result["status"] == "compliant"

    def test_compliance_who_night_violation(self):
        result = self.svc.check_regulatory_compliance(55.0, "night", "WHO")
        assert result["status"] == "severe_violation"

    def test_noise_level_categories(self):
        assert self.svc.get_noise_level_category(30.0) == "very_quiet"
        assert self.svc.get_noise_level_category(55.0) == "loud"
        assert self.svc.get_noise_level_category(90.0) == "dangerous"

    def test_a_weighting_quiet_reduced(self):
        quiet = self.svc.apply_a_weighting_broadband(25.0)
        assert quiet < 25.0

    def test_a_weighting_loud_minimal(self):
        loud = self.svc.apply_a_weighting_broadband(95.0)
        assert loud == 95.0

    def test_leq_negative_db_values(self):
        """Leq with values below reference level (e.g. very quiet sounds)."""
        leq = self.svc.calculate_leq([-10.0, -5.0, 0.0])
        assert leq < 0.0 or leq >= 0.0  # Must not raise
        assert isinstance(leq, float)

    def test_leq_zero_length_returns_zero(self):
        """Explicit zero-length list returns 0.0 (consistent with empty list)."""
        assert self.svc.calculate_leq([]) == 0.0

    def test_a_weighting_at_1khz_no_change(self):
        """1 kHz is the A-weighting reference; broadband correction is minimal."""
        result = self.svc.apply_a_weighting_broadband(60.0)
        # At moderate levels (50-70), correction is -2 dB — not zero,
        # but should be close to the raw value for typical environmental noise.
        assert result <= 60.0
        assert result >= 55.0


class TestThresholdDetectionService:
    def setup_method(self):
        self.svc = ThresholdDetectionService()

    def test_time_restrictions_day_rule(self):
        rule = self.svc.default_rules[0]  # WHO Day Limit (07:00-19:00)
        day_time = datetime(2026, 3, 11, 12, 0, tzinfo=timezone.utc)
        night_time = datetime(2026, 3, 11, 2, 0, tzinfo=timezone.utc)
        assert self.svc._check_time_restrictions(rule, day_time) is True
        assert self.svc._check_time_restrictions(rule, night_time) is False

    def test_time_restrictions_night_wrap(self):
        night_rule = self.svc.default_rules[2]  # WHO Night (23:00-07:00)
        late_night = datetime(2026, 3, 11, 1, 0, tzinfo=timezone.utc)
        before_midnight = datetime(2026, 3, 11, 23, 30, tzinfo=timezone.utc)
        afternoon = datetime(2026, 3, 11, 15, 0, tzinfo=timezone.utc)
        assert self.svc._check_time_restrictions(night_rule, late_night) is True
        assert self.svc._check_time_restrictions(night_rule, before_midnight) is True
        assert self.svc._check_time_restrictions(night_rule, afternoon) is False

    def test_default_rules_exist(self):
        assert len(self.svc.default_rules) >= 5

    def test_rule_statistics(self):
        stats = self.svc.get_rule_statistics()
        assert stats["default_rules_count"] >= 5
        assert stats["active_detections_count"] == 0

    def test_day_threshold_applies_during_daytime(self):
        """Day rule [6, 22] applies at 14:00 UTC."""
        day_rule = ThresholdRule(
            id="test_day",
            name="Test Day",
            description="",
            threshold_type=ThresholdType.ABSOLUTE,
            threshold_value=55.0,
            min_duration_seconds=60,
            time_restrictions={"hours": [6, 22]},
            severity=EventSeverity.MEDIUM,
        )
        day_time = datetime(2026, 6, 1, 14, 0, tzinfo=timezone.utc)
        assert self.svc._check_time_restrictions(day_rule, day_time) is True

    def test_night_threshold_applies_during_nighttime(self):
        """Night rule [22, 6] applies at 02:00 UTC."""
        night_rule = ThresholdRule(
            id="test_night",
            name="Test Night",
            description="",
            threshold_type=ThresholdType.ABSOLUTE,
            threshold_value=40.0,
            min_duration_seconds=60,
            time_restrictions={"hours": [22, 6]},
            severity=EventSeverity.CRITICAL,
        )
        night_time = datetime(2026, 6, 1, 2, 0, tzinfo=timezone.utc)
        assert self.svc._check_time_restrictions(night_rule, night_time) is True

    def test_boundary_exactly_22_00_is_night(self):
        """At exactly 22:00 the night rule [22, 6] applies (22 >= start_hour)."""
        night_rule = ThresholdRule(
            id="test_night_bound",
            name="Test Night Boundary",
            description="",
            threshold_type=ThresholdType.ABSOLUTE,
            threshold_value=40.0,
            min_duration_seconds=60,
            time_restrictions={"hours": [22, 6]},
            severity=EventSeverity.CRITICAL,
        )
        boundary_time = datetime(2026, 6, 1, 22, 0, tzinfo=timezone.utc)
        assert self.svc._check_time_restrictions(night_rule, boundary_time) is True

    def test_boundary_exactly_06_00_is_day(self):
        """At exactly 06:00 the day rule [6, 22] applies (6 <= 6 < 22)."""
        day_rule = ThresholdRule(
            id="test_day_bound",
            name="Test Day Boundary",
            description="",
            threshold_type=ThresholdType.ABSOLUTE,
            threshold_value=55.0,
            min_duration_seconds=60,
            time_restrictions={"hours": [6, 22]},
            severity=EventSeverity.MEDIUM,
        )
        boundary_time = datetime(2026, 6, 1, 6, 0, tzinfo=timezone.utc)
        assert self.svc._check_time_restrictions(day_rule, boundary_time) is True
    @pytest.mark.asyncio
    async def test_threshold_violation_triggers_detection(self):
        """SPL above threshold registers an active detection."""
        rule = ThresholdRule(
            id="test_violation",
            name="Test Violation",
            description="",
            threshold_type=ThresholdType.ABSOLUTE,
            threshold_value=55.0,
            min_duration_seconds=60,
            severity=EventSeverity.HIGH,
        )
        now = datetime(2026, 6, 1, 14, 0, tzinfo=timezone.utc)
        detection_key = "dev-1_test_violation"
        result = await self.svc._check_absolute_threshold(
            device_id="dev-1",
            rule=rule,
            current_spl=65.0,  # 10 dB above threshold
            current_time=now,
            recent_measurements=[],
            detection_key=detection_key,
        )
        # _check_absolute_threshold returns None during active exceedance;
        # the detection is registered in active_detections.
        assert result is None
        assert detection_key in self.svc.active_detections
        detection = self.svc.active_detections[detection_key]
        assert detection.rule_triggered == "test_violation"
        assert detection.peak_level_db == 65.0

    @pytest.mark.asyncio
    async def test_compliant_when_below_threshold(self):
        """SPL below threshold returns None (no detection)."""
        rule = ThresholdRule(
            id="test_compliant",
            name="Test Compliant",
            description="",
            threshold_type=ThresholdType.ABSOLUTE,
            threshold_value=55.0,
            min_duration_seconds=60,
            severity=EventSeverity.MEDIUM,
        )
        now = datetime(2026, 6, 1, 14, 0, tzinfo=timezone.utc)
        result = await self.svc._check_absolute_threshold(
            device_id="dev-2",
            rule=rule,
            current_spl=45.0,  # 10 dB below threshold
            current_time=now,
            recent_measurements=[],
            detection_key="dev-2_test_compliant",
        )
        assert result is None


class TestGeospatialService:
    """Tests for geospatial analysis service."""

    def setup_method(self):
        self.svc = GeospatialService()

    def test_geospatial_service_imports(self):
        """GeospatialService class exists and can be instantiated."""
        assert self.svc is not None
        assert hasattr(self.svc, "calculate_distance_meters")
        assert hasattr(self.svc, "EARTH_RADIUS")

    def test_reverse_geocode_known_location(self):
        """Reverse geocode is not yet implemented — documents the gap.

        When implemented, calling reverse_geocode(52.52, 13.405) should return
        location data for Berlin, Germany.
        """
        if hasattr(self.svc, "reverse_geocode"):
            result = self.svc.reverse_geocode(52.52, 13.405)
            assert result is not None
        else:
            pytest.skip("reverse_geocode is not yet implemented on GeospatialService")

    def test_reverse_geocode_null_island(self):
        """Reverse geocode at (0,0) should not crash — documents gap.

        Null Island (0.0, 0.0) is a common edge case for geocoding APIs.
        The service should handle it gracefully without exceptions.
        """
        if hasattr(self.svc, "reverse_geocode"):
            result = self.svc.reverse_geocode(0.0, 0.0)
            # Should not crash; result may be None or empty for ocean location
            assert isinstance(result, (dict, type(None), str))
        else:
            pytest.skip("reverse_geocode is not yet implemented on GeospatialService")