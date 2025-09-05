#!/bin/bash

# Production Deployment Script for OpenNoiseNet
# This script handles production deployment

set -e

echo "🚀 OpenNoiseNet Production Deployment"
echo "====================================="

# Configuration
DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-production}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Load environment variables
load_environment() {
    if [ -f ".env.${DEPLOYMENT_ENV}" ]; then
        echo "📁 Loading environment from .env.${DEPLOYMENT_ENV}"
        export $(cat ".env.${DEPLOYMENT_ENV}" | xargs)
    elif [ -f ".env" ]; then
        echo "📁 Loading environment from .env"
        export $(cat .env | xargs)
    else
        echo "❌ No environment file found"
        exit 1
    fi
}

# Pre-deployment checks
pre_deployment_checks() {
    echo "🔍 Running pre-deployment checks..."
    
    # Check if required environment variables are set
    required_vars=("POSTGRES_PASSWORD" "SECRET_KEY" "JWT_SECRET_KEY")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "❌ Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Not in a git repository"
        exit 1
    fi
    
    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        echo "⚠️  Warning: You have uncommitted changes"
        echo "   Commit your changes before deploying to production"
        if [ "$DEPLOYMENT_ENV" = "production" ]; then
            exit 1
        fi
    fi
    
    echo "✅ Pre-deployment checks passed"
}

# Build Docker images
build_images() {
    echo "🏗️  Building Docker images..."
    
    # Get git commit hash for tagging
    GIT_HASH=$(git rev-parse --short HEAD)
    BUILD_TAG="${IMAGE_TAG}-${GIT_HASH}"
    
    # Build backend image
    echo "🐍 Building backend image..."
    docker build -t "noisenet-backend:${BUILD_TAG}" ./backend
    
    # Build frontend image
    echo "⚛️  Building frontend image..."
    docker build -t "noisenet-frontend:${BUILD_TAG}" ./frontend
    
    # Tag as latest
    docker tag "noisenet-backend:${BUILD_TAG}" "noisenet-backend:latest"
    docker tag "noisenet-frontend:${BUILD_TAG}" "noisenet-frontend:latest"
    
    echo "✅ Docker images built successfully"
    export BUILD_TAG
}

# Push images to registry (if configured)
push_images() {
    if [ -n "$DOCKER_REGISTRY" ]; then
        echo "📤 Pushing images to registry..."
        
        # Tag and push backend
        docker tag "noisenet-backend:${BUILD_TAG}" "${DOCKER_REGISTRY}/noisenet-backend:${BUILD_TAG}"
        docker tag "noisenet-backend:latest" "${DOCKER_REGISTRY}/noisenet-backend:latest"
        docker push "${DOCKER_REGISTRY}/noisenet-backend:${BUILD_TAG}"
        docker push "${DOCKER_REGISTRY}/noisenet-backend:latest"
        
        # Tag and push frontend
        docker tag "noisenet-frontend:${BUILD_TAG}" "${DOCKER_REGISTRY}/noisenet-frontend:${BUILD_TAG}"
        docker tag "noisenet-frontend:latest" "${DOCKER_REGISTRY}/noisenet-frontend:latest"
        docker push "${DOCKER_REGISTRY}/noisenet-frontend:${BUILD_TAG}"
        docker push "${DOCKER_REGISTRY}/noisenet-frontend:latest"
        
        echo "✅ Images pushed to registry"
    else
        echo "⏭️  Skipping image push (no registry configured)"
    fi
}

# Backup database
backup_database() {
    if [ "$DEPLOYMENT_ENV" = "production" ]; then
        echo "💾 Creating database backup..."
        
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"
        
        # Create backup
        docker-compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_FILE"
        
        # Compress backup
        gzip "$BACKUP_FILE"
        
        echo "✅ Database backup created: ${BACKUP_FILE}.gz"
    else
        echo "⏭️  Skipping database backup (not production)"
    fi
}

# Deploy services
deploy_services() {
    echo "🚀 Deploying services..."
    
    # Use production docker-compose file if available
    COMPOSE_FILE="docker-compose.yml"
    if [ -f "docker-compose.${DEPLOYMENT_ENV}.yml" ]; then
        COMPOSE_FILE="docker-compose.${DEPLOYMENT_ENV}.yml"
        echo "📁 Using compose file: $COMPOSE_FILE"
    fi
    
    # Deploy with zero-downtime strategy
    if [ "$DEPLOYMENT_ENV" = "production" ]; then
        echo "🔄 Performing zero-downtime deployment..."
        
        # Update database first
        docker-compose -f "$COMPOSE_FILE" up -d postgres redis
        sleep 10
        
        # Run migrations
        echo "🗄️  Running database migrations..."
        docker-compose -f "$COMPOSE_FILE" run --rm backend alembic upgrade head
        
        # Update backend services
        docker-compose -f "$COMPOSE_FILE" up -d --no-deps backend celery celery-beat
        
        # Wait for backend to be healthy
        echo "⏳ Waiting for backend to be healthy..."
        timeout 60 bash -c 'until curl -f http://localhost:8000/health; do sleep 2; done'
        
        # Update frontend and nginx
        docker-compose -f "$COMPOSE_FILE" up -d --no-deps frontend nginx
        
    else
        # Simple deployment for non-production
        docker-compose -f "$COMPOSE_FILE" up -d
    fi
    
    echo "✅ Services deployed successfully"
}

# Post-deployment verification
post_deployment_verification() {
    echo "🔍 Running post-deployment verification..."
    
    # Check service health
    services=("backend" "frontend" "postgres" "redis")
    
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            echo "✅ $service is running"
        else
            echo "❌ $service is not running"
            exit 1
        fi
    done
    
    # Check API health
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Backend API is healthy"
    else
        echo "❌ Backend API health check failed"
        exit 1
    fi
    
    # Check frontend
    if curl -f http://localhost:3000 > /dev/null 2>&1; then
        echo "✅ Frontend is accessible"
    else
        echo "❌ Frontend is not accessible"
        exit 1
    fi
    
    echo "✅ Post-deployment verification passed"
}

# Rollback function
rollback() {
    echo "⏪ Rolling back deployment..."
    
    # Stop current services
    docker-compose down
    
    # Restore database if backup exists
    if [ -f "$BACKUP_DIR/backup-*.sql.gz" ]; then
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/backup-*.sql.gz | head -1)
        echo "📁 Restoring database from: $LATEST_BACKUP"
        
        gunzip -c "$LATEST_BACKUP" | docker-compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
    fi
    
    # Start services with previous images
    # This would require keeping track of previous image tags
    echo "❌ Rollback completed - manual intervention may be required"
}

# Clean up old images and backups
cleanup() {
    echo "🧹 Cleaning up old resources..."
    
    # Remove old Docker images (keep last 5)
    docker images "noisenet-*" --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" | \
    tail -n +2 | head -n -5 | awk '{print $1}' | xargs -r docker rmi || true
    
    # Remove old backups (keep last 10)
    find "$BACKUP_DIR" -name "backup-*.sql.gz" -type f | \
    sort -r | tail -n +11 | xargs -r rm || true
    
    echo "✅ Cleanup completed"
}

# Show deployment status
show_status() {
    echo "📊 Deployment Status"
    echo "==================="
    
    echo "Git commit: $(git rev-parse --short HEAD)"
    echo "Git branch: $(git branch --show-current)"
    echo "Environment: $DEPLOYMENT_ENV"
    echo ""
    
    echo "Services:"
    docker-compose ps
    
    echo ""
    echo "Recent logs:"
    docker-compose logs --tail=10
}

# Main deployment function
main() {
    case "${1:-deploy}" in
        "deploy")
            load_environment
            pre_deployment_checks
            build_images
            push_images
            backup_database
            deploy_services
            post_deployment_verification
            cleanup
            show_status
            echo ""
            echo "🎉 Deployment completed successfully!"
            ;;
        "rollback")
            load_environment
            rollback
            ;;
        "status")
            load_environment
            show_status
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            echo "Usage: $0 [deploy|rollback|status|cleanup]"
            echo ""
            echo "Commands:"
            echo "  deploy    Deploy the application (default)"
            echo "  rollback  Rollback to previous version"
            echo "  status    Show deployment status"
            echo "  cleanup   Clean up old images and backups"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'echo "❌ Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"