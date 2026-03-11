"""Test worker task logic (unit tests, no Celery broker needed)."""
import pytest
from datetime import datetime, timezone

from app.services.spl_calculation_service import SPLCalculationService
from app.services.threshold_detection_service import ThresholdDetectionService


def test_spl_leq_calculation():
    svc = SPLCalculationService()
    leq = svc.calculate_leq([60.0, 70.0, 65.0])
    assert 60.0 < leq < 75.0


def test_spl_noise_statistics():
    svc = SPLCalculationService()
    stats = svc.calculate_noise_statistics([40.0, 50.0, 60.0, 70.0, 80.0])
    assert stats["lmin"] == 40.0
    assert stats["lmax"] == 80.0
    assert stats["sample_count"] == 5
    assert stats["l50"] > 0


def test_spl_a_weighting():
    svc = SPLCalculationService()
    quiet = svc.apply_a_weighting_broadband(25.0)
    loud = svc.apply_a_weighting_broadband(95.0)
    assert quiet < 25.0
    assert loud == 95.0


def test_threshold_time_restrictions():
    svc = ThresholdDetectionService()
    rule = svc.default_rules[0]  # WHO Day Limit (07:00-19:00)
    day_time = datetime(2026, 3, 11, 12, 0, tzinfo=timezone.utc)
    night_time = datetime(2026, 3, 11, 2, 0, tzinfo=timezone.utc)
    assert svc._check_time_restrictions(rule, day_time) is True
    assert svc._check_time_restrictions(rule, night_time) is False


def test_threshold_night_wrap_around():
    svc = ThresholdDetectionService()
    night_rule = svc.default_rules[2]  # WHO Night Limit (23:00-07:00)
    late_night = datetime(2026, 3, 11, 1, 0, tzinfo=timezone.utc)
    before_midnight = datetime(2026, 3, 11, 23, 30, tzinfo=timezone.utc)
    afternoon = datetime(2026, 3, 11, 15, 0, tzinfo=timezone.utc)
    assert svc._check_time_restrictions(night_rule, late_night) is True
    assert svc._check_time_restrictions(night_rule, before_midnight) is True
    assert svc._check_time_restrictions(night_rule, afternoon) is False


def test_noise_level_categories():
    svc = SPLCalculationService()
    assert svc.get_noise_level_category(30.0) == "very_quiet"
    assert svc.get_noise_level_category(55.0) == "loud"
    assert svc.get_noise_level_category(90.0) == "dangerous"


def test_regulatory_compliance():
    svc = SPLCalculationService()
    compliant = svc.check_regulatory_compliance(40.0, "night", "WHO")
    assert compliant["status"] == "compliant"
    violation = svc.check_regulatory_compliance(70.0, "night", "WHO")
    assert violation["status"] == "severe_violation"
