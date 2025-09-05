# OpenNoiseNet Implementation Plan

## Overview

This document outlines the comprehensive implementation plan for OpenNoiseNet, an open-source environmental noise monitoring platform. The project follows a waterfall approach with a solid foundation first, utilizing FastAPI Full-Stack Template, Docker infrastructure, PostgreSQL with TimescaleDB, and Flutter for mobile development with old smartphones as noise detectors.

## Project Architecture

### Core Components
- **Backend**: FastAPI with UV package manager, PostgreSQL + TimescaleDB
- **Frontend**: React web application for admin and public map
- **Mobile**: Flutter cross-platform app with on-device AI processing
- **Infrastructure**: Docker Compose, Redis, Celery, Nginx
- **AI Processing**: MiniCPM-o 2.6 via cactus framework (llama.cpp/GGUF)

### Project Structure
```
/open_noisenet
├── backend/                    # FastAPI backend services
│   ├── app/
│   │   ├── api/               # API endpoints
│   │   ├── core/              # Core configuration
│   │   ├── db/                # Database models and migrations
│   │   ├── services/          # Business logic services
│   │   └── workers/           # Celery background tasks
│   ├── tests/                 # Backend tests
│   ├── Dockerfile
│   ├── pyproject.toml         # UV configuration
│   └── requirements.txt
├── frontend/                   # React web frontend
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── services/
│   │   └── utils/
│   ├── package.json
│   └── Dockerfile
├── mobile/                     # Flutter mobile application
│   ├── android/               # Android-specific code
│   ├── ios/                   # iOS-specific code
│   ├── lib/
│   │   ├── core/              # Core app architecture
│   │   ├── features/          # Feature modules
│   │   ├── services/          # API and background services
│   │   └── widgets/           # Reusable widgets
│   ├── pubspec.yaml
│   └── README.md
├── infrastructure/             # Docker and deployment configs
│   ├── docker-compose.yml
│   ├── nginx/
│   ├── postgres/
│   └── monitoring/
├── docs/                      # Documentation
│   ├── api/                   # API documentation
│   ├── mobile/                # Mobile app guides
│   └── deployment/            # Deployment guides
├── scripts/                   # Setup and utility scripts
│   ├── setup.sh
│   ├── deploy.sh
│   └── migrate.sh
├── .env.example              # Environment variables template
├── .gitignore
├── docker-compose.yml        # Main infrastructure setup
└── README.md
```

## EPIC 1: Foundation & Infrastructure Setup (Weeks 1-3)

### 1.1 Project Initialization & Structure
**Duration**: 2-3 days

**Deliverables**:
- [x] Monorepo directory structure
- [ ] Git repository setup with proper .gitignore
- [ ] UV package manager configuration for Python
- [ ] Pre-commit hooks and linting setup
- [ ] Initial README.md and documentation structure

**Tasks**:
1. Create base directory structure
2. Initialize git with appropriate .gitignore for Python, Flutter, React
3. Setup UV for Python package management
4. Configure pre-commit hooks (black, ruff, mypy)
5. Create initial documentation templates

### 1.2 Docker Infrastructure Setup
**Duration**: 3-4 days

**Deliverables**:
- [ ] Docker Compose configuration for all services
- [ ] PostgreSQL + TimescaleDB container setup
- [ ] Redis container for caching and queues
- [ ] Nginx reverse proxy configuration
- [ ] Development environment setup scripts

**Services Configuration**:
```yaml
services:
  postgres:
    image: timescale/timescaledb:latest-pg15
    environment:
      POSTGRES_DB: noisenet
      POSTGRES_USER: noisenet
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infrastructure/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://noisenet:${DB_PASSWORD}@postgres:5432/noisenet
      REDIS_URL: redis://redis:6379
    depends_on:
      - postgres
      - redis

  celery:
    build: ./backend
    command: celery -A app.workers.celery worker --loglevel=info
    depends_on:
      - postgres
      - redis

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./infrastructure/nginx/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - backend
```

### 1.3 Database Design & Models
**Duration**: 4-5 days

**Core Database Schema**:

```sql
-- Extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS postgis;

-- Tables
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    device_type VARCHAR(50) NOT NULL, -- 'smartphone', 'esp32', 'raspberry_pi'
    location GEOGRAPHY(Point, 4326),
    firmware_version VARCHAR(50),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    timestamp_start TIMESTAMP WITH TIME ZONE NOT NULL,
    timestamp_end TIMESTAMP WITH TIME ZONE NOT NULL,
    leq_db REAL NOT NULL,
    lmax_db REAL,
    lmin_db REAL,
    exceedance_pct REAL,
    rule_triggered VARCHAR(100),
    location GEOGRAPHY(Point, 4326),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE audio_snippets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    codec VARCHAR(20) NOT NULL,
    duration_seconds INTEGER NOT NULL,
    file_size_bytes INTEGER,
    file_path VARCHAR(500),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE event_labels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    label VARCHAR(100) NOT NULL,
    confidence REAL NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    model_version VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    is_superuser BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Hypertables for time-series data
SELECT create_hypertable('events', 'timestamp_start');
SELECT create_hypertable('audio_snippets', 'uploaded_at');

-- Indexes
CREATE INDEX idx_events_device_id ON events(device_id);
CREATE INDEX idx_events_timestamp ON events(timestamp_start DESC);
CREATE INDEX idx_events_location ON events USING GIST(location);
CREATE INDEX idx_devices_location ON devices USING GIST(location);
CREATE INDEX idx_devices_device_id ON devices(device_id);
CREATE INDEX idx_event_labels_event_id ON event_labels(event_id);
```

**Deliverables**:
- [ ] SQLAlchemy models with proper relationships
- [ ] Alembic migration setup
- [ ] Data validation with Pydantic schemas
- [ ] Database initialization scripts

## EPIC 2: Backend Core Services (Weeks 4-6)

### 2.1 FastAPI Foundation
**Duration**: 5-6 days

**Core API Structure**:
```python
# API Endpoints Structure
/api/v1/
├── auth/              # Authentication endpoints
│   ├── POST /login
│   ├── POST /register  
│   └── POST /refresh
├── devices/           # Device management
│   ├── POST /register
│   ├── GET /{device_id}
│   ├── PUT /{device_id}
│   ├── POST /{device_id}/heartbeat
│   └── GET /
├── events/            # Event ingestion and retrieval
│   ├── POST /
│   ├── GET /
│   ├── GET /{event_id}
│   └── DELETE /{event_id}
├── snippets/          # Audio snippet management
│   ├── POST /upload
│   ├── GET /{snippet_id}
│   └── DELETE /{snippet_id}
├── map/               # Map data endpoints
│   ├── GET /events    # GeoJSON format
│   ├── GET /heatmap   # Aggregated data
│   └── GET /stats     # Statistics
└── admin/             # Admin endpoints
    ├── GET /stats
    ├── GET /devices
    └── GET /system-health
```

**Deliverables**:
- [ ] JWT authentication system
- [ ] API rate limiting
- [ ] Request/response validation
- [ ] Error handling and logging
- [ ] OpenAPI documentation
- [ ] Health check endpoints

### 2.2 Event Processing Services
**Duration**: 6-7 days

**Core Services**:
1. **SPL Calculation Service**
   - A-weighting filter implementation
   - Leq calculation over time windows
   - Statistical aggregation functions

2. **Threshold Detection Service**
   - Rule engine for noise exceedance detection
   - Configurable thresholds per device
   - Pattern recognition for recurring events

3. **Geospatial Service**
   - Location-based event queries
   - Heatmap data generation
   - Spatial clustering algorithms

**Deliverables**:
- [ ] Audio processing utilities
- [ ] Event aggregation services
- [ ] Geospatial query optimization
- [ ] Caching layer implementation

### 2.3 Background Task Processing
**Duration**: 3-4 days

**Celery Tasks**:
- Data aggregation and cleanup
- Audio snippet processing
- Alert notifications
- Report generation
- System maintenance tasks

**Deliverables**:
- [ ] Celery worker configuration
- [ ] Task scheduling setup
- [ ] Error handling and retries
- [ ] Monitoring and logging

## EPIC 3: Web Frontend (Weeks 7-8)

### 3.1 Admin Dashboard
**Duration**: 5-6 days

**Features**:
- Device management interface
- Real-time system monitoring
- User management
- Event data visualization
- System configuration

**Technology Stack**:
- React 18+ with TypeScript
- Material-UI or Tailwind CSS
- React Query for API state management
- Chart.js or Recharts for visualizations

**Deliverables**:
- [ ] Authentication flow
- [ ] Device management interface
- [ ] Monitoring dashboard
- [ ] Data export functionality

### 3.2 Public Map Interface
**Duration**: 3-4 days

**Features**:
- Interactive noise map with Leaflet/Mapbox
- Real-time data visualization
- Event filtering and search
- Historical data playback

**Deliverables**:
- [ ] Map component with clustering
- [ ] Event popup displays
- [ ] Time-based filtering
- [ ] Responsive design

## EPIC 4: Mobile Application - Flutter (Weeks 9-12)

### 4.1 Flutter App Architecture
**Duration**: 4-5 days

**Architecture Pattern**: Clean Architecture with BLoC state management

**Core Structure**:
```dart
lib/
├── core/                    # Core utilities and base classes
│   ├── constants/
│   ├── errors/
│   ├── network/
│   └── utils/
├── features/                # Feature modules
│   ├── auth/
│   ├── device_setup/
│   ├── noise_monitoring/
│   ├── settings/
│   └── data_sync/
├── shared/                  # Shared components
│   ├── widgets/
│   ├── models/
│   └── services/
└── main.dart
```

**Deliverables**:
- [ ] Project setup with proper architecture
- [ ] BLoC state management setup
- [ ] Navigation configuration
- [ ] Dependency injection setup

### 4.2 Audio Processing & AI Integration
**Duration**: 7-8 days

**Core Components**:

1. **Audio Capture Service**
   ```dart
   class AudioCaptureService {
     Stream<AudioSample> startCapture();
     Future<void> stopCapture();
     Future<double> calculateSPL(AudioSample sample);
     Future<double> calculateLeq(List<AudioSample> samples);
   }
   ```

2. **On-Device AI Processing**
   ```dart
   class AIProcessingService {
     Future<void> initializeModel(); // Load MiniCPM-o 2.6 GGUF
     Future<List<EventLabel>> classifyAudio(AudioSample sample);
     Future<String> generateSummary(List<AudioSample> samples);
   }
   ```

3. **Event Detection**
   ```dart
   class EventDetectionService {
     Stream<NoiseEvent> detectEvents(Stream<double> splStream);
     bool checkThresholdExceedance(double spl, DateTime time);
   }
   ```

**Deliverables**:
- [ ] Cactus framework integration
- [ ] MiniCPM-o 2.6 model loading
- [ ] Audio processing pipeline
- [ ] Event detection algorithms
- [ ] Local data storage (SQLite)

### 4.3 Platform-Specific Implementation

#### 4.3.1 Android Implementation (5-6 days)
**Foreground Service Configuration**:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />

<service
    android:name=".NoiseMonitoringService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="microphone" />
```

**Service Implementation**:
```kotlin
class NoiseMonitoringService : FlutterBackgroundService() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        startAudioCapture()
        return START_STICKY
    }
    
    private fun startAudioCapture() {
        // Initialize audio capture with proper parameters
        // Integrate with Flutter engine for processing
    }
}
```

**Deliverables**:
- [ ] Foreground Service implementation
- [ ] Persistent notification setup
- [ ] Battery optimization handling
- [ ] Permission management

#### 4.3.2 iOS Implementation (3-4 days)
**Background Audio Configuration**:
```xml
<!-- ios/Runner/Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>background-processing</string>
</array>
```

**AVAudioSession Setup**:
```swift
class AudioSessionManager {
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
    }
}
```

**Deliverables**:
- [ ] Background audio configuration
- [ ] AVAudioSession setup
- [ ] Background task management
- [ ] App lifecycle handling

### 4.4 Core App Features
**Duration**: 6-7 days

**Key Features**:

1. **Device Registration & Setup**
   - Onboarding flow
   - Permission requests
   - Device calibration
   - Location setup

2. **Privacy Management**
   - Clear privacy explanations
   - Data retention settings
   - Audio upload preferences
   - User consent management

3. **Monitoring Interface**
   - Real-time SPL display
   - Event history
   - Service status indicators
   - Manual controls (start/stop)

4. **Data Synchronization**
   - Offline event storage
   - Batch upload mechanism
   - Sync status indicators
   - Retry logic for failed uploads

**Deliverables**:
- [ ] Complete onboarding flow
- [ ] Privacy-focused UI/UX
- [ ] Real-time monitoring interface
- [ ] Robust sync mechanism

## EPIC 5: Integration & Testing (Weeks 13-14)

### 5.1 End-to-End Integration Testing
**Duration**: 5-6 days

**Test Scenarios**:
- Device registration flow
- Event data pipeline (mobile → backend → frontend)
- Real-time synchronization
- Error recovery and offline handling
- Performance under load

**Deliverables**:
- [ ] Integration test suite
- [ ] API contract testing
- [ ] Mobile app E2E tests
- [ ] Performance benchmarks

### 5.2 Quality Assurance
**Duration**: 3-4 days

**Testing Coverage**:
- Backend unit tests (>90% coverage)
- API integration tests
- Mobile app unit and widget tests
- Security penetration testing
- Load testing for concurrent devices

**Deliverables**:
- [ ] Comprehensive test suite
- [ ] CI/CD pipeline setup
- [ ] Security audit report
- [ ] Performance optimization

## EPIC 6: Deployment & Documentation (Weeks 15-16)

### 6.1 Production Deployment
**Duration**: 4-5 days

**Infrastructure Components**:
- Cloud server setup (Hetzner/DigitalOcean)
- SSL/TLS certificate configuration
- Database backup strategies
- Monitoring and alerting (Prometheus/Grafana)
- Log aggregation and analysis

**Deliverables**:
- [ ] Production deployment scripts
- [ ] SSL certificate automation
- [ ] Backup and recovery procedures
- [ ] Monitoring dashboard
- [ ] CI/CD pipeline

### 6.2 Documentation & Community Setup
**Duration**: 3-4 days

**Documentation Deliverables**:
- [ ] API documentation (OpenAPI/Swagger)
- [ ] Mobile app user guide
- [ ] Deployment documentation
- [ ] Developer contribution guide
- [ ] Privacy policy and GDPR compliance
- [ ] Community guidelines

## Technical Specifications

### Performance Requirements
- **Mobile App**: <3% battery drain per hour in continuous mode
- **Backend**: Handle 1000+ concurrent devices
- **Database**: Sub-second query response for map data
- **Real-time Processing**: <1 minute delay for event detection

### Security Requirements
- **Data Transmission**: HTTPS/TLS 1.3 only
- **Authentication**: JWT with refresh tokens
- **Audio Data**: AES-256 encryption for snippets
- **Privacy**: No raw audio upload by default
- **GDPR Compliance**: Full data portability and deletion

### Scalability Considerations
- **Horizontal Scaling**: Containerized services with load balancing
- **Database Partitioning**: Time-based partitioning for events table
- **Caching Strategy**: Redis for frequently accessed data
- **CDN Integration**: Static assets and map tiles

## Risk Mitigation

### Technical Risks
1. **Mobile Battery Performance**: Implement duty-cycle modes and optimization
2. **AI Model Performance**: Use quantized models and hybrid processing
3. **iOS Background Limitations**: Document constraints and alternatives
4. **Data Volume**: Implement efficient compression and aggregation

### Project Risks
1. **Timeline Delays**: Parallel development and MVP prioritization
2. **Resource Constraints**: Clear scope definition and phased delivery
3. **Community Adoption**: Strong documentation and onboarding experience

## Success Metrics

### Technical Metrics
- [ ] 99.5% uptime for core services
- [ ] <500ms average API response time
- [ ] >12 hours continuous mobile app operation
- [ ] <1% event data loss rate

### Business Metrics
- [ ] 100+ active devices in first 6 months
- [ ] 10+ community contributors
- [ ] 5+ cities with deployed sensors
- [ ] 1+ NGO partnership

## Next Steps

After completing this implementation plan:
1. **Community Building**: Engage with citizen science communities
2. **Hardware Integration**: Support for ESP32 and Raspberry Pi devices
3. **Advanced Analytics**: ML-based pattern recognition and forecasting
4. **Policy Integration**: Tools for regulatory compliance reporting
5. **Global Expansion**: Multi-language support and regional deployments

---

*This implementation plan serves as the foundation for building a comprehensive, privacy-focused, open-source noise monitoring platform that empowers communities to measure and act on environmental noise pollution.*