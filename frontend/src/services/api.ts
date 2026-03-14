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

// Token storage
const TOKEN_KEY = 'noisenet_access_token'

function setAuthToken(token: string | null) {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token)
    apiClient.defaults.headers.common['Authorization'] = `Bearer ${token}`
  } else {
    localStorage.removeItem(TOKEN_KEY)
    delete apiClient.defaults.headers.common['Authorization']
  }
}

// Restore token on load
const storedToken = typeof localStorage !== 'undefined' ? localStorage.getItem(TOKEN_KEY) : null
if (storedToken) {
  apiClient.defaults.headers.common['Authorization'] = `Bearer ${storedToken}`
}

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
  id: string
  device_id: string
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
  id: string
  device_id: string
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

export interface EventListResponse {
  events: NoiseEvent[]
  total: number
  offset: number
  limit: number
}

// Auth types
export interface LoginRequest {
  email: string
  password: string
}

export interface RegisterRequest {
  email: string
  password: string
  full_name: string
}

export interface AuthTokens {
  access_token: string
  refresh_token: string
  token_type: string
  expires_in: number
}

// Map types
export interface GeoJSONFeature {
  type: 'Feature'
  geometry: { type: 'Point'; coordinates: [number, number] }
  properties: {
    id: string
    leq_db: number
    lmax_db?: number
    timestamp: string
    rule_triggered?: string
    status: string
  }
}

export interface GeoJSONResponse {
  type: 'FeatureCollection'
  features: GeoJSONFeature[]
}

export interface HeatmapPoint {
  lat: number
  lng: number
  intensity: number
  event_count: number
}

export interface HeatmapResponse {
  points: HeatmapPoint[]
  min_intensity?: number
  max_intensity?: number
}

export interface MapStats {
  total_events: number
  total_devices: number
  avg_leq_db?: number
  max_leq_db?: number
  active_devices_24h: number
  events_24h: number
}

// API Functions
export const api = {
  // Health check (at root, not under /api/v1)
  health: () => {
    const rootUrl = API_BASE_URL.replace('/api/v1', '')
    return axios.get(`${rootUrl}/health`).then(res => res.data)
  },

  // Auth API
  auth: {
    login: (data: LoginRequest) =>
      apiClient.post<AuthTokens>('/auth/login', data).then(res => {
        setAuthToken(res.data.access_token)
        return res.data
      }),

    register: (data: RegisterRequest) =>
      apiClient.post<AuthTokens>('/auth/register', data).then(res => {
        setAuthToken(res.data.access_token)
        return res.data
      }),

    logout: () => {
      setAuthToken(null)
    },
  },

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

  // Map API (public, no auth required)
  map: {
    events: (params?: { min_lat?: number; max_lat?: number; min_lng?: number; max_lng?: number; hours?: number }) =>
      apiClient.get<GeoJSONResponse>('/map/events', { params }).then(res => res.data),

    heatmap: (params: { min_lat: number; max_lat: number; min_lng: number; max_lng: number; hours?: number }) =>
      apiClient.get<HeatmapResponse>('/map/heatmap', { params }).then(res => res.data),

    stats: () =>
      apiClient.get<MapStats>('/map/stats').then(res => res.data),
  },
}

export default apiClient
