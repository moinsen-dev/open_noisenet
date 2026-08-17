import { Routes, Route } from 'react-router-dom'
import { Container } from '@mui/material'
import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import EventsPage from './pages/EventsPage'
import MapPage from './pages/MapPage'
import DevicesPage from './pages/DevicesPage'
import NotFoundPage from './pages/NotFoundPage'
import EpisodeInboxPage from './pages/EpisodeInboxPage'
import CaseDetailPage from './pages/CaseDetailPage'
import DeviceTimelinePage from './pages/DeviceTimelinePage'
function App() {
  return (
    <Layout>
      <Container maxWidth="xl" sx={{ mt: 2, mb: 2 }}>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/events" element={<EventsPage />} />
          <Route path="/map" element={<MapPage />} />
          <Route path="/devices" element={<DevicesPage />} />
          <Route path="/devices/:deviceId/timeline" element={<DeviceTimelinePage />} />
          <Route path="/operations/inbox" element={<EpisodeInboxPage />} />
          <Route path="/operations/cases/:caseId" element={<CaseDetailPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </Container>
    </Layout>
  )
}

export default App
