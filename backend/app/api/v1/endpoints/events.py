"""Noise event endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.post("/")
async def create_event():
    """Create a new noise event."""
    return {"message": "Create event - TODO"}


@router.get("/")
async def list_events():
    """List noise events with filtering."""
    return {"message": "List events - TODO"}


@router.get("/{event_id}")
async def get_event(event_id: str):
    """Get specific event details."""
    return {"message": f"Get event {event_id} - TODO"}


@router.delete("/{event_id}")
async def delete_event(event_id: str):
    """Delete a noise event."""
    return {"message": f"Delete event {event_id} - TODO"}