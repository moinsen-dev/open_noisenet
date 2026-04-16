import { useEffect, useRef, useState } from 'react'
import { Alert, Box, Card, CardContent, CircularProgress, Paper, Typography } from '@mui/material'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

import { api, GeoJSONFeature, MapStats } from '../services/api'

interface MapState {
  features: GeoJSONFeature[]
  stats: MapStats | null
  loading: boolean
  error: string | null
}

function getNoiseColor(level?: number): string {
  if (level == null) return '#607D8B'
  if (level < 45) return '#4CAF50'
  if (level < 55) return '#FF9800'
  if (level < 65) return '#FF5722'
  return '#C62828'
}

export default function MapPage() {
  const mapRef = useRef<L.Map | null>(null)
  const layerRef = useRef<L.LayerGroup | null>(null)
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const [state, setState] = useState<MapState>({
    features: [],
    stats: null,
    loading: true,
    error: null,
  })

  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) {
      return
    }

    const map = L.map(mapContainerRef.current).setView([52.520008, 13.404954], 10)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
    }).addTo(map)

    layerRef.current = L.layerGroup().addTo(map)
    mapRef.current = map

    return () => {
      mapRef.current?.remove()
      mapRef.current = null
      layerRef.current = null
    }
  }, [])

  useEffect(() => {
    let cancelled = false

    async function loadMapData() {
      setState((prev) => ({ ...prev, loading: true, error: null }))

      try {
        const [geojson, stats] = await Promise.all([
          api.map.events({ hours: 168, limit: 500 }),
          api.map.stats(),
        ])

        if (cancelled) {
          return
        }

        setState({
          features: geojson.features,
          stats,
          loading: false,
          error: null,
        })
      } catch (error: any) {
        if (cancelled) {
          return
        }

        setState({
          features: [],
          stats: null,
          loading: false,
          error:
            error.response?.data?.detail ||
            error.message ||
            'Failed to load map data from the backend.',
        })
      }
    }

    void loadMapData()

    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    if (!layerRef.current || !mapRef.current) {
      return
    }

    layerRef.current.clearLayers()

    if (state.features.length === 0) {
      return
    }

    const bounds = L.latLngBounds([])

    state.features.forEach((feature) => {
      const [lng, lat] = feature.geometry.coordinates
      const marker = L.circleMarker([lat, lng], {
        radius: 9,
        fillColor: getNoiseColor(feature.properties.leq_db),
        color: '#ffffff',
        weight: 2,
        opacity: 1,
        fillOpacity: 0.85,
      })

      marker.bindPopup(`
        <div>
          <strong>Event ${feature.properties.id.slice(0, 8)}</strong><br/>
          Device: ${feature.properties.device_id.slice(0, 8)}<br/>
          Leq: ${feature.properties.leq_db?.toFixed?.(1) ?? feature.properties.leq_db ?? '—'} dB<br/>
          Status: ${feature.properties.status}<br/>
          Started: ${feature.properties.timestamp_start ?? '—'}
        </div>
      `)

      marker.addTo(layerRef.current!)
      bounds.extend([lat, lng])
    })

    if (bounds.isValid()) {
      mapRef.current.fitBounds(bounds.pad(0.2))
    }
  }, [state.features])

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Noise Event Map
      </Typography>
      <Typography variant="body1" color="textSecondary" paragraph>
        Public MVP view of the live event feed from the supported `/map`
        endpoints.
      </Typography>

      {state.error ? (
        <Alert severity="warning" sx={{ mb: 2 }}>
          {state.error}
        </Alert>
      ) : null}

      <Box sx={{ display: 'flex', gap: 2, height: 'calc(100vh - 220px)' }}>
        <Box sx={{ flex: 1, minHeight: 500 }}>
          <Paper
            ref={mapContainerRef}
            sx={{
              position: 'relative',
              height: '100%',
              borderRadius: 2,
              overflow: 'hidden',
            }}
          >
            {state.loading ? (
              <Box
                sx={{
                  position: 'absolute',
                  inset: 0,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  zIndex: 500,
                  backgroundColor: 'rgba(255,255,255,0.7)',
                }}
              >
                <CircularProgress />
              </Box>
            ) : null}
          </Paper>
        </Box>

        <Box sx={{ width: 320 }}>
          <Card sx={{ mb: 2 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Legend
              </Typography>
              {[
                ['Quiet', '#4CAF50', '< 45 dB'],
                ['Moderate', '#FF9800', '45-55 dB'],
                ['Loud', '#FF5722', '55-65 dB'],
                ['Very Loud', '#C62828', '> 65 dB'],
              ].map(([label, color, range]) => (
                <Box
                  key={label}
                  sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}
                >
                  <Box
                    sx={{
                      width: 16,
                      height: 16,
                      borderRadius: '50%',
                      backgroundColor: color,
                    }}
                  />
                  <Typography variant="body2">
                    {label} ({range})
                  </Typography>
                </Box>
              ))}
            </CardContent>
          </Card>

          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Current Map Stats
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Events on map: {state.features.length}
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Total devices: {state.stats?.total_devices ?? '—'}
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Events (24h): {state.stats?.events_24h ?? '—'}
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Avg Leq: {state.stats?.avg_leq_db?.toFixed(1) ?? '—'} dB
              </Typography>
            </CardContent>
          </Card>
        </Box>
      </Box>
    </Box>
  )
}
