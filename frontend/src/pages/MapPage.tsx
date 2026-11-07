import { Alert, Box, Card, CardContent, Typography } from '@mui/material'

// The pilot stays closed until its public projection and privacy safeguards pass.
// Do not request legacy individual-event APIs or third-party map tiles here.
export default function MapPage() {
  return (
    <Box>
      <Typography variant="h4" gutterBottom>Öffentliche Lärmkarte</Typography>
      <Typography color="text.secondary" paragraph>
        Für den ersten Kartenpilot ist Hamburg-Eimsbüttel als gemeinsames Gebiet vorgesehen.
        Einzelne Standorte und Geräte werden nicht angezeigt.
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        Noch keine ausreichend geschützten und vergleichbaren Daten verfügbar.
        Fehlende Daten bedeuten nicht, dass es ruhig ist.
      </Alert>
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>So ist der Pilot vorgesehen</Typography>
          <Typography paragraph>
            Freiwillige Beiträge sollen nur für das gesamte Gebiet und für abgeschlossene
            Wochen zusammengefasst werden. Eine Veröffentlichung erfolgt erst, wenn die
            Datenschutz- und Qualitätsprüfungen bestanden sind.
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
