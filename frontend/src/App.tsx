import { Routes, Route } from 'react-router-dom'
import { Container } from '@mui/material'

import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import EventsPage from './pages/EventsPage'
import MapPage from './pages/MapPage'
import DevicesPage from './pages/DevicesPage'
import NotFoundPage from './pages/NotFoundPage'
import OperationsPage from './pages/OperationsPage'

function App() {
  return (
    <Layout>
      <Container maxWidth="xl" sx={{ mt: 2, mb: 2 }}>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/events" element={<EventsPage />} />
          <Route path="/map" element={<MapPage />} />
          <Route path="/devices" element={<DevicesPage />} />
          <Route path="/operations" element={<OperationsPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </Container>
    </Layout>
  )
}

export default App
