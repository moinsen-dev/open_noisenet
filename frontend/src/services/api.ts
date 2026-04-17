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

export function hasStoredAuthToken(): boolean {
  return typeof localStorage !== 'undefined' && Boolean(localStorage.getItem(TOKEN_KEY))
}

apiClient.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject(error)
)

export interface NoiseEvent {
  id: string
  event_uuid?: string
  episode_id?: string
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
  analysis_state: string
  classification_label?: string
  classification_confidence?: number
  classification_source?: string
  segment_type?: string
  reportability_score?: number
  reportability_reason?: string
  peak_to_average_delta_db?: number
  variability_db?: number
  threshold_exceedance_ratio?: number
  analysis_updated_at?: string
  status: 'active' | 'processed' | 'archived' | 'invalid'
  created_at: string
  updated_at: string
}

export interface NoiseEventCreate {
  event_uuid?: string
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
  classification_label?: string
  classification_confidence?: number
  classification_source?: string
  segment_type?: string
  reportability_score?: number
  reportability_reason?: string
  peak_to_average_delta_db?: number
  variability_db?: number
  threshold_exceedance_ratio?: number
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
  site_id?: string
  zone_id?: string
  calibration_profile_id?: string
  is_active: boolean
  is_public: boolean
  created_at: string
  updated_at: string
  last_seen?: string
  last_heartbeat?: string
}

export interface Organization {
  id: string
  name: string
  slug: string
  plan_tier: 'pro_site' | 'portfolio'
  status: 'active' | 'inactive' | 'pilot'
  billing_state: string
  created_by_id: string
  current_user_role: 'owner' | 'admin' | 'member'
  created_at: string
  updated_at: string
}

export interface OrganizationCreate {
  name: string
  slug: string
  plan_tier?: 'pro_site' | 'portfolio'
}

export interface Site {
  id: string
  organization_id: string
  name: string
  timezone: string
  address?: string
  location_lat?: number
  location_lng?: number
  is_public: boolean
  created_at: string
  updated_at: string
}

export interface SiteCreate {
  organization_id: string
  name: string
  timezone?: string
  address?: string
  location_lat?: number
  location_lng?: number
  is_public?: boolean
}

export interface Zone {
  id: string
  site_id: string
  name: string
  description?: string
  quiet_hours_start?: string
  quiet_hours_end?: string
  is_public: boolean
  created_at: string
  updated_at: string
}

export interface ZoneCreate {
  site_id: string
  name: string
  description?: string
  quiet_hours_start?: string
  quiet_hours_end?: string
  is_public?: boolean
}

export interface Policy {
  id: string
  scope_type: 'organization' | 'site' | 'zone'
  organization_id?: string
  site_id?: string
  zone_id?: string
  name: string
  evidence_mode: 'derived_only' | 'encrypted_buffer' | 'redacted_snippet'
  retention_days: number
  quiet_hours_start?: string
  quiet_hours_end?: string
  day_threshold_db?: number
  night_threshold_db?: number
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface PolicyCreate {
  scope_type: 'organization' | 'site' | 'zone'
  organization_id?: string
  site_id?: string
  zone_id?: string
  name: string
  evidence_mode?: 'derived_only' | 'encrypted_buffer' | 'redacted_snippet'
  retention_days?: number
  quiet_hours_start?: string
  quiet_hours_end?: string
  day_threshold_db?: number
  night_threshold_db?: number
  is_active?: boolean
}

export interface CalibrationProfile {
  id: string
  organization_id: string
  site_id?: string
  name: string
  offset_db: number
  method?: string
  confidence?: number
  notes?: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface CalibrationProfileCreate {
  organization_id: string
  site_id?: string
  name: string
  offset_db?: number
  method?: string
  confidence?: number
  notes?: string
  is_active?: boolean
}

export interface DeviceAssignment {
  device_id: string
  site_id: string
  zone_id?: string
  calibration_profile_id?: string
  updated_at: string
}

export interface DeviceAssignmentUpdate {
  site_id: string
  zone_id?: string
  calibration_profile_id?: string
}

export interface SiteDevice {
  id: string
  device_id: string
  name: string
  device_type: string
  site_id?: string
  zone_id?: string
  calibration_profile_id?: string
  is_active: boolean
  hardware_info?: Record<string, unknown>
  last_seen?: string
  last_heartbeat?: string
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

export interface EventReceipt {
  event_uuid: string
  server_event_id: string
  episode_id?: string
  device_id: string
  status: string
  received_at: string
  acknowledged_at: string
  analysis_state: string
  classification_label?: string
  reportability_score?: number
  classification_source?: string
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

export interface Episode {
  id: string
  organization_id: string
  site_id: string
  zone_id?: string
  device_id: string
  device_public_id: string
  policy_id?: string
  primary_class: string
  effective_label: string
  class_family?: string
  review_label?: string
  classification_confidence?: number
  severity: 'informational' | 'low' | 'medium' | 'high' | 'critical'
  effective_severity: 'informational' | 'low' | 'medium' | 'high' | 'critical'
  reviewed_severity?: 'informational' | 'low' | 'medium' | 'high' | 'critical'
  nuisance_score: number
  quiet_hours_triggered: boolean
  evidence_mode: 'derived_only' | 'encrypted_buffer' | 'redacted_snippet'
  review_state: 'pending_review' | 'confirmed' | 'overridden' | 'suppressed'
  lifecycle_state: 'open' | 'extended' | 'closed' | 'exported'
  started_at: string
  ended_at: string
  event_count: number
  review_notes?: string
  model_bundle_id?: string
  reviewed_by_id?: string
  reviewed_at?: string
  exported_at?: string
  created_at: string
  updated_at: string
}

export interface EpisodeListResponse {
  episodes: Episode[]
  total: number
}

export interface EpisodeReviewRequest {
  review_state?: 'pending_review' | 'confirmed' | 'overridden' | 'suppressed'
  review_label?: string
  severity?: 'informational' | 'low' | 'medium' | 'high' | 'critical'
  notes?: string
}

export interface Case {
  id: string
  organization_id: string
  site_id: string
  zone_id?: string
  opened_by_id: string
  closed_by_id?: string
  last_status_changed_by_id?: string
  last_status_changed_at?: string
  status: 'open' | 'in_review' | 'closed'
  title: string
  summary?: string
  audit_history: CaseAuditEntry[]
  opened_at: string
  closed_at?: string
  episode_ids: string[]
  episode_count: number
  created_at: string
  updated_at: string
}

export interface CaseAuditEntry {
  event_type: string
  at: string
  actor_id?: string
  actor_email?: string
  note?: string
  from_status?: string
  to_status?: string
  changed_fields?: string[]
  metadata?: Record<string, unknown>
}

export interface CaseStatusUpdate {
  status?: Case['status']
  title?: string
  summary?: string
  note?: string
}

export interface CaseCreate {
  organization_id: string
  site_id: string
  zone_id?: string
  title: string
  summary?: string
  episode_ids: string[]
}

export interface ExportJob {
  id: string
  case_id: string
  created_by_id: string
  format: 'json' | 'csv' | 'pdf'
  status: 'ready' | 'failed'
  file_name: string
  content_type: string
  output_encoding: string
  preview?: string
  exported_at?: string
  created_at: string
  updated_at: string
}

export interface ExportCreate {
  case_id: string
  format: 'json' | 'csv' | 'pdf'
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

    hasSession: () => hasStoredAuthToken(),
  },

  events: {
    list: (params?: EventsListParams) =>
      apiClient
        .get<EventListResponse>('/events/', { params })
        .then((res) => res.data),

    get: (id: string) =>
      apiClient.get<NoiseEvent>(`/events/${id}`).then((res) => res.data),

    create: (event: NoiseEventCreate) =>
      apiClient.post<EventReceipt>('/events/', event).then((res) => res.data),
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

  organizations: {
    list: () =>
      apiClient.get<Organization[]>('/organizations/').then((res) => res.data),

    get: (organizationId: string) =>
      apiClient
        .get<Organization>(`/organizations/${organizationId}`)
        .then((res) => res.data),

    create: (organization: OrganizationCreate) =>
      apiClient
        .post<Organization>('/organizations/', organization)
        .then((res) => res.data),
  },

  sites: {
    list: (organizationId: string) =>
      apiClient
        .get<Site[]>('/sites/', { params: { organization_id: organizationId } })
        .then((res) => res.data),

    get: (siteId: string) =>
      apiClient.get<Site>(`/sites/${siteId}`).then((res) => res.data),

    create: (site: SiteCreate) =>
      apiClient.post<Site>('/sites/', site).then((res) => res.data),

    listDevices: (siteId: string) =>
      apiClient
        .get<SiteDevice[]>(`/sites/${siteId}/devices`)
        .then((res) => res.data),

    assignDevice: (deviceId: string, assignment: DeviceAssignmentUpdate) =>
      apiClient
        .put<DeviceAssignment>(`/sites/devices/${deviceId}/assignment`, assignment)
        .then((res) => res.data),
  },

  zones: {
    list: (siteId: string) =>
      apiClient
        .get<Zone[]>('/zones/', { params: { site_id: siteId } })
        .then((res) => res.data),

    get: (zoneId: string) =>
      apiClient.get<Zone>(`/zones/${zoneId}`).then((res) => res.data),

    create: (zone: ZoneCreate) =>
      apiClient.post<Zone>('/zones/', zone).then((res) => res.data),
  },

  policies: {
    list: (params: {
      organization_id?: string
      site_id?: string
      zone_id?: string
    }) =>
      apiClient.get<Policy[]>('/policies/', { params }).then((res) => res.data),

    get: (policyId: string) =>
      apiClient.get<Policy>(`/policies/${policyId}`).then((res) => res.data),

    create: (policy: PolicyCreate) =>
      apiClient.post<Policy>('/policies/', policy).then((res) => res.data),
  },

  calibrationProfiles: {
    list: (organizationId: string, siteId?: string) =>
      apiClient
        .get<CalibrationProfile[]>('/calibration-profiles/', {
          params: { organization_id: organizationId, site_id: siteId },
        })
        .then((res) => res.data),

    get: (profileId: string) =>
      apiClient
        .get<CalibrationProfile>(`/calibration-profiles/${profileId}`)
        .then((res) => res.data),

    create: (profile: CalibrationProfileCreate) =>
      apiClient
        .post<CalibrationProfile>('/calibration-profiles/', profile)
        .then((res) => res.data),
  },

  episodes: {
    list: (params: {
      organization_id: string
      site_id?: string
      zone_id?: string
      review_state?: string
      severity?: string
      limit?: number
    }) =>
      apiClient
        .get<EpisodeListResponse>('/episodes/', { params })
        .then((res) => res.data),

    get: (episodeId: string) =>
      apiClient.get<Episode>(`/episodes/${episodeId}`).then((res) => res.data),

    review: (episodeId: string, payload: EpisodeReviewRequest) =>
      apiClient
        .post<Episode>(`/episodes/${episodeId}/review`, payload)
        .then((res) => res.data),
  },

  cases: {
    list: (params: {
      organization_id: string
      site_id?: string
      status?: string
    }) =>
      apiClient.get<Case[]>('/cases/', { params }).then((res) => res.data),

    get: (caseId: string) =>
      apiClient.get<Case>(`/cases/${caseId}`).then((res) => res.data),

    listEpisodes: (caseId: string) =>
      apiClient
        .get<Episode[]>(`/cases/${caseId}/episodes`)
        .then((res) => res.data),

    create: (payload: CaseCreate) =>
      apiClient.post<Case>('/cases/', payload).then((res) => res.data),

    update: (caseId: string, payload: CaseStatusUpdate) =>
      apiClient.patch<Case>(`/cases/${caseId}`, payload).then((res) => res.data),
  },

  exports: {
    list: (params: { organization_id: string; case_id?: string }) =>
      apiClient.get<ExportJob[]>('/exports/', { params }).then((res) => res.data),

    get: (exportId: string) =>
      apiClient.get<ExportJob>(`/exports/${exportId}`).then((res) => res.data),

    create: (payload: ExportCreate) =>
      apiClient.post<ExportJob>('/exports/', payload).then((res) => res.data),

    download: (exportId: string) =>
      apiClient
        .get<Blob>(`/exports/${exportId}/content`, { responseType: 'blob' })
        .then((res) => res.data),
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
