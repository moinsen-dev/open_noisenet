import axios from 'axios'

export const API_BASE_URL =
  import.meta.env.VITE_API_URL || 'http://localhost:8100/api/v1'

export const API_ROOT_URL = API_BASE_URL.replace(/\/api\/v1\/?$/, '')

const TOKEN_KEY = 'noisenet_access_token'

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
})

function setAuthToken(token: string | null) {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token)
    apiClient.defaults.headers.common.Authorization = `Bearer ${token}`
  } else {
    localStorage.removeItem(TOKEN_KEY)
    delete apiClient.defaults.headers.common.Authorization
  }
}

const storedToken =
  typeof localStorage !== 'undefined' ? localStorage.getItem(TOKEN_KEY) : null

if (storedToken) {
  apiClient.defaults.headers.common.Authorization = `Bearer ${storedToken}`
}

apiClient.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject(error)
)

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
  weather_conditions?: Record<string, unknown>
  event_metadata?: Record<string, unknown>
  status: 'active' | 'processed' | 'archived' | 'invalid'
  created_at: string
  updated_at: string
}

export interface NoiseEventCreate {
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
  weather_conditions?: Record<string, unknown>
  event_metadata?: Record<string, unknown>
}

export interface Device {
  id: string
  device_id: string
  name: string
  device_type: 'smartphone' | 'esp32' | 'raspberry_pi' | 'custom'
  firmware_version?: string
  hardware_info?: Record<string, unknown>
  calibration_offset: number
  location_lat?: number
  location_lng?: number
  address?: string
  is_active: boolean
  is_public: boolean
  created_at: string
  updated_at: string
  last_seen?: string
  last_heartbeat?: string
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

export interface GeoJSONFeature {
  type: 'Feature'
  geometry: { type: 'Point'; coordinates: [number, number] }
  properties: {
    id: string
    device_id: string
    leq_db?: number
    lmax_db?: number
    lmin_db?: number
    timestamp_start?: string
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

export const api = {
  health: () => axios.get(`${API_ROOT_URL}/health`).then((res) => res.data),

  auth: {
    login: (data: LoginRequest) =>
      apiClient.post<AuthTokens>('/auth/login', data).then((res) => {
        setAuthToken(res.data.access_token)
        return res.data
      }),

    register: (data: RegisterRequest) =>
      apiClient.post<AuthTokens>('/auth/register', data).then((res) => {
        setAuthToken(res.data.access_token)
        return res.data
      }),

    logout: () => {
      setAuthToken(null)
    },
  },

  events: {
    list: (params?: EventsListParams) =>
      apiClient
        .get<EventListResponse>('/events/', { params })
        .then((res) => res.data),

    get: (id: string) =>
      apiClient.get<NoiseEvent>(`/events/${id}`).then((res) => res.data),

    create: (event: NoiseEventCreate) =>
      apiClient.post<NoiseEvent>('/events/', event).then((res) => res.data),
  },

  devices: {
    list: () => apiClient.get<Device[]>('/devices/').then((res) => res.data),

    get: (deviceId: string) =>
      apiClient.get<Device>(`/devices/${deviceId}`).then((res) => res.data),

    create: (device: Partial<Device> & Pick<Device, 'device_id' | 'name'>) =>
      apiClient.post<Device>('/devices/register', device).then((res) => res.data),

    update: (deviceId: string, device: Partial<Device>) =>
      apiClient.put<Device>(`/devices/${deviceId}`, device).then((res) => res.data),
  },

  map: {
    events: (params?: {
      min_lat?: number
      max_lat?: number
      min_lng?: number
      max_lng?: number
      hours?: number
      limit?: number
    }) => apiClient.get<GeoJSONResponse>('/map/events', { params }).then((res) => res.data),

    heatmap: (params: {
      min_lat: number
      max_lat: number
      min_lng: number
      max_lng: number
      hours?: number
    }) => apiClient.get<HeatmapResponse>('/map/heatmap', { params }).then((res) => res.data),

    stats: () => apiClient.get<MapStats>('/map/stats').then((res) => res.data),
  },
}

export default apiClient
