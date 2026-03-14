"""Unit tests for backend services."""
import pytest
from datetime import datetime, timedelta, timezone

from app.services.spl_calculation_service import SPLCalculationService
from app.services.threshold_detection_service import ThresholdDetectionService


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
