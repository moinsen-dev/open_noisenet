import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import HomePage from './HomePage'
import { api } from '../services/api'

vi.mock('../services/api', () => ({
  api: {
    health: vi.fn(),
    map: { stats: vi.fn() },
    events: { list: vi.fn() },
  },
}))

describe('dashboard', () => {
  beforeEach(() => vi.resetAllMocks())
  afterEach(cleanup)

  it('shows confirmed empty results and a measured zero level', async () => {
    vi.mocked(api.health).mockResolvedValue({ status: 'healthy' })
    vi.mocked(api.map.stats).mockResolvedValue({
      total_devices: 1, total_events: 0, active_devices_24h: 1,
      events_24h: 0, avg_leq_db: 0,
    })
    vi.mocked(api.events.list).mockResolvedValue({ events: [], total: 0, offset: 0, limit: 5 })

    render(<HomePage />)

    expect(await screen.findByText('0.0 dB')).toBeInTheDocument()
    expect(screen.getByText(/No events have been ingested yet/)).toBeInTheDocument()
    expect(screen.getByText(/API: Healthy/)).toBeInTheDocument()
  })

  it('does not confuse an unavailable backend with an empty event history', async () => {
    vi.mocked(api.health).mockRejectedValue(new Error('Network unavailable'))
    vi.mocked(api.map.stats).mockResolvedValue({ total_devices: 0, total_events: 0, active_devices_24h: 0, events_24h: 0 })
    vi.mocked(api.events.list).mockResolvedValue({ events: [], total: 0, offset: 0, limit: 5 })

    render(<HomePage />)

    expect(await screen.findByText('Network unavailable')).toBeInTheDocument()
    expect(screen.getByText(/Recent events are unavailable/)).toBeInTheDocument()
    expect(screen.queryByText(/No events have been ingested yet/)).not.toBeInTheDocument()
  })
})
