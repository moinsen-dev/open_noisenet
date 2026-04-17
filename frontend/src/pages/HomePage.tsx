import { useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Card,
  CardContent,
  CircularProgress,
  Grid,
  List,
  ListItem,
  ListItemText,
  Typography,
} from '@mui/material'
import { Devices, TrendingUp, VolumeUp, Warning } from '@mui/icons-material'
import { formatDistanceToNow, parseISO } from 'date-fns'

import { api, MapStats, NoiseEvent } from '../services/api'

interface StatCardProps {
  title: string
  value: string | number
  icon: React.ReactNode
  color?: 'primary' | 'secondary' | 'error' | 'warning' | 'info' | 'success'
}

interface DashboardState {
  stats: MapStats | null
  recentEvents: NoiseEvent[]
  backendHealthy: boolean
  loading: boolean
  error: string | null
}

function StatCard({ title, value, icon, color = 'primary' }: StatCardProps) {
  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 48,
              height: 48,
              borderRadius: '50%',
              bgcolor: `${color}.light`,
              color: `${color}.contrastText`,
            }}
          >
            {icon}
          </Box>
          <Box sx={{ flex: 1 }}>
            <Typography color="textSecondary" gutterBottom>
              {title}
            </Typography>
            <Typography variant="h4" component="div">
              {value}
            </Typography>
          </Box>
        </Box>
      </CardContent>
    </Card>
  )
}

export default function HomePage() {
  const [state, setState] = useState<DashboardState>({
    stats: null,
    recentEvents: [],
    backendHealthy: false,
    loading: true,
    error: null,
  })

  useEffect(() => {
    let cancelled = false

    async function loadDashboard() {
      setState((prev) => ({ ...prev, loading: true, error: null }))

      try {
        const [health, stats, eventsResponse] = await Promise.all([
          api.health(),
          api.map.stats(),
          api.events.list({ limit: 5 }),
        ])

        if (cancelled) {
          return
        }

        setState({
          stats,
          recentEvents: eventsResponse.events,
          backendHealthy: health.status === 'healthy',
          loading: false,
          error: null,
        })
      } catch (error: any) {
        if (cancelled) {
          return
        }

        setState({
          stats: null,
          recentEvents: [],
          backendHealthy: false,
          loading: false,
          error:
            error.response?.data?.detail ||
            error.message ||
            'Failed to load the dashboard from the backend.',
        })
      }
    }

    void loadDashboard()

    return () => {
      cancelled = true
    }
  }, [])

  const stats = state.stats

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard Overview
      </Typography>
      <Typography variant="body1" color="textSecondary" paragraph>
        Current public MVP status across the release-supported backend surfaces:
        auth, devices, events, and map data. Initial Pro foundations exist in
        the repo, but they are still pre-release and being hardened.
      </Typography>

      {state.error ? (
        <Alert severity="warning" sx={{ mb: 3 }}>
          {state.error}
        </Alert>
      ) : null}

      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Registered Devices"
            value={stats?.total_devices ?? '—'}
            icon={<Devices />}
            color="primary"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Avg Noise Level"
            value={stats?.avg_leq_db ? `${stats.avg_leq_db.toFixed(1)} dB` : '—'}
            icon={<VolumeUp />}
            color="info"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Events (24h)"
            value={stats?.events_24h ?? '—'}
            icon={<TrendingUp />}
            color="success"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Active Devices (24h)"
            value={stats?.active_devices_24h ?? '—'}
            icon={<Warning />}
            color="warning"
          />
        </Grid>

        <Grid item xs={12} md={8}>
          <Card sx={{ minHeight: 280 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Recent Events
              </Typography>

              {state.loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
                  <CircularProgress />
                </Box>
              ) : state.recentEvents.length === 0 ? (
                <Typography variant="body2" color="textSecondary">
                  No events have been ingested yet. Once a device submits an
                  event, it will appear here.
                </Typography>
              ) : (
                <List disablePadding>
                  {state.recentEvents.map((event) => (
                    <ListItem key={event.id} disableGutters divider>
                      <ListItemText
                        primary={`${event.leq_db.toFixed(1)} dB • ${event.status}`}
                        secondary={`Device ${event.device_id.slice(0, 8)} • ${formatDistanceToNow(
                          parseISO(event.timestamp_start),
                          { addSuffix: true }
                        )}`}
                      />
                    </ListItem>
                  ))}
                </List>
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ minHeight: 280 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                System Status & Scope
              </Typography>
              <Typography variant="body2" color="textSecondary" paragraph>
                This dashboard is wired to the current public MVP surface.
                Pro-domain objects, operator inbox flows, and exports now exist
                in the repo, but they remain pre-release while the stabilization
                gate is still open.
              </Typography>
              <Typography variant="body2">
                API: {state.backendHealthy ? 'Healthy' : 'Unavailable'}
              </Typography>
              <Typography variant="body2">
                Background Processing: Best effort
              </Typography>
              <Typography variant="body2">
                Supported Surfaces: Auth, Devices, Events, Map
              </Typography>
              <Typography variant="body2">
                Pre-release Pro: Organizations, Episodes, Cases, Exports
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  )
}
