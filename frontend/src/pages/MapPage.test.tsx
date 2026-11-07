import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import MapPage from './MapPage'

afterEach(() => { cleanup(); vi.restoreAllMocks() })

describe('Pilotkarte', () => {
  it('erklärt eine Datenlücke und lädt keine externen Kacheln', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValue({ ok: true, json: async () => ({ status: 'not_available', areas: [] }) } as Response)
    render(<MapPage />)
    expect(await screen.findByText(/Fehlende Daten bedeuten nicht/)).toBeInTheDocument()
    expect(document.querySelectorAll('iframe')).toHaveLength(0)
    expect(screen.getByRole('img')).toHaveAttribute('src', '/eimsbuettel.svg')
    expect(fetchSpy).toHaveBeenCalledTimes(1)
    expect(fetchSpy.mock.calls[0][0]).toContain('/map-pilot/public')
    expect(fetchSpy.mock.calls[0][1]).toMatchObject({ credentials: 'omit', cache: 'no-store' })
  })

  it('zeigt ausschließlich freigegebene synthetische Gebietswoche', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue({ ok: true, json: async () => ({ status: 'available', areas: [
      { area: 'hamburg-eimsbuettel', week_start: '2026-10-26', band: 'medium', device_id: 'private-device' },
      { area: 'other', week_start: '2026-10-26', band: 'high' },
    ] }) } as Response)
    render(<MapPage />)
    expect(await screen.findByText(/UTC-Woche ab 2026-10-26: Kategorie mittel/)).toBeInTheDocument()
    expect(screen.queryByText(/private-device/)).not.toBeInTheDocument()
    expect(screen.queryByText(/Kategorie hoch/)).not.toBeInTheDocument()
  })
})
