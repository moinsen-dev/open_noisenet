"""Admin endpoints.

The admin surface exists in the codebase but is not released as part of the MVP.
"""

from fastapi import APIRouter, HTTPException, status

router = APIRouter()


@router.get("/stats")
async def get_admin_stats():
    """Admin APIs are intentionally out of scope for the current MVP."""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Admin APIs are not part of the current MVP release.",
    )


@router.get("/devices")
async def get_admin_devices():
    """Admin APIs are intentionally out of scope for the current MVP."""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Admin APIs are not part of the current MVP release.",
    )


@router.get("/system-health")
async def get_system_health():
    """Admin APIs are intentionally out of scope for the current MVP."""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Admin APIs are not part of the current MVP release.",
    )
