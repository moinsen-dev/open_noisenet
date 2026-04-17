import { useEffect, useMemo, useState } from 'react'
import { Link as RouterLink } from 'react-router-dom'
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Divider,
  FormControl,
  Grid,
  InputLabel,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  MenuItem,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material'
import { Apartment, Business, Logout, Security, Tune } from '@mui/icons-material'
import toast from 'react-hot-toast'

import {
  api,
  Case as OperatorCase,
  CalibrationProfile,
  Device,
  DeviceAssignmentUpdate,
  Episode,
  ExportJob,
  Organization,
  Policy,
  Site,
  SiteDevice,
  Zone,
  hasStoredAuthToken,
} from '../services/api'

function formatError(error: any): string {
  return (
    error?.response?.data?.detail ||
    error?.response?.data?.message ||
    error?.message ||
    'Request failed'
  )
}

export default function OperationsPage() {
  const [authenticated, setAuthenticated] = useState(hasStoredAuthToken())
  const [authMode, setAuthMode] = useState<'login' | 'register'>('register')
  const [authLoading, setAuthLoading] = useState(false)
  const [authError, setAuthError] = useState<string | null>(null)
  const [authForm, setAuthForm] = useState({
    email: '',
    password: '',
    full_name: '',
  })

  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [organizations, setOrganizations] = useState<Organization[]>([])
  const [sites, setSites] = useState<Site[]>([])
  const [zones, setZones] = useState<Zone[]>([])
  const [policies, setPolicies] = useState<Policy[]>([])
  const [profiles, setProfiles] = useState<CalibrationProfile[]>([])
  const [devices, setDevices] = useState<Device[]>([])
  const [siteDevices, setSiteDevices] = useState<SiteDevice[]>([])
  const [episodes, setEpisodes] = useState<Episode[]>([])
  const [cases, setCases] = useState<OperatorCase[]>([])
  const [exports, setExports] = useState<ExportJob[]>([])

  const [selectedOrganizationId, setSelectedOrganizationId] = useState('')
  const [selectedSiteId, setSelectedSiteId] = useState('')
  const [selectedZoneId, setSelectedZoneId] = useState('')
  const [selectedEpisodeId, setSelectedEpisodeId] = useState('')
  const [selectedCaseId, setSelectedCaseId] = useState('')
  const [selectedEpisodeIds, setSelectedEpisodeIds] = useState<string[]>([])

  const [organizationForm, setOrganizationForm] = useState({
    name: '',
    slug: '',
    plan_tier: 'pro_site' as 'pro_site' | 'portfolio',
  })
  const [siteForm, setSiteForm] = useState({
    name: '',
    timezone: 'Europe/Berlin',
    address: '',
  })
  const [zoneForm, setZoneForm] = useState({
    name: '',
    description: '',
    quiet_hours_start: '22:00',
    quiet_hours_end: '06:00',
  })
  const [policyForm, setPolicyForm] = useState({
    scope_type: 'site' as 'organization' | 'site' | 'zone',
    name: 'Quiet Hours Policy',
    evidence_mode: 'derived_only' as 'derived_only' | 'encrypted_buffer' | 'redacted_snippet',
    retention_days: 365,
    quiet_hours_start: '22:00',
    quiet_hours_end: '06:00',
    day_threshold_db: 65,
    night_threshold_db: 55,
  })
  const [profileForm, setProfileForm] = useState({
    name: 'Default Site Calibration',
    offset_db: 0,
    method: 'manual meter alignment',
    confidence: 0.8,
  })
  const [assignmentForm, setAssignmentForm] = useState<DeviceAssignmentUpdate & { device_id: string }>({
    device_id: '',
    site_id: '',
    zone_id: '',
    calibration_profile_id: '',
  })
  const [episodeReviewForm, setEpisodeReviewForm] = useState({
    review_label: '',
    severity: 'medium' as 'informational' | 'low' | 'medium' | 'high' | 'critical',
    notes: '',
  })
  const [caseForm, setCaseForm] = useState({
    title: '',
    summary: '',
  })
  const [exportFormat, setExportFormat] = useState<'json' | 'csv' | 'pdf'>('json')

  const selectedOrganization = useMemo(
    () => organizations.find((organization) => organization.id === selectedOrganizationId) ?? null,
    [organizations, selectedOrganizationId]
  )
  const selectedSite = useMemo(
    () => sites.find((site) => site.id === selectedSiteId) ?? null,
    [sites, selectedSiteId]
  )
  const selectedEpisode = useMemo(
    () => episodes.find((episode) => episode.id === selectedEpisodeId) ?? null,
    [episodes, selectedEpisodeId]
  )

  async function loadOrganizations() {
    const loaded = await api.organizations.list()
    setOrganizations(loaded)
    if (!selectedOrganizationId && loaded[0]) {
      setSelectedOrganizationId(loaded[0].id)
    } else if (selectedOrganizationId && !loaded.find((item) => item.id === selectedOrganizationId)) {
      setSelectedOrganizationId(loaded[0]?.id ?? '')
    }
    return loaded
  }

  async function loadOrganizationContext(organizationId: string) {
    const [loadedSites, loadedPolicies, loadedProfiles, loadedDevices] = await Promise.all([
      api.sites.list(organizationId),
      api.policies.list({ organization_id: organizationId }),
      api.calibrationProfiles.list(organizationId),
      api.devices.list(),
    ])

    setSites(loadedSites)
    setProfiles(loadedProfiles)
    setDevices(loadedDevices)

    setPolicies((prev) => {
      const remaining = prev.filter((policy) => policy.organization_id !== organizationId)
      return [...loadedPolicies, ...remaining]
    })

    const nextSiteId =
      selectedSiteId && loadedSites.find((site) => site.id === selectedSiteId)
        ? selectedSiteId
        : loadedSites[0]?.id ?? ''
    setSelectedSiteId(nextSiteId)
    if (nextSiteId) {
      await loadSiteContext(nextSiteId, organizationId)
    } else {
      setZones([])
      setSiteDevices([])
      setEpisodes([])
      setCases([])
      setExports([])
      setSelectedEpisodeId('')
      setSelectedCaseId('')
      setSelectedEpisodeIds([])
    }
  }

  async function loadSiteContext(siteId: string, organizationId = selectedOrganizationId) {
    const [loadedZones, loadedPolicies, loadedSiteDevices, loadedEpisodes, loadedCases, loadedExports] = await Promise.all([
      api.zones.list(siteId),
      api.policies.list({ site_id: siteId }),
      api.sites.listDevices(siteId),
      api.episodes.list({ organization_id: organizationId, site_id: siteId }),
      api.cases.list({ organization_id: organizationId, site_id: siteId }),
      api.exports.list({ organization_id: organizationId }),
    ])
    setZones(loadedZones)
    setSiteDevices(loadedSiteDevices)
    setEpisodes(loadedEpisodes.episodes)
    setCases(loadedCases)
    setExports(loadedExports)

    setPolicies((prev) => {
      const remaining = prev.filter((policy) => policy.site_id !== siteId)
      return [...loadedPolicies, ...remaining]
    })

    const nextZoneId =
      selectedZoneId && loadedZones.find((zone) => zone.id === selectedZoneId)
        ? selectedZoneId
        : loadedZones[0]?.id ?? ''
    setSelectedZoneId(nextZoneId)
    setSelectedEpisodeId((current) =>
      current && loadedEpisodes.episodes.find((episode) => episode.id === current)
        ? current
        : loadedEpisodes.episodes[0]?.id ?? ''
    )
    setSelectedCaseId((current) =>
      current && loadedCases.find((item) => item.id === current)
        ? current
        : loadedCases[0]?.id ?? ''
    )
    setSelectedEpisodeIds((current) =>
      current.filter((episodeId) => loadedEpisodes.episodes.some((episode) => episode.id === episodeId))
    )
  }

  useEffect(() => {
    if (!authenticated) {
      return
    }

    let cancelled = false

    async function bootstrap() {
      setLoading(true)
      setError(null)
      try {
        const loadedOrganizations = await loadOrganizations()
        if (cancelled) return
        const nextOrganizationId = selectedOrganizationId || loadedOrganizations[0]?.id
        if (nextOrganizationId) {
          await loadOrganizationContext(nextOrganizationId)
        } else {
          setSites([])
          setZones([])
          setPolicies([])
          setProfiles([])
          setDevices([])
          setSiteDevices([])
        }
      } catch (err) {
        if (!cancelled) {
          setError(formatError(err))
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    void bootstrap()
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authenticated])

  useEffect(() => {
    if (!authenticated || !selectedOrganizationId) {
      return
    }
    let cancelled = false
    async function load() {
      setLoading(true)
      setError(null)
      try {
        await loadOrganizationContext(selectedOrganizationId)
      } catch (err) {
        if (!cancelled) {
          setError(formatError(err))
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }
    void load()
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedOrganizationId])

  useEffect(() => {
    if (!authenticated || !selectedSiteId) {
      setZones([])
      setSiteDevices([])
      return
    }
    let cancelled = false
    async function load() {
      setLoading(true)
      setError(null)
      try {
        await loadSiteContext(selectedSiteId)
      } catch (err) {
        if (!cancelled) {
          setError(formatError(err))
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }
    void load()
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedSiteId])

  const handleAuthSubmit = async () => {
    setAuthLoading(true)
    setAuthError(null)
    try {
      if (authMode === 'register') {
        await api.auth.register({
          email: authForm.email,
          password: authForm.password,
          full_name: authForm.full_name,
        })
      } else {
        await api.auth.login({
          email: authForm.email,
          password: authForm.password,
        })
      }
      setAuthenticated(true)
      toast.success(authMode === 'register' ? 'Account created' : 'Signed in')
    } catch (err) {
      setAuthError(formatError(err))
    } finally {
      setAuthLoading(false)
    }
  }

  const handleLogout = () => {
    api.auth.logout()
    setAuthenticated(false)
    setOrganizations([])
    setSites([])
    setZones([])
    setPolicies([])
    setProfiles([])
    setDevices([])
    setSiteDevices([])
    setEpisodes([])
    setCases([])
    setExports([])
    setSelectedOrganizationId('')
    setSelectedSiteId('')
    setSelectedZoneId('')
    setSelectedEpisodeId('')
    setSelectedCaseId('')
    setSelectedEpisodeIds([])
  }

  const handleCreateOrganization = async () => {
    try {
      const created = await api.organizations.create(organizationForm)
      toast.success('Organization created')
      setOrganizationForm({ name: '', slug: '', plan_tier: organizationForm.plan_tier })
      await loadOrganizations()
      setSelectedOrganizationId(created.id)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleCreateSite = async () => {
    if (!selectedOrganizationId) return
    try {
      const created = await api.sites.create({
        organization_id: selectedOrganizationId,
        name: siteForm.name,
        timezone: siteForm.timezone,
        address: siteForm.address || undefined,
      })
      toast.success('Site created')
      setSiteForm({ ...siteForm, name: '', address: '' })
      await loadOrganizationContext(selectedOrganizationId)
      setSelectedSiteId(created.id)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleCreateZone = async () => {
    if (!selectedSiteId) return
    try {
      const created = await api.zones.create({
        site_id: selectedSiteId,
        name: zoneForm.name,
        description: zoneForm.description || undefined,
        quiet_hours_start: zoneForm.quiet_hours_start || undefined,
        quiet_hours_end: zoneForm.quiet_hours_end || undefined,
      })
      toast.success('Zone created')
      setZoneForm({ ...zoneForm, name: '', description: '' })
      await loadSiteContext(selectedSiteId)
      setSelectedZoneId(created.id)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleCreatePolicy = async () => {
    if (!selectedOrganizationId) return

    try {
      const payload: Record<string, unknown> = {
        scope_type: policyForm.scope_type,
        name: policyForm.name,
        evidence_mode: policyForm.evidence_mode,
        retention_days: policyForm.retention_days,
        quiet_hours_start: policyForm.quiet_hours_start || undefined,
        quiet_hours_end: policyForm.quiet_hours_end || undefined,
        day_threshold_db: policyForm.day_threshold_db,
        night_threshold_db: policyForm.night_threshold_db,
      }

      if (policyForm.scope_type === 'organization') {
        payload.organization_id = selectedOrganizationId
      } else if (policyForm.scope_type === 'site') {
        payload.site_id = selectedSiteId
      } else {
        payload.zone_id = selectedZoneId
      }

      await api.policies.create(payload as any)
      toast.success('Policy created')
      if (policyForm.scope_type === 'organization') {
        await loadOrganizationContext(selectedOrganizationId)
      } else {
        await loadSiteContext(selectedSiteId)
      }
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleCreateProfile = async () => {
    if (!selectedOrganizationId || !selectedSiteId) return
    try {
      await api.calibrationProfiles.create({
        organization_id: selectedOrganizationId,
        site_id: selectedSiteId,
        name: profileForm.name,
        offset_db: profileForm.offset_db,
        method: profileForm.method || undefined,
        confidence: profileForm.confidence,
      })
      toast.success('Calibration profile created')
      await loadOrganizationContext(selectedOrganizationId)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleAssignDevice = async () => {
    if (!assignmentForm.device_id || !selectedSiteId) return
    try {
      await api.sites.assignDevice(assignmentForm.device_id, {
        site_id: selectedSiteId,
        zone_id: assignmentForm.zone_id || undefined,
        calibration_profile_id: assignmentForm.calibration_profile_id || undefined,
      })
      toast.success('Device assigned')
      setAssignmentForm({
        device_id: '',
        site_id: selectedSiteId,
        zone_id: '',
        calibration_profile_id: '',
      })
      await loadSiteContext(selectedSiteId)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const toggleEpisodeSelection = (episodeId: string) => {
    setSelectedEpisodeIds((current) =>
      current.includes(episodeId)
        ? current.filter((id) => id !== episodeId)
        : [...current, episodeId]
    )
  }

  const handleOpenEpisodeReview = (episode: Episode) => {
    setSelectedEpisodeId(episode.id)
    setEpisodeReviewForm({
      review_label: episode.review_label || episode.effective_label,
      severity: episode.effective_severity,
      notes: episode.review_notes || '',
    })
  }

  const handleReviewEpisode = async () => {
    if (!selectedEpisodeId) return
    try {
      await api.episodes.review(selectedEpisodeId, {
        review_state: 'overridden',
        review_label: episodeReviewForm.review_label || undefined,
        severity: episodeReviewForm.severity,
        notes: episodeReviewForm.notes || undefined,
      })
      toast.success('Episode reviewed')
      await loadSiteContext(selectedSiteId)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleConfirmEpisode = async (episodeId: string) => {
    try {
      await api.episodes.review(episodeId, { review_state: 'confirmed' })
      toast.success('Episode confirmed')
      await loadSiteContext(selectedSiteId)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleCreateCase = async () => {
    if (!selectedOrganizationId || !selectedSiteId || selectedEpisodeIds.length === 0) return
    try {
      const created = await api.cases.create({
        organization_id: selectedOrganizationId,
        site_id: selectedSiteId,
        zone_id: selectedZoneId || undefined,
        title: caseForm.title,
        summary: caseForm.summary || undefined,
        episode_ids: selectedEpisodeIds,
      })
      toast.success('Case created')
      setCaseForm({ title: '', summary: '' })
      setSelectedEpisodeIds([])
      setSelectedCaseId(created.id)
      await loadSiteContext(selectedSiteId)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleCreateExport = async () => {
    if (!selectedCaseId || !selectedOrganizationId) return
    try {
      const created = await api.exports.create({
        case_id: selectedCaseId,
        format: exportFormat,
      })
      toast.success(`Export ${created.format.toUpperCase()} generated`)
      await loadSiteContext(selectedSiteId)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const handleDownloadExport = async (exportJob: ExportJob) => {
    try {
      const blob = await api.exports.download(exportJob.id)
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = exportJob.file_name
      link.click()
      window.URL.revokeObjectURL(url)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const policiesForCurrentContext = policies.filter((policy) => {
    if (policy.scope_type === 'organization') {
      return policy.organization_id === selectedOrganizationId
    }
    if (policy.scope_type === 'site') {
      return policy.site_id === selectedSiteId
    }
    return policy.zone_id === selectedZoneId
  })

  const profilesForCurrentSite = profiles.filter(
    (profile) => !profile.site_id || profile.site_id === selectedSiteId
  )

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Pro Setup
          </Typography>
          <Typography variant="body1" color="textSecondary">
            Configure organizations, sites, policies, calibration, and device assignment before handing off daily review to the operator inbox.
          </Typography>
        </Box>
        {authenticated ? (
          <Button variant="contained" component={RouterLink} to="/operations/inbox">
            Open Episode Inbox
          </Button>
        ) : null}
        {authenticated ? (
          <Button variant="outlined" color="inherit" startIcon={<Logout />} onClick={handleLogout}>
            Sign out
          </Button>
        ) : null}
      </Box>

      {error ? (
        <Alert severity="warning" sx={{ mb: 3 }}>
          {error}
        </Alert>
      ) : null}

      {!authenticated ? (
        <Grid container spacing={3}>
          <Grid item xs={12} md={7}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Operator Access
                </Typography>
                <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
                  <Button
                    variant={authMode === 'register' ? 'contained' : 'outlined'}
                    onClick={() => setAuthMode('register')}
                  >
                    Register
                  </Button>
                  <Button
                    variant={authMode === 'login' ? 'contained' : 'outlined'}
                    onClick={() => setAuthMode('login')}
                  >
                    Login
                  </Button>
                </Stack>
                {authError ? (
                  <Alert severity="error" sx={{ mb: 2 }}>
                    {authError}
                  </Alert>
                ) : null}
                <Grid container spacing={2}>
                  <Grid item xs={12} md={authMode === 'register' ? 4 : 6}>
                    <TextField
                      fullWidth
                      label="Email"
                      value={authForm.email}
                      onChange={(event) =>
                        setAuthForm((prev) => ({ ...prev, email: event.target.value }))
                      }
                    />
                  </Grid>
                  <Grid item xs={12} md={authMode === 'register' ? 4 : 6}>
                    <TextField
                      fullWidth
                      type="password"
                      label="Password"
                      value={authForm.password}
                      onChange={(event) =>
                        setAuthForm((prev) => ({ ...prev, password: event.target.value }))
                      }
                    />
                  </Grid>
                  {authMode === 'register' ? (
                    <Grid item xs={12} md={4}>
                      <TextField
                        fullWidth
                        label="Full name"
                        value={authForm.full_name}
                        onChange={(event) =>
                          setAuthForm((prev) => ({ ...prev, full_name: event.target.value }))
                        }
                      />
                    </Grid>
                  ) : null}
                </Grid>
                <Button
                  sx={{ mt: 2 }}
                  variant="contained"
                  onClick={handleAuthSubmit}
                  disabled={authLoading || !authForm.email || !authForm.password || (authMode === 'register' && !authForm.full_name)}
                >
                  {authLoading ? 'Working…' : authMode === 'register' ? 'Create operator account' : 'Sign in'}
                </Button>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} md={5}>
            <Card sx={{ height: '100%' }}>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  What this flow covers
                </Typography>
                <Typography variant="body2" color="textSecondary" paragraph>
                  This is the first Pro operator surface on top of the current MVP APIs. It is intentionally narrow:
                  establish tenant context, place devices into site and zone structure, define policy defaults,
                  and prepare the episode-based workflow.
                </Typography>
                <Stack spacing={1}>
                  <Chip icon={<Business />} label="Organization and plan tier" />
                  <Chip icon={<Apartment />} label="Site and zone structure" />
                  <Chip icon={<Security />} label="Policy and evidence defaults" />
                  <Chip icon={<Tune />} label="Calibration and device assignment" />
                </Stack>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      ) : (
        <>
          {loading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
              <CircularProgress />
            </Box>
          ) : null}

          <Grid container spacing={3}>
            <Grid item xs={12} md={4}>
              <Card sx={{ height: '100%' }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Organizations
                  </Typography>
                  <List dense sx={{ mb: 2 }}>
                    {organizations.map((organization) => (
                      <ListItem key={organization.id} disablePadding>
                        <ListItemButton
                          selected={organization.id === selectedOrganizationId}
                          onClick={() => setSelectedOrganizationId(organization.id)}
                        >
                          <ListItemText
                            primary={organization.name}
                            secondary={`${organization.plan_tier} • ${organization.current_user_role}`}
                          />
                        </ListItemButton>
                      </ListItem>
                    ))}
                  </List>
                  <Divider sx={{ mb: 2 }} />
                  <Typography variant="subtitle1" gutterBottom>
                    Create organization
                  </Typography>
                  <Stack spacing={2}>
                    <TextField
                      label="Name"
                      value={organizationForm.name}
                      onChange={(event) =>
                        setOrganizationForm((prev) => ({ ...prev, name: event.target.value }))
                      }
                    />
                    <TextField
                      label="Slug"
                      value={organizationForm.slug}
                      onChange={(event) =>
                        setOrganizationForm((prev) => ({ ...prev, slug: event.target.value }))
                      }
                    />
                    <FormControl fullWidth>
                      <InputLabel>Plan tier</InputLabel>
                      <Select
                        label="Plan tier"
                        value={organizationForm.plan_tier}
                        onChange={(event) =>
                          setOrganizationForm((prev) => ({
                            ...prev,
                            plan_tier: event.target.value as 'pro_site' | 'portfolio',
                          }))
                        }
                      >
                        <MenuItem value="pro_site">Pro Site</MenuItem>
                        <MenuItem value="portfolio">Portfolio</MenuItem>
                      </Select>
                    </FormControl>
                    <Button
                      variant="contained"
                      onClick={handleCreateOrganization}
                      disabled={!organizationForm.name || !organizationForm.slug}
                    >
                      Create organization
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>

            <Grid item xs={12} md={4}>
              <Card sx={{ height: '100%' }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Sites
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    {selectedOrganization ? selectedOrganization.name : 'Select an organization first'}
                  </Typography>
                  <List dense sx={{ mb: 2 }}>
                    {sites.map((site) => (
                      <ListItem key={site.id} disablePadding>
                        <ListItemButton
                          selected={site.id === selectedSiteId}
                          onClick={() => setSelectedSiteId(site.id)}
                        >
                          <ListItemText
                            primary={site.name}
                            secondary={`${site.timezone}${site.address ? ` • ${site.address}` : ''}`}
                          />
                        </ListItemButton>
                      </ListItem>
                    ))}
                  </List>
                  <Divider sx={{ mb: 2 }} />
                  <Typography variant="subtitle1" gutterBottom>
                    Create site
                  </Typography>
                  <Stack spacing={2}>
                    <TextField
                      label="Name"
                      value={siteForm.name}
                      onChange={(event) =>
                        setSiteForm((prev) => ({ ...prev, name: event.target.value }))
                      }
                    />
                    <TextField
                      label="Timezone"
                      value={siteForm.timezone}
                      onChange={(event) =>
                        setSiteForm((prev) => ({ ...prev, timezone: event.target.value }))
                      }
                    />
                    <TextField
                      label="Address"
                      value={siteForm.address}
                      onChange={(event) =>
                        setSiteForm((prev) => ({ ...prev, address: event.target.value }))
                      }
                    />
                    <Button
                      variant="contained"
                      onClick={handleCreateSite}
                      disabled={!selectedOrganizationId || !siteForm.name}
                    >
                      Create site
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>

            <Grid item xs={12} md={4}>
              <Card sx={{ height: '100%' }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Zones
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    {selectedSite ? selectedSite.name : 'Select a site first'}
                  </Typography>
                  <List dense sx={{ mb: 2 }}>
                    {zones.map((zone) => (
                      <ListItem key={zone.id} disablePadding>
                        <ListItemButton
                          selected={zone.id === selectedZoneId}
                          onClick={() => setSelectedZoneId(zone.id)}
                        >
                          <ListItemText
                            primary={zone.name}
                            secondary={
                              zone.quiet_hours_start && zone.quiet_hours_end
                                ? `${zone.quiet_hours_start}-${zone.quiet_hours_end}`
                                : zone.description || 'No quiet hours'
                            }
                          />
                        </ListItemButton>
                      </ListItem>
                    ))}
                  </List>
                  <Divider sx={{ mb: 2 }} />
                  <Typography variant="subtitle1" gutterBottom>
                    Create zone
                  </Typography>
                  <Stack spacing={2}>
                    <TextField
                      label="Name"
                      value={zoneForm.name}
                      onChange={(event) =>
                        setZoneForm((prev) => ({ ...prev, name: event.target.value }))
                      }
                    />
                    <TextField
                      label="Description"
                      value={zoneForm.description}
                      onChange={(event) =>
                        setZoneForm((prev) => ({ ...prev, description: event.target.value }))
                      }
                    />
                    <Stack direction="row" spacing={2}>
                      <TextField
                        label="Quiet start"
                        value={zoneForm.quiet_hours_start}
                        onChange={(event) =>
                          setZoneForm((prev) => ({ ...prev, quiet_hours_start: event.target.value }))
                        }
                      />
                      <TextField
                        label="Quiet end"
                        value={zoneForm.quiet_hours_end}
                        onChange={(event) =>
                          setZoneForm((prev) => ({ ...prev, quiet_hours_end: event.target.value }))
                        }
                      />
                    </Stack>
                    <Button
                      variant="contained"
                      onClick={handleCreateZone}
                      disabled={!selectedSiteId || !zoneForm.name}
                    >
                      Create zone
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>

            <Grid item xs={12} lg={6}>
              <Card sx={{ height: '100%' }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Policies
                  </Typography>
                  <Stack spacing={2} sx={{ mb: 3 }}>
                    <FormControl fullWidth>
                      <InputLabel>Scope</InputLabel>
                      <Select
                        label="Scope"
                        value={policyForm.scope_type}
                        onChange={(event) =>
                          setPolicyForm((prev) => ({
                            ...prev,
                            scope_type: event.target.value as 'organization' | 'site' | 'zone',
                          }))
                        }
                      >
                        <MenuItem value="organization">Organization</MenuItem>
                        <MenuItem value="site">Site</MenuItem>
                        <MenuItem value="zone">Zone</MenuItem>
                      </Select>
                    </FormControl>
                    <TextField
                      label="Policy name"
                      value={policyForm.name}
                      onChange={(event) =>
                        setPolicyForm((prev) => ({ ...prev, name: event.target.value }))
                      }
                    />
                    <Stack direction="row" spacing={2}>
                      <TextField
                        type="number"
                        label="Day threshold"
                        value={policyForm.day_threshold_db}
                        onChange={(event) =>
                          setPolicyForm((prev) => ({
                            ...prev,
                            day_threshold_db: Number(event.target.value),
                          }))
                        }
                      />
                      <TextField
                        type="number"
                        label="Night threshold"
                        value={policyForm.night_threshold_db}
                        onChange={(event) =>
                          setPolicyForm((prev) => ({
                            ...prev,
                            night_threshold_db: Number(event.target.value),
                          }))
                        }
                      />
                    </Stack>
                    <Button
                      variant="contained"
                      onClick={handleCreatePolicy}
                      disabled={
                        !selectedOrganizationId ||
                        !policyForm.name ||
                        (policyForm.scope_type === 'site' && !selectedSiteId) ||
                        (policyForm.scope_type === 'zone' && !selectedZoneId)
                      }
                    >
                      Create policy
                    </Button>
                  </Stack>
                  <Divider sx={{ mb: 2 }} />
                  <List dense>
                    {policiesForCurrentContext.map((policy) => (
                      <ListItem key={policy.id}>
                        <ListItemText
                          primary={`${policy.name} • ${policy.scope_type}`}
                          secondary={`Evidence: ${policy.evidence_mode} • Day ${policy.day_threshold_db ?? '—'} dB • Night ${policy.night_threshold_db ?? '—'} dB`}
                        />
                      </ListItem>
                    ))}
                  </List>
                </CardContent>
              </Card>
            </Grid>

            <Grid item xs={12} lg={6}>
              <Card sx={{ height: '100%' }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Calibration Profiles
                  </Typography>
                  <Stack spacing={2} sx={{ mb: 3 }}>
                    <TextField
                      label="Profile name"
                      value={profileForm.name}
                      onChange={(event) =>
                        setProfileForm((prev) => ({ ...prev, name: event.target.value }))
                      }
                    />
                    <Stack direction="row" spacing={2}>
                      <TextField
                        type="number"
                        label="Offset dB"
                        value={profileForm.offset_db}
                        onChange={(event) =>
                          setProfileForm((prev) => ({
                            ...prev,
                            offset_db: Number(event.target.value),
                          }))
                        }
                      />
                      <TextField
                        type="number"
                        label="Confidence"
                        inputProps={{ min: 0, max: 1, step: 0.1 }}
                        value={profileForm.confidence}
                        onChange={(event) =>
                          setProfileForm((prev) => ({
                            ...prev,
                            confidence: Number(event.target.value),
                          }))
                        }
                      />
                    </Stack>
                    <TextField
                      label="Method"
                      value={profileForm.method}
                      onChange={(event) =>
                        setProfileForm((prev) => ({ ...prev, method: event.target.value }))
                      }
                    />
                    <Button
                      variant="contained"
                      onClick={handleCreateProfile}
                      disabled={!selectedOrganizationId || !selectedSiteId || !profileForm.name}
                    >
                      Create calibration profile
                    </Button>
                  </Stack>
                  <Divider sx={{ mb: 2 }} />
                  <List dense>
                    {profilesForCurrentSite.map((profile) => (
                      <ListItem key={profile.id}>
                        <ListItemText
                          primary={`${profile.name} • ${profile.offset_db.toFixed(1)} dB`}
                          secondary={`${profile.method || 'No method'}${profile.confidence != null ? ` • confidence ${profile.confidence}` : ''}`}
                        />
                      </ListItem>
                    ))}
                  </List>
                </CardContent>
              </Card>
            </Grid>

            <Grid item xs={12}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Device Assignment
                  </Typography>
                  <Grid container spacing={2} sx={{ mb: 3 }}>
                    <Grid item xs={12} md={4}>
                      <FormControl fullWidth>
                        <InputLabel>Device</InputLabel>
                        <Select
                          label="Device"
                          value={assignmentForm.device_id}
                          onChange={(event) =>
                            setAssignmentForm((prev) => ({
                              ...prev,
                              device_id: event.target.value,
                              site_id: selectedSiteId,
                            }))
                          }
                        >
                          {devices.map((device) => (
                            <MenuItem key={device.id} value={device.device_id}>
                              {device.name} • {device.device_id}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    </Grid>
                    <Grid item xs={12} md={4}>
                      <FormControl fullWidth>
                        <InputLabel>Zone</InputLabel>
                        <Select
                          label="Zone"
                          value={assignmentForm.zone_id || ''}
                          onChange={(event) =>
                            setAssignmentForm((prev) => ({
                              ...prev,
                              zone_id: event.target.value,
                            }))
                          }
                        >
                          <MenuItem value="">No zone</MenuItem>
                          {zones.map((zone) => (
                            <MenuItem key={zone.id} value={zone.id}>
                              {zone.name}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    </Grid>
                    <Grid item xs={12} md={4}>
                      <FormControl fullWidth>
                        <InputLabel>Calibration profile</InputLabel>
                        <Select
                          label="Calibration profile"
                          value={assignmentForm.calibration_profile_id || ''}
                          onChange={(event) =>
                            setAssignmentForm((prev) => ({
                              ...prev,
                              calibration_profile_id: event.target.value,
                            }))
                          }
                        >
                          <MenuItem value="">No profile</MenuItem>
                          {profilesForCurrentSite.map((profile) => (
                            <MenuItem key={profile.id} value={profile.id}>
                              {profile.name}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    </Grid>
                  </Grid>
                  <Button
                    variant="contained"
                    onClick={handleAssignDevice}
                    disabled={!selectedSiteId || !assignmentForm.device_id}
                  >
                    Assign device to site
                  </Button>

                  <Divider sx={{ my: 3 }} />

                  <Typography variant="subtitle1" gutterBottom>
                    Site Devices
                  </Typography>
                  <TableContainer>
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>Device</TableCell>
                          <TableCell>Type</TableCell>
                          <TableCell>Zone</TableCell>
                          <TableCell>Calibration</TableCell>
                          <TableCell>Last Heartbeat</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {siteDevices.map((device) => (
                          <TableRow key={device.id}>
                            <TableCell>
                              <Typography variant="body2" fontWeight="medium">
                                {device.name}
                              </Typography>
                              <Typography variant="caption" color="textSecondary">
                                {device.device_id}
                              </Typography>
                            </TableCell>
                            <TableCell>{device.device_type}</TableCell>
                            <TableCell>
                              {zones.find((zone) => zone.id === device.zone_id)?.name || '—'}
                            </TableCell>
                            <TableCell>
                              {profiles.find((profile) => profile.id === device.calibration_profile_id)?.name || '—'}
                            </TableCell>
                            <TableCell>{device.last_heartbeat || device.last_seen || 'No heartbeat yet'}</TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </CardContent>
              </Card>
            </Grid>

            <Grid item xs={12} lg={7}>
              <Card sx={{ height: '100%' }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Episodes
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    Reviewable disturbances derived from device events for the selected site.
                  </Typography>
                  <TableContainer sx={{ mb: 3 }}>
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>Label</TableCell>
                          <TableCell>Severity</TableCell>
                          <TableCell>Score</TableCell>
                          <TableCell>Window</TableCell>
                          <TableCell>Actions</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {episodes.map((episode) => (
                          <TableRow
                            key={episode.id}
                            selected={episode.id === selectedEpisodeId}
                            hover
                          >
                            <TableCell>
                              <Typography variant="body2" fontWeight="medium">
                                {episode.effective_label}
                              </Typography>
                              <Typography variant="caption" color="textSecondary">
                                {episode.device_public_id} • {episode.review_state}
                              </Typography>
                            </TableCell>
                            <TableCell>{episode.effective_severity}</TableCell>
                            <TableCell>{episode.nuisance_score.toFixed(1)}</TableCell>
                            <TableCell>
                              <Typography variant="caption">
                                {new Date(episode.started_at).toLocaleString()}
                              </Typography>
                              <br />
                              <Typography variant="caption" color="textSecondary">
                                {episode.event_count} event{episode.event_count === 1 ? '' : 's'}
                              </Typography>
                            </TableCell>
                            <TableCell>
                              <Stack direction="row" spacing={1}>
                                <Button
                                  size="small"
                                  variant="outlined"
                                  onClick={() => handleOpenEpisodeReview(episode)}
                                >
                                  Review
                                </Button>
                                <Button
                                  size="small"
                                  variant="text"
                                  onClick={() => handleConfirmEpisode(episode.id)}
                                >
                                  Confirm
                                </Button>
                                <Button
                                  size="small"
                                  variant={selectedEpisodeIds.includes(episode.id) ? 'contained' : 'text'}
                                  onClick={() => toggleEpisodeSelection(episode.id)}
                                >
                                  {selectedEpisodeIds.includes(episode.id) ? 'Selected' : 'Add to case'}
                                </Button>
                              </Stack>
                            </TableCell>
                          </TableRow>
                        ))}
                        {episodes.length === 0 ? (
                          <TableRow>
                            <TableCell colSpan={5}>No episodes yet for this site.</TableCell>
                          </TableRow>
                        ) : null}
                      </TableBody>
                    </Table>
                  </TableContainer>

                  <Divider sx={{ mb: 2 }} />
                  <Typography variant="subtitle1" gutterBottom>
                    Review selected episode
                  </Typography>
                  <Stack spacing={2}>
                    <TextField
                      label="Review label"
                      value={episodeReviewForm.review_label}
                      onChange={(event) =>
                        setEpisodeReviewForm((prev) => ({
                          ...prev,
                          review_label: event.target.value,
                        }))
                      }
                      disabled={!selectedEpisode}
                    />
                    <FormControl fullWidth disabled={!selectedEpisode}>
                      <InputLabel>Severity</InputLabel>
                      <Select
                        label="Severity"
                        value={episodeReviewForm.severity}
                        onChange={(event) =>
                          setEpisodeReviewForm((prev) => ({
                            ...prev,
                            severity: event.target.value as
                              | 'informational'
                              | 'low'
                              | 'medium'
                              | 'high'
                              | 'critical',
                          }))
                        }
                      >
                        <MenuItem value="informational">Informational</MenuItem>
                        <MenuItem value="low">Low</MenuItem>
                        <MenuItem value="medium">Medium</MenuItem>
                        <MenuItem value="high">High</MenuItem>
                        <MenuItem value="critical">Critical</MenuItem>
                      </Select>
                    </FormControl>
                    <TextField
                      label="Review notes"
                      multiline
                      minRows={3}
                      value={episodeReviewForm.notes}
                      onChange={(event) =>
                        setEpisodeReviewForm((prev) => ({
                          ...prev,
                          notes: event.target.value,
                        }))
                      }
                      disabled={!selectedEpisode}
                    />
                    <Button variant="contained" onClick={handleReviewEpisode} disabled={!selectedEpisode}>
                      Save review override
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>

            <Grid item xs={12} lg={5}>
              <Card sx={{ mb: 3 }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Case Builder
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    Selected episodes: {selectedEpisodeIds.length}
                  </Typography>
                  <Stack spacing={2}>
                    <TextField
                      label="Case title"
                      value={caseForm.title}
                      onChange={(event) =>
                        setCaseForm((prev) => ({ ...prev, title: event.target.value }))
                      }
                    />
                    <TextField
                      label="Summary"
                      multiline
                      minRows={3}
                      value={caseForm.summary}
                      onChange={(event) =>
                        setCaseForm((prev) => ({ ...prev, summary: event.target.value }))
                      }
                    />
                    <Button
                      variant="contained"
                      onClick={handleCreateCase}
                      disabled={!caseForm.title || selectedEpisodeIds.length === 0}
                    >
                      Open case from selected episodes
                    </Button>
                  </Stack>
                </CardContent>
              </Card>

              <Card sx={{ mb: 3 }}>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Cases
                  </Typography>
                  <List dense>
                    {cases.map((item) => (
                      <ListItem key={item.id} disablePadding>
                        <ListItemButton
                          selected={item.id === selectedCaseId}
                          onClick={() => setSelectedCaseId(item.id)}
                        >
                          <ListItemText
                            primary={item.title}
                            secondary={`${item.episode_count} episodes • ${item.status}`}
                          />
                        </ListItemButton>
                      </ListItem>
                    ))}
                    {cases.length === 0 ? (
                      <ListItem>
                        <ListItemText primary="No cases yet." />
                      </ListItem>
                    ) : null}
                  </List>
                </CardContent>
              </Card>

              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Exports
                  </Typography>
                  <Stack direction="row" spacing={2} sx={{ mb: 2 }}>
                    <FormControl fullWidth>
                      <InputLabel>Format</InputLabel>
                      <Select
                        label="Format"
                        value={exportFormat}
                        onChange={(event) =>
                          setExportFormat(event.target.value as 'json' | 'csv' | 'pdf')
                        }
                      >
                        <MenuItem value="json">JSON</MenuItem>
                        <MenuItem value="csv">CSV</MenuItem>
                        <MenuItem value="pdf">PDF</MenuItem>
                      </Select>
                    </FormControl>
                    <Button
                      variant="contained"
                      onClick={handleCreateExport}
                      disabled={!selectedCaseId}
                    >
                      Generate
                    </Button>
                  </Stack>
                  <List dense>
                    {exports.map((exportJob) => (
                      <ListItem
                        key={exportJob.id}
                        secondaryAction={
                          <Button size="small" onClick={() => handleDownloadExport(exportJob)}>
                            Download
                          </Button>
                        }
                      >
                        <ListItemText
                          primary={`${exportJob.file_name} • ${exportJob.format.toUpperCase()}`}
                          secondary={exportJob.preview || exportJob.status}
                        />
                      </ListItem>
                    ))}
                    {exports.length === 0 ? (
                      <ListItem>
                        <ListItemText primary="No exports yet." />
                      </ListItem>
                    ) : null}
                  </List>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </>
      )}
    </Box>
  )
}
