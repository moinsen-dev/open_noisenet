"""
API v1 router configuration.
"""

from fastapi import APIRouter

from app.api.v1.endpoints import (
    account_deletion,
    admin,
    auth,
    devices,
    events,
    map,
    map_pilot,
    pro_domains,
    pro_incidents,
    snippets,
    source_phases,
)

api_router = APIRouter()
api_router.include_router(source_phases.router, prefix="/source-phases", tags=["private-source-phases"])

# Experimental intake only; no public pilot data is exposed.
api_router.include_router(map_pilot.router, prefix="/map-pilot", tags=["map-pilot"])

# Include all endpoint routers
api_router.include_router(account_deletion.router, prefix="/auth", tags=["account-deletion"])
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(devices.router, prefix="/devices", tags=["devices"])
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(snippets.router, prefix="/snippets", tags=["audio-snippets"])
api_router.include_router(map.router, prefix="/map", tags=["map-data"])
api_router.include_router(admin.router, prefix="/admin", tags=["administration"])
api_router.include_router(
    pro_domains.organizations_router, prefix="/organizations", tags=["organizations"]
)
api_router.include_router(pro_domains.sites_router, prefix="/sites", tags=["sites"])
api_router.include_router(pro_domains.zones_router, prefix="/zones", tags=["zones"])
api_router.include_router(
    pro_domains.policies_router, prefix="/policies", tags=["policies"]
)
api_router.include_router(
    pro_domains.calibration_profiles_router,
    prefix="/calibration-profiles",
    tags=["calibration-profiles"],
)
api_router.include_router(
    pro_incidents.episodes_router, prefix="/episodes", tags=["episodes"]
)
api_router.include_router(pro_incidents.cases_router, prefix="/cases", tags=["cases"])
api_router.include_router(
    pro_incidents.exports_router, prefix="/exports", tags=["exports"]
)
