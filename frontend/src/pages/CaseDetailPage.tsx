import { useEffect, useState } from 'react'
import { Link as RouterLink, useParams } from 'react-router-dom'
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
  Typography,
} from '@mui/material'
import toast from 'react-hot-toast'

import {
  api,
  Case as OperatorCase,
  CaseAuditEntry,
  CaseStatusUpdate,
  Episode,
  ExportJob,
  hasStoredAuthToken,
} from '../services/api'

type CaseHistoryEntry = {
  id: string
  at: string
  title: string
  subtitle: string
  tone: 'default' | 'info' | 'success' | 'warning'
}

type CaseTransition = {
  status: OperatorCase['status']
  label: string
  description: string
}

const CASE_STATUS_META: Record<
  OperatorCase['status'],
  { label: string; color: 'default' | 'info' | 'success'; description: string }
> = {
  open: {
    label: 'Open',
    color: 'default',
    description: 'Case is gathering evidence and needs operator review.',
  },
  in_review: {
    label: 'In Review',
    color: 'info',
    description: 'Case is actively being assessed by an operator.',
  },
  closed: {
    label: 'Closed',
    color: 'success',
    description: 'Case is finalized and ready for archival or export.',
  },
}

const CASE_TRANSITIONS: Record<OperatorCase['status'], CaseTransition[]> = {
  open: [
    {
      status: 'in_review',
      label: 'Move to review',
      description: 'Mark the case as actively triaged by an operator.',
    },
    {
      status: 'closed',
      label: 'Close case',
      description: 'Finalize the case after evidence has been exported.',
    },
  ],
  in_review: [
    {
      status: 'open',
      label: 'Reopen',
      description: 'Return the case to the intake state.',
    },
    {
      status: 'closed',
      label: 'Close case',
      description: 'Finalize the case after review is complete.',
    },
  ],
  closed: [
    {
      status: 'open',
      label: 'Reopen',
      description: 'Reopen the case for additional evidence or follow-up.',
    },
  ],
}

function formatError(error: any): string {
  return (
    error?.response?.data?.detail ||
    error?.response?.data?.message ||
    error?.message ||
    'Request failed'
  )
}

function formatTimestamp(value?: string) {
  return value ? new Date(value).toLocaleString() : '—'
}

function formatStatusLabel(status: string) {
  return status
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

function getStatusChipColor(status: OperatorCase['status']) {
  return CASE_STATUS_META[status].color
}

function getSeverityColor(severity: Episode['effective_severity']) {
  if (severity === 'critical' || severity === 'high') {
    return 'error'
  }
  if (severity === 'medium') {
    return 'warning'
  }
  return 'default'
}

function buildCaseHistory(caseRecord: OperatorCase, episodes: Episode[]) {
  const entries: CaseHistoryEntry[] = (caseRecord.audit_history || []).map(
    (entry: CaseAuditEntry, index) => {
      const eventType = entry.event_type
      const actor =
        entry.actor_email || entry.actor_id || 'unknown operator'
      let title = formatStatusLabel(eventType.replace(/_/g, ' '))
      let subtitle = entry.note || 'No additional note.'
      let tone: CaseHistoryEntry['tone'] = 'info'

      if (eventType === 'case_created') {
        title = 'Case opened'
        subtitle = `${caseRecord.title} entered the operator queue.`
        tone = 'info'
      } else if (eventType === 'status_changed') {
        title = `Status changed to ${formatStatusLabel(entry.to_status || 'updated')}`
        subtitle = [
          `Actor ${actor}`,
          `From ${formatStatusLabel(entry.from_status || 'unknown')}`,
          `To ${formatStatusLabel(entry.to_status || 'unknown')}`,
          entry.note || 'No note recorded.',
        ].join(' • ')
        tone = entry.to_status === 'closed' ? 'success' : 'info'
      } else if (eventType === 'export_generated') {
        title = 'Export generated'
        subtitle = [
          entry.note || 'Operator artifact generated.',
          actor,
          entry.metadata?.format ? `Format ${String(entry.metadata.format).toUpperCase()}` : '',
        ]
          .filter(Boolean)
          .join(' • ')
        tone = 'success'
      } else if (eventType === 'case_updated') {
        title = 'Case updated'
        subtitle = [
          actor,
          entry.changed_fields?.length
            ? `Fields ${entry.changed_fields.join(', ')}`
            : 'Fields updated.',
          entry.note || 'No note recorded.',
        ].join(' • ')
      } else if (eventType === 'note_added') {
        title = 'Operator note added'
        subtitle = [actor, entry.note || 'No note recorded.'].join(' • ')
      }

      return {
        id: `case-audit-${caseRecord.id}-${index}`,
        at: entry.at,
        title,
        subtitle,
        tone,
      }
    }
  )

  episodes.forEach((episode) => {
    if (!episode.reviewed_at) {
      return
    }
    entries.push({
      id: `episode-reviewed-${episode.id}`,
      at: episode.reviewed_at,
      title: `Episode reviewed: ${episode.effective_label}`,
      subtitle: [
        `State ${episode.review_state}`,
        episode.review_notes || 'No review notes recorded.',
        episode.reviewed_by_id ? `Reviewer ${episode.reviewed_by_id}` : 'No reviewer recorded.',
      ].join(' • '),
      tone: episode.review_state === 'suppressed' ? 'warning' : 'success',
    })
  })

  return entries.sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
}

export default function CaseDetailPage() {
  const { caseId } = useParams<{ caseId: string }>()
  const [authenticated] = useState(hasStoredAuthToken())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [caseRecord, setCaseRecord] = useState<OperatorCase | null>(null)
  const [episodes, setEpisodes] = useState<Episode[]>([])
  const [exports, setExports] = useState<ExportJob[]>([])
  const [exportFormat, setExportFormat] = useState<'json' | 'csv' | 'pdf'>('pdf')
  const [lifecycleUpdateInFlight, setLifecycleUpdateInFlight] = useState<string | null>(null)

  const loadCaseDetail = async (targetCaseId: string, applyState = true) => {
    const caseResponse = await api.cases.get(targetCaseId)
    const [episodeResponse, exportResponse] = await Promise.all([
      api.cases.listEpisodes(targetCaseId),
      api.exports.list({
        organization_id: caseResponse.organization_id,
        case_id: targetCaseId,
      }),
    ])
    if (applyState) {
      setCaseRecord(caseResponse)
      setEpisodes(episodeResponse)
      setExports(exportResponse)
    }
    return { caseResponse, episodeResponse, exportResponse }
  }

  useEffect(() => {
    if (!authenticated || !caseId) {
      setLoading(false)
      return
    }

    let cancelled = false

    async function fetchCaseDetail() {
      if (!caseId) {
        return
      }
      setLoading(true)
      setError(null)
      try {
        const { caseResponse, episodeResponse, exportResponse } = await loadCaseDetail(caseId, false)
        if (cancelled) return
        setCaseRecord(caseResponse)
        setEpisodes(episodeResponse)
        setExports(exportResponse)
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

    void fetchCaseDetail()
    return () => {
      cancelled = true
    }
  }, [authenticated, caseId])

  const generateExport = async () => {
    if (!caseId) return
    try {
      const created = await api.exports.create({
        case_id: caseId,
        format: exportFormat,
      })
      toast.success(`${created.format.toUpperCase()} export generated`)
      await loadCaseDetail(caseId)
    } catch (err) {
      setError(formatError(err))
    }
  }

  const downloadExport = async (exportJob: ExportJob) => {
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

  const updateCaseLifecycle = async (payload: CaseStatusUpdate) => {
    if (!caseId) return
    try {
      setLifecycleUpdateInFlight(payload.status || 'update')
      const updated = await api.cases.update(caseId, payload)
      toast.success(`Case moved to ${formatStatusLabel(updated.status)}`)
      await loadCaseDetail(caseId)
    } catch (err) {
      setError(formatError(err))
    } finally {
      setLifecycleUpdateInFlight(null)
    }
  }

  if (!authenticated) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Case Detail
        </Typography>
        <Alert severity="info" sx={{ mb: 2 }}>
          An operator session is required to review cases.
        </Alert>
        <Button variant="contained" component={RouterLink} to="/operations">
          Open Pro setup and sign in
        </Button>
      </Box>
    )
  }

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
        <CircularProgress />
      </Box>
    )
  }

  if (error || !caseRecord) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Case Detail
        </Typography>
        <Alert severity="warning">{error || 'Case not found'}</Alert>
      </Box>
    )
  }

  const statusMeta = CASE_STATUS_META[caseRecord.status]
  const reviewedEpisodeCount = episodes.filter(
    (episode) => episode.review_state !== 'pending_review' || Boolean(episode.reviewed_at)
  ).length
  const pendingReviewCount = episodes.length - reviewedEpisodeCount
  const orderedExports = [...exports].sort(
    (left, right) =>
      new Date(right.exported_at || right.created_at).getTime() -
      new Date(left.exported_at || left.created_at).getTime()
  )
  const readyExportCount = exports.filter((exportJob) => exportJob.status === 'ready').length
  const failedExportCount = exports.filter((exportJob) => exportJob.status === 'failed').length
  const caseHistory = buildCaseHistory(caseRecord, episodes)

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
            <Typography variant="h4">{caseRecord.title}</Typography>
            <Chip
              size="small"
              label={statusMeta.label}
              color={getStatusChipColor(caseRecord.status)}
            />
          </Stack>
          <Typography variant="body1" color="textSecondary">
            {statusMeta.description} Opened {formatTimestamp(caseRecord.opened_at)} with{' '}
            {caseRecord.episode_count} episode{caseRecord.episode_count === 1 ? '' : 's'}.
          </Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <Button variant="outlined" component={RouterLink} to="/operations/inbox">
            Back to inbox
          </Button>
        </Stack>
      </Box>

      {error ? (
        <Alert severity="warning" sx={{ mb: 3 }}>
          {error}
        </Alert>
      ) : null}

      <Grid container spacing={3}>
        <Grid item xs={12} md={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Operator Summary
              </Typography>
              <Stack spacing={1.5}>
                <Typography variant="body2">
                  <strong>Status:</strong> {formatStatusLabel(caseRecord.status)}
                </Typography>
                <Typography variant="body2">
                  <strong>Opened:</strong> {formatTimestamp(caseRecord.opened_at)}
                </Typography>
                <Typography variant="body2">
                  <strong>Closed:</strong> {formatTimestamp(caseRecord.closed_at)}
                </Typography>
                <Typography variant="body2">
                  <strong>Episodes:</strong> {caseRecord.episode_count}
                </Typography>
                <Typography variant="body2">
                  <strong>Reviewed:</strong> {reviewedEpisodeCount}
                </Typography>
                <Typography variant="body2">
                  <strong>Pending review:</strong> {pendingReviewCount}
                </Typography>
                <Typography variant="body2">
                  <strong>Summary:</strong> {caseRecord.summary || 'No summary provided.'}
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Lifecycle
              </Typography>
              <Stack spacing={1.5}>
                <Typography variant="body2">
                  <strong>Current stage:</strong> {statusMeta.label}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  {caseHistory.length > 0
                    ? 'The timeline below reconstructs the case lifecycle from reviews and export activity.'
                    : 'Lifecycle history is still being accumulated.'}
                </Typography>
                <Divider />
                <Typography variant="subtitle2">Available transitions</Typography>
                {CASE_TRANSITIONS[caseRecord.status].map((transition) => (
                  <Box key={transition.status}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <Button
                        size="small"
                        variant="outlined"
                        disabled={lifecycleUpdateInFlight !== null}
                        sx={{ minWidth: 140 }}
                        onClick={() =>
                          updateCaseLifecycle({
                            status: transition.status,
                            note: transition.description,
                          })
                        }
                      >
                        {transition.label}
                      </Button>
                      <Typography variant="body2" color="textSecondary">
                        {transition.description}
                      </Typography>
                    </Stack>
                  </Box>
                ))}
                <Alert severity="info">
                  Status transitions are now persisted to the operator case history and reflected in
                  downstream exports.
                </Alert>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Export Inventory
              </Typography>
              <Stack spacing={1.5}>
                <Typography variant="body2">
                  <strong>Ready artifacts:</strong> {readyExportCount}
                </Typography>
                <Typography variant="body2">
                  <strong>Failed artifacts:</strong> {failedExportCount}
                </Typography>
                <Typography variant="body2">
                  <strong>Last artifact:</strong>{' '}
                  {orderedExports[0]
                    ? `${orderedExports[0].format.toUpperCase()} · ${formatTimestamp(orderedExports[0].exported_at || orderedExports[0].created_at)}`
                    : 'No exports yet.'}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Export artifacts are generated from the reviewed episode set and stay attached to
                  the case for operator retrieval.
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={8}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Export Center
              </Typography>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} sx={{ mb: 3 }}>
                <FormControl sx={{ minWidth: 180 }}>
                  <InputLabel>Format</InputLabel>
                  <Select
                    label="Format"
                    value={exportFormat}
                    onChange={(event) =>
                      setExportFormat(event.target.value as 'json' | 'csv' | 'pdf')
                    }
                  >
                    <MenuItem value="pdf">PDF</MenuItem>
                    <MenuItem value="json">JSON</MenuItem>
                    <MenuItem value="csv">CSV</MenuItem>
                  </Select>
                </FormControl>
                <Button variant="contained" onClick={generateExport}>
                  Generate export artifact
                </Button>
              </Stack>

              <List dense>
                {orderedExports.map((exportJob) => (
                  <ListItem
                    key={exportJob.id}
                    secondaryAction={
                      <Button size="small" onClick={() => downloadExport(exportJob)}>
                        Download
                      </Button>
                    }
                  >
                    <ListItemText
                      primary={`${exportJob.file_name} • ${exportJob.format.toUpperCase()}`}
                      secondary={exportJob.preview || formatTimestamp(exportJob.exported_at)}
                    />
                  </ListItem>
                ))}
                {orderedExports.length === 0 ? (
                  <ListItem>
                    <ListItemText primary="No exports generated yet." />
                  </ListItem>
                ) : null}
              </List>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Export Artifact Summaries
              </Typography>
              <Stack spacing={2}>
                {orderedExports.length === 0 ? (
                  <Alert severity="info">No export artifacts are attached to this case yet.</Alert>
                ) : (
                  orderedExports.map((exportJob) => (
                    <Card key={exportJob.id} variant="outlined">
                      <CardContent>
                        <Stack spacing={1}>
                          <Stack direction="row" spacing={1} alignItems="center">
                            <Chip
                              size="small"
                              label={exportJob.status}
                              color={exportJob.status === 'ready' ? 'success' : 'error'}
                            />
                            <Chip size="small" label={exportJob.format.toUpperCase()} />
                          </Stack>
                          <Typography variant="subtitle2">{exportJob.file_name}</Typography>
                          <Typography variant="body2" color="textSecondary">
                            {exportJob.preview || 'No preview text available.'}
                          </Typography>
                          <Typography variant="caption" color="textSecondary">
                            Exported {formatTimestamp(exportJob.exported_at || exportJob.created_at)}
                          </Typography>
                          <Typography variant="caption" color="textSecondary">
                            {exportJob.content_type} • {exportJob.output_encoding}
                          </Typography>
                        </Stack>
                      </CardContent>
                    </Card>
                  ))
                )}
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Episode Timeline
              </Typography>
              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Label</TableCell>
                      <TableCell>Severity</TableCell>
                      <TableCell>Review State</TableCell>
                      <TableCell>Window</TableCell>
                      <TableCell>Evidence</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {episodes.map((episode) => (
                      <TableRow key={episode.id}>
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
                            color={getSeverityColor(episode.effective_severity)}
                          />
                        </TableCell>
                        <TableCell>
                          <Stack spacing={0.5}>
                            <Typography variant="body2">{formatStatusLabel(episode.review_state)}</Typography>
                            <Typography variant="caption" color="textSecondary">
                              {episode.review_notes || 'No review notes'}
                            </Typography>
                          </Stack>
                        </TableCell>
                        <TableCell>
                          <Typography variant="caption">
                            {formatTimestamp(episode.started_at)}
                          </Typography>
                          <br />
                          <Typography variant="caption" color="textSecondary">
                            {episode.event_count} events
                          </Typography>
                        </TableCell>
                        <TableCell>{episode.evidence_mode}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Case History
              </Typography>
              <List dense>
                {caseHistory.map((entry) => (
                  <ListItem key={entry.id} alignItems="flex-start">
                    <ListItemText
                      primary={
                        <Stack direction="row" spacing={1} alignItems="center">
                          <Chip size="small" label={entry.tone} color={entry.tone} />
                          <Typography variant="body2" fontWeight="medium">
                            {entry.title}
                          </Typography>
                        </Stack>
                      }
                      secondary={
                        <Stack spacing={0.5}>
                          <Typography variant="body2">{entry.subtitle}</Typography>
                          <Typography variant="caption" color="textSecondary">
                            {formatTimestamp(entry.at)}
                          </Typography>
                        </Stack>
                      }
                    />
                  </ListItem>
                ))}
                {caseHistory.length === 0 ? (
                  <ListItem>
                    <ListItemText primary="No history entries yet." />
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
