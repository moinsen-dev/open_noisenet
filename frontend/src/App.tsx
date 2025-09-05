import { Routes, Route } from 'react-router-dom'
import { Container } from '@mui/material'

import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import MapPage from './pages/MapPage'
import AdminPage from './pages/AdminPage'
import DevicesPage from './pages/DevicesPage'
import NotFoundPage from './pages/NotFoundPage'

function App() {
  return (
    <Layout>
      <Container maxWidth="xl" sx={{ mt: 2, mb: 2 }}>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/map" element={<MapPage />} />
          <Route path="/devices" element={<DevicesPage />} />
          <Route path="/admin" element={<AdminPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </Container>
    </Layout>
  )
}

export default App