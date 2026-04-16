#!/bin/bash

# OpenNoiseNet Setup Script
# This script sets up the development environment for the OpenNoiseNet project

set -e

echo "🔧 OpenNoiseNet Development Setup"
echo "================================="

# Check if required tools are installed
check_requirements() {
    echo "📋 Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose plugin
    if ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose plugin is not installed. Please install Docker Desktop or the Compose plugin first."
        exit 1
    fi
    
    # Check Node.js for frontend
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js is not installed. Please install Node.js first."
        exit 1
    fi
    
    # Check Python and uv for backend
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python 3 is not installed. Please install Python 3 first."
        exit 1
    fi

    if ! command -v uv &> /dev/null; then
        echo "❌ uv is not installed. Please install uv first: https://docs.astral.sh/uv/"
        exit 1
    fi
    
    # Check Flutter for mobile
    if ! command -v flutter &> /dev/null; then
        echo "⚠️  Flutter is not installed. Mobile development will not be available."
        echo "   You can install Flutter later from https://flutter.dev"
    else
        echo "✅ Flutter is installed"
    fi
    
    echo "✅ All required tools are available"
}

# Setup environment files
setup_environment() {
    echo "📁 Setting up environment files..."
    
    if [ ! -f .env ]; then
        echo "📝 Creating .env file from template..."
        cp .env.example .env
        echo "⚠️  Please edit .env file and set appropriate values"
    else
        echo "✅ .env file already exists"
    fi
}

# Initialize backend
setup_backend() {
    echo "🐍 Setting up Python backend..."
    
    cd backend
    
    # Install dependencies
    echo "📦 Installing Python dependencies..."
    uv sync --extra dev
    
    echo "✅ Backend setup complete"
    cd ..
}

# Initialize frontend
setup_frontend() {
    echo "⚛️  Setting up React frontend..."
    
    cd frontend
    
    # Install dependencies
    echo "📦 Installing Node.js dependencies..."
    npm ci
    
    echo "✅ Frontend setup complete"
    cd ..
}

# Initialize mobile app (if Flutter is available)
setup_mobile() {
    if command -v flutter &> /dev/null; then
        echo "📱 Setting up Flutter mobile app..."
        
        cd mobile
        
        # Get Flutter dependencies
        echo "📦 Installing Flutter dependencies..."
        flutter pub get
        
        # Generate code (if needed)
        if [ -f "build_runner.yaml" ]; then
            echo "🔧 Running code generation..."
            flutter packages pub run build_runner build
        fi
        
        echo "✅ Mobile app setup complete"
        cd ..
    else
        echo "⏭️  Skipping mobile setup (Flutter not installed)"
    fi
}

# Build and start services
start_services() {
    echo "🚀 Building and starting Docker services..."
    
    # Build and start services
    docker compose up --build -d postgres redis
    
    # Wait for database to be ready
    echo "⏳ Waiting for database to be ready..."
    sleep 10
    
    # Run database migrations
    echo "🗄️  Running database migrations..."
    cd backend
    uv run alembic upgrade head
    cd ..
    
    # Start all services
    echo "🔄 Starting all services..."
    docker compose up -d
    
    echo "✅ All services started successfully!"
}

# Display helpful information
show_info() {
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "📋 Service URLs:"
    echo "  Backend API:     http://localhost:8100"
    echo "  API Docs:        http://localhost:8100/docs"
    echo "  Frontend:        http://localhost:3100"
    echo "  Database:        localhost:5432"
    echo "  Redis:           localhost:6379"
    echo "  Grafana:         http://localhost:3001 (admin/admin)"
    echo "  Prometheus:      http://localhost:9090"
    echo ""
    echo "🔧 Useful commands:"
    echo "  View logs:       docker compose logs -f"
    echo "  Stop services:   docker compose down"
    echo "  Restart:         docker compose restart"
    echo "  Reset database:  docker compose down -v && docker compose up -d"
    echo ""
    echo "📖 Next steps:"
    echo "  1. Edit .env file with your configuration"
    echo "  2. Check all services are running: docker compose ps"
    echo "  3. Visit http://localhost:3100 to see the dashboard"
    echo "  4. Check API documentation at http://localhost:8100/docs"
    echo ""
}

# Main execution
main() {
    check_requirements
    setup_environment
    setup_backend
    setup_frontend
    setup_mobile
    start_services
    show_info
}

# Run main function
main "$@"
