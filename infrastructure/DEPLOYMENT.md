# Open NoiseNet Deployment Guide

This document provides comprehensive deployment instructions for Open NoiseNet infrastructure.

## 🏗️ Architecture Overview

Open NoiseNet uses a **separated deployment architecture**:

### **Landing Page** (GitHub Pages)
- **Next.js static site** deployed to GitHub Pages
- **Automatic deployment** on `landing_v*` tags
- **Global CDN** via GitHub Pages
- **Free SSL** and custom domain support
- **URL**: https://moinsen-dev.github.io/open_noisenet/

### **Application Infrastructure** (Docker)
- **React Frontend**: Dashboard for noise monitoring
- **FastAPI Backend**: API server with event ingestion and processing
- **PostgreSQL + TimescaleDB**: Time-series database for noise events
- **Redis**: Message broker for Celery workers
- **Celery Workers**: Background processing for audio analysis and ML
- **Nginx**: Reverse proxy for internal routing
- **Optional**: Prometheus + Grafana for monitoring

---

## 🌐 Landing Page Deployment (GitHub Pages)

The landing page is deployed separately using GitHub Actions and hosted on GitHub Pages.

### Automatic Deployment

1. **Create a landing page release tag**:
   ```bash
   git tag landing_v0.2.0
   git push origin landing_v0.2.0
   ```

2. **GitHub Actions automatically**:
   - Builds Next.js with static export
   - Deploys to GitHub Pages
   - Available at: https://moinsen-dev.github.io/open_noisenet/

### Custom Domain Setup

To use a custom domain (e.g., `opennoisenet.org`):

1. **Configure GitHub Pages**:
   - Go to repository Settings → Pages
   - Add your custom domain
   - Enable "Enforce HTTPS"

2. **Update Next.js configuration**:
   ```typescript
   // landing/next.config.ts
   const nextConfig: NextConfig = {
     output: 'export',
     trailingSlash: true,
     images: { unoptimized: true },
     // Remove basePath and assetPrefix for custom domains
   };
   ```

3. **Add CNAME file**:
   ```bash
   # Add to landing/public/CNAME
   echo "opennoisenet.org" > landing/public/CNAME
   ```

### Local Development

```bash
cd landing/
pnpm install
pnpm dev
# Available at http://localhost:3000
```

---

## 🚀 Application Infrastructure Deployment

The backend API and frontend dashboard are deployed together using Docker.

### Option 1: Coolify (Recommended)

Coolify is the simplest deployment method, providing automated deployments with GitHub integration.

### Prerequisites

- Coolify instance set up on your server
- GitHub repository access
- Domain name pointed to your server

### 1. Environment Configuration

Copy `.env.coolify` to your Coolify project environment:

```bash
# Application
ENVIRONMENT=production
SECRET_KEY=your-super-secret-production-key-change-this-immediately

# Database Configuration
POSTGRES_DB=noisenet
POSTGRES_USER=noisenet
POSTGRES_PASSWORD=your-secure-postgres-password
POSTGRES_HOST_AUTH_METHOD=trust

# Redis Configuration
REDIS_PASSWORD=your-secure-redis-password

# API Configuration - Coolify handles domain/SSL
CORS_ORIGINS=*
REACT_APP_API_URL=/api

# External Services
REACT_APP_MAPBOX_TOKEN=your-mapbox-token

# Node.js Production
NODE_ENV=production
```

### 2. Coolify Project Setup

1. **Create New Project** in Coolify
2. **Connect GitHub Repository**: `https://github.com/your-username/open_noisenet`
3. **Select Branch**: `main` or `develop`
4. **Set Build Configuration**:
   - **Build Type**: Docker Compose
   - **Docker Compose File**: `docker-compose.coolify.yml`
   - **Port**: 80 (Nginx)

### 3. Domain Configuration

1. **Set Domain**: Configure your domain in Coolify project settings
2. **SSL Certificate**: Coolify automatically provisions SSL with Let's Encrypt
3. **Custom Domains**: Add additional domains if needed

### 4. Database Initialization

The PostgreSQL container automatically initializes with:
- TimescaleDB extensions
- Required database schema from `infrastructure/postgres/init.sql`

### 5. Deployment

1. **Deploy**: Click "Deploy" in Coolify dashboard
2. **Monitor**: Watch deployment logs for any issues
3. **Verify**: Check all services are healthy via Coolify service status

### 6. Post-Deployment

- **React app**: `https://your-domain.com/app`
- **API**: `https://your-domain.com/api`
- **Health check**: `https://your-domain.com/api/health`

---

## ⚙️ Deployment Option 2: Traditional Docker Compose

For manual deployment on your own infrastructure.

### Prerequisites

- Docker and Docker Compose installed
- Server with sufficient resources (2GB RAM minimum)
- Domain name and SSL certificates (optional)

### 1. Clone Repository

```bash
git clone https://github.com/your-username/open_noisenet.git
cd open_noisenet
```

### 2. Environment Configuration

```bash
# Copy and edit environment file
cp .env.example .env
nano .env
```

Required environment variables:
```bash
# Database
POSTGRES_DB=noisenet
POSTGRES_USER=noisenet
POSTGRES_PASSWORD=secure_password_here
REDIS_PASSWORD=secure_redis_password

# Application
SECRET_KEY=your-secret-key-here
ENVIRONMENT=production
CORS_ORIGINS=https://your-domain.com

# External Services
REACT_APP_MAPBOX_TOKEN=your-mapbox-token
REACT_APP_API_URL=https://your-domain.com/api

# Ports (optional - defaults provided)
HTTP_PORT=80
HTTPS_PORT=443
BACKEND_PORT=8000
FRONTEND_PORT=3001
```

### 3. SSL Configuration (Production)

For HTTPS support, place your SSL certificates in `infrastructure/nginx/ssl/`:

```bash
mkdir -p infrastructure/nginx/ssl
# Copy your certificate files:
# - certificate.crt
# - private.key
```

Update `infrastructure/nginx/production.conf` with your certificate paths.

### 4. Deployment

```bash
# Build and start all services
docker-compose up -d

# Check service health
docker-compose ps
docker-compose logs

# View specific service logs
docker-compose logs backend
docker-compose logs frontend
```

### 5. Database Migration

```bash
# Initialize TimescaleDB extensions (automatically done via init.sql)
docker-compose exec postgres psql -U noisenet -d noisenet -c "SELECT * FROM pg_extension;"
```

### 6. Service Verification

- **React App**: `http://localhost:3001`
- **API**: `http://localhost:8000`
- **API Health**: `http://localhost:8000/health`
- **Prometheus**: `http://localhost:9090` (if enabled)
- **Grafana**: `http://localhost:3002` (if enabled)

---

## ☁️ Deployment Option 3: Terraform (Google Cloud)

For enterprise-grade cloud deployment with Infrastructure as Code.

### Prerequisites

- Google Cloud Project with billing enabled
- Terraform installed locally
- `gcloud` CLI configured

### 1. Google Cloud Setup

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com
```

### 2. Terraform Configuration

The repository includes example Terraform configuration at `terraform-example.tf`.

Create a new directory for your deployment:

```bash
mkdir infrastructure/terraform
cd infrastructure/terraform
```

Create `terraform.tf`:
```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

Create `variables.tf`:
```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west3"  # Frankfurt for GDPR compliance
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}
```

### 3. Cloud Run Services

Add to your Terraform configuration:

```hcl
# Cloud Run for Landing Page
resource "google_cloud_run_service" "landing" {
  name     = "noisenet-landing"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/noisenet-landing:latest"
        ports {
          container_port = 3000
        }
        env {
          name  = "NODE_ENV"
          value = "production"
        }
      }
    }
  }
}

# Cloud Run for Backend API
resource "google_cloud_run_service" "backend" {
  name     = "noisenet-backend"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/noisenet-backend:latest"
        ports {
          container_port = 8000
        }
        env {
          name  = "DATABASE_URL"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_url.id
              key  = "latest"
            }
          }
        }
        env {
          name  = "REDIS_URL"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.redis_url.id
              key  = "latest"
            }
          }
        }
      }
    }
  }
}
```

### 4. Database Configuration

```hcl
# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "noisenet_db" {
  name             = "noisenet-db"
  database_version = "POSTGRES_14"
  region           = var.region
  deletion_protection = false

  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled    = true
      start_time = "03:00"
      backup_retention_settings {
        retained_backups = 7
      }
    }
    
    ip_configuration {
      ipv4_enabled = false
      private_network = google_compute_network.noisenet_vpc.self_link
      require_ssl = true
    }

    database_flags {
      name  = "shared_preload_libraries"
      value = "timescaledb"
    }
  }
}

resource "google_sql_database" "noisenet" {
  name     = "noisenet"
  instance = google_sql_database_instance.noisenet_db.name
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_sql_user" "noisenet_user" {
  name     = "noisenet"
  instance = google_sql_database_instance.noisenet_db.name
  password = random_password.db_password.result
}
```

### 5. Redis (Memory Store)

```hcl
resource "google_redis_instance" "noisenet_redis" {
  name           = "noisenet-redis"
  memory_size_gb = 1
  region         = var.region
  tier           = "BASIC"

  authorized_network = google_compute_network.noisenet_vpc.id
  redis_version      = "REDIS_7_0"
  
  auth_enabled = true
}
```

### 6. Secret Management

```hcl
resource "google_secret_manager_secret" "db_url" {
  secret_id = "database-url"
}

resource "google_secret_manager_secret_version" "db_url" {
  secret      = google_secret_manager_secret.db_url.id
  secret_data = "postgresql://${google_sql_user.noisenet_user.name}:${random_password.db_password.result}@${google_sql_database_instance.noisenet_db.private_ip_address}/noisenet"
}

resource "google_secret_manager_secret" "redis_url" {
  secret_id = "redis-url"
}

resource "google_secret_manager_secret_version" "redis_url" {
  secret      = google_secret_manager_secret.redis_url.id
  secret_data = "redis://:${google_redis_instance.noisenet_redis.auth_string}@${google_redis_instance.noisenet_redis.host}:${google_redis_instance.noisenet_redis.port}"
}
```

### 7. Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="project_id=YOUR_PROJECT_ID" -var="domain_name=your-domain.com"

# Apply configuration
terraform apply -var="project_id=YOUR_PROJECT_ID" -var="domain_name=your-domain.com"
```

### 8. Build and Push Images

```bash
# Build and push Docker images to Google Container Registry
docker build -t gcr.io/YOUR_PROJECT_ID/noisenet-landing ./landing
docker push gcr.io/YOUR_PROJECT_ID/noisenet-landing

docker build -t gcr.io/YOUR_PROJECT_ID/noisenet-backend ./backend
docker push gcr.io/YOUR_PROJECT_ID/noisenet-backend

docker build -t gcr.io/YOUR_PROJECT_ID/noisenet-frontend ./frontend
docker push gcr.io/YOUR_PROJECT_ID/noisenet-frontend
```

---

## 🔧 Configuration Reference

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `ENVIRONMENT` | Application environment | Yes | `development` |
| `SECRET_KEY` | FastAPI secret key | Yes | - |
| `DATABASE_URL` | PostgreSQL connection string | Yes | - |
| `REDIS_URL` | Redis connection string | Yes | - |
| `CORS_ORIGINS` | Allowed CORS origins | No | `*` |
| `REACT_APP_API_URL` | Frontend API base URL | Yes | `/api` |
| `REACT_APP_MAPBOX_TOKEN` | Mapbox API token | No | - |
| `NODE_ENV` | Node.js environment | No | `development` |

### Service Ports

| Service | Internal Port | External Port | Description |
|---------|---------------|---------------|-------------|
| Frontend | 3000 | 3001 | React dashboard |
| Backend | 8000 | 8000 | FastAPI server |
| PostgreSQL | 5432 | 5432 | Database |
| Redis | 6379 | 6379 | Cache/Queue |
| Nginx | 80/443 | 80/443 | Reverse proxy |
| Prometheus | 9090 | 9090 | Metrics |
| Grafana | 3000 | 3002 | Monitoring |

### Health Checks

All services include health check endpoints:

- **Backend**: `GET /health`
- **Frontend**: `GET /` (HTTP 200)
- **Landing**: `GET /` (HTTP 200)
- **Database**: `pg_isready`
- **Redis**: `redis-cli ping`

---

## 🔍 Monitoring and Troubleshooting

### Service Logs

#### Coolify
- Access logs through Coolify dashboard
- Real-time log streaming available
- Service-specific log filtering

#### Docker Compose
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f postgres
```

#### Terraform/GCP
```bash
# Cloud Run logs
gcloud logs tail projects/YOUR_PROJECT_ID/logs/run.googleapis.com%2Frequest_log

# Cloud SQL logs
gcloud sql operations list --instance=noisenet-db
```

### Common Issues

1. **Database Connection Failed**
   - Check PostgreSQL container health
   - Verify environment variables
   - Ensure TimescaleDB extension loaded

2. **Frontend API Errors**
   - Check CORS origins configuration
   - Verify API URL in frontend build
   - Ensure backend service is healthy

3. **SSL Certificate Issues**
   - Verify certificate files exist and are valid
   - Check Nginx configuration
   - Ensure domain DNS is correctly configured

4. **Memory/Performance Issues**
   - Monitor container resource usage
   - Check Celery worker performance
   - Review database query performance

### Performance Optimization

1. **Database**
   - Enable TimescaleDB compression for older data
   - Create appropriate indexes for time-series queries
   - Configure connection pooling

2. **Caching**
   - Implement Redis caching for frequently accessed data
   - Use CDN for static assets
   - Enable browser caching headers

3. **Scaling**
   - Scale Celery workers based on queue length
   - Use read replicas for database queries
   - Implement horizontal scaling for API servers

---

## 🔐 Security Considerations

### Production Security Checklist

- [ ] **Environment Variables**: All secrets stored securely (not in code)
- [ ] **Database**: Strong passwords, SSL connections enabled
- [ ] **API**: Rate limiting and authentication implemented
- [ ] **HTTPS**: SSL certificates configured and auto-renewal enabled
- [ ] **CORS**: Restrictive origins (not `*` in production)
- [ ] **Firewall**: Only necessary ports exposed
- [ ] **Updates**: Regular dependency and security updates
- [ ] **Backups**: Automated database backups configured
- [ ] **Monitoring**: Error tracking and alerting set up

### GDPR Compliance

Open NoiseNet includes privacy-first design:

- **No audio recording by default**: Only SPL measurements stored
- **Optional encrypted audio**: 7-day retention with user consent
- **Anonymized location data**: Precision limited to protect privacy
- **Data portability**: Export functionality for user data
- **Right to deletion**: Complete data removal capabilities

---

## 📚 Additional Resources

### Documentation Links

- [Technical Architecture](./technology.md)
- [API Documentation](./docs/api.md)
- [Development Guide](./CONTRIBUTING.md)
- [Project Requirements](./prd.md)

### External Resources

- [Coolify Documentation](https://coolify.io/docs)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [TimescaleDB Configuration](https://docs.timescale.com/timescaledb/latest/)

---

## 🆘 Support

For deployment issues and questions:

1. **GitHub Issues**: [Create an issue](https://github.com/your-username/open_noisenet/issues)
2. **GitHub Discussions**: [Community support](https://github.com/your-username/open_noisenet/discussions)
3. **Documentation**: Check project wiki and documentation files

---

**Ready to deploy Open NoiseNet? Choose your preferred method above and start building the world's first open-source noise monitoring network! 🌍🔊**