import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import MapPage from './MapPage'

describe('geschlossene Pilotkarte', () => {
  it('erklärt die Datenlücke und fordert keine Ereignisse oder Kartenkacheln an', () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch')
    render(<MapPage />)
    expect(screen.getByText(/Fehlende Daten bedeuten nicht/)).toBeInTheDocument()
    expect(screen.getByText(/Karte ist noch nicht in Betrieb/)).toBeInTheDocument()
    expect(document.querySelectorAll('img, iframe')).toHaveLength(0)
    expect(fetchSpy).not.toHaveBeenCalled()
    fetchSpy.mockRestore()
  })
})
