import { useEffect, useMemo, useState } from 'react'
import { Link as RouterLink, useNavigate } from 'react-router-dom'
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
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
import toast from 'react-hot-toast'

import { api, Episode, Organization, Site, Zone, Case as OperatorCase, hasStoredAuthToken } from '../services/api'

function formatError(error: any): string {
  return (
    error?.response?.data?.detail ||
    error?.response?.data?.message ||
    error?.message ||
    'Request failed'
  )
}

function formatTimestamp(value: string) {
  return new Date(value).toLocaleString()
}

export default function EpisodeInboxPage() {
  const navigate = useNavigate()
  const [authenticated] = useState(hasStoredAuthToken())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [organizations, setOrganizations] = useState<Organization[]>([])
  const [sites, setSites] = useState<Site[]>([])
  const [zones, setZones] = useState<Zone[]>([])
  const [episodes, setEpisodes] = useState<Episode[]>([])
  const [cases, setCases] = useState<OperatorCase[]>([])
  const [selectedOrganizationId, setSelectedOrganizationId] = useState('')
  const [selectedSiteId, setSelectedSiteId] = useState('')
  const [selectedZoneId, setSelectedZoneId] = useState('')
  const [selectedEpisodeId, setSelectedEpisodeId] = useState('')
  const [selectedEpisodeIds, setSelectedEpisodeIds] = useState<string[]>([])
  const [filters, setFilters] = useState({
    search: '',
    review_state: 'all',
    severity: 'all',
  })
  const [reviewForm, setReviewForm] = useState({
    review_label: '',
    severity: 'medium' as 'informational' | 'low' | 'medium' | 'high' | 'critical',
    notes: '',
  })
  const [caseForm, setCaseForm] = useState({
    title: '',
    summary: '',
  })

  const selectedEpisode = useMemo(
    () => episodes.find((episode) => episode.id === selectedEpisodeId) ?? null,
    [episodes, selectedEpisodeId]
  )

  const filteredEpisodes = useMemo(() => {
    return episodes.filter((episode) => {
      if (selectedZoneId && episode.zone_id !== selectedZoneId) {
        return false
      }
      if (filters.review_state !== 'all' && episode.review_state !== filters.review_state) {
        return false
      }
      if (filters.severity !== 'all' && episode.effective_severity !== filters.severity) {
        return false
      }
      if (!filters.search) {
        return true
      }
      const haystack = [
        episode.effective_label,
        episode.primary_class,
        episode.device_public_id,
        episode.review_notes || '',
      ]
        .join(' ')
        .toLowerCase()
      return haystack.includes(filters.search.toLowerCase())
    })
  }, [episodes, filters, selectedZoneId])

  const selectedCases = useMemo(
    () => cases.slice(0, 6),
    [cases]
  )

  useEffect(() => {
    if (!authenticated) {
      setLoading(false)
      return
    }

    let cancelled = false
    async function bootstrap() {
      setLoading(true)
      setError(null)
      try {
        const loadedOrganizations = await api.organizations.list()
        if (cancelled) return
        setOrganizations(loadedOrganizations)
        const nextOrganizationId = loadedOrganizations[0]?.id ?? ''
        setSelectedOrganizationId(nextOrganizationId)
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
  }, [authenticated])

  useEffect(() => {
    if (!authenticated || !selectedOrganizationId) {
      return
    }

    let cancelled = false
    async function loadOrganizationContext() {
      setLoading(true)
      setError(null)
      try {
        const [loadedSites, loadedCases] = await Promise.all([
          api.sites.list(selectedOrganizationId),
          api.cases.list({ organization_id: selectedOrganizationId }),
        ])
        if (cancelled) return
        setSites(loadedSites)
        setCases(loadedCases)
        const nextSiteId = loadedSites[0]?.id ?? ''
        setSelectedSiteId((current) =>
          current && loadedSites.some((site) => site.id === current) ? current : nextSiteId
        )
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

    void loadOrganizationContext()
    return () => {
      cancelled = true
    }
  }, [authenticated, selectedOrganizationId])

  useEffect(() => {
    if (!authenticated || !selectedOrganizationId || !selectedSiteId) {
      setZones([])
      setEpisodes([])
      return
    }

    let cancelled = false
    async function loadSiteContext() {
      setLoading(true)
      setError(null)
      try {
        const [loadedZones, loadedEpisodes] = await Promise.all([
          api.zones.list(selectedSiteId),
          api.episodes.list({
            organization_id: selectedOrganizationId,
            site_id: selectedSiteId,
            limit: 250,
          }),
        ])
        if (cancelled) return
        setZones(loadedZones)
        setEpisodes(loadedEpisodes.episodes)
        const nextEpisodeId = loadedEpisodes.episodes[0]?.id ?? ''
        setSelectedEpisodeId((current) =>
          current && loadedEpisodes.episodes.some((episode) => episode.id === current)
            ? current
            : nextEpisodeId
        )
        setSelectedEpisodeIds((current) =>
          current.filter((episodeId) => loadedEpisodes.episodes.some((episode) => episode.id === episodeId))
        )
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

    void loadSiteContext()
    return () => {
      cancelled = true
    }
  }, [authenticated, selectedOrganizationId, selectedSiteId])

  const openEpisode = (episode: Episode) => {
    setSelectedEpisodeId(episode.id)
    setReviewForm({
      review_label: episode.review_label || episode.effective_label,
      severity: episode.effective_severity,
      notes: episode.review_notes || '',
    })
  }

  const toggleEpisodeSelection = (episodeId: string) => {
    setSelectedEpisodeIds((current) =>
      current.includes(episodeId)
        ? current.filter((id) => id !== episodeId)
        : [...current, episodeId]
    )
  }

  const reloadEpisodes = async () => {
    if (!selectedOrganizationId || !selectedSiteId) return
    const loadedEpisodes = await api.episodes.list({
      organization_id: selectedOrganizationId,
      site_id: selectedSiteId,
      limit: 250,
    })
    setEpisodes(loadedEpisodes.episodes)
  }

  const reviewEpisode = async () => {
    if (!selectedEpisodeId) return
    try {
      await api.episodes.review(selectedEpisodeId, {
        review_state: 'overridden',
        review_label: reviewForm.review_label || undefined,
        severity: reviewForm.severity,
        notes: reviewForm.notes || undefined,
      })
      toast.success('Episode review saved')
      await reloadEpisodes()
    } catch (err) {
      setError(formatError(err))
    }
  }

  const confirmEpisode = async (episodeId: string) => {
    try {
      await api.episodes.review(episodeId, { review_state: 'confirmed' })
      toast.success('Episode confirmed')
      await reloadEpisodes()
    } catch (err) {
      setError(formatError(err))
    }
  }

  const createCase = async () => {
    if (!selectedOrganizationId || !selectedSiteId || selectedEpisodeIds.length === 0 || !caseForm.title) {
      return
    }

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
      navigate(`/operations/cases/${created.id}`)
    } catch (err) {
      setError(formatError(err))
    }
  }

  if (!authenticated) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Episode Inbox
        </Typography>
        <Alert severity="info" sx={{ mb: 2 }}>
          Pro inbox access requires an operator session.
        </Alert>
        <Button variant="contained" component={RouterLink} to="/operations">
          Open Pro setup and sign in
        </Button>
      </Box>
    )
  }

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Episode Inbox
          </Typography>
          <Typography variant="body1" color="textSecondary">
            Review disturbances, promote them into cases, and hand off evidence exports.
          </Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <Button variant="outlined" component={RouterLink} to="/operations">
            Pro setup
          </Button>
        </Stack>
      </Box>

      {error ? (
        <Alert severity="warning" sx={{ mb: 3 }}>
          {error}
        </Alert>
      ) : null}

      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} md={4}>
          <FormControl fullWidth>
            <InputLabel>Organization</InputLabel>
            <Select
              label="Organization"
              value={selectedOrganizationId}
              onChange={(event) => setSelectedOrganizationId(event.target.value)}
            >
              {organizations.map((organization) => (
                <MenuItem key={organization.id} value={organization.id}>
                  {organization.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </Grid>
        <Grid item xs={12} md={4}>
          <FormControl fullWidth>
            <InputLabel>Site</InputLabel>
            <Select
              label="Site"
              value={selectedSiteId}
              onChange={(event) => setSelectedSiteId(event.target.value)}
            >
              {sites.map((site) => (
                <MenuItem key={site.id} value={site.id}>
                  {site.name}
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
              value={selectedZoneId}
              onChange={(event) => setSelectedZoneId(event.target.value)}
            >
              <MenuItem value="">All zones</MenuItem>
              {zones.map((zone) => (
                <MenuItem key={zone.id} value={zone.id}>
                  {zone.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        <Grid item xs={12} lg={8}>
          <Card>
            <CardContent>
              <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ mb: 3 }}>
                <TextField
                  fullWidth
                  label="Search"
                  value={filters.search}
                  onChange={(event) =>
                    setFilters((prev) => ({ ...prev, search: event.target.value }))
                  }
                />
                <FormControl sx={{ minWidth: 180 }}>
                  <InputLabel>Review State</InputLabel>
                  <Select
                    label="Review State"
                    value={filters.review_state}
                    onChange={(event) =>
                      setFilters((prev) => ({ ...prev, review_state: event.target.value }))
                    }
                  >
                    <MenuItem value="all">All</MenuItem>
                    <MenuItem value="pending_review">Pending</MenuItem>
                    <MenuItem value="confirmed">Confirmed</MenuItem>
                    <MenuItem value="overridden">Overridden</MenuItem>
                    <MenuItem value="suppressed">Suppressed</MenuItem>
                  </Select>
                </FormControl>
                <FormControl sx={{ minWidth: 180 }}>
                  <InputLabel>Severity</InputLabel>
                  <Select
                    label="Severity"
                    value={filters.severity}
                    onChange={(event) =>
                      setFilters((prev) => ({ ...prev, severity: event.target.value }))
                    }
                  >
                    <MenuItem value="all">All</MenuItem>
                    <MenuItem value="informational">Informational</MenuItem>
                    <MenuItem value="low">Low</MenuItem>
                    <MenuItem value="medium">Medium</MenuItem>
                    <MenuItem value="high">High</MenuItem>
                    <MenuItem value="critical">Critical</MenuItem>
                  </Select>
                </FormControl>
              </Stack>

              {loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
                  <CircularProgress />
                </Box>
              ) : (
                <TableContainer>
                  <Table size="small">
                    <TableHead>
                      <TableRow>
                        <TableCell>Label</TableCell>
                        <TableCell>Severity</TableCell>
                        <TableCell>Score</TableCell>
                        <TableCell>Window</TableCell>
                        <TableCell>Review</TableCell>
                        <TableCell>Actions</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {filteredEpisodes.map((episode) => (
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
                              {episode.device_public_id}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Chip
                              size="small"
                              label={episode.effective_severity}
                              color={
                                episode.effective_severity === 'critical' || episode.effective_severity === 'high'
                                  ? 'error'
                                  : episode.effective_severity === 'medium'
                                    ? 'warning'
                                    : 'default'
                              }
                            />
                          </TableCell>
                          <TableCell>{episode.nuisance_score.toFixed(1)}</TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              {formatTimestamp(episode.started_at)}
                            </Typography>
                            <br />
                            <Typography variant="caption" color="textSecondary">
                              {episode.event_count} events
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2">{episode.review_state}</Typography>
                            {episode.reviewed_at ? (
                              <Typography variant="caption" color="textSecondary">
                                {formatTimestamp(episode.reviewed_at)}
                              </Typography>
                            ) : null}
                          </TableCell>
                          <TableCell>
                            <Stack direction="row" spacing={1}>
                              <Button size="small" onClick={() => openEpisode(episode)}>
                                Review
                              </Button>
                              <Button size="small" onClick={() => confirmEpisode(episode.id)}>
                                Confirm
                              </Button>
                              <Button
                                size="small"
                                variant={selectedEpisodeIds.includes(episode.id) ? 'contained' : 'outlined'}
                                onClick={() => toggleEpisodeSelection(episode.id)}
                              >
                                {selectedEpisodeIds.includes(episode.id) ? 'Selected' : 'Select'}
                              </Button>
                            </Stack>
                          </TableCell>
                        </TableRow>
                      ))}
                      {filteredEpisodes.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={6}>No episodes match the current filters.</TableCell>
                        </TableRow>
                      ) : null}
                    </TableBody>
                  </Table>
                </TableContainer>
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} lg={4}>
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Episode Review
              </Typography>
              {selectedEpisode ? (
                <Stack spacing={2}>
                  <Typography variant="body2" color="textSecondary">
                    {selectedEpisode.device_public_id} • {selectedEpisode.primary_class}
                  </Typography>
                  <TextField
                    label="Review label"
                    value={reviewForm.review_label}
                    onChange={(event) =>
                      setReviewForm((prev) => ({ ...prev, review_label: event.target.value }))
                    }
                  />
                  <FormControl fullWidth>
                    <InputLabel>Severity</InputLabel>
                    <Select
                      label="Severity"
                      value={reviewForm.severity}
                      onChange={(event) =>
                        setReviewForm((prev) => ({
                          ...prev,
                          severity: event.target.value as 'informational' | 'low' | 'medium' | 'high' | 'critical',
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
                    value={reviewForm.notes}
                    onChange={(event) =>
                      setReviewForm((prev) => ({ ...prev, notes: event.target.value }))
                    }
                  />
                  <Button variant="contained" onClick={reviewEpisode}>
                    Save review
                  </Button>
                </Stack>
              ) : (
                <Typography color="textSecondary">Select an episode from the inbox.</Typography>
              )}
            </CardContent>
          </Card>

          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Case Builder
              </Typography>
              <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                {selectedEpisodeIds.length} episode{selectedEpisodeIds.length === 1 ? '' : 's'} selected
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
                  onClick={createCase}
                  disabled={!caseForm.title || selectedEpisodeIds.length === 0}
                >
                  Open case
                </Button>
              </Stack>
            </CardContent>
          </Card>

          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Recent Cases
              </Typography>
              <List dense>
                {selectedCases.map((item) => (
                  <ListItem key={item.id} disablePadding>
                    <ListItemButton onClick={() => navigate(`/operations/cases/${item.id}`)}>
                      <ListItemText
                        primary={item.title}
                        secondary={`${item.episode_count} episodes • ${item.status}`}
                      />
                    </ListItemButton>
                  </ListItem>
                ))}
                {selectedCases.length === 0 ? (
                  <ListItem>
                    <ListItemText primary="No cases yet." />
                  </ListItem>
                ) : null}
              </List>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  )
}
