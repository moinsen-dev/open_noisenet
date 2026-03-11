"""
Celery application configuration for OpenNoiseNet background tasks.
"""

import os
from celery import Celery
from kombu import Queue

from app.core.config import settings

# Create Celery instance
celery_app = Celery(
    "noisenet_worker",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=[
        "app.workers.noise_processing_tasks",
        "app.workers.data_aggregation_tasks",
        "app.workers.notification_tasks",
        "app.workers.maintenance_tasks",
        "app.workers.ai_processing_tasks",
    ],
)

# Celery configuration
celery_app.conf.update(
    # Task settings
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    # Worker settings
    worker_prefetch_multiplier=1,
    task_acks_late=True,
    worker_max_tasks_per_child=1000,
    # Queue settings
    task_default_queue="default",
    task_routes={
        # High priority tasks
        "app.workers.noise_processing_tasks.process_real_time_measurement": {
            "queue": "realtime"
        },
        "app.workers.notification_tasks.send_alert_notification": {
            "queue": "notifications"
        },
        # Medium priority tasks
        "app.workers.ai_processing_tasks.analyze_noise_event": {
            "queue": "ai_processing"
        },
        "app.workers.data_aggregation_tasks.calculate_hourly_statistics": {
            "queue": "aggregation"
        },
        # Low priority tasks
        "app.workers.maintenance_tasks.cleanup_old_data": {"queue": "maintenance"},
        "app.workers.maintenance_tasks.generate_daily_reports": {
            "queue": "maintenance"
        },
    },
    # Define queues with different priorities
    task_queues=(
        Queue(
            "realtime", routing_key="realtime", queue_arguments={"x-max-priority": 10}
        ),
        Queue(
            "notifications",
            routing_key="notifications",
            queue_arguments={"x-max-priority": 8},
        ),
        Queue(
            "ai_processing",
            routing_key="ai_processing",
            queue_arguments={"x-max-priority": 6},
        ),
        Queue(
            "aggregation",
            routing_key="aggregation",
            queue_arguments={"x-max-priority": 4},
        ),
        Queue(
            "maintenance",
            routing_key="maintenance",
            queue_arguments={"x-max-priority": 1},
        ),
        Queue("default", routing_key="default", queue_arguments={"x-max-priority": 5}),
    ),
    # Beat schedule for periodic tasks
    beat_schedule={
        # Real-time data processing (every minute)
        "process-pending-measurements": {
            "task": "app.workers.noise_processing_tasks.process_pending_measurements",
            "schedule": 60.0,  # Every minute
        },
        # Hourly aggregations
        "calculate-hourly-statistics": {
            "task": "app.workers.data_aggregation_tasks.calculate_hourly_statistics",
            "schedule": 3600.0,  # Every hour
        },
        # Daily aggregations
        "calculate-daily-statistics": {
            "task": "app.workers.data_aggregation_tasks.calculate_daily_statistics",
            "schedule": 86400.0,  # Every day at midnight
        },
        # Cleanup tasks (daily)
        "cleanup-old-data": {
            "task": "app.workers.maintenance_tasks.cleanup_old_data",
            "schedule": 86400.0,  # Every day
        },
        # Health checks (every 5 minutes)
        "system-health-check": {
            "task": "app.workers.maintenance_tasks.system_health_check",
            "schedule": 300.0,  # Every 5 minutes
        },
        # Generate reports (weekly)
        "generate-weekly-reports": {
            "task": "app.workers.maintenance_tasks.generate_weekly_reports",
            "schedule": 604800.0,  # Every week
        },
    },
    # Result backend settings
    result_expires=3600,  # Results expire after 1 hour
    result_backend_transport_options={
        "master_name": "mymaster",
        "retry_on_timeout": True,
    },
    # Error handling
    task_reject_on_worker_lost=True,
    task_ignore_result=False,
    # Logging
    worker_log_format="[%(asctime)s: %(levelname)s/%(processName)s/%(name)s] %(message)s",
    worker_task_log_format="[%(asctime)s: %(levelname)s/%(processName)s/%(name)s/%(task_name)s(%(task_id)s)] %(message)s",
)

# Import tasks to register them
from app.workers import (
    noise_processing_tasks,
    data_aggregation_tasks,
    notification_tasks,
    maintenance_tasks,
    ai_processing_tasks,
)

if __name__ == "__main__":
    celery_app.start()
