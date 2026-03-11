"""Map visualization schemas."""

from typing import Any, Dict, List, Optional

from pydantic import BaseModel


class MapEventFeature(BaseModel):
    type: str = "Feature"
    geometry: Dict[str, Any]
    properties: Dict[str, Any]


class GeoJSONResponse(BaseModel):
    type: str = "FeatureCollection"
    features: List[MapEventFeature]


class HeatmapPoint(BaseModel):
    lat: float
    lng: float
    intensity: float
    event_count: int


class HeatmapResponse(BaseModel):
    points: List[HeatmapPoint]
    min_intensity: Optional[float] = None
    max_intensity: Optional[float] = None


class MapStats(BaseModel):
    total_events: int
    total_devices: int
    avg_leq_db: Optional[float] = None
    max_leq_db: Optional[float] = None
    active_devices_24h: int
    events_24h: int
