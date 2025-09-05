"""
API v1 router configuration.
"""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, devices, events, map, snippets, admin

api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(devices.router, prefix="/devices", tags=["devices"])
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(snippets.router, prefix="/snippets", tags=["audio-snippets"])
api_router.include_router(map.router, prefix="/map", tags=["map-data"])
api_router.include_router(admin.router, prefix="/admin", tags=["administration"])