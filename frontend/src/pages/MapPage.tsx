import { useEffect, useRef } from 'react'
import { Box, Card, CardContent, Typography, Paper } from '@mui/material'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

// Fix for default markers in React Leaflet
delete (L.Icon.Default.prototype as any)._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
})

export default function MapPage() {
  const mapRef = useRef<L.Map | null>(null)
  const mapContainerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return

    // Initialize map
    const map = L.map(mapContainerRef.current).setView([52.520008, 13.404954], 10)

    // Add OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map)

    // Sample marker data (TODO: Replace with real API data)
    const sampleDevices = [
      { id: 1, lat: 52.520008, lng: 13.404954, level: 45.2 },
      { id: 2, lat: 52.530008, lng: 13.414954, level: 58.7 },
      { id: 3, lat: 52.510008, lng: 13.394954, level: 62.1 },
    ]

    // Add markers for devices
    sampleDevices.forEach(device => {
      const color = getNoiseColor(device.level)
      
      const marker = L.circleMarker([device.lat, device.lng], {
        radius: 10,
        fillColor: color,
        color: '#fff',
        weight: 2,
        opacity: 1,
        fillOpacity: 0.8
      })
      
      marker.bindPopup(`
        <div>
          <strong>Device ${device.id}</strong><br/>
          Noise Level: ${device.level} dB<br/>
          Status: Active
        </div>
      `)
      
      marker.addTo(map)
    })

    mapRef.current = map

    return () => {
      if (mapRef.current) {
        mapRef.current.remove()
        mapRef.current = null
      }
    }
  }, [])

  const getNoiseColor = (level: number): string => {
    if (level < 45) return '#4CAF50' // Green
    if (level < 55) return '#FF9800' // Orange
    if (level < 65) return '#FF5722' // Red
    return '#9C27B0' // Purple
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Noise Level Map
      </Typography>
      <Typography variant="body1" color="textSecondary" paragraph>
        Real-time environmental noise levels from connected devices.
      </Typography>

      <Box sx={{ display: 'flex', gap: 2, height: 'calc(100vh - 200px)' }}>
        <Box sx={{ flex: 1 }}>
          <Paper
            ref={mapContainerRef}
            sx={{
              height: '100%',
              borderRadius: 2,
              overflow: 'hidden',
            }}
          />
        </Box>
        
        <Box sx={{ width: 300 }}>
          <Card sx={{ mb: 2 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Legend
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Box
                    sx={{
                      width: 16,
                      height: 16,
                      borderRadius: '50%',
                      backgroundColor: '#4CAF50'
                    }}
                  />
                  <Typography variant="body2">Quiet (&lt; 45 dB)</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Box
                    sx={{
                      width: 16,
                      height: 16,
                      borderRadius: '50%',
                      backgroundColor: '#FF9800'
                    }}
                  />
                  <Typography variant="body2">Moderate (45-55 dB)</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Box
                    sx={{
                      width: 16,
                      height: 16,
                      borderRadius: '50%',
                      backgroundColor: '#FF5722'
                    }}
                  />
                  <Typography variant="body2">Loud (55-65 dB)</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Box
                    sx={{
                      width: 16,
                      height: 16,
                      borderRadius: '50%',
                      backgroundColor: '#9C27B0'
                    }}
                  />
                  <Typography variant="body2">Very Loud (&gt; 65 dB)</Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Active Devices
              </Typography>
              <Typography variant="body2" color="textSecondary">
                3 devices currently monitoring
              </Typography>
              <Typography variant="body2" sx={{ mt: 1 }}>
                Last updated: Just now
              </Typography>
            </CardContent>
          </Card>
        </Box>
      </Box>
    </Box>
  )
}