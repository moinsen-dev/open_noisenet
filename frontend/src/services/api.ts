import axios from 'axios'

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8100/api/v1'

// Create axios instance
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
})

// Request interceptor
apiClient.interceptors.request.use(
  (config) => {
    console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`)
    return config
  },
  (error) => {
    console.error('API Request Error:', error)
    return Promise.reject(error)
  }
)

// Response interceptor
apiClient.interceptors.response.use(
  (response) => {
    console.log(`API Response: ${response.status} ${response.config.url}`)
    return response
  },
  (error) => {
    console.error('API Response Error:', error.response?.status, error.response?.data)
    return Promise.reject(error)
  }
)

// Types based on backend API models
export interface NoiseEvent {
  id: string // Event UUID
  device_id: string // Device internal UUID (references Device.id)
  timestamp_start: string
  timestamp_end: string
  leq_db: number
  lmax_db?: number
  lmin_db?: number
  laeq_db?: number
  exceedance_pct?: number
  samples_count?: number
  rule_triggered?: string
  location_lat?: number
  location_lng?: number
  weather_conditions?: Record<string, any>
  event_metadata?: Record<string, any>
  status: 'pending' | 'processed' | 'failed'
  created_at: string
  updated_at: string
}

export interface Device {
  id: string // Internal UUID
  device_id: string // External device identifier
  name: string
  device_type: 'smartphone' | 'esp32' | 'raspberry_pi' | 'custom'
  firmware_version?: string
  hardware_info?: Record<string, any>
  calibration_offset: number
  location_lat?: number
  location_lng?: number
  address?: string
  is_active: boolean
  is_public: boolean
  created_at: string
  updated_at: string
}

export interface EventsListParams {
  device_id?: string
  start_time?: string
  end_time?: string
  limit?: number
  offset?: number
}

// Backend response types
export interface EventListResponse {
  events: NoiseEvent[]
  total: number
  offset: number
  limit: number
}

// API Functions
export const api = {
  // Health check (at root, not under /api/v1)
  health: () => apiClient.get('/health').then(res => res.data),

  // Events API
  events: {
    list: (params?: EventsListParams) => 
      apiClient.get<EventListResponse>('/events/', { params }).then(res => res.data),
    
    get: (id: string) => 
      apiClient.get<NoiseEvent>(`/events/${id}`).then(res => res.data),
    
    create: (event: NoiseEvent) => 
      apiClient.post<NoiseEvent>('/events/', event).then(res => res.data),
  },

  // Devices API
  devices: {
    list: () => 
      apiClient.get<Device[]>('/devices/').then(res => res.data),
    
    get: (deviceId: string) => 
      apiClient.get<Device>(`/devices/${deviceId}`).then(res => res.data),
    
    create: (device: Device) => 
      apiClient.post<Device>('/devices/register', device).then(res => res.data),
    
    update: (deviceId: string, device: Partial<Device>) => 
      apiClient.put<Device>(`/devices/${deviceId}`, device).then(res => res.data),
  },
}

export default apiClient