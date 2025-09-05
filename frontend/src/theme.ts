import { createTheme } from '@mui/material/styles'

export const theme = createTheme({
  palette: {
    primary: {
      main: '#2E7D32', // Green for environmental theme
      light: '#60AD5E',
      dark: '#005005',
      contrastText: '#ffffff',
    },
    secondary: {
      main: '#558B2F',
      light: '#8BC34A',
      dark: '#33691E',
      contrastText: '#ffffff',
    },
    error: {
      main: '#D32F2F',
      light: '#EF5350',
      dark: '#C62828',
    },
    warning: {
      main: '#F57C00',
      light: '#FF9800',
      dark: '#E65100',
    },
    info: {
      main: '#1976D2',
      light: '#2196F3',
      dark: '#0D47A1',
    },
    success: {
      main: '#388E3C',
      light: '#4CAF50',
      dark: '#1B5E20',
    },
    background: {
      default: '#fafafa',
      paper: '#ffffff',
    },
  },
  typography: {
    fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
    h1: {
      fontSize: '2.5rem',
      fontWeight: 600,
    },
    h2: {
      fontSize: '2rem',
      fontWeight: 600,
    },
    h3: {
      fontSize: '1.75rem',
      fontWeight: 600,
    },
    h4: {
      fontSize: '1.5rem',
      fontWeight: 600,
    },
    h5: {
      fontSize: '1.25rem',
      fontWeight: 600,
    },
    h6: {
      fontSize: '1rem',
      fontWeight: 600,
    },
  },
  shape: {
    borderRadius: 8,
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 500,
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
          borderRadius: 12,
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)',
        },
      },
    },
  },
})

// Custom noise level colors
export const noiseColors = {
  quiet: '#4CAF50',      // Green
  moderate: '#FF9800',   // Orange  
  loud: '#FF5722',       // Red
  veryLoud: '#9C27B0',   // Purple
}

export const getNoiseColor = (dbLevel: number): string => {
  if (dbLevel < 45) return noiseColors.quiet
  if (dbLevel < 55) return noiseColors.moderate
  if (dbLevel < 65) return noiseColors.loud
  return noiseColors.veryLoud
}

export const getNoiseLevelLabel = (dbLevel: number): string => {
  if (dbLevel < 45) return 'Quiet'
  if (dbLevel < 55) return 'Moderate'
  if (dbLevel < 65) return 'Loud'
  return 'Very Loud'
}