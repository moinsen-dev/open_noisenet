"""
Celery tasks for real-time noise data processing.
"""

import asyncio
from datetime import datetime, timedelta
from typing import Dict, Any, List
import json
import logging

from celery import Task
from sqlalchemy.ext.asyncio import AsyncSession

from app.workers.celery_app import celery_app
from app.core.logging import get_logger
from app.db.session import async_session
from app.services.spl_calculation_service import SPLCalculationService
from app.services.threshold_detection_service import ThresholdDetectionService
from app.services.geospatial_service import GeospatialService

logger = get_logger(__name__)


class AsyncTask(Task):
    """Base task class that supports async operations."""

    def run(self, *args, **kwargs):
        """Run the task in an async context."""
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            return loop.run_until_complete(self.async_run(*args, **kwargs))
        finally:
            loop.close()

    async def async_run(self, *args, **kwargs):
        """Override this method in subclasses."""
        raise NotImplementedError


@celery_app.task(bind=True, base=AsyncTask, name="process_real_time_measurement")
async def process_real_time_measurement(
    self, device_id: str, measurement_data: Dict[str, Any]
):
    """
    Process a single real-time noise measurement.

    Args:
        device_id: ID of the device that sent the measurement
        measurement_data: Raw measurement data from device
    """
    try:
        logger.info(f"Processing real-time measurement from device {device_id}")

        async with async_session() as db:
            # Initialize services
            spl_service = SPLCalculationService()
            threshold_service = ThresholdDetectionService()

            # Extract and validate measurement data
            raw_spl = measurement_data.get("spl_db", 0.0)
            timestamp = datetime.fromisoformat(
                measurement_data.get("timestamp", datetime.utcnow().isoformat())
            )
            location = measurement_data.get("location", {})

            # Apply A-weighting and calibration
            calibrated_spl = spl_service.apply_a_weighting_broadband(raw_spl)

            # Prepare processed measurement
            processed_measurement = {
                "device_id": device_id,
                "timestamp": timestamp,
                "spl_db": calibrated_spl,
                "raw_spl_db": raw_spl,
                "latitude": location.get("latitude"),
                "longitude": location.get("longitude"),
                "metadata": measurement_data.get("metadata", {}),
            }

            # Store measurement (would save to measurements table)
            # await store_measurement(processed_measurement, db)

            # Check for threshold exceedances
            detected_events = await threshold_service.process_measurement(
                device_id, processed_measurement, db
            )

            # Trigger follow-up tasks for detected events
            for event in detected_events:
                # Queue AI analysis
                analyze_noise_event.delay(
                    event.device_id,
                    {
                        "event_id": f"temp_{event.start_time.isoformat()}",
                        "start_time": event.start_time.isoformat(),
                        "peak_level_db": event.peak_level_db,
                        "average_level_db": event.average_level_db,
                        "duration_seconds": event.duration_seconds,
                        "rule_triggered": event.rule_triggered,
                        "location": location,
                    },
                )

                # Send notifications if critical
                if event.severity.value in ["high", "critical"]:
                    send_alert_notification.delay(
                        device_id,
                        {
                            "event_type": "threshold_exceedance",
                            "severity": event.severity.value,
                            "spl_db": event.peak_level_db,
                            "rule": event.rule_triggered,
                            "location": location,
                        },
                    )

            logger.info(
                f"Successfully processed measurement from device {device_id}, detected {len(detected_events)} events"
            )

            return {
                "status": "success",
                "device_id": device_id,
                "processed_spl_db": calibrated_spl,
                "events_detected": len(detected_events),
                "timestamp": timestamp.isoformat(),
            }

    except Exception as e:
        logger.error(
            f"Error processing real-time measurement from device {device_id}: {e}"
        )
        self.retry(countdown=60, max_retries=3)


@celery_app.task(bind=True, base=AsyncTask, name="process_pending_measurements")
async def process_pending_measurements(self):
    """
    Process all pending measurements in batch.
    Runs periodically to handle any backlog.
    """
    try:
        logger.info("Processing pending measurements batch")

        async with async_session() as db:
            # This would query for unprocessed measurements
            # For now, just log the batch processing

            processed_count = 0
            error_count = 0

            # In real implementation:
            # 1. Query for unprocessed measurements
            # 2. Process each measurement
            # 3. Update processing status
            # 4. Generate aggregated statistics

            logger.info(
                f"Batch processing completed: {processed_count} processed, {error_count} errors"
            )

            return {
                "status": "success",
                "processed_count": processed_count,
                "error_count": error_count,
                "timestamp": datetime.utcnow().isoformat(),
            }

    except Exception as e:
        logger.error(f"Error in batch measurement processing: {e}")
        return {"status": "error", "message": str(e)}


@celery_app.task(bind=True, base=AsyncTask, name="calculate_device_statistics")
async def calculate_device_statistics(
    self, device_id: str, time_window_hours: int = 24
):
    """
    Calculate comprehensive statistics for a specific device.

    Args:
        device_id: ID of the device
        time_window_hours: Time window for statistics calculation
    """
    try:
        logger.info(
            f"Calculating statistics for device {device_id} (last {time_window_hours}h)"
        )

        async with async_session() as db:
            spl_service = SPLCalculationService()

            # Get recent measurements for device
            cutoff_time = datetime.utcnow() - timedelta(hours=time_window_hours)

            # This would query measurements table
            measurements = []  # Placeholder

            if not measurements:
                logger.warning(f"No measurements found for device {device_id}")
                return {"status": "no_data", "device_id": device_id}

            # Calculate comprehensive statistics
            spl_values = [m.get("spl_db", 0.0) for m in measurements]
            stats = spl_service.calculate_noise_statistics(spl_values)

            # Calculate regulatory compliance
            current_hour = datetime.utcnow().hour
            if 7 <= current_hour < 19:
                time_period = "day"
            elif 19 <= current_hour < 23:
                time_period = "evening"
            else:
                time_period = "night"

            compliance = spl_service.check_regulatory_compliance(
                stats["leq"], time_period
            )

            # Calculate exposure metrics
            exposure_metrics = spl_service.calculate_exposure_metrics(measurements)

            result = {
                "device_id": device_id,
                "time_window_hours": time_window_hours,
                "measurement_count": len(measurements),
                "statistics": stats,
                "compliance": compliance,
                "exposure_metrics": exposure_metrics,
                "calculated_at": datetime.utcnow().isoformat(),
            }

            # Store statistics (would save to device_statistics table)
            # await store_device_statistics(result, db)

            logger.info(
                f"Statistics calculated for device {device_id}: Leq={stats['leq']:.1f}dB"
            )

            return result

    except Exception as e:
        logger.error(f"Error calculating device statistics for {device_id}: {e}")
        self.retry(countdown=300, max_retries=2)


@celery_app.task(bind=True, base=AsyncTask, name="detect_anomalies")
async def detect_anomalies(self, device_id: str, measurement_data: Dict[str, Any]):
    """
    Detect anomalies in noise measurements using statistical methods.

    Args:
        device_id: ID of the device
        measurement_data: Current measurement data
    """
    try:
        logger.info(f"Running anomaly detection for device {device_id}")

        async with async_session() as db:
            current_spl = measurement_data.get("spl_db", 0.0)
            timestamp = datetime.fromisoformat(
                measurement_data.get("timestamp", datetime.utcnow().isoformat())
            )

            # Get historical data for baseline
            lookback_hours = 168  # 1 week
            cutoff_time = timestamp - timedelta(hours=lookback_hours)

            # This would query historical measurements
            historical_measurements = []  # Placeholder

            if len(historical_measurements) < 100:
                logger.info(
                    f"Insufficient historical data for anomaly detection on device {device_id}"
                )
                return {"status": "insufficient_data"}

            # Calculate baseline statistics
            historical_spl = [m.get("spl_db", 0.0) for m in historical_measurements]
            baseline_mean = sum(historical_spl) / len(historical_spl)
            baseline_std = (
                sum((x - baseline_mean) ** 2 for x in historical_spl)
                / len(historical_spl)
            ) ** 0.5

            # Detect anomalies using z-score
            z_score = (
                abs(current_spl - baseline_mean) / baseline_std
                if baseline_std > 0
                else 0
            )

            anomaly_detected = False
            anomaly_type = None
            confidence = 0.0

            if z_score > 3.0:  # 3-sigma rule
                anomaly_detected = True
                anomaly_type = "statistical_outlier"
                confidence = min(0.95, z_score / 5.0)

                # Additional checks for specific anomaly types
                if current_spl > baseline_mean + 3 * baseline_std:
                    anomaly_type = "sudden_increase"
                elif current_spl < baseline_mean - 3 * baseline_std:
                    anomaly_type = "sudden_decrease"

            result = {
                "device_id": device_id,
                "timestamp": timestamp.isoformat(),
                "current_spl_db": current_spl,
                "baseline_mean_db": baseline_mean,
                "baseline_std_db": baseline_std,
                "z_score": z_score,
                "anomaly_detected": anomaly_detected,
                "anomaly_type": anomaly_type,
                "confidence": confidence,
                "lookback_hours": lookback_hours,
                "baseline_samples": len(historical_measurements),
            }

            # If anomaly detected, trigger notification
            if anomaly_detected and confidence > 0.8:
                send_alert_notification.delay(
                    device_id,
                    {
                        "event_type": "anomaly_detection",
                        "anomaly_type": anomaly_type,
                        "confidence": confidence,
                        "current_spl_db": current_spl,
                        "z_score": z_score,
                    },
                )

            logger.info(
                f"Anomaly detection completed for device {device_id}: {'ANOMALY' if anomaly_detected else 'NORMAL'}"
            )

            return result

    except Exception as e:
        logger.error(f"Error in anomaly detection for device {device_id}: {e}")
        return {"status": "error", "message": str(e)}


@celery_app.task(bind=True, base=AsyncTask, name="update_device_status")
async def update_device_status(self, device_id: str):
    """
    Update device status based on recent activity.

    Args:
        device_id: ID of the device to check
    """
    try:
        async with async_session() as db:
            # Check recent activity (last 10 minutes)
            cutoff_time = datetime.utcnow() - timedelta(minutes=10)

            # This would query for recent measurements
            recent_measurements = []  # Placeholder

            # Determine device status
            if recent_measurements:
                status = "active"
                last_seen = max(
                    m.get("timestamp", cutoff_time) for m in recent_measurements
                )
            else:
                # Check if device was recently active
                last_hour_cutoff = datetime.utcnow() - timedelta(hours=1)
                # Query for measurements in last hour
                last_hour_measurements = []  # Placeholder

                if last_hour_measurements:
                    status = "idle"
                    last_seen = max(
                        m.get("timestamp", last_hour_cutoff)
                        for m in last_hour_measurements
                    )
                else:
                    status = "offline"
                    last_seen = datetime.utcnow() - timedelta(days=1)  # Default

            # Update device status in database
            device_status = {
                "device_id": device_id,
                "status": status,
                "last_seen": last_seen.isoformat()
                if isinstance(last_seen, datetime)
                else last_seen,
                "updated_at": datetime.utcnow().isoformat(),
            }

            logger.info(f"Device {device_id} status updated: {status}")

            return device_status

    except Exception as e:
        logger.error(f"Error updating device status for {device_id}: {e}")
        return {"status": "error", "message": str(e)}


# Import other task modules to avoid circular imports
from app.workers.ai_processing_tasks import analyze_noise_event
from app.workers.notification_tasks import send_alert_notification
