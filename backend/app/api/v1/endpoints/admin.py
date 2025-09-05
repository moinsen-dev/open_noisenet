"""Admin endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/stats")
async def get_admin_stats():
    """Get system statistics for admin dashboard."""
    return {"message": "Get admin stats - TODO"}


@router.get("/devices")
async def get_admin_devices():
    """Get all devices for admin management."""
    return {"message": "Get admin devices - TODO"}


@router.get("/system-health")
async def get_system_health():
    """Get system health metrics."""
    return {"message": "Get system health - TODO"}