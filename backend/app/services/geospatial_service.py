"""
Geospatial service for location-based noise event queries and spatial analysis.
Implements efficient spatial clustering and heatmap generation.
"""

import math
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
import json
import logging
from dataclasses import dataclass
from enum import Enum

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func, text
from geoalchemy2 import Geometry
from geoalchemy2.functions import ST_DWithin, ST_Distance, ST_MakePoint, ST_Transform

from app.core.logging import get_logger
from app.db.models.noise_event import NoiseEvent
from app.db.models.device import Device

logger = get_logger(__name__)


class HeatmapResolution(Enum):
    """Heatmap resolution levels."""

    LOW = "low"  # ~1km grid
    MEDIUM = "medium"  # ~500m grid
    HIGH = "high"  # ~100m grid
    ULTRA = "ultra"  # ~50m grid


@dataclass
class BoundingBox:
    """Geographic bounding box."""

    min_lat: float
    min_lng: float
    max_lat: float
    max_lng: float

    def center(self) -> Tuple[float, float]:
        """Get center point of bounding box."""
        return ((self.min_lat + self.max_lat) / 2, (self.min_lng + self.max_lng) / 2)

    def area_km2(self) -> float:
        """Approximate area in square kilometers."""
        lat_diff = self.max_lat - self.min_lat
        lng_diff = self.max_lng - self.min_lng

        # Rough approximation (not accounting for Earth's curvature)
        lat_km = lat_diff * 111.32  # 1 degree lat ≈ 111.32 km
        center_lat = (self.min_lat + self.max_lat) / 2
        lng_km = lng_diff * 111.32 * math.cos(math.radians(center_lat))

        return lat_km * lng_km


@dataclass
class SpatialCluster:
    """Spatial cluster of noise events."""

    center_lat: float
    center_lng: float
    event_count: int
    average_spl_db: float
    max_spl_db: float
    radius_meters: float
    event_ids: List[int]
    cluster_id: str


@dataclass
class HeatmapCell:
    """Single cell in a noise heatmap."""

    lat: float
    lng: float
    value: float
    event_count: int
    cell_size_meters: float


class GeospatialService:
    """Service for geospatial analysis of noise data."""

    # Earth's radius in meters
    EARTH_RADIUS = 6371000

    def __init__(self):
        self.srid_wgs84 = 4326  # WGS84 coordinate system
        self.srid_web_mercator = 3857  # Web Mercator for distance calculations

    @staticmethod
    def calculate_distance_meters(
        lat1: float, lng1: float, lat2: float, lng2: float
    ) -> float:
        """Calculate distance between two points using Haversine formula."""
        # Convert to radians
        lat1_rad = math.radians(lat1)
        lng1_rad = math.radians(lng1)
        lat2_rad = math.radians(lat2)
        lng2_rad = math.radians(lng2)

        # Haversine formula
        dlat = lat2_rad - lat1_rad
        dlng = lng2_rad - lng1_rad

        a = (
            math.sin(dlat / 2) ** 2
            + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlng / 2) ** 2
        )
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return GeospatialService.EARTH_RADIUS * c

    async def get_events_within_radius(
        self,
        center_lat: float,
        center_lng: float,
        radius_meters: float,
        db: AsyncSession,
        time_range_hours: Optional[int] = None,
        min_spl_db: Optional[float] = None,
    ) -> List[Dict[str, Any]]:
        """Get noise events within specified radius of a point."""
        try:
            # Build query
            query = select(NoiseEvent).where(
                ST_DWithin(
                    NoiseEvent.location,
                    ST_Transform(
                        ST_MakePoint(center_lng, center_lat, self.srid_wgs84),
                        self.srid_web_mercator,
                    ),
                    radius_meters,
                )
            )

            # Add time filter
            if time_range_hours:
                cutoff_time = datetime.utcnow() - timedelta(hours=time_range_hours)
                query = query.where(NoiseEvent.start_time >= cutoff_time)

            # Add SPL filter
            if min_spl_db:
                query = query.where(NoiseEvent.average_leq_db >= min_spl_db)

            # Execute query
            result = await db.execute(query)
            events = result.scalars().all()

            # Convert to dict format with distance
            event_list = []
            for event in events:
                # Calculate actual distance
                distance = self.calculate_distance_meters(
                    center_lat, center_lng, event.latitude, event.longitude
                )

                event_dict = {
                    "id": event.id,
                    "device_id": event.device_id,
                    "start_time": event.start_time.isoformat(),
                    "end_time": event.end_time.isoformat() if event.end_time else None,
                    "latitude": event.latitude,
                    "longitude": event.longitude,
                    "average_leq_db": event.average_leq_db,
                    "max_level_db": event.max_level_db,
                    "duration_seconds": event.duration_seconds,
                    "distance_meters": distance,
                    "rule_triggered": event.rule_triggered,
                }
                event_list.append(event_dict)

            # Sort by distance
            event_list.sort(key=lambda x: x["distance_meters"])

            logger.info(
                f"Found {len(event_list)} events within {radius_meters}m radius"
            )
            return event_list

        except Exception as e:
            logger.error(f"Error querying events within radius: {e}")
            return []

    async def generate_heatmap(
        self,
        bbox: BoundingBox,
        resolution: HeatmapResolution,
        db: AsyncSession,
        time_range_hours: Optional[int] = None,
        aggregation_method: str = "average",
    ) -> List[HeatmapCell]:
        """Generate noise heatmap for specified area."""

        # Determine grid size based on resolution
        grid_sizes = {
            HeatmapResolution.LOW: 1000,  # 1km
            HeatmapResolution.MEDIUM: 500,  # 500m
            HeatmapResolution.HIGH: 100,  # 100m
            HeatmapResolution.ULTRA: 50,  # 50m
        }

        cell_size_meters = grid_sizes[resolution]

        try:
            # Calculate grid dimensions
            center_lat, center_lng = bbox.center()

            # Convert degrees to approximate meters at center latitude
            lat_meters_per_degree = 111320
            lng_meters_per_degree = 111320 * math.cos(math.radians(center_lat))

            lat_cell_size = cell_size_meters / lat_meters_per_degree
            lng_cell_size = cell_size_meters / lng_meters_per_degree

            # Generate grid points
            heatmap_cells = []

            lat = bbox.min_lat
            while lat <= bbox.max_lat:
                lng = bbox.min_lng
                while lng <= bbox.max_lng:
                    # Get events within this cell
                    cell_events = await self.get_events_within_radius(
                        lat, lng, cell_size_meters / 2, db, time_range_hours
                    )

                    if cell_events:
                        # Calculate aggregated value
                        spl_values = [event["average_leq_db"] for event in cell_events]

                        if aggregation_method == "average":
                            cell_value = sum(spl_values) / len(spl_values)
                        elif aggregation_method == "max":
                            cell_value = max(spl_values)
                        elif aggregation_method == "count":
                            cell_value = len(spl_values)
                        else:
                            cell_value = sum(spl_values) / len(
                                spl_values
                            )  # Default to average

                        heatmap_cells.append(
                            HeatmapCell(
                                lat=lat,
                                lng=lng,
                                value=cell_value,
                                event_count=len(cell_events),
                                cell_size_meters=cell_size_meters,
                            )
                        )

                    lng += lng_cell_size
                lat += lat_cell_size

            logger.info(f"Generated heatmap with {len(heatmap_cells)} cells")
            return heatmap_cells

        except Exception as e:
            logger.error(f"Error generating heatmap: {e}")
            return []

    async def find_spatial_clusters(
        self,
        bbox: BoundingBox,
        db: AsyncSession,
        cluster_radius_meters: float = 500,
        min_events_per_cluster: int = 3,
        time_range_hours: Optional[int] = None,
    ) -> List[SpatialCluster]:
        """Find spatial clusters of noise events using DBSCAN-like algorithm."""

        try:
            # Get all events in bounding box
            query = select(NoiseEvent).where(
                and_(
                    NoiseEvent.latitude.between(bbox.min_lat, bbox.max_lat),
                    NoiseEvent.longitude.between(bbox.min_lng, bbox.max_lng),
                )
            )

            if time_range_hours:
                cutoff_time = datetime.utcnow() - timedelta(hours=time_range_hours)
                query = query.where(NoiseEvent.start_time >= cutoff_time)

            result = await db.execute(query)
            events = result.scalars().all()

            if len(events) < min_events_per_cluster:
                return []

            # Convert to list of points
            points = [
                {
                    "id": event.id,
                    "lat": event.latitude,
                    "lng": event.longitude,
                    "spl_db": event.average_leq_db,
                    "event": event,
                }
                for event in events
            ]

            # Simple clustering algorithm
            clusters = []
            visited = set()

            for i, point in enumerate(points):
                if i in visited:
                    continue

                # Find all points within cluster radius
                cluster_points = [point]
                visited.add(i)

                for j, other_point in enumerate(points):
                    if j in visited or i == j:
                        continue

                    distance = self.calculate_distance_meters(
                        point["lat"],
                        point["lng"],
                        other_point["lat"],
                        other_point["lng"],
                    )

                    if distance <= cluster_radius_meters:
                        cluster_points.append(other_point)
                        visited.add(j)

                # Create cluster if enough points
                if len(cluster_points) >= min_events_per_cluster:
                    cluster = self._create_cluster_from_points(
                        cluster_points, cluster_radius_meters
                    )
                    clusters.append(cluster)

            logger.info(f"Found {len(clusters)} spatial clusters")
            return clusters

        except Exception as e:
            logger.error(f"Error finding spatial clusters: {e}")
            return []

    def _create_cluster_from_points(
        self, points: List[Dict[str, Any]], radius_meters: float
    ) -> SpatialCluster:
        """Create a spatial cluster from a list of points."""

        # Calculate center (centroid)
        center_lat = sum(p["lat"] for p in points) / len(points)
        center_lng = sum(p["lng"] for p in points) / len(points)

        # Calculate statistics
        spl_values = [p["spl_db"] for p in points]
        average_spl = sum(spl_values) / len(spl_values)
        max_spl = max(spl_values)

        # Get event IDs
        event_ids = [p["id"] for p in points]

        # Generate cluster ID
        cluster_id = f"cluster_{int(center_lat * 1000000)}_{int(center_lng * 1000000)}"

        return SpatialCluster(
            center_lat=center_lat,
            center_lng=center_lng,
            event_count=len(points),
            average_spl_db=average_spl,
            max_spl_db=max_spl,
            radius_meters=radius_meters,
            event_ids=event_ids,
            cluster_id=cluster_id,
        )

    async def get_noise_statistics_by_area(
        self,
        bbox: BoundingBox,
        db: AsyncSession,
        time_range_hours: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Get comprehensive noise statistics for a geographic area."""

        try:
            # Get all events in area
            events = await self.get_events_within_radius(
                *bbox.center(),
                self.calculate_distance_meters(
                    *bbox.center(), bbox.max_lat, bbox.max_lng
                ),
                db,
                time_range_hours,
            )

            if not events:
                return {"error": "No events found in specified area"}

            # Calculate statistics
            spl_values = [event["average_leq_db"] for event in events]
            durations = [event["duration_seconds"] for event in events]

            # Basic statistics
            stats = {
                "area_km2": bbox.area_km2(),
                "total_events": len(events),
                "time_range_hours": time_range_hours,
                "spl_statistics": {
                    "min": min(spl_values),
                    "max": max(spl_values),
                    "average": sum(spl_values) / len(spl_values),
                    "median": sorted(spl_values)[len(spl_values) // 2],
                },
                "duration_statistics": {
                    "min_seconds": min(durations),
                    "max_seconds": max(durations),
                    "average_seconds": sum(durations) / len(durations),
                    "total_hours": sum(durations) / 3600,
                },
                "event_density_per_km2": len(events) / bbox.area_km2(),
                "unique_devices": len(set(event["device_id"] for event in events)),
            }

            # Time distribution
            hour_counts = {}
            for event in events:
                hour = datetime.fromisoformat(event["start_time"]).hour
                hour_counts[hour] = hour_counts.get(hour, 0) + 1

            stats["hourly_distribution"] = hour_counts

            # Rule distribution
            rule_counts = {}
            for event in events:
                rule = event.get("rule_triggered", "unknown")
                rule_counts[rule] = rule_counts.get(rule, 0) + 1

            stats["rule_distribution"] = rule_counts

            return stats

        except Exception as e:
            logger.error(f"Error calculating area statistics: {e}")
            return {"error": str(e)}

    async def find_hotspots(
        self,
        bbox: BoundingBox,
        db: AsyncSession,
        hotspot_threshold_events: int = 10,
        radius_meters: float = 1000,
        time_range_hours: Optional[int] = 24,
    ) -> List[Dict[str, Any]]:
        """Find noise hotspots (areas with high event density)."""

        try:
            # Generate a coarse grid for hotspot detection
            grid_size_deg = 0.01  # ~1km at equator
            hotspots = []

            lat = bbox.min_lat
            while lat <= bbox.max_lat:
                lng = bbox.min_lng
                while lng <= bbox.max_lng:
                    # Count events in this area
                    events = await self.get_events_within_radius(
                        lat, lng, radius_meters, db, time_range_hours
                    )

                    if len(events) >= hotspot_threshold_events:
                        # Calculate hotspot statistics
                        spl_values = [event["average_leq_db"] for event in events]

                        hotspot = {
                            "center_lat": lat,
                            "center_lng": lng,
                            "radius_meters": radius_meters,
                            "event_count": len(events),
                            "average_spl_db": sum(spl_values) / len(spl_values),
                            "max_spl_db": max(spl_values),
                            "unique_devices": len(
                                set(event["device_id"] for event in events)
                            ),
                            "severity_score": len(events)
                            * (sum(spl_values) / len(spl_values))
                            / 1000,
                        }
                        hotspots.append(hotspot)

                    lng += grid_size_deg
                lat += grid_size_deg

            # Sort by severity score
            hotspots.sort(key=lambda x: x["severity_score"], reverse=True)

            logger.info(f"Found {len(hotspots)} noise hotspots")
            return hotspots

        except Exception as e:
            logger.error(f"Error finding hotspots: {e}")
            return []

    def calculate_optimal_zoom_level(
        self, bbox: BoundingBox, map_width_pixels: int = 800
    ) -> int:
        """Calculate optimal map zoom level for given bounding box."""

        # Calculate the span in degrees
        lat_span = bbox.max_lat - bbox.min_lat
        lng_span = bbox.max_lng - bbox.min_lng

        # Web Mercator projection zoom levels
        # Each zoom level doubles the resolution
        for zoom in range(1, 20):
            # At each zoom level, calculate degrees per pixel
            degrees_per_pixel_lat = 180 / (256 * (2**zoom))
            degrees_per_pixel_lng = 360 / (256 * (2**zoom))

            # Check if bbox fits in map width
            if (
                lat_span / degrees_per_pixel_lat <= map_width_pixels
                and lng_span / degrees_per_pixel_lng <= map_width_pixels
            ):
                return zoom

        return 18  # Maximum practical zoom

    def get_geospatial_capabilities(self) -> Dict[str, Any]:
        """Get information about geospatial service capabilities."""
        return {
            "coordinate_systems": [self.srid_wgs84, self.srid_web_mercator],
            "distance_calculation": "Haversine formula",
            "clustering_algorithm": "DBSCAN-like spatial clustering",
            "heatmap_resolutions": [res.value for res in HeatmapResolution],
            "max_query_radius_km": 50,
            "max_heatmap_cells": 10000,
            "supported_aggregations": ["average", "max", "count"],
            "hotspot_detection": True,
            "spatial_statistics": True,
        }
