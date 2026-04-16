import { useState, useEffect } from 'react'
import {
  Box,
  Card,
  CardContent,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
  TextField,
  Grid,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Alert,
  CircularProgress,
  Tooltip,
  Button,
} from '@mui/material'
import {
  Refresh,
  VolumeUp,
  LocationOn,
  Schedule,
  Warning,
  CheckCircle,
  Error as ErrorIcon,
} from '@mui/icons-material'
import { format, parseISO } from 'date-fns'

import { api, NoiseEvent, Device } from '../services/api'

interface EventsState {
  events: NoiseEvent[]
  devices: Device[]
  loading: boolean
  error: string | null
}

export default function EventsPage() {
  const [state, setState] = useState<EventsState>({
    events: [],
    devices: [],
    loading: true,
    error: null,
  })

  const [filters, setFilters] = useState({
    device_id: '',
    limit: 50,
    offset: 0,
  })

  const [lastRefresh, setLastRefresh] = useState<Date>(new Date())

  // Load events and devices
  const loadData = async () => {
    setState(prev => ({ ...prev, loading: true, error: null }))
    
    try {
      // Test backend connection first
      await api.health()
      
      // Load events and devices in parallel
      const [eventsResponse, devices] = await Promise.all([
        api.events.list(filters),
        api.devices.list(),
      ])

      setState(prev => ({
        ...prev,
        events: eventsResponse.events || [],
        devices: devices || [],
        loading: false,
      }))
      
      setLastRefresh(new Date())
    } catch (error: any) {
      console.error('Failed to load data:', error)
      setState(prev => ({
        ...prev,
        loading: false,
        error:
          error.response?.data?.detail ||
          error.response?.data?.message ||
          error.message ||
          'Failed to load data from backend',
      }))
    }
  }

  // Load data on component mount and when filters change
  useEffect(() => {
    loadData()
  }, [filters.device_id, filters.limit]) // eslint-disable-line react-hooks/exhaustive-deps

  // Get device name by internal ID (UUID)
  const getDeviceName = (deviceId: string): string => {
    const device = state.devices.find(d => d.id === deviceId)
    return device?.name || `Device ${deviceId.slice(0, 8)}`
  }

  // Get device type by internal ID (UUID)
  const getDeviceType = (deviceId: string): string => {
    const device = state.devices.find(d => d.id === deviceId)
    return device?.device_type || 'unknown'
  }

  // Format noise level with color
  const getNoiseLevel = (leqDb: number) => {
    let color: 'success' | 'warning' | 'error' = 'success'
    if (leqDb > 70) color = 'error'
    else if (leqDb > 55) color = 'warning'
    
    return { level: `${leqDb.toFixed(1)} dB`, color }
  }

  // Format duration
  const getDuration = (start: string, end: string): string => {
    try {
      const startTime = parseISO(start)
      const endTime = parseISO(end)
      const diffMs = endTime.getTime() - startTime.getTime()
      const diffSec = Math.round(diffMs / 1000)
      
      if (diffSec < 60) return `${diffSec}s`
      if (diffSec < 3600) return `${Math.round(diffSec / 60)}m`
      return `${Math.round(diffSec / 3600)}h`
    } catch {
      return 'N/A'
    }
  }

  if (state.loading && state.events.length === 0) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '50vh' }}>
        <Box sx={{ textAlign: 'center' }}>
          <CircularProgress size={48} />
          <Typography variant="h6" sx={{ mt: 2 }}>
            Loading events from backend...
          </Typography>
          <Typography variant="body2" color="textSecondary">
            Connecting to {import.meta.env.VITE_API_URL || 'http://localhost:8100'}
          </Typography>
        </Box>
      </Box>
    )
  }

  if (state.error) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Noise Events
        </Typography>
        <Alert 
          severity="error" 
          action={
            <Button color="inherit" size="small" onClick={loadData}>
              Retry
            </Button>
          }
        >
          <Typography variant="h6">Backend Connection Failed</Typography>
          <Typography variant="body2">{state.error}</Typography>
          <Typography variant="caption" sx={{ mt: 1, display: 'block' }}>
            Backend URL: {import.meta.env.VITE_API_URL || 'http://localhost:8100/api/v1'}
          </Typography>
        </Alert>
      </Box>
    )
  }

  return (
    <Box>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Noise Events
          </Typography>
          <Typography variant="body1" color="textSecondary">
            Real-time noise monitoring events from connected devices
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Typography variant="body2" color="textSecondary">
            Last updated: {format(lastRefresh, 'HH:mm:ss')}
          </Typography>
          <Tooltip title="Refresh events">
            <IconButton onClick={loadData} disabled={state.loading}>
              <Refresh />
            </IconButton>
          </Tooltip>
        </Box>
      </Box>

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <VolumeUp color="primary" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="h4">{state.events.length}</Typography>
              <Typography color="textSecondary">Total Events</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <CheckCircle color="success" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="h4">{state.devices.length}</Typography>
              <Typography color="textSecondary">Active Devices</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <Warning color="warning" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="h4">
                {state.events.filter(e => e.leq_db > 70).length}
              </Typography>
              <Typography color="textSecondary">High Noise (&gt;70dB)</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent sx={{ textAlign: 'center' }}>
              <Schedule color="info" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="h4">
                {state.events.filter(e => new Date(e.timestamp_start).getTime() > Date.now() - 3600000).length}
              </Typography>
              <Typography color="textSecondary">Last Hour</Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Filters
          </Typography>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Device</InputLabel>
                <Select
                  value={filters.device_id}
                  label="Device"
                  onChange={(e) => setFilters(prev => ({ ...prev, device_id: e.target.value }))}
                >
                  <MenuItem value="">All Devices</MenuItem>
                  {state.devices.map((device) => (
                    <MenuItem key={device.id} value={device.id}>
                      {device.name} ({device.device_type})
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                size="small"
                type="number"
                label="Limit"
                value={filters.limit}
                onChange={(e) => setFilters(prev => ({ ...prev, limit: parseInt(e.target.value) || 50 }))}
                inputProps={{ min: 1, max: 1000 }}
              />
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Events Table */}
      <Card>
        <CardContent>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
            <Typography variant="h6">
              Recent Events ({state.events.length})
            </Typography>
            {state.loading && <CircularProgress size={20} />}
          </Box>
          
          {state.events.length === 0 ? (
            <Box sx={{ textAlign: 'center', py: 4 }}>
              <ErrorIcon color="disabled" sx={{ fontSize: 64, mb: 2 }} />
              <Typography variant="h6" color="textSecondary">
                No events found
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Try adjusting your filters or check if devices are sending data
              </Typography>
            </Box>
          ) : (
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Device</TableCell>
                    <TableCell>Time</TableCell>
                    <TableCell>Duration</TableCell>
                    <TableCell>Noise Level</TableCell>
                    <TableCell>Peak (L_max)</TableCell>
                    <TableCell>Rule</TableCell>
                    <TableCell>Location</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {state.events.map((event, index) => {
                    const noiseLevel = getNoiseLevel(event.leq_db)
                    return (
                      <TableRow key={event.id || index} hover>
                        <TableCell>
                          <Box>
                            <Typography variant="body2" fontWeight="medium">
                              {getDeviceName(event.device_id)}
                            </Typography>
                            <Typography variant="caption" color="textSecondary">
                              {getDeviceType(event.device_id)}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">
                            {format(parseISO(event.timestamp_start), 'MMM dd, HH:mm:ss')}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">
                            {getDuration(event.timestamp_start, event.timestamp_end)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Chip
                            label={noiseLevel.level}
                            color={noiseLevel.color}
                            size="small"
                            variant="outlined"
                          />
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">
                            {event.lmax_db ? `${event.lmax_db.toFixed(1)} dB` : 'N/A'}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          {event.rule_triggered ? (
                            <Chip label={event.rule_triggered} size="small" color="warning" />
                          ) : (
                            <Typography variant="body2" color="textSecondary">None</Typography>
                          )}
                        </TableCell>
                        <TableCell>
                          {event.location_lat && event.location_lng ? (
                            <Tooltip title={`${event.location_lat}, ${event.location_lng}`}>
                              <LocationOn fontSize="small" color="action" />
                            </Tooltip>
                          ) : (
                            <Typography variant="body2" color="textSecondary">N/A</Typography>
                          )}
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
