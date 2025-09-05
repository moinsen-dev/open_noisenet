import {
  Box,
  Card,
  CardContent,
  Grid,
  Typography,
  LinearProgress,
} from '@mui/material'
import {
  VolumeUp,
  Devices,
  TrendingUp,
  Warning,
} from '@mui/icons-material'

interface StatCardProps {
  title: string
  value: string | number
  icon: React.ReactNode
  color?: 'primary' | 'secondary' | 'error' | 'warning' | 'info' | 'success'
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
  // TODO: Replace with real data from API
  const stats = {
    activeDevices: 42,
    currentAvgLevel: '52.3 dB',
    eventsToday: 127,
    alertsActive: 3,
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard Overview
      </Typography>
      <Typography variant="body1" color="textSecondary" paragraph>
        Monitor environmental noise levels across your network of devices.
      </Typography>

      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Active Devices"
            value={stats.activeDevices}
            icon={<Devices />}
            color="primary"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Avg Noise Level"
            value={stats.currentAvgLevel}
            icon={<VolumeUp />}
            color="info"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Events Today"
            value={stats.eventsToday}
            icon={<TrendingUp />}
            color="success"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Active Alerts"
            value={stats.alertsActive}
            icon={<Warning />}
            color="warning"
          />
        </Grid>

        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Recent Activity
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Loading activity data...
              </Typography>
              <Box sx={{ mt: 2 }}>
                <LinearProgress />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                System Status
              </Typography>
              <Typography variant="body2" color="textSecondary">
                All systems operational
              </Typography>
              <Box sx={{ mt: 2 }}>
                <Typography variant="body2">
                  Database: ✓ Healthy<br />
                  API: ✓ Online<br />
                  Workers: ✓ Active
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  )
}