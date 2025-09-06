# Docker Configuration

This project uses a unified `docker-compose.yml` file that includes all services.

## Services

### Core Application
- **Frontend** (`frontend`): Port 3001 - React frontend application  
- **Backend** (`backend`): Port 8000 - FastAPI backend
- **Nginx** (`nginx`): Ports 80/443 - Reverse proxy and load balancer

### Data & Processing
- **PostgreSQL** (`postgres`): Port 5432 - TimescaleDB for time-series data
- **Redis** (`redis`): Port 6379 - Cache and message broker
- **Celery Worker** (`celery`): Background task processing
- **Celery Beat** (`celery-beat`): Scheduled task management

### Monitoring
- **Prometheus** (`prometheus`): Port 9090 - Metrics collection
- **Grafana** (`grafana`): Port 3002 - Metrics visualization

## Quick Start

1. Copy environment variables:
   ```bash
   cp .env.example .env
   ```

2. Start all services:
   ```bash
   docker-compose up -d
   ```

3. Access the services:
   - **Frontend App**: http://localhost:3001  
   - **API Backend**: http://localhost:8000
   - **Grafana**: http://localhost:3002

## Port Configuration

Ports can be customized via environment variables:
- `FRONTEND_PORT=3001` - React frontend
- `BACKEND_PORT=8000` - FastAPI backend
- `GRAFANA_PORT=3002` - Grafana dashboard

## Routing

Nginx routes traffic as follows:
- `/app/` → Frontend Application (React)
- `/api/` → Backend API (FastAPI)

## Development vs Production

- **Development**: Use default ports, file watching, debug mode
- **Production**: Set `NODE_ENV=production`, use environment-specific configs