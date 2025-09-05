"""Map data endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/events")
async def get_map_events():
    """Get events in GeoJSON format for map display."""
    return {"message": "Get map events - TODO"}


@router.get("/heatmap")
async def get_heatmap_data():
    """Get aggregated data for heatmap visualization."""
    return {"message": "Get heatmap data - TODO"}


@router.get("/stats")
async def get_map_statistics():
    """Get general statistics for map display."""
    return {"message": "Get map statistics - TODO"}