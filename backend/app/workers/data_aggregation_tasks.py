"""
Celery tasks for data aggregation and statistical calculations.
"""

import asyncio
from datetime import datetime, timedelta
from typing import Dict, Any, List
import logging
import statistics

from app.workers.celery_app import celery_app
from app.workers.noise_processing_tasks import AsyncTask
from app.core.logging import get_logger
from app.db.session import async_session
from app.services.spl_calculation_service import SPLCalculationService
from app.services.geospatial_service import GeospatialService, BoundingBox

logger = get_logger(__name__)


@celery_app.task(bind=True, base=AsyncTask, name="calculate_hourly_statistics")
async def calculate_hourly_statistics(self):
    """
    Calculate hourly noise statistics for all devices.
    """
    try:
        logger.info("Calculating hourly statistics")

        current_time = datetime.utcnow()
        hour_start = current_time.replace(minute=0, second=0, microsecond=0)
        hour_end = hour_start + timedelta(hours=1)

        async with async_session() as db:
            spl_service = SPLCalculationService()

            # Get all active devices
            active_devices = await _get_active_devices(db)

            hourly_stats = {
                "calculation_time": current_time.isoformat(),
                "hour_start": hour_start.isoformat(),
                "hour_end": hour_end.isoformat(),
                "device_statistics": {},
                "system_totals": {},
            }

            total_measurements = 0
            total_events = 0
            all_spl_values = []

            for device_id in active_devices:
                try:
                    # Get measurements for this device in the hour
                    measurements = await _get_device_measurements(
                        device_id, hour_start, hour_end, db
                    )

                    if not measurements:
                        continue

                    # Calculate device statistics
                    spl_values = [m.get("spl_db", 0.0) for m in measurements]
                    device_stats = spl_service.calculate_noise_statistics(spl_values)

                    # Get events for this hour
                    events = await _get_device_events(
                        device_id, hour_start, hour_end, db
                    )

                    # Calculate compliance
                    hour_of_day = hour_start.hour
                    if 7 <= hour_of_day < 19:
                        time_period = "day"
                    elif 19 <= hour_of_day < 23:
                        time_period = "evening"
                    else:
                        time_period = "night"

                    compliance = spl_service.check_regulatory_compliance(
                        device_stats["leq"], time_period
                    )

                    # Store device hourly statistics
                    device_hourly_stats = {
                        "device_id": device_id,
                        "hour_start": hour_start.isoformat(),
                        "measurement_count": len(measurements),
                        "event_count": len(events),
                        "statistics": device_stats,
                        "compliance": compliance,
                        "dominant_sources": _identify_dominant_sources(events),
                    }

                    hourly_stats["device_statistics"][device_id] = device_hourly_stats

                    # Add to system totals
                    total_measurements += len(measurements)
                    total_events += len(events)
                    all_spl_values.extend(spl_values)

                    # Store in database
                    await _store_hourly_device_stats(device_hourly_stats, db)

                except Exception as e:
                    logger.error(
                        f"Error calculating hourly stats for device {device_id}: {e}"
                    )
                    continue

            # Calculate system-wide statistics
            if all_spl_values:
                system_stats = spl_service.calculate_noise_statistics(all_spl_values)
                hourly_stats["system_totals"] = {
                    "total_measurements": total_measurements,
                    "total_events": total_events,
                    "active_devices": len(hourly_stats["device_statistics"]),
                    "system_statistics": system_stats,
                    "avg_device_leq": statistics.mean(
                        [
                            stats["statistics"]["leq"]
                            for stats in hourly_stats["device_statistics"].values()
                        ]
                    )
                    if hourly_stats["device_statistics"]
                    else 0.0,
                }

                # Store system hourly statistics
                await _store_hourly_system_stats(
                    hourly_stats["system_totals"], hour_start, db
                )

            logger.info(
                f"Hourly statistics calculated for {len(hourly_stats['device_statistics'])} devices"
            )

            return hourly_stats

    except Exception as e:
        logger.error(f"Error calculating hourly statistics: {e}")
        return {"status": "error", "message": str(e)}


@celery_app.task(bind=True, base=AsyncTask, name="calculate_daily_statistics")
async def calculate_daily_statistics(self):
    """
    Calculate daily noise statistics and trends.
    """
    try:
        logger.info("Calculating daily statistics")

        today = datetime.utcnow().date()
        day_start = datetime.combine(today, datetime.min.time())
        day_end = day_start + timedelta(days=1)

        async with async_session() as db:
            spl_service = SPLCalculationService()

            # Get all devices
            active_devices = await _get_active_devices(db)

            daily_stats = {
                "calculation_date": today.isoformat(),
                "calculation_time": datetime.utcnow().isoformat(),
                "device_statistics": {},
                "geographic_analysis": {},
                "trend_analysis": {},
                "system_summary": {},
            }

            # Calculate per-device daily statistics
            for device_id in active_devices:
                device_daily_stats = await _calculate_device_daily_stats(
                    device_id, day_start, day_end, db, spl_service
                )
                if device_daily_stats:
                    daily_stats["device_statistics"][device_id] = device_daily_stats

            # Geographic analysis
            daily_stats["geographic_analysis"] = await _perform_geographic_analysis(
                day_start, day_end, db
            )

            # Trend analysis
            daily_stats["trend_analysis"] = await _perform_trend_analysis(today, db)

            # System summary
            daily_stats["system_summary"] = await _calculate_system_daily_summary(
                daily_stats["device_statistics"]
            )

            # Store daily statistics
            await _store_daily_stats(daily_stats, db)

            logger.info(
                f"Daily statistics calculated for {len(daily_stats['device_statistics'])} devices"
            )

            return daily_stats

    except Exception as e:
        logger.error(f"Error calculating daily statistics: {e}")
        return {"status": "error", "message": str(e)}


async def _calculate_device_daily_stats(
    device_id: str,
    day_start: datetime,
    day_end: datetime,
    db,
    spl_service: SPLCalculationService,
) -> Dict[str, Any]:
    """Calculate comprehensive daily statistics for a device."""

    try:
        # Get all measurements for the day
        measurements = await _get_device_measurements(device_id, day_start, day_end, db)
        events = await _get_device_events(device_id, day_start, day_end, db)

        if not measurements:
            return None

        spl_values = [m.get("spl_db", 0.0) for m in measurements]

        # Basic statistics
        basic_stats = spl_service.calculate_noise_statistics(spl_values)

        # Time-period analysis (day/evening/night)
        period_stats = {}
        for period, hours in [
            ("day", range(7, 19)),
            ("evening", range(19, 23)),
            ("night", list(range(0, 7)) + [23]),
        ]:
            period_measurements = [
                m
                for m in measurements
                if m.get("timestamp", datetime.min).hour in hours
            ]

            if period_measurements:
                period_spl = [m.get("spl_db", 0.0) for m in period_measurements]
                period_stats[period] = {
                    "statistics": spl_service.calculate_noise_statistics(period_spl),
                    "measurement_count": len(period_measurements),
                    "compliance": spl_service.check_regulatory_compliance(
                        spl_service.calculate_leq(period_spl), period
                    ),
                }

        # Hourly pattern analysis
        hourly_patterns = {}
        for hour in range(24):
            hour_measurements = [
                m for m in measurements if m.get("timestamp", datetime.min).hour == hour
            ]

            if hour_measurements:
                hour_spl = [m.get("spl_db", 0.0) for m in hour_measurements]
                hourly_patterns[str(hour)] = {
                    "avg_spl": statistics.mean(hour_spl),
                    "measurement_count": len(hour_measurements),
                }

        # Event analysis
        event_analysis = {
            "total_events": len(events),
            "event_types": {},
            "peak_event_time": None,
            "longest_event_duration": 0,
        }

        if events:
            # Analyze event types
            for event in events:
                event_type = event.get("rule_triggered", "unknown")
                event_analysis["event_types"][event_type] = (
                    event_analysis["event_types"].get(event_type, 0) + 1
                )

            # Find peak event
            peak_event = max(events, key=lambda e: e.get("peak_level_db", 0))
            event_analysis["peak_event_time"] = (
                peak_event.get("start_time", "").isoformat()
                if hasattr(peak_event.get("start_time", ""), "isoformat")
                else str(peak_event.get("start_time", ""))
            )

            # Find longest event
            longest_event = max(events, key=lambda e: e.get("duration_seconds", 0))
            event_analysis["longest_event_duration"] = longest_event.get(
                "duration_seconds", 0
            )

        return {
            "device_id": device_id,
            "date": day_start.date().isoformat(),
            "basic_statistics": basic_stats,
            "period_analysis": period_stats,
            "hourly_patterns": hourly_patterns,
            "event_analysis": event_analysis,
            "data_quality": {
                "total_measurements": len(measurements),
                "expected_measurements": 24 * 60,  # 1 per minute
                "coverage_percent": (len(measurements) / (24 * 60)) * 100,
                "uptime_percent": _calculate_device_uptime(
                    measurements, day_start, day_end
                ),
            },
        }

    except Exception as e:
        logger.error(f"Error calculating device daily stats for {device_id}: {e}")
        return None


def _calculate_device_uptime(
    measurements: List[Dict], start_time: datetime, end_time: datetime
) -> float:
    """Calculate device uptime percentage based on measurement intervals."""
    if not measurements:
        return 0.0

    # Sort measurements by timestamp
    sorted_measurements = sorted(
        measurements, key=lambda m: m.get("timestamp", datetime.min)
    )

    # Calculate gaps between measurements
    total_duration = (end_time - start_time).total_seconds()
    gap_duration = 0

    for i in range(len(sorted_measurements) - 1):
        current_time = sorted_measurements[i].get("timestamp", datetime.min)
        next_time = sorted_measurements[i + 1].get("timestamp", datetime.min)

        gap = (next_time - current_time).total_seconds()
        if gap > 300:  # Gap longer than 5 minutes indicates downtime
            gap_duration += gap - 60  # Allow for normal 1-minute intervals

    uptime_duration = total_duration - gap_duration
    return max(0, min(100, (uptime_duration / total_duration) * 100))


async def _perform_geographic_analysis(
    start_time: datetime, end_time: datetime, db
) -> Dict[str, Any]:
    """Perform geographic analysis of noise patterns."""

    try:
        geo_service = GeospatialService()

        # This would perform actual geographic analysis
        # For now, return placeholder data

        return {
            "hotspots_detected": 3,
            "hotspot_locations": [
                {"lat": 52.5200, "lng": 13.4050, "avg_spl_db": 68.5, "event_count": 15},
                {"lat": 52.5100, "lng": 13.4000, "avg_spl_db": 65.2, "event_count": 12},
                {"lat": 52.5150, "lng": 13.4100, "avg_spl_db": 63.8, "event_count": 9},
            ],
            "spatial_clusters": 2,
            "coverage_area_km2": 25.3,
            "average_device_density": 0.8,  # devices per km²
        }

    except Exception as e:
        logger.error(f"Error in geographic analysis: {e}")
        return {"error": str(e)}


async def _perform_trend_analysis(current_date, db) -> Dict[str, Any]:
    """Perform trend analysis comparing with previous periods."""

    try:
        # Compare with previous day, week, month
        trends = {
            "daily_trend": await _calculate_period_trend(current_date, 1, db),
            "weekly_trend": await _calculate_period_trend(current_date, 7, db),
            "monthly_trend": await _calculate_period_trend(current_date, 30, db),
        }

        return trends

    except Exception as e:
        logger.error(f"Error in trend analysis: {e}")
        return {"error": str(e)}


async def _calculate_period_trend(current_date, days_back: int, db) -> Dict[str, Any]:
    """Calculate trend comparison for a specific period."""

    # This would compare statistics between periods
    # For now, return placeholder data

    return {
        "period_days": days_back,
        "noise_level_change_db": -1.2,  # Negative means decrease
        "event_count_change_percent": 5.3,  # Positive means increase
        "compliance_rate_change_percent": 2.1,
        "trend_direction": "improving",  # improving, worsening, stable
    }


async def _calculate_system_daily_summary(
    device_statistics: Dict[str, Any],
) -> Dict[str, Any]:
    """Calculate system-wide daily summary."""

    if not device_statistics:
        return {"error": "No device statistics available"}

    # Aggregate across all devices
    all_leq_values = []
    total_events = 0
    total_measurements = 0
    compliance_violations = 0

    for device_stats in device_statistics.values():
        all_leq_values.append(device_stats["basic_statistics"]["leq"])
        total_events += device_stats["event_analysis"]["total_events"]
        total_measurements += device_stats["data_quality"]["total_measurements"]

        # Count compliance violations
        for period_stats in device_stats["period_analysis"].values():
            if period_stats["compliance"]["status"] != "compliant":
                compliance_violations += 1

    return {
        "total_devices": len(device_statistics),
        "system_avg_leq_db": statistics.mean(all_leq_values) if all_leq_values else 0.0,
        "system_max_leq_db": max(all_leq_values) if all_leq_values else 0.0,
        "system_min_leq_db": min(all_leq_values) if all_leq_values else 0.0,
        "total_events_detected": total_events,
        "total_measurements": total_measurements,
        "compliance_violations": compliance_violations,
        "system_uptime_percent": statistics.mean(
            [
                device_stats["data_quality"]["uptime_percent"]
                for device_stats in device_statistics.values()
            ]
        )
        if device_statistics
        else 0.0,
        "data_coverage_percent": statistics.mean(
            [
                device_stats["data_quality"]["coverage_percent"]
                for device_stats in device_statistics.values()
            ]
        )
        if device_statistics
        else 0.0,
    }


# Helper functions for database queries


async def _get_active_devices(db) -> List[str]:
    """Get list of active device IDs."""
    from sqlalchemy import select
    from app.db.models.device import Device
    result = await db.execute(
        select(Device.device_id).where(Device.is_active == True)
    )
    return [row[0] for row in result.all()]


async def _get_device_measurements(
    device_id: str, start_time: datetime, end_time: datetime, db
) -> List[Dict]:
    """Get events for a device in time range (events serve as measurements)."""
    from sqlalchemy import select
    from app.db.models.event import Event
    from app.db.models.device import Device

    # Find device by public device_id, then query events by the internal UUID.
    device_result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = device_result.scalar_one_or_none()
    if not device:
        return []

    result = await db.execute(
        select(Event)
        .where(Event.device_id == device.id)
        .where(Event.timestamp_start >= start_time)
        .where(Event.timestamp_start < end_time)
    )
    events = result.scalars().all()
    return [
        {
            "spl_db": float(e.leq_db),
            "timestamp": e.timestamp_start,
            "device_id": device_id,
        }
        for e in events
    ]


async def _get_device_events(
    device_id: str, start_time: datetime, end_time: datetime, db
) -> List[Dict]:
    """Get events with rule_triggered for a device."""
    from sqlalchemy import select
    from app.db.models.event import Event
    from app.db.models.device import Device

    device_result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = device_result.scalar_one_or_none()
    if not device:
        return []

    result = await db.execute(
        select(Event)
        .where(Event.device_id == device.id)
        .where(Event.timestamp_start >= start_time)
        .where(Event.timestamp_start < end_time)
        .where(Event.rule_triggered.is_not(None))
    )
    events = result.scalars().all()
    return [
        {
            "rule_triggered": e.rule_triggered,
            "peak_level_db": float(e.lmax_db) if e.lmax_db else float(e.leq_db),
            "start_time": e.timestamp_start,
            "duration_seconds": (e.timestamp_end - e.timestamp_start).total_seconds()
            if e.timestamp_end and e.timestamp_start
            else 0,
        }
        for e in events
    ]


def _identify_dominant_sources(events: List[Dict]) -> List[str]:
    """Identify dominant noise sources from events."""
    if not events:
        return []

    source_counts = {}
    for event in events:
        source = event.get("rule_triggered", "unknown")
        source_counts[source] = source_counts.get(source, 0) + 1

    # Return sources sorted by frequency
    return sorted(source_counts.keys(), key=lambda s: source_counts[s], reverse=True)


async def _store_hourly_device_stats(stats: Dict[str, Any], db):
    """Store as EventAggregation."""
    from sqlalchemy import select
    from app.db.models.event import EventAggregation
    from app.db.models.device import Device

    device_result = await db.execute(
        select(Device).where(Device.device_id == stats["device_id"])
    )
    device = device_result.scalar_one_or_none()
    if not device:
        return

    agg = EventAggregation(
        device_id=device.id,
        time_bucket=datetime.fromisoformat(stats["hour_start"]),
        bucket_duration=str(timedelta(hours=1)),
        avg_leq_db=stats["statistics"]["leq"],
        max_leq_db=stats["statistics"]["lmax"],
        min_leq_db=stats["statistics"]["lmin"],
        event_count=stats["event_count"],
        exceedance_count=stats["event_count"],
    )
    db.add(agg)
    await db.flush()


async def _store_hourly_system_stats(stats: Dict[str, Any], hour_start: datetime, db):
    """Store hourly system statistics."""
    # No table for system stats yet
    pass


async def _store_daily_stats(stats: Dict[str, Any], db):
    """Store daily statistics."""
    # No table for daily stats yet
    pass
