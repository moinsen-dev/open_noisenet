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
  Chip,
  IconButton,
} from '@mui/material'
import { Edit, Delete, Circle } from '@mui/icons-material'

interface Device {
  id: string
  name: string
  type: 'smartphone' | 'esp32' | 'raspberry_pi'
  status: 'online' | 'offline' | 'warning'
  lastSeen: string
  location: string
  currentLevel?: number
}

const mockDevices: Device[] = [
  {
    id: 'device-001',
    name: 'Berlin Mitte Sensor',
    type: 'smartphone',
    status: 'online',
    lastSeen: '2 minutes ago',
    location: 'Berlin, Germany',
    currentLevel: 52.3,
  },
  {
    id: 'device-002',
    name: 'Park Monitor',
    type: 'esp32',
    status: 'online',
    lastSeen: '5 minutes ago',
    location: 'Munich, Germany',
    currentLevel: 41.7,
  },
  {
    id: 'device-003',
    name: 'Traffic Junction',
    type: 'raspberry_pi',
    status: 'warning',
    lastSeen: '1 hour ago',
    location: 'Hamburg, Germany',
    currentLevel: 67.2,
  },
]

function getStatusColor(status: Device['status']) {
  switch (status) {
    case 'online':
      return 'success'
    case 'warning':
      return 'warning'
    case 'offline':
      return 'error'
    default:
      return 'default'
  }
}

function getDeviceTypeLabel(type: Device['type']) {
  switch (type) {
    case 'smartphone':
      return 'Smartphone'
    case 'esp32':
      return 'ESP32'
    case 'raspberry_pi':
      return 'Raspberry Pi'
    default:
      return type
  }
}

export default function DevicesPage() {
  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Device Management
      </Typography>
      <Typography variant="body1" color="textSecondary" paragraph>
        Monitor and manage your noise monitoring devices.
      </Typography>

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Connected Devices ({mockDevices.length})
          </Typography>
          
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Device</TableCell>
                  <TableCell>Type</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell>Location</TableCell>
                  <TableCell>Current Level</TableCell>
                  <TableCell>Last Seen</TableCell>
                  <TableCell>Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {mockDevices.map((device) => (
                  <TableRow key={device.id}>
                    <TableCell>
                      <Box>
                        <Typography variant="body1" fontWeight="medium">
                          {device.name}
                        </Typography>
                        <Typography variant="body2" color="textSecondary">
                          {device.id}
                        </Typography>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Chip
                        label={getDeviceTypeLabel(device.type)}
                        size="small"
                        variant="outlined"
                      />
                    </TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Circle
                          sx={{
                            fontSize: 12,
                            color: `${getStatusColor(device.status)}.main`,
                          }}
                        />
                        <Chip
                          label={device.status}
                          color={getStatusColor(device.status)}
                          size="small"
                        />
                      </Box>
                    </TableCell>
                    <TableCell>{device.location}</TableCell>
                    <TableCell>
                      {device.currentLevel ? (
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                          <Typography variant="body2" fontWeight="medium">
                            {device.currentLevel} dB
                          </Typography>
                          <Circle
                            sx={{
                              fontSize: 8,
                              color: device.currentLevel > 60 ? 'error.main' : 
                                     device.currentLevel > 50 ? 'warning.main' : 'success.main',
                            }}
                          />
                        </Box>
                      ) : (
                        <Typography variant="body2" color="textSecondary">
                          No data
                        </Typography>
                      )}
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="textSecondary">
                        {device.lastSeen}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', gap: 1 }}>
                        <IconButton size="small" color="primary">
                          <Edit fontSize="small" />
                        </IconButton>
                        <IconButton size="small" color="error">
                          <Delete fontSize="small" />
                        </IconButton>
                      </Box>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </CardContent>
      </Card>
    </Box>
  )
}