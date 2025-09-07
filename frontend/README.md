# OpenNoiseNet Frontend

A React TypeScript frontend for the OpenNoiseNet environmental noise monitoring platform.

## 🚀 Quick Start

### Development (localhost)
```bash
npm install
npm run dev
```

Frontend will be available at: http://localhost:3000

### With Backend on Same Machine
The development environment is configured to connect to:
- **Backend**: `http://localhost:8100/api/v1`
- **Health check**: http://localhost:8100/health

### For Mobile Testing (network access)
Update `.env.development` to use your network IP:
```env
VITE_API_URL=http://192.168.178.157:8100/api/v1
```

Then run:
```bash
npm run build
npm run preview
```

## 📱 Pages

### Events Page (/events)
- **Real-time events table** from all connected devices
- **Device filtering** and search
- **Statistics cards** showing event counts, noise levels, etc.
- **Connection status** with backend health checks
- **Responsive design** for mobile and desktop

## 🛠 Features

✅ **Backend Integration**
- Health check with connection status
- Events API with filtering
- Devices API integration
- Error handling with retry

✅ **UI Components**
- Material-UI design system
- Responsive navigation
- Real-time data refresh
- Loading states and error handling

✅ **Development**
- TypeScript with strict checking
- Vite dev server with proxy
- PWA support
- Code splitting

## 🔧 Scripts

```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run preview      # Preview production build
npm run type-check   # TypeScript checking
npm run lint         # ESLint checking
npm run test         # Run tests
```

## 🌐 Backend Connection

The frontend automatically connects to your backend API:

1. **Development**: Uses proxy to `localhost:8100`
2. **Production**: Uses `VITE_API_URL` environment variable
3. **Network testing**: Configure IP in `.env.development`

### Testing Backend Connection

1. Start backend: `docker compose up`
2. Check health: http://localhost:8100/health
3. Start frontend: `npm run dev`
4. Visit: http://localhost:3000/events

The Events page will show:
- ✅ Connection successful → Events table with data
- ❌ Connection failed → Error message with retry button

## 📊 API Integration

The frontend connects to these backend endpoints:

- `GET /health` - Backend health check
- `GET /api/v1/events/` - List noise events
- `GET /api/v1/devices/` - List devices
- `GET /api/v1/events/{id}` - Get specific event

## 🎯 Next Steps

1. **Test with real mobile devices** sending events
2. **Add real-time updates** with WebSocket/SSE
3. **Implement map visualization** of events
4. **Add event details modal** with charts