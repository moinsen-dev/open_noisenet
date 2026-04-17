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

import { api, Case as OperatorCase, Episode, ExportJob, hasStoredAuthToken } from '../services/api'

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

export default function CaseDetailPage() {
  const { caseId } = useParams<{ caseId: string }>()
  const [authenticated] = useState(hasStoredAuthToken())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [caseRecord, setCaseRecord] = useState<OperatorCase | null>(null)
  const [episodes, setEpisodes] = useState<Episode[]>([])
  const [exports, setExports] = useState<ExportJob[]>([])
  const [exportFormat, setExportFormat] = useState<'json' | 'csv' | 'pdf'>('pdf')

  useEffect(() => {
    if (!authenticated || !caseId) {
      setLoading(false)
      return
    }

    let cancelled = false
    async function loadCaseDetail() {
      if (!caseId) {
        return
      }
      setLoading(true)
      setError(null)
      try {
        const caseResponse = await api.cases.get(caseId)
        const [episodeResponse, exportResponse] = await Promise.all([
          api.cases.listEpisodes(caseId),
          api.exports.list({
            organization_id: caseResponse.organization_id,
            case_id: caseId,
          }),
        ])
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

    void loadCaseDetail()
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
      if (caseRecord) {
        const exportResponse = await api.exports.list({
          organization_id: caseRecord.organization_id,
          case_id: caseId,
        })
        setExports(exportResponse)
      }
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

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            {caseRecord.title}
          </Typography>
          <Typography variant="body1" color="textSecondary">
            Case opened {formatTimestamp(caseRecord.opened_at)} with {caseRecord.episode_count} episode{caseRecord.episode_count === 1 ? '' : 's'}.
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
                Case Summary
              </Typography>
              <Stack spacing={1.5}>
                <Typography variant="body2">
                  <strong>Status:</strong> {caseRecord.status}
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
                  <strong>Summary:</strong> {caseRecord.summary || 'No summary provided.'}
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
                  Generate Export
                </Button>
              </Stack>

              <List dense>
                {exports.map((exportJob) => (
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
                {exports.length === 0 ? (
                  <ListItem>
                    <ListItemText primary="No exports generated yet." />
                  </ListItem>
                ) : null}
              </List>
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
                            color={
                              episode.effective_severity === 'critical' || episode.effective_severity === 'high'
                                ? 'error'
                                : episode.effective_severity === 'medium'
                                  ? 'warning'
                                  : 'default'
                            }
                          />
                        </TableCell>
                        <TableCell>{episode.review_state}</TableCell>
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
                Review History
              </Typography>
              <List dense>
                {episodes.map((episode) => (
                  <ListItem key={episode.id}>
                    <ListItemText
                      primary={`${episode.effective_label} • ${episode.review_state}`}
                      secondary={[
                        episode.review_notes || 'No review notes',
                        episode.reviewed_at ? `Reviewed ${formatTimestamp(episode.reviewed_at)}` : 'Not reviewed yet',
                        episode.reviewed_by_id ? `Reviewer ${episode.reviewed_by_id}` : 'No reviewer recorded',
                      ].join(' • ')}
                    />
                  </ListItem>
                ))}
              </List>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  )
}
