"""Verify all modules import without errors."""


def test_import_logging():
    from app.core.logging import get_logger, setup_logging
    logger = get_logger("test")
    assert logger is not None


def test_import_spl_service():
    from app.services.spl_calculation_service import SPLCalculationService
    svc = SPLCalculationService()
    assert svc is not None


def test_import_threshold_service():
    from app.services.threshold_detection_service import ThresholdDetectionService
    svc = ThresholdDetectionService()
    assert svc is not None


def test_import_geospatial_service():
    from app.services.geospatial_service import GeospatialService
    svc = GeospatialService()
    assert svc is not None


def test_import_main():
    from app.main import create_application
    application = create_application()
    assert application is not None
