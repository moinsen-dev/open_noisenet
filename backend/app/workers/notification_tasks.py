"""
Celery tasks for notification and alert management.
"""

import asyncio
from datetime import datetime
from typing import Dict, Any, List
import json
import logging

from app.workers.celery_app import celery_app
from app.workers.noise_processing_tasks import AsyncTask
from app.core.logging import get_logger

logger = get_logger(__name__)


@celery_app.task(bind=True, base=AsyncTask, name="send_alert_notification")
async def send_alert_notification(self, device_id: str, alert_data: Dict[str, Any]):
    """
    Send alert notification for noise threshold exceedance.

    Args:
        device_id: ID of the device that triggered the alert
        alert_data: Alert details including severity, SPL level, etc.
    """
    try:
        logger.info(f"Sending alert notification for device {device_id}")

        event_type = alert_data.get("event_type", "threshold_exceedance")
        severity = alert_data.get("severity", "medium")
        spl_db = alert_data.get("spl_db", 0.0)
        rule = alert_data.get("rule", "unknown")
        location = alert_data.get("location", {})

        # Format notification message
        message = _format_alert_message(event_type, severity, spl_db, rule)

        # Send to different channels based on severity
        notification_result = {
            "device_id": device_id,
            "event_type": event_type,
            "severity": severity,
            "message": message,
            "timestamp": datetime.utcnow().isoformat(),
            "channels_sent": [],
        }

        # Email notifications for high/critical severity
        if severity in ["high", "critical"]:
            email_sent = await _send_email_notification(device_id, message, alert_data)
            if email_sent:
                notification_result["channels_sent"].append("email")

        # Push notifications for all alerts
        push_sent = await _send_push_notification(device_id, message, alert_data)
        if push_sent:
            notification_result["channels_sent"].append("push")

        # SMS for critical alerts
        if severity == "critical" and spl_db > 90:
            sms_sent = await _send_sms_notification(device_id, message, alert_data)
            if sms_sent:
                notification_result["channels_sent"].append("sms")

        # Log to notification system
        await _log_notification(notification_result)

        logger.info(
            f"Alert notification sent for device {device_id} via {len(notification_result['channels_sent'])} channels"
        )

        return notification_result

    except Exception as e:
        logger.error(f"Error sending alert notification for device {device_id}: {e}")
        self.retry(countdown=60, max_retries=3)


@celery_app.task(bind=True, base=AsyncTask, name="send_ai_analysis_notification")
async def send_ai_analysis_notification(
    self, device_id: str, analysis_result: Dict[str, Any]
):
    """
    Send notification with AI analysis results.

    Args:
        device_id: ID of the device
        analysis_result: AI analysis results
    """
    try:
        logger.info(f"Sending AI analysis notification for device {device_id}")

        classification = analysis_result.get("classification", {})
        primary_category = classification.get("primary_category", "unknown")
        confidence = analysis_result.get("confidence_score", 0.0)
        recommendations = analysis_result.get("recommendations", [])

        # Only send notifications for high-confidence, actionable results
        if confidence < 0.7:
            logger.info(
                f"Skipping AI notification for device {device_id} - low confidence ({confidence})"
            )
            return {"status": "skipped", "reason": "low_confidence"}

        # Format AI analysis message
        message = _format_ai_analysis_message(
            primary_category, confidence, recommendations
        )

        # Send via appropriate channels
        notification_channels = []

        # Push notification with analysis summary
        push_sent = await _send_push_notification(
            device_id,
            message,
            {
                "type": "ai_analysis",
                "category": primary_category,
                "confidence": confidence,
            },
        )
        if push_sent:
            notification_channels.append("push")

        # Email with detailed analysis for significant events
        if confidence > 0.8 and primary_category in [
            "construction_activity",
            "traffic_noise",
            "industrial_noise",
        ]:
            detailed_message = _format_detailed_ai_message(analysis_result)
            email_sent = await _send_email_notification(
                device_id,
                detailed_message,
                {"type": "ai_analysis_detailed", "analysis": analysis_result},
            )
            if email_sent:
                notification_channels.append("email")

        result = {
            "device_id": device_id,
            "notification_type": "ai_analysis",
            "primary_category": primary_category,
            "confidence": confidence,
            "channels_sent": notification_channels,
            "timestamp": datetime.utcnow().isoformat(),
        }

        await _log_notification(result)

        logger.info(
            f"AI analysis notification sent for device {device_id}: {primary_category}"
        )

        return result

    except Exception as e:
        logger.error(
            f"Error sending AI analysis notification for device {device_id}: {e}"
        )
        return {"status": "error", "message": str(e)}


def _format_alert_message(
    event_type: str, severity: str, spl_db: float, rule: str
) -> str:
    """Format alert notification message."""
    severity_labels = {
        "low": "🟢 Low",
        "medium": "🟡 Medium",
        "high": "🟠 High",
        "critical": "🔴 Critical",
    }

    severity_label = severity_labels.get(severity, severity.title())

    if event_type == "threshold_exceedance":
        return (
            f"{severity_label} Noise Alert\n"
            f"Sound level: {spl_db:.1f} dB\n"
            f"Rule triggered: {rule}\n"
            f"Time: {datetime.utcnow().strftime('%H:%M')}"
        )
    elif event_type == "anomaly_detection":
        return (
            f"{severity_label} Noise Anomaly\n"
            f"Unusual sound pattern detected\n"
            f"Level: {spl_db:.1f} dB\n"
            f"Time: {datetime.utcnow().strftime('%H:%M')}"
        )
    else:
        return f"{severity_label} Noise Event: {spl_db:.1f} dB at {datetime.utcnow().strftime('%H:%M')}"


def _format_ai_analysis_message(
    category: str, confidence: float, recommendations: List[str]
) -> str:
    """Format AI analysis notification message."""
    category_labels = {
        "traffic_noise": "🚗 Traffic Noise",
        "construction_activity": "🚧 Construction Activity",
        "aircraft_noise": "✈️ Aircraft Noise",
        "industrial_noise": "🏭 Industrial Noise",
        "human_activity": "👥 Human Activity",
        "emergency_vehicle": "🚨 Emergency Vehicle",
        "natural_sounds": "🌿 Natural Sounds",
        "building_systems": "🏢 Building Systems",
    }

    category_label = category_labels.get(category, category.replace("_", " ").title())
    confidence_pct = int(confidence * 100)

    message = (
        f"🤖 AI Analysis Complete\n"
        f"Source: {category_label}\n"
        f"Confidence: {confidence_pct}%\n"
    )

    if recommendations:
        top_recommendation = recommendations[0]
        message += f"Recommendation: {top_recommendation}"

    return message


def _format_detailed_ai_message(analysis_result: Dict[str, Any]) -> str:
    """Format detailed AI analysis for email."""
    classification = analysis_result.get("classification", {})
    detailed_analysis = analysis_result.get("detailed_analysis", {})
    context = analysis_result.get("context", {})

    message = f"""
OpenNoiseNet - Detailed AI Analysis Report

Event Details:
- Category: {classification.get("primary_category", "Unknown").replace("_", " ").title()}
- Confidence: {int(analysis_result.get("confidence_score", 0) * 100)}%
- Peak Level: {context.get("peak_level_db", 0):.1f} dB
- Duration: {context.get("duration_seconds", 0):.0f} seconds
- Time: {context.get("time_of_day", "Unknown")}

Health Impact: {detailed_analysis.get("health_impact", "Unknown").title()}

Regulatory Compliance:
- Status: {detailed_analysis.get("compliance", {}).get("status", "Unknown").title()}
- Applicable Limit: {detailed_analysis.get("compliance", {}).get("applicable_limit_db", 0)} dB
- Exceedance: {detailed_analysis.get("compliance", {}).get("exceedance_db", 0):.1f} dB

Recommendations:
"""

    for i, rec in enumerate(analysis_result.get("recommendations", []), 1):
        message += f"{i}. {rec}\n"

    return message


async def _send_email_notification(
    device_id: str, message: str, data: Dict[str, Any]
) -> bool:
    """Send email notification (placeholder implementation)."""
    try:
        # This would integrate with email service (SendGrid, SES, etc.)
        logger.info(f"Email notification would be sent for device {device_id}")

        # Simulate email sending
        await asyncio.sleep(0.1)

        return True

    except Exception as e:
        logger.error(f"Error sending email notification: {e}")
        return False


async def _send_push_notification(
    device_id: str, message: str, data: Dict[str, Any]
) -> bool:
    """Send push notification (placeholder implementation)."""
    try:
        # This would integrate with push notification service (FCM, APNs, etc.)
        logger.info(f"Push notification would be sent for device {device_id}")

        # Simulate push notification
        await asyncio.sleep(0.1)

        return True

    except Exception as e:
        logger.error(f"Error sending push notification: {e}")
        return False


async def _send_sms_notification(
    device_id: str, message: str, data: Dict[str, Any]
) -> bool:
    """Send SMS notification (placeholder implementation)."""
    try:
        # This would integrate with SMS service (Twilio, etc.)
        logger.info(f"SMS notification would be sent for device {device_id}")

        # Simulate SMS sending
        await asyncio.sleep(0.1)

        return True

    except Exception as e:
        logger.error(f"Error sending SMS notification: {e}")
        return False


async def _log_notification(notification_data: Dict[str, Any]):
    """Log notification to database for tracking."""
    try:
        # This would save to notifications table
        logger.info(f"Notification logged: {notification_data['device_id']}")

    except Exception as e:
        logger.error(f"Error logging notification: {e}")


@celery_app.task(bind=True, base=AsyncTask, name="send_daily_summary")
async def send_daily_summary(self, device_id: str):
    """
    Send daily noise summary to device owner.

    Args:
        device_id: ID of the device
    """
    try:
        logger.info(f"Generating daily summary for device {device_id}")

        # This would query daily statistics
        daily_stats = {
            "device_id": device_id,
            "date": datetime.utcnow().date().isoformat(),
            "total_events": 12,
            "avg_spl_db": 58.3,
            "max_spl_db": 78.1,
            "compliance_status": "mostly_compliant",
            "dominant_source": "traffic_noise",
        }

        # Format summary message
        summary_message = f"""
Daily Noise Summary - {daily_stats["date"]}

📊 Statistics:
- Events detected: {daily_stats["total_events"]}
- Average level: {daily_stats["avg_spl_db"]:.1f} dB
- Peak level: {daily_stats["max_spl_db"]:.1f} dB
- Main source: {daily_stats["dominant_source"].replace("_", " ").title()}

✅ Compliance: {daily_stats["compliance_status"].replace("_", " ").title()}

View detailed report: https://opennoisenet.org/reports/{device_id}
"""

        # Send summary notification
        await _send_email_notification(
            device_id, summary_message, {"type": "daily_summary", "stats": daily_stats}
        )

        logger.info(f"Daily summary sent for device {device_id}")

        return {
            "device_id": device_id,
            "summary_type": "daily",
            "stats": daily_stats,
            "sent_at": datetime.utcnow().isoformat(),
        }

    except Exception as e:
        logger.error(f"Error sending daily summary for device {device_id}: {e}")
        return {"status": "error", "message": str(e)}


@celery_app.task(bind=True, base=AsyncTask, name="send_weekly_report")
async def send_weekly_report(self, device_id: str):
    """
    Send weekly noise analysis report.

    Args:
        device_id: ID of the device
    """
    try:
        logger.info(f"Generating weekly report for device {device_id}")

        # This would generate comprehensive weekly statistics
        weekly_stats = {
            "device_id": device_id,
            "week_ending": datetime.utcnow().date().isoformat(),
            "total_events": 89,
            "avg_spl_db": 56.7,
            "trends": "decreasing",
            "recommendations": [
                "Monitor construction activity on weekday mornings",
                "Traffic noise peaks during rush hours",
            ],
        }

        # Generate detailed report (would create PDF or HTML)
        report_url = f"https://opennoisenet.org/reports/weekly/{device_id}"

        report_message = f"""
📈 Weekly Noise Analysis Report

Week ending: {weekly_stats["week_ending"]}
Total events: {weekly_stats["total_events"]}
Average noise level: {weekly_stats["avg_spl_db"]:.1f} dB
Trend: {weekly_stats["trends"].title()}

📋 Key Recommendations:
"""

        for rec in weekly_stats["recommendations"]:
            report_message += f"• {rec}\n"

        report_message += f"\n📊 View full report: {report_url}"

        # Send report
        await _send_email_notification(
            device_id,
            report_message,
            {"type": "weekly_report", "stats": weekly_stats, "report_url": report_url},
        )

        logger.info(f"Weekly report sent for device {device_id}")

        return {
            "device_id": device_id,
            "report_type": "weekly",
            "stats": weekly_stats,
            "report_url": report_url,
            "sent_at": datetime.utcnow().isoformat(),
        }

    except Exception as e:
        logger.error(f"Error sending weekly report for device {device_id}: {e}")
        return {"status": "error", "message": str(e)}
