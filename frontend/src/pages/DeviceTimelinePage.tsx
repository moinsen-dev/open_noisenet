import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import {
  Alert, Box, Card, CardContent, Chip, CircularProgress,
  Table, TableBody, TableCell, TableContainer, TableHead,
  TableRow, Typography, Stack, LinearProgress,
} from '@mui/material'

interface TimelineEvent {
  id: string
  timestamp_start: string | null
  leq_db: number
  lmax_db: number | null
  classification_label: string | null
  status: string
  episode_id: string | null
}

interface TimelineEpisode {
  id: string
  primary_class: string
  label_de: string
  started_at: string | null
  ended_at: string | null
  severity: string
  nuisance_score: number
  event_count: number
  quiet_hours_triggered: boolean
  avg_leq_db: number | null
}

interface NoiseDuration {
  total: string
  total_seconds: number
  night: string
  night_seconds: number
  episode_count: number
  by_threshold: Record<string, string>
}

interface TimelineData {
  device_id: string
  date: string
  events: TimelineEvent[]
  episodes: TimelineEpisode[]
  summary: string
  noise_duration: NoiseDuration
}

function severityColor(severity: string): 'error' | 'warning' | 'info' | 'default' {
  switch (severity) {
    case 'critical': return 'error'
    case 'high': return 'warning'
    case 'moderate': return 'info'
    default: return 'default'
  }
}

function formatTime(iso: string | null): string {
  if (!iso) return '—'
  const d = new Date(iso)
  return d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
}

function noiseToBar(db: number, max: number): number {
  return Math.min((db / Math.max(max, 1)) * 100, 100)
}

export default function DeviceTimelinePage() {
  const { deviceId } = useParams<{ deviceId: string }>()
  const [data, setData] = useState<TimelineData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!deviceId) return
    const today = new Date().toISOString().slice(0, 10)
    fetch(`/api/v1/devices/${deviceId}/timeline?date=${today}`)
      .then(r => r.json())
      .then(d => {
        if (d.detail) throw new Error(d.detail)
        setData(d)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [deviceId])

  if (loading) return <Box display="flex" justifyContent="center" mt={8}><CircularProgress /></Box>
  if (error) return <Alert severity="error" sx={{ mt: 4 }}>{error}</Alert>
  if (!data) return <Alert severity="warning" sx={{ mt: 4 }}>Keine Daten</Alert>

  const episodes = data.episodes

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Tagesverlauf: {deviceId}
      </Typography>
      <Typography variant="subtitle1" color="text.secondary" gutterBottom>
        {data.date}
      </Typography>

      {/* Summary */}
      <Card sx={{ mb: 3, bgcolor: 'primary.dark', color: 'white' }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>Zusammenfassung</Typography>
          <Typography>{data.summary || 'Keine nennenswerten Lärmereignisse'}</Typography>
        </CardContent>
      </Card>

      {/* Noise Duration Summary */}
      {data.noise_duration && data.noise_duration.total_seconds > 0 && (
        <Card sx={{ mb: 3, bgcolor: 'warning.dark', color: 'white' }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>🔊 Lärmdauer heute</Typography>
            <Stack direction="row" spacing={4} alignItems="center">
              <Box>
                <Typography variant="h4">{data.noise_duration.total}</Typography>
                <Typography variant="body2">Gesamtdauer</Typography>
              </Box>
              {data.noise_duration.night_seconds > 0 && (
                <Box>
                  <Typography variant="h4" color="error.light">
                    {data.noise_duration.night}
                  </Typography>
                  <Typography variant="body2">davon in der Nachtruhe</Typography>
                </Box>
              )}
              <Box>
                <Typography variant="h4">{data.noise_duration.episode_count}</Typography>
                <Typography variant="body2">Einzelepisoden</Typography>
              </Box>
              <Box sx={{ flex: 1 }}>
                <Typography variant="body2" gutterBottom>Nach Lautstärke:</Typography>
                {Object.entries(data.noise_duration.by_threshold).map(([threshold, duration]) => (
                  <Typography key={threshold} variant="body2" sx={{ opacity: 0.9 }}>
                    &gt; {threshold}: {duration}
                  </Typography>
                ))}
              </Box>
            </Stack>
          </CardContent>
        </Card>
      )}

      {/* Episode Timeline */}
      {episodes.length > 0 && (
        <>
          <Typography variant="h5" gutterBottom>Episoden</Typography>
          <Stack spacing={2} sx={{ mb: 4 }}>
            {episodes.map(ep => (
              <Card key={ep.id}>
                <CardContent>
                  <Stack direction="row" justifyContent="space-between" alignItems="center" mb={1}>
                    <Typography variant="h6">{ep.label_de}</Typography>
                    <Chip
                      label={ep.severity}
                      color={severityColor(ep.severity)}
                      size="small"
                    />
                  </Stack>
                  <Stack direction="row" spacing={3} mb={1}>
                    <Typography variant="body2" color="text.secondary">
                      {formatTime(ep.started_at)} – {formatTime(ep.ended_at)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      {ep.event_count} Events
                    </Typography>
                    {ep.avg_leq_db && (
                      <Typography variant="body2" color="text.secondary">
                        ø {ep.avg_leq_db} dB
                      </Typography>
                    )}
                    <Typography variant="body2" color="text.secondary">
                      Nuisance: {ep.nuisance_score}/100
                    </Typography>
                    {ep.quiet_hours_triggered && (
                      <Chip label="Nachtruhe" color="error" size="small" />
                    )}
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
        </>
      )}

      {/* Hour-by-hour noise bars */}
      <Typography variant="h5" gutterBottom>Stündlicher Pegelverlauf</Typography>
      <Card sx={{ mb: 3, p: 2 }}>
        <Stack spacing={0.5}>
          {Array.from({ length: 24 }, (_, h) => {
            const hourEvents = data.events.filter(e => {
              if (!e.timestamp_start) return false
              return new Date(e.timestamp_start).getHours() === h
            })
            const avgDb = hourEvents.length > 0
              ? hourEvents.reduce((s, e) => s + e.leq_db, 0) / hourEvents.length
              : 0
            return { hour: h, avgDb: Math.round(avgDb), count: hourEvents.length }
          }).map(({ hour, avgDb, count }) => (
            <Stack key={hour} direction="row" alignItems="center" spacing={1}>
              <Typography variant="caption" sx={{ width: 40, textAlign: 'right' }}>
                {String(hour).padStart(2, '0')}:00
              </Typography>
              <LinearProgress
                variant="determinate"
                value={noiseToBar(avgDb, 90)}
                color={avgDb > 65 ? 'error' : avgDb > 55 ? 'warning' : 'primary'}
                sx={{ flex: 1, height: 10, borderRadius: 5 }}
              />
              <Typography variant="caption" sx={{ width: 50 }}>
                {avgDb > 0 ? `${avgDb} dB` : '—'}
              </Typography>
              <Typography variant="caption" color="text.secondary" sx={{ width: 40 }}>
                {count > 0 ? `${count} Evt` : ''}
              </Typography>
            </Stack>
          ))}
        </Stack>
      </Card>

      {/* Event Table */}
      <Typography variant="h5" gutterBottom>Einzelereignisse</Typography>
      <TableContainer component={Card}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Zeit</TableCell>
              <TableCell>Leq</TableCell>
              <TableCell>Max</TableCell>
              <TableCell>Klassifikation</TableCell>
              <TableCell>Episode</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {data.events.slice(0, 50).map(event => {
              const ep = event.episode_id
                ? episodes.find(e => e.id === event.episode_id)
                : null
              return (
                <TableRow key={event.id}>
                  <TableCell>{formatTime(event.timestamp_start)}</TableCell>
                  <TableCell>{event.leq_db?.toFixed(1)} dB</TableCell>
                  <TableCell>{event.lmax_db?.toFixed(1) ?? '—'} dB</TableCell>
                  <TableCell>{event.classification_label ?? '—'}</TableCell>
                  <TableCell>
                    {ep ? (
                      <Chip label={ep.label_de} size="small" color={severityColor(ep.severity)} />
                    ) : '—'}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  )
}
