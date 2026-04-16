import { useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material'
import { Circle } from '@mui/icons-material'
import { formatDistanceToNow, parseISO } from 'date-fns'

import { api, Device } from '../services/api'

interface DevicesState {
  devices: Device[]
  loading: boolean
  error: string | null
}

function getStatusLabel(device: Device) {
  if (!device.is_active) {
    return 'inactive'
  }

  return device.last_heartbeat || device.last_seen ? 'active' : 'registered'
}

function formatTimestamp(value?: string) {
  if (!value) {
    return 'No heartbeat yet'
  }

  try {
    return formatDistanceToNow(parseISO(value), { addSuffix: true })
  } catch {
    return value
  }
}

export default function DevicesPage() {
  const [state, setState] = useState<DevicesState>({
    devices: [],
    loading: true,
    error: null,
  })

  useEffect(() => {
    let cancelled = false

    async function loadDevices() {
      setState((prev) => ({ ...prev, loading: true, error: null }))

      try {
        const devices = await api.devices.list()

        if (cancelled) {
          return
        }

        setState({
          devices,
          loading: false,
          error: null,
        })
      } catch (error: any) {
        if (cancelled) {
          return
        }

        setState({
          devices: [],
          loading: false,
          error:
            error.response?.data?.detail ||
            error.message ||
            'Failed to load devices from the backend.',
        })
      }
    }

    void loadDevices()

    return () => {
      cancelled = true
    }
  }, [])

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Devices
      </Typography>
      <Typography variant="body1" color="textSecondary" paragraph>
        Registered devices from the supported MVP `/devices` endpoints.
      </Typography>

      {state.error ? (
        <Alert severity="warning" sx={{ mb: 2 }}>
          {state.error}
        </Alert>
      ) : null}

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Registered Devices ({state.devices.length})
          </Typography>

          {state.loading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
              <CircularProgress />
            </Box>
          ) : (
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Device</TableCell>
                    <TableCell>Type</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Location</TableCell>
                    <TableCell>Visibility</TableCell>
                    <TableCell>Last Seen</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {state.devices.map((device) => {
                    const status = getStatusLabel(device)

                    return (
                      <TableRow key={device.id}>
                        <TableCell>
                          <Box>
                            <Typography variant="body1" fontWeight="medium">
                              {device.name}
                            </Typography>
                            <Typography variant="body2" color="textSecondary">
                              {device.device_id}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Chip label={device.device_type} size="small" variant="outlined" />
                        </TableCell>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Circle
                              sx={{
                                fontSize: 12,
                                color: device.is_active ? 'success.main' : 'warning.main',
                              }}
                            />
                            <Chip
                              label={status}
                              color={device.is_active ? 'success' : 'warning'}
                              size="small"
                            />
                          </Box>
                        </TableCell>
                        <TableCell>
                          {device.address ||
                            (device.location_lat != null && device.location_lng != null
                              ? `${device.location_lat.toFixed(4)}, ${device.location_lng.toFixed(4)}`
                              : 'No location set')}
                        </TableCell>
                        <TableCell>{device.is_public ? 'Public' : 'Private'}</TableCell>
                        <TableCell>
                          <Typography variant="body2" color="textSecondary">
                            {formatTimestamp(device.last_heartbeat || device.last_seen)}
                          </Typography>
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>
    </Box>
  )
}
