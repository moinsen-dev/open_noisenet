import { useEffect, useState } from 'react'
import { Alert, Box, Card, CardContent, Typography } from '@mui/material'
import { API_BASE_URL } from '../services/api'

type Band = 'low' | 'medium' | 'high'
interface AreaWeek { area: 'hamburg-eimsbuettel'; week_start: string; band: Band }

function readWeeks(value: unknown): AreaWeek[] {
  if (!value || typeof value !== 'object' || !('status' in value) || !('areas' in value)) return []
  if (value.status !== 'available' || !Array.isArray(value.areas)) return []
  return value.areas.filter((row): row is AreaWeek =>
    row && typeof row === 'object' && row.area === 'hamburg-eimsbuettel' &&
    typeof row.week_start === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(row.week_start) &&
    ['low', 'medium', 'high'].includes(row.band),
  )
}

export default function MapPage() {
  const [weeks, setWeeks] = useState<AreaWeek[]>([])
  useEffect(() => {
    const controller = new AbortController()
    void fetch(`${API_BASE_URL}/map-pilot/public`, {
      credentials: 'omit', cache: 'no-store', signal: controller.signal,
    }).then((response) => response.ok ? response.json() : null)
      .then((data: unknown) => setWeeks(readWeeks(data)))
      .catch(() => { /* Unavailable is not a measurement of silence. */ })
    return () => controller.abort()
  }, [])
  const labels: Record<Band, string> = { low: 'niedrig', medium: 'mittel', high: 'hoch' }
  return (
    <Box>
      <Typography variant="h4" gutterBottom>Öffentliche Lärmkarte</Typography>
      <Typography color="text.secondary" paragraph>
        Gebiet: Stadtteil Hamburg-Eimsbüttel. Einzelne Standorte und Geräte werden nicht angezeigt.
      </Typography>
      <Box component="img" src="/eimsbuettel.svg" alt="Umriss des Stadtteils Hamburg-Eimsbüttel"
        sx={{ display: 'block', width: 'min(100%, 320px)', mb: 1 }} />
      <Typography variant="caption" display="block" gutterBottom>
        <a href="https://suche.transparenz.hamburg.de/dataset/regionalstatistische-daten-der-stadtteile-hamburgs22">Gebietsgrenze</a>:
        {' '}Statistisches Amt für Hamburg und Schleswig-Holstein,{' '}
        <a href="https://www.govdata.de/dl-de/by-2-0">Datenlizenz Deutschland Namensnennung 2.0</a>;
        vereinfachte Darstellung ohne Straßen und Sensorstandorte.
      </Typography>
      {weeks.length === 0 ? (
        <Alert severity="info" sx={{ mb: 2 }}>
          Noch keine ausreichend geschützten und vergleichbaren Daten verfügbar.
          Fehlende Daten bedeuten nicht, dass es ruhig ist.
        </Alert>
      ) : weeks.map((week) => (
        <Card key={week.week_start} sx={{ mb: 2 }}>
          <CardContent>
            <Typography variant="h6">Hamburg-Eimsbüttel</Typography>
            <Typography>UTC-Woche ab {week.week_start}: Kategorie {labels[week.band]}</Typography>
          </CardContent>
        </Card>
      ))}
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Zum Pilot</Typography>
          <Typography paragraph>
            Freiwillige Beiträge werden für das gesamte Gebiet und abgeschlossene Wochen
            zusammengefasst. Daten fehlen, wenn sie nicht ausreichend geschützt sind.
          </Typography>
          <Typography color="text.secondary">
            Telefonmessungen sind geräteabhängig und weisen weder eine Lärmquelle noch
            einen Grenzwertverstoß nach. Die Karte ist noch nicht in Betrieb.
          </Typography>
        </CardContent>
      </Card>
    </Box>
  )
}
